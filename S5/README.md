# Namy: a distributed name server

## Introduction
Your task will be to implement a distributed name server similar to DNS. Instead of addresses we will store process identifiers of hosts. Our system will not be able to interoperate with regular DNS servers but it will show you the principles of caching data in a tree structure.

## Architecture
Our architecture will have four kind of nodes:

-  **Servers** are responsible for a domain and hold a set of registered hosts and sub-domain servers. Servers form a tree structure. 
- **Resolvers** are responsible for helping clients find addresses to hosts. Will query servers in an iterative way and keep a cache of answers. 
- **Hosts** are nodes that have a name and are registered in one server. Hosts will reply to ping messages. 
- **Clients** know only the address of a resolver and use it to find addresses of hosts. Will only send a ping message to a host and wait for a reply. 

Separating the tasks of the server and the resolver will make the implemen- tation cleaner and easier to understand. In real life, DNS servers also take on the responsibility of a resolver. 

### A server
This is how we implement a server. This is a vanilla set-up where we spawn a process and register it under the name server. This means that we will only have one server running in each Erlang node. If you want you can modify the code to take an extra argument with the name to register the server under.

```erlang
-module(server).
-export([start/0, start/2, stop/0]).

start() ->
	register(server, spawn(fun()-> init() end)).

start(Domain, Parent) ->
	register(server, spawn(fun()-> init(Domain, Parent) end)).

stop() ->
	server ! stop,
	unregister(server).

init() ->
	io:format("Server: create root domain~n"),
	server([], 0).

init(Domain, Parent) ->
	io:format("Server: create domain ~w at ~w~n", [Domain, Parent]),
	Parent ! {register, Domain, {domain, self()}},
	server([], 0).
```

Note that there are two ways to start a server. Either it will be the root server in our network (use `start/0`) or a server responsible for a sub-domain (use `start/2`). If it is responsible for a sub-domain, the domain name has to be registered in the parent server. Domain names are represented with atoms such as: edu, com, upc, etc. Note that the ’upc server’ will register in the ’edu server’ under the name upc but it does not hold any information that it is responsible for the `[upc,edu]` sub-domain; this is implicit in the tree structure.

The server process will keep a list of key-value entries (`Entries`). The key will be the domain name and the value will be the identifier of the process responsible for that domain. In particular, hosts will register an identifier for- matted as a tuple `{host, Pid}` and name servers as a tuple `{domain, Pid}`. The difference will be used by the resolver to prevent it from sending resolution requests to host nodes.

The server also keeps a time-to-live value (`TTL`) that will be sent with each reply. The value is the number of seconds that the answer will be valid. In real life this is normally set to 24h but to experiment with caching we use seconds instead. The default value is zero seconds, that is, no caching allowed.

```erlang
server(Entries, TTL) ->
	receive
		{request, From, Req}->
			io:format("Server: received request to solve [~w]~n", [Req]),
			Reply = entry:lookup(Req, Entries),
			From ! {reply, Reply, TTL},
			server(Entries, TTL);
		{register, Name, Entry} ->
			Updated = entry:add(Name, Entry, Entries),
			server(Updated, TTL);
		{deregister, Name} ->
			Updated = entry:remove(Name, Entries),
			server(Updated, TTL);
		{ttl, Sec} ->
			server(Entries, Sec);
		status ->
			io:format("Server: List of DNS entries: ~w~n", [Entries]),
			server(Entries, TTL);
		stop ->
			io:format("Server: closing down~n", []),
			ok;
		Error ->
			io:format("Server: reception of strange message ~w~n", [Error]),
			server(Entries, TTL)
	end.
```

Note that when the server receives a request it will try to look it up in its list of entries. The `lookup/2` function will return `unknown` if not found. It does not matter what the result is, the server will not try to find a better answer to the request or a best match. It is up to the resolver to make iterative requests.

**You must implement the `lookup/2` function in an `entry` module, together with the `add/3` and `remove/2` procedures** (hint: you can use `lists:keyfind/3`, `lists:keystore/4`, and `lists:keydelete/3` functions).

Also note that in this implementation there is only one kind of request. We could have divided the registered hosts and sub-domains and explicitly requested either or, perhaps a cleaner design, but we’ll keep things simple.

### A resolver
The resolver is more complex since we will now have a cache to consider and since we will do an **iterative** lookup procedure to find the final answer. We will use a time module (you can find the code in the Appendix) that will help us to determine if a cache entry is valid or not. We will also use a trick and enter a permanent entry in the cache that refers to the root server.

```erlang
-module(resolver).
-export([start/1, stop/0]).
start(Root) ->
    register(resolver, spawn(fun()-> init(Root) end)).
stop() ->
    resolver ! stop,
    unregister(resolver).
init(Root) ->
    Empty = cache:new(),
    Inf = time:inf(),
    Cache = cache:add([], Inf, {domain, Root}, Empty),
    resolver(Cache).
resolver(Cache) ->
    receive
        {request, From, Req}->
            io:format("Resolver: request from ~w to solve ~w~n", [From, Req]),
            {Reply, Updated} = resolve(Req, Cache),
            From ! {reply, Reply},
            resolver(Updated);
status ->
io:format("Resolver: cache content: ~w~n", [Cache]),
            resolver(Cache);
        stop ->
            io:format("Resolver: closing down~n", []),
ok; Error ->
            io:format("Resolver: reception of strange message ~w~n", [Error]),
            resolver(Cache)
end.
```

Note that the resolver only knows the root server (`[]`): it does know in which domain it is working. If it cannot find a better entry in the cache it will send a request to the root server. The requests are of the form `[www, upc, edu]`. If we do not find a match of the whole name in the cache we will try with `[upc, edu]`. If there is no entry for `[upc, edu]` nor for `[edu]` we will find the entry for `[]`, which will give us the address of the root server.

When we contact the root server we ask for an entry for the `edu` domain. We save the answer in the cache and then send a request to the ’edu server’ asking for the `upc` domain, and so on. When we have the address of the `www` host we send the reply back to the client.

The implementation of the `resolve` function is quite intricate and it takes a while to understand why and how it works. Since the resolving of a name can change the cache, the procedure returns both the reply and an updated cache. The idea is now as follows: `lookup/2` will look in the cache and return either `unknown`, `invalid` in case an old value was found, or a valid entry (`Reply`). If the domain name was `unknown` or `invalid`, a recursive procedure takes over, if an entry is found this can be returned directly.

```erlang
resolve(Name, Cache)->
	io:format("Resolve ~w: ", [Name]),
	case cache:lookup(Name, Cache) of
		unknown ->
			io:format("unknown ~n", []),
			recursive(Name, Cache);
		invalid ->
			io:format("invalid ~n", []),
			NewCache = cache:remove(Name, Cache),
			recursive(Name, NewCache);
		Reply ->
			io:format("found ~w~n", [Reply]),
			{Reply, Cache}
	end.
```

The recursive procedure will divide the domain name into two parts. If we are looking for `[www, upc, edu]` we should first look for `[upc, edu]` and then use this value to request an address for `www`. The best way to find an address for `[upc, edu]` is to use the `resolve` procedure.

We now make the assumption that `resolve/2` actually does return something (remember that the cache holds the permanent entry for the root domain `[]`) and that it is either `unknown` or a server entry `{domain, Srv}`. We could have a situation where it returns a host entry `{host, Hst}` but then our setup would be faulty.

```erlang
recursive([Name|Domain], Cache) ->
	io:format("Recursive ~w: ", [Domain]),
	case resolve(Domain, Cache) of
		{unknown, Updated} ->
			io:format("unknown ~n", []),
			{unknown, Updated};
		{{domain, Srv}, Updated} ->
			Srv ! {request, self(), Name},
			io:format("Resolver: sent request to solve [~w] to ~w~n", [Name, Srv]),
			receive
				{reply, unknown, _} ->
					{unknown, Updated};
				{reply, Reply, TTL} ->
					Expire = time:add(time:now(), TTL),
					NewCache = cache:add([Name|Domain], Expire, Reply, Updated),
					{Reply, NewCache}
			end
	end.
```

If the domain `[upc, edu]` turns out to be unknown then there is no way that `[www, upc, edu]` could be known so an `unknown` value can be returned directly. If however, we have a domain name server for `[upc, edu]` we should of course ask this for the address to `www`. We send a request and wait for a reply, whatever we get is the final answer. We return the reply but also update the cache with a new entry for the full name `[www, upc, edu]`.

Left to implement is the lookup procedure in the cache which will be almost identical to the lookup procedure of the server. We must however store the expiration time of each entry and check if the entry is still valid when performing the lookup. **You must implement the `lookup/2` function in a `cache` module, together with the `new/0`, `add/4` and `remove/2` procedures.**

### A host
We create some host only in order to have something to register and something to communicate with. The only thing our hosts will do is to reply to ping messages. We only have to remember to register the host with a name server.

```erlang
-module(host).
-export([start/3, stop/1]).

start(Name, Domain, Parent) ->
	register(Name, spawn(fun()-> init(Domain, Parent) end)).

stop(Name) ->
	Name ! stop,
	unregister(Name).

init(Domain, Parent) ->
	io:format("Host: create domain ~w at ~w~n", [Domain, Parent]),
	Parent ! {register, Domain, {host, self()}},
	host().

host() ->
	receive
		{ping, From} ->
			io:format("Host: Ping from ~w~n", [From]),
			From ! pong,
			host();
		stop ->
			io:format("Host: Closing down~n", []),
			ok;
		Error ->
			io:format("Host: reception of strange message ~w~n", [Error]),
			host()
	end.
```

Note that a host is started by giving it a name (to register the process ID), a domain name and a name server. The domain name is only the name of the host, for example `www`. The location of the name server in the tree decides the full domain name of the host.

### Testing client
We will implement a simple client to test our system. Given that we have a hierarchy of name servers with registered hosts we can use a resolver to find a host and then ping it. We wait for 1000 ms for a reply from the resolver and 1000 ms for a ping reply.

```erlang
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
```

## Experiments
Now let’s set up a network of name servers and do some experiments. Following the idea of the example below, build a name space having several top-level domains, intermediate domains and hosts.

You need to start some Erlang shells on different computers. Let’s have name servers on dedicated computers and have several hosts and clients on others.

Remember to start Erlang using the `-name` and `-setcookie` parameters. A root server on `130.237.250.69` can be started like this:

```shell
erl -name root@130.237.250.69 -setcookie dns
Eshell V5.4.13 (abort with ^G)
(root@130.237.250.69)1> server:start().
true
```

We can then start servers for the top-level domains. Notice how they register with their local name only, not the full domain name. This is what it would look like on two machines: `130.237.250.123`, `130.237.250.145`.

```shell
erl -name edu@130.237.250.123 -setcookie dns
Eshell V5.4.13 (abort with ^G)
(edu@130.237.250.123)1> server:start(edu, {server, ’root@130.237.250.69’}).
true
erl -name upc@130.237.250.145 -setcookie dns
Eshell V5.4.13 (abort with ^G)
(upc@130.237.250.145)1> server:start(upc, {server, ’edu@130.237.250.123’}).
true
```

Now we can register some hosts per domain.

```shell
erl -name hosts@130.237.250.152 -setcookie dns
Eshell V5.4.13 (abort with ^G)
(hosts@130.237.250.152)1> host:start(www, www, {server, ’upc@130.237.250.145’}).
true
(hosts@130.237.250.152)2> host:start(ftp, ftp, {server, ’upc@130.237.250.145’}).
true
```

Finally, we can start a resolver and experiment with several clients asking for name resolution concurrently.

```shell
erl -name client@130.237.250.201 -setcookie dns
Eshell V5.4.13 (abort with ^G)
(client@130.237.250.201)1> resolver:start({server, ’root@130.237.250.69’}).
true
(client@130.237.250.201)2> namy:test([www,upc,edu], resolver).
```

## Using the cache

#### Experiments
1. In our initial setup, the time-to-live (TTL) was zero seconds. Do experiments with TTL equal to 10 and 20 seconds and try to quantify the amount of message traffic reduced when you repeat the same query during 1 minute.
2. Set a long TTL (i.e. minutes), and check what happens when we a) shutdown a host and start it up registered under the same name; b) shutdown a host and start it up registered under a new name.

#### Open questions
1. Discuss the impact (e.g. what nodes need to know about the change? what happens with cached information?) of shutting down nodes. Think about this in our scenario where we map names to process identifiers, but also in a real DNS scenario where names are mapped to IP addresses.
2. Our cache also suffers from old entries that are never removed. Invalid entries are removed and updated but if we never search for the entry we will not remove it. What can we do to solve this issue?

## Recursive resolution

#### Open questions
1. Discuss the needed changes in the code to use recursive resolution instead of iterative one.
