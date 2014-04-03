-module(muty_split).
-export([start/3, start/1, stop/0]).

%% @doc Client server
start(BootServer) ->
    ServerPid = spawn(fun() -> init_server(BootServer) end),
    register(myserver, ServerPid).

init_server(BootServer) ->
    BootServer ! {join, node()},
    receive
        {params, Id, Lock, Sleep, Work, Nodes} ->
            run(Id, Lock, Sleep, Work, Nodes)
    end.

%% @doc Master server
start(Lock, Sleep, Work) ->
    io:format("Server muty ~w ~w ~w~n", [Lock, Sleep, Work]),
    ServerPid = spawn(fun() -> init_server(Lock, Sleep, Work, [node()]) end),
    register(myserver, ServerPid).

init_server(Lock, Sleep, Work, Nodes) ->
    receive
        {join, Node} ->
            NewNodes = [Node|Nodes],
            if
                length(NewNodes) == 4 ->
                    broadcast(NewNodes, {params, Lock, Sleep, Work, NewNodes}),
                    run(1, Lock, Sleep, Work, NewNodes);
                true ->
                    init_server(Lock, Sleep, Work, NewNodes)
            end
    end.

%% @doc Broadcast messages to clients
broadcast(PeerList, {params, Lock, Sleep, Work, NewNodes}) ->
    Fun = fun(Peer, Id) -> {myserver, Peer} ! {params, Id, Lock, Sleep, Work, NewNodes} end,
    lists:foldl(Fun, 2, PeerList).


%% @doc Run "local" lock and worker
run(Id, Lock, Sleep, Work, Nodes) ->
    Name = lists:concat(["Beatle ", Id, " ", node()]),
    register(lock, spawn(Lock, init,[Id, get_locks(Nodes)])),
    register(worker,   spawn(worker, init, [Name,  lock, Sleep, Work])),
    ok.

%% @doc Get locks for this node
get_locks(Nodes) ->
    if
        Nodes == [] ->
            [];
        true ->
            [Head|Tail] = Nodes,
            if
                Head == node() ->
                    get_locks(Tail);
                true ->
                    [{lock, Head}|get_locks(Tail)]
            end
    end.

stop() ->
    worker ! stop,
    lock ! stop.
