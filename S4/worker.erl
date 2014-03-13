-module(worker).
-export([start/3, start/4]).

-define(change, 20).
-define(color, {0,0,0}).

start(Name, Module, Sleep) ->
    spawn(fun() -> init(Name, Module, Sleep) end).

init(Name, Module, Sleep) ->
    Cast = apply(Module, start, [Name]),
    Color = ?color,
    init_cont(Name, Cast, Color, Sleep).

start(Name, Module, Peer, Sleep) ->
    spawn(fun() -> init(Name, Module, Peer, Sleep) end).

init(Name, Module, Peer, Sleep) ->
    Cast = apply(Module, start, [Name, Peer]),
    receive
        {ok, Color} ->
            init_cont(Name, Cast, Color, Sleep);
        {error, Error} ->
            io:format("error: ~s~n", [Error])
    end.

init_cont(Name, Cast, Color, Sleep) ->
    {A1,A2,A3} = now(),
    random:seed(A1, A2, A3),
    Gui = gui:start(Name, self()),
    Gui ! {color, Color}, 
    worker(Name, Cast, Color, Gui, Sleep),
    Cast ! stop,
    Gui ! stop.

worker(Name, Cast, Color, Gui, Sleep) ->
    Wait = if Sleep == 0 -> 0; true -> random:uniform(Sleep) end,
    receive
        {deliver, {_From, N}} ->
            Color2 = change_color(N, Color),
            Gui ! {color, Color2},
            worker(Name, Cast, Color2, Gui, Sleep);
        {join, Peer} ->
            Cast ! {join, Peer},
            worker(Name, Cast, Color, Gui, Sleep);            
        request ->
            Cast ! {ok, Color},
            worker(Name, Cast, Color, Gui, Sleep);
        stop ->
            ok;
        Error ->
            io:format("strange message: ~w~n", [Error]),
            worker(Name, Cast, Color, Gui, Sleep)
    after Wait ->
            Cast !  {mcast, {Name, random:uniform(?change)}},
            worker(Name, Cast, Color, Gui, Sleep)     
    end.

change_color(N, {R,G,B}) ->
    {G, B, ((R+N) rem 256)}.