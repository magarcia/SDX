-module(lock2).
-export([init/2]).

init(Id, Nodes) ->
    open(Nodes, Id).

open(Nodes, Id) ->
    receive
        % We receive a take signal from the worker, we send a request signal to
        % the other nodes and we wait for the ok signal
        {take, Master} ->
            Refs = requests(Nodes, Id),
            wait(Nodes, Master, Refs, [], Id);

        % We receive a request signal from a node with reference ref and id _.
        % We don't need the id for send it the ok signal
        {request, From,  Ref, _} ->
            From ! {ok, Ref},
            open(Nodes, Id);

        stop ->
            ok
    end.

% We send a request signal to each node. We send our PID, reference and id.
requests(Nodes, Id) ->
    lists:map(
      fun(P) ->
        R = make_ref(),
        P ! {request, self(), R, Id},
        R
      end,
      Nodes).

% We enter in the wait status with all the necessary ok signals received.
% We send a taken signal to the worker and go inside critical section.
wait(Nodes, Master, [], Waiting, Id) ->
    Master ! taken,
    held(Nodes, Waiting, Id);

% We enter in the wait status waiting for all the necessary ok signals received.
wait(Nodes, Master, Refs, Waiting, Id) ->
    receive
        % We received a request signal asking for access to critical section.
        {request, From, Ref, Rid} ->
            if
                % If the request have an id lower than our id, we send it an ok signal.
                % We send a request signal to that node and we keep in wait status.
                Id > Rid ->
                    From ! {ok, Ref},
                    Ref2 = requests([From], Id),
                    NewRefs = lists:append(Ref2, Refs),
                    wait(Nodes, Master, NewRefs, Waiting, Id);

                % If our id is lower, we add this request to the waiting queue.
                true ->
                    wait(Nodes, Master, Refs, [{From, Ref}|Waiting], Id)
            end;

        % When we receive an ok signal, we remove that node from the reference
        % list and keep in wait status.
        {ok, Ref} ->
            NewRefs = lists:delete(Ref, Refs),
            wait(Nodes, Master, NewRefs, Waiting, Id);

        % When we receive a release signal from the worker, we send an ok signal
        % to each node in the waiting queue and we go back to the initial state.
        release ->
            ok(Waiting),
            open(Nodes, Id)
    end.

% We send an ok signal to each node in the waiting queue.
ok(Waiting) ->
    lists:map(
      fun({F,R}) ->
        F ! {ok, R}
      end,
      Waiting).

% We go inside critical section.
held(Nodes, Waiting, Id) ->
    receive
        % We received a request signal, so we add the node to the waiting queue
        % and we keep in the critical section.
        {request, From, Ref, _} ->
            held(Nodes, [{From, Ref}|Waiting], Id);

        % We received a release signal from the worker, we release the critical
        % section and send an ok signal to each node in the waiting queue.
        % We go back to the initial state.
        release ->
            ok(Waiting),
            open(Nodes, Id)
    end.