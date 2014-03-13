-module(gms1).
-export([start/1, start/2]).

start(Name) ->
    Self = self(),
    spawn_link(fun()-> init(Name, Self) end).

init(Name, Master) ->
    leader(Name, Master, []).

start(Name, Grp) ->
    Self = self(),
    spawn_link(fun()-> init(Name, Grp, Self) end).    

init(Name, Grp, Master) ->
    Self = self(), 
    Grp ! {join, Self},
    receive
        {view, State, Leader, Peers} ->
            Master ! {ok, State},
            slave(Name, Master, Leader, Peers)
    end.

leader(Name, Master, Peers) ->    
    receive
        {mcast, Msg} ->
            bcast(Name, ..., ...),  %% TODO: COMPLETE
            %% TODO: ADD SOME CODE
            leader(Name, Master, Peers);
        {join, Peer} ->
            %% TODO: ADD SOME CODE
            joining(Name, ..., ..., ...);  %% TODO: COMPLETE
        stop ->
            ok;
        Error ->
            io:format("leader ~w: strange message ~w~n", [Name, Error])
    end.
    
bcast(_, Msg, Nodes) ->
    lists:foreach(fun(Node) -> Node ! Msg end, Nodes).

joining(Name, Master, Peer, Peers) ->
    receive 
        {ok, State} ->
            NewPeers = lists:append(Peers, [Peer]),           
            bcast(Name, {view, State, self(), NewPeers}, NewPeers),
            leader(Name, Master, NewPeers);
        stop ->
            ok
    end.

slave(Name, Master, Leader, Peers) ->    
    receive
        {mcast, Msg} ->
            %% TODO: ADD SOME CODE
            slave(Name, Master, Leader, Peers);
        {join, Peer} ->
            %% TODO: ADD SOME CODE
            slave(Name, Master, Leader, Peers);
        {msg, Msg} ->
            %% TODO: ADD SOME CODE
            slave(Name, Master, Leader, Peers);
        {view, _, _, View} ->
            slave(Name, Master, Leader, View);           
        stop ->
            ok;
        Error ->
            io:format("slave ~w: strange message ~w~n", [Name, Error])
    end.