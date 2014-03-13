-module(namy).
-export([test/2]).

test(Host, Resolver) ->
    io:format("Client: looking up ~w~n", [Host]),
    Resolver ! {request, self(), Host},
    receive
        {reply, {host, Pid}} ->
            io:format("Client: sending ping to host ~w ... ", [Host]),
            Pid ! {ping, self()},
            receive
                pong ->
                    io:format("Client: pong reply~n")
            after 1000 ->
                io:format("Client: no reply~n")
            end;
        {reply, unknown} ->
            io:format("Client: unknown host~n", []),
            ok;
        Strange ->
            io:format("Client: strange reply from resolver: ~w~n", [Strange]),
            ok
    after 1000 ->
        io:format("Client: no reply from resolver~n", []),
        ok
    end.