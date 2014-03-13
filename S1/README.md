# Chatty: a simple chat service

## Introduction
Your task will be to implement a distributed system that will allow you to chat among buddies. The purpose of this seminar is that you think about the main problems in distributed systems as well as learn a little bit of Erlang. We are going to implement two different versions of our chat system: i) a system composed by a single chat server to chat with your buddies; ii) a decentralized system with several chat servers which allows to clients connected to different servers chat with each other.
This document provides almost every piece of code. However, you may need to fill in the gaps (. . .) to ensure you understand what is the expected behavior of the system. In the following seminars, the code provided will not be so detailed.

## Chatting with buddies
The initial version of the chat will consist of two different types of processes: _clients_ (friend to chat with) and a _server_. Clients will connect to the server and the server is going to be responsible to maintain the list of clients attached and relay messages sent by a client to the rest of clients. As this design is quite simple from the distributed systems point of view, we are going make things more robust later on.

### The server
We need to implement a server that keeps track of connected users and relays messages sent by one user to the rest of users. Thus, the message interface the server is going to handle is as follows:

- `{client join req, Name, From}`: a join request from a client containing its username (Name) and a reference or process identifier (From) that the server should use to contact it. The server needs to update the list of connected clients and send to the connected users this new event (join).
- `{client leave req, Name, From}`: a leave request from a client contain- ing its username (Name) and a its process identifier (From). The server needs to update (remove) the process from the list of connected clients and send to the connected users this new event (leave).
- `{send, Name, Text}`: a request to send a message (Text) to the connected users and the client’s username (Name).
- `disconnect`: server receiving the message disconnects.

The following code is an example of the implementation of the above message interface (remember to fill the gaps). Open up a new file **server.erl** and declare the module **server**:

```erlang
-module(server).
%% Exported Functions
-export([start/0]).

%% API Functions
start() ->
	ServerPid = spawn(fun() -> process_requests([]) end),
	register(myserver, ServerPid).

process_requests(Clients) ->
	receive
		{client_join_req, Name, From} ->
			NewClients = [...|Clients],  %% TODO: COMPLETE
			broadcast(NewClients, {join, Name}),
			process_requests(...);  %% TODO: COMPLETE
		{client_leave_req, Name, From} ->
			NewClients = lists:delete(..., Clients),  %% TODO: COMPLETE
			broadcast(Clients, ...),  %% TODO: COMPLETE
			From ! exit,
			process_requests(...);  %% TODO: COMPLETE
		{send, Name, Text} ->
			broadcast(..., ...),  %% TODO: COMPLETE
			process_requests(Clients);
		disconnect ->
			unregister(myserver)
	end.

%% Local Functions
broadcast(PeerList, Message) ->
	Fun = fun(Peer) -> Peer ! Message end,
	lists:map(Fun, PeerList).
```

### The client
So far, we have seen how the server is implemented. Now, we will specify how the client works. The client process will have two different tasks to perform. We will have a background task responsible for handling replies from the server and the main task will be responsible to read a message from the standard input to be sent to the rest of your buddies. The background task (the one handling server replies) should handle the following message interface:

- `{join, Name}`: the server informs that a new client is connected. We should write through the standard output this information.
- `{leave, Name}`: the server informs that a connected client is about to disconnect. We should write down this information through the standard output.
- `{message, Name, Text}`: this is a message sent back by the server from one of the connected users (Name). We should print this message (Text) so we can actually read it.
- `exit`: the client background task is terminated.

Notice that, in this case, we do not need the reference to the client sending a message (From) as a buddy does not contact directly with other buddies but with the server.

The main process should block waiting for the user to write down some text to send to the chatting room. If a user wants to leave, we need to write a _command_ (exit) to actually leave the chat. Once the user writes this keyword, the main process will send a request to the server to leave the room.

The following code is an example of the implementation of the above message interface (remember to fill the gaps). Open a new file **client.erl** and declare the module **client**.

```erlang
-module(client).
%% Exported Functions
-export([start/2]).

%% API Functions
start(ServerPid, MyName) ->
	ClientPid = spawn(fun() -> init_client(ServerPid, MyName) end),
	process_commands(ServerPid, MyName, ClientPid).

init_client(ServerPid, MyName) ->
	ServerPid ! {client_join_req, ..., ...},  %% TODO: COMPLETE
	process_requests().

%% Local Functions
%% This is the background task logic
process_requests() ->
	receive
		{join, Name} ->
			io:format("[JOIN] ~s joined the chat~n", [Name]),
			%% TODO: ADD SOME CODE
		{leave, Name} ->
			%% TODO: ADD SOME CODE
			process_requests();
		{message, Name, Text} ->
			io:format("[~s] ~s", [Name, Text]),
			%% TODO: ADD SOME CODE
		exit ->
			ok
	end.

%% This is the main task logic
process_commands(ServerPid, MyName, ClientPid) ->
	%% Read from standard input and send to server
	Text = io:get_line("-> "),
	if
		Text  == "exit\n" ->
			ServerPid ! {client_leave_req, ..., ...},  %% TODO: COMPLETE
			ok;
		true ->
			ServerPid ! {send, ..., ...},  %% TODO: COMPLETE
			process_commands(ServerPid, MyName, ClientPid)
	end.
```
### Testing
Debugging Erlang code may be quite confusing sometimes because of the error messages. Once you get used to them, you will quickly understand what is wrong with your code. In the meanwhile, it is useful to put debugging information to know where your code is failing and the state of your variables.

If you are not using an Erlang IDE which automatically compiles your code, you will need to do it by hand before calling your implemented procedures. A simple test can be done in a single computer. You will execute a server and a client in different terminals. To start a server type (remember to change the local IP by your public IP when communicating with remote nodes):

```shell
user@host:~/Chatty$ erl -name server_node@127.0.0.1 -setcookie secret
(server_node@127.0.0.1)1> c(server). %% Compile server module
(server_node@127.0.0.1)2> server:start().
true
```
Open up a new terminal and write the following:

```shell
user@host:~/Chatty$ erl -name client_node@127.0.0.1 -setcookie secret
(client_node@127.0.0.1)1> c(client). %% Compile client module
(client_node@127.0.0.1)2> client:start({myserver, ’server_node@127.0.0.1’}, "John").
[JOIN] John joined the chat
```
And if you type a message, you should see something like...

```shell
-> hi!
[John] hi!
```

#### Experiments
Experiments. Try opening 2 or 3 clients and test that all of them receive all the messages. You can also try to communicate among different physical machines (remember to change the local IP line by the public IP of the server you are connecting to). Read the ’Erlang primer’ to refresh how to contact remote nodes.

#### Open questions
1. Does this solution scale when the number of users increase?
2. What happens if the server fails?
3. Are the messages from a single client to any other client guaranteed to be delivered in the order they were issued? (hint: search for the ’order of message reception’ in Erlang FAQ)
4. What about the messages from different clients (hint: think on several clients sending messages concurrently to another one)?
5. If a user joins/leaves the chat while the server is broadcasting a message, will he receive that message?

## Making it robust
The previous design has its disadvantages. Mainly, it is not robust to failures –i.e. if the server fails the whole system will become useless. A solution to this problem is to have more servers (replication). Thus, if a server fails, we will have other servers still running and continue sending messages. As usually, solving a problem is an open door for other interesting problems.

We will have a set of replicated servers to which users may connect indis- tinctly. This way, if a server fails, only those users connected to the failing server will lose connectivity but the rest will remain connected. Of course we could implement a solution in which clients automatically reconnect to another server when they detect a failure but we are going to keep things simple.

We will only need to change the server implementation to introduce this new functionality. This new implementation needs to know the list of replicated servers. Besides, we need to handle the membership of the set of servers. Users will connect to one of the servers and send messages to it. This server will forward the message to the set of servers which in turn will relay the message to its clients.

The new messages that the server needs to handle are as follows:

- `{server join req, From}`: a new server is added to the set of replicated servers. We need to update the list of servers and inform the rest of servers of this new node.
- `{update servers, NewServers}`: a server gets informed when a new server has joined the set.
- `RelayMessage`: if the message received does not match any of the previous clauses, the server relays the message to all of its clients (it may be either a message of type join, leave or message).

Be aware that now, the messages previously implemented (`client_join_req`, `client_leave_req` and `send`) **are not forwarded directly to the clients but to every member of the set of servers**. They in turn will relay those messages to their connected clients. In addition, when a server disconnects, the rest of servers are informed.

The following code is an example of the implementation of the above message interface (remember to fill the gaps). Open a new file **server2.erl** and declare the module **server2**.

```erlang
-module(server2).
%% Exported Functions
-export([start/0, start/1]).

%% API Functions
start() ->
	ServerPid = spawn(fun() -> init_server() end),
	register(myserver, ServerPid).

start(BootServer) ->
	ServerPid = spawn(fun() -> init_server(BootServer) end),
	register(myserver, ServerPid).

init_server() ->
	process_requests([], [self()]).

init_server(BootServer) ->
	BootServer ! {server_join_req, self()},
	process_requests([], []).

process_requests(Clients, Servers) ->
	receive
		%% Messages between client and server
		{client_join_req, Name, From} ->
			NewClients = [...|Clients],  %% TODO: COMPLETE
			broadcast(..., {join, Name}),  %% TODO: COMPLETE
			process_requests(..., ...);  %% TODO: COMPLETE
		{client_leave_req, Name, From} ->
			NewClients = lists:delete(..., Clients),  %% TODO: COMPLETE
			broadcast(..., {leave, Name}),  %% TODO: COMPLETE
			From ! exit,
			process_requests(..., ...);  %% TODO: COMPLETE
		{send, Name, Text} ->
			broadcast(Servers, ...),  %% TODO: COMPLETE
			process_requests(Clients, Servers);

		%% Messages between servers
		disconnect ->
			NewServers = lists:delete(self(), Servers),
			broadcast(..., {update_servers, NewServers}),  %% TODO: COMPLETE
			unregister(myserver);
		{server_join_req, From} ->
			NewServers = [...|Servers],  %% TODO: COMPLETE
			broadcast(..., {update_servers, NewServers}),  %% TODO: COMPLETE
			process_requests(Clients, NewServers);
		{update_servers, NewServers} ->
			io:format("[SERVER UPDATE] ~w~n", [NewServers]),
			process_requests(Clients, ...);  %% TODO: COMPLETE
		RelayMessage -> %% Whatever other message is relayed to its clients
			broadcast(Clients, RelayMessage),
			process_requests(Clients, Servers)
		end.

%% Local Functions
broadcast(PeerList, Message) ->
	Fun = fun(Peer) -> Peer ! Message end,
	lists:map(Fun, PeerList).
```

You need to first start a server with the function **server2:start()** –which creates a server with an empty list of server references– and, then start different servers with the function **server2:start({myserver,’server_node@IP’})**– which will connect this server to the rest of servers. Remember to change the remote hostname by the IP of the server you are connecting to.

#### Experiments
Once you have a set of servers up and running, try connecting some clients to each of the server instances and begin to chat. Does it work? You can also try to crash some of the servers and see what happens.

#### Open questions
1. What happens if a server fails?
2. What happens if there are concurrent requests from servers to join or leave the system?
3. What are the advantages and disadvantages of this implementation regarding the previous one?




