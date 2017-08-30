# MetaTrader4 Server

## Introduction

For those of you who don't know MetaTrader4, it is the most used Forex trading
platform for personal investors. The power of MetaTrader4 is that it contains a
programming environment that allows the user to create automated trading agents
(called Expert Advisors by MetaQuotes, the company behind this platform). The
language is called MQL (MetaQuotes Language), which is a somewhat simplified C++
with Java like compiled intermediate format and a JIT runtime (the so called
Terminal). The free MetaTrader4 Terminal comes with a simple yet complete IDE
called MetaEditor, which is the de-facto IDE for writing MQL.

The MQL language was basically C in earlier versions. Then MetaQuotes started to
push their next generation platform called MetaTrader5 with a improved language
MQL5 (with OO capabilities like C++). But they faced extreme difficulty when
doing this because of the widespread use of MetaTrader4 and the lack of certain
features in MetaTrader5 Terminal. You know that, Python2/3, Perl5/6, etc. Things
like these happen. However, a good thing is that MQL4 and MQL5 has been merged
and they at least make the language backward compatible.

For more information about MQL you can check out my
library [mql4-lib](https://github.com/dingmaotu/mql4-lib) and see what problems
the language has.

Though the MQL is powerful enough for writing simple EAs, it is a propriety
platform and a lot of people want to jump out of the MetaTrader4 jail. They just
want to use the MQL trading API and don't want to use the MetaTrader4 Terminal.
MetaQuotes used to provide a standalone MQL compiler and C++ SDK for writing
clients to interact directly with the MetaTrader4 server. Then they stopped all
these and we can only use MetaTrader4 Terminal for executing trades and
MetaEditor to compile MQL programs. The Terminal can hold multiple accounts, but
only one account can be active. And it is extremely difficult to call into MQL
from outside
(see
[a description of this problem](https://github.com/dingmaotu/mql4-lib#external-events)).
This is understandable since as a commercial offering, it is reasonable to not
undermine your own flagship product with another more powerful solution.

The ideal solution to this problem would be resversing the communicating
protocol between the client and the server but it is illegal and extremely
difficult (the communication is encrypted). Then there are those commercial or
open source platforms that are either bindings (C# or Python binding to MQL) or
general trading platforms with proxies to MetaTrader4. The implemenation details
are not known but based on my years of experience dealing with MetaTrader4, they
could be ugly under the cover. So I stick with the MetaTrader4 Terminal but I
disable most features and reduce chart history to the smallest as possbile. I
want to make this Terminal accessable from the outside.

In recent years, I was trying to build a complex EA and a robust trading
infrastructure to serve a small fund. During the process, basic software
solutions for communication between components and for persistence are needed.
So I created the
bindings
[mql-zmq](https://github.com/dingmaotu/mql-zmq),
[mql-sqlite3](https://github.com/dingmaotu/mql-sqlite3),
and [mql4-redis](https://github.com/dingmaotu/mql4-redis). The mql4-redis
binding is based on [hiredis](https://github.com/redis/hiredis) but the hiredis
library is not designed to be cosumed in a DLL. You have to wrap the library in
a DLL and then use the DLL in MetaTrader. I am not comfortable with this and so
I decided to rewrite the client completely in MQL. The first step is to
implement the REdis Serialization Protocol (RESP) encoder/decoder and then I
found the protocol is a generally useful serialization format so I put it in
the [mql4-lib](https://github.com/dingmaotu/mql4-lib#serialization-formats)
library. With this format and the ZMQ library, I came up with the idea that we
can use these standard and proven technologies to create a server for
MetaTrader4 and allow existing clients to interact with MetaTrader4 directly.
Think about the widespread use of Redis and the sheer number of Redis client
bindings, suddenly MetaTrader4 is accessable from all these clients, locally or
remotely. If you are using a ZMQ client, you can use `inproc`, `ipc`, `udp` or
any other supported transport to access the server. And you can benefit from ZMQ
features like the server can be down and the client can continue to run waiting
for the server to be up.

The reason that I share this project is to show the power of using standard
technologies and the flexibities you can achieve. It could be also a useful
reference for writing request/reply type servers that can be accessed by both
ZMQ clients and ordinary TCP clients. For those who want to create general
trading platforms, this could be a start for a MetaTrader4 proxy.

## Screenshots

### 1. Starting the Server

![start the server](/Files/start-script.png)

### 2. Simple session on a live account

![simple redis-cli session](/Files/redis-cli-session.png)

### 3. Buy/Sell session on a demo account (with some errors)

![buy sell session with errors](/Files/redis-cli-buy-sell.png)


## Installation

This server depends on two other
libraries: [mql-zmq](https://github.com/dingmaotu/mql-zmq)
and [mql4-lib](https://github.com/dingmaotu/mql4-lib). Install them first.

Then copy this project to your `Projects` folder or `Scripts` folder and compile
`Mt4ServerRaw.mq4` and `Mt4ServerZMQ.mq4` in MetaEditor.

## Changes

2017-08-30: Initial version.
