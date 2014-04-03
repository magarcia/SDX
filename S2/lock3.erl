-module(lock3).
-export([init/2]).

% We start initializing the clock to zero.
init(Id, Nodes) ->
    Clock = 0,
    open(Nodes, Id, Clock).

open(Nodes, Id, Clock) ->
    receive
        % We receive a take signal from the worker, we send a request signal to
        % the other nodes and we wait for the ok signal
        {take, Master} ->
            Refs = requests(Nodes, Id, Clock),
            wait(Nodes, Master, Refs, [], Id, Clock, Clock);

        % We receive a request signal from a node with reference ref, with id _
        % and clock Rclock. We update the clock with the max value of the two
        % clocks plus one, and send an ok signal with the new clock.
        % We keep in initial status, but with the new clock value.
        {request, From,  Ref, _, Rclock} ->
            NewClock = lists:max([Clock, Rclock]) + 1,
            From ! {ok, Ref, NewClock},
            open(Nodes, Id, NewClock);

        stop ->
            ok
    end.

% We send a request signal to each node. We send our PID, reference, id and
% clock.
requests(Nodes, Id, Clock) ->
    lists:map(
      fun(P) ->
        R = make_ref(),
        P ! {request, self(), R, Id, Clock},
        R
      end,
      Nodes).

% We enter in the wait status with all the necessary ok signals received.
% We send a taken signal to the worker and go inside critical section.
wait(Nodes, Master, [], Waiting, Id, Clock, _) ->
    Master ! taken,
    held(Nodes, Waiting, Id, Clock);


% We enter in the wait status waiting for all the necessary ok signals received.
% Clock -> Max clock seen.
% OurClock -> Our clock when send the request signal.
wait(Nodes, Master, Refs, Waiting, Id, Clock, OurClock) ->
    receive
        % We received a request signal asking for access to critical section.
        {request, From, Ref, Rid, Rclock} ->

            % Update the max clock seen with the clock received.
            NewClock = lists:max([Clock, Rclock]) + 1,

            if
                % If our clock is greater than the clock received, we send an ok
                % signal and keep in waiting status with the new max clock.
                OurClock > Rclock ->
                    From ! {ok, Ref, NewClock},
                    wait(Nodes, Master, Refs, Waiting, Id, NewClock, OurClock);

                % If the clock received is equal that our clock, resolve the
                % request by id priority.
                OurClock == Rclock ->
                    if

                        % If the request have an id lower than our id, we send
                        % it an ok signal with the new max clock.
                        Id > Rid ->
                            From ! {ok, Ref, NewClock},
                            wait(Nodes, Master, Refs, Waiting, Id, NewClock, OurClock);

                        % If our id is lower, we add this request to the waiting queue.
                        true ->
                            wait(Nodes, Master, Refs, [{From, Ref}|Waiting], Id, NewClock, OurClock)
                    end;

                % If our clock is lower, we add this request to the waiting queue.
                true ->
                    wait(Nodes, Master, Refs, [{From, Ref}|Waiting], Id, NewClock, OurClock)
            end;

        % When we receive an ok signal, we update the max clock value, remove
        % that node from the reference list and keep in wait status.
        {ok, Ref, Rclock} ->
            NewClock = lists:max([Clock, Rclock]) + 1,
            NewRefs = lists:delete(Ref, Refs),
            wait(Nodes, Master, NewRefs, Waiting, Id, NewClock, OurClock);

        % When we receive a release signal from the worker, we send an ok signal
        % to each node in the waiting queue and we go back to the initial state
        % with the new max clock value.
        release ->
            ok(Waiting, Clock),
            open(Nodes, Id, Clock)
    end.

% We send an ok signal to each node in the waiting queue.
ok(Waiting, Clock) ->
    lists:map(
      fun({F,R}) ->
        F ! {ok, R, Clock}
      end,
      Waiting).

% We go inside critical section.
held(Nodes, Waiting, Id, Clock) ->
    receive
        % We received a request signal, so we add the node to the waiting queue,
        % update the clock value and we keep in the critical section.
        {request, From, Ref, _, Rclock} ->
            NewClock = lists:max([Clock, Rclock]) + 1,
            held(Nodes, [{From, Ref}|Waiting], Id, NewClock);

        % We received a release signal from the worker, we release the critical
        % section and send an ok signal to each node in the waiting queue.
        % We go back to the initial state.
        release ->
            ok(Waiting, Clock),
            open(Nodes, Id, Clock)
    end.