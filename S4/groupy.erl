-module(groupy).
-export([start/2, stop/0]).

start(Module, Sleep) ->
    Leader = worker:start("P1", Module, Sleep),
    register(a, Leader), 
    register(b, worker:start("P2", Module, Leader, Sleep)),
    register(c, worker:start("P3", Module, Leader, Sleep)),
    register(d, worker:start("P4", Module, Leader, Sleep)),
    register(e, worker:start("P5", Module, Leader, Sleep)).

stop() ->
    a ! stop,
    b ! stop,
    c ! stop,
    d ! stop,
    e ! stop.