//+------------------------------------------------------------------+
//| Module: Mt4ServerRaw.mq4                                         |
//| This file is part of the mt4-server project:                     |
//|     https://github.com/dingmaotu/mt4-server                      |
//|                                                                  |
//| Copyright 2017 Li Ding <dingmaotu@hotmail.com>                   |
//|                                                                  |
//| Licensed under the Apache License, Version 2.0 (the "License");  |
//| you may not use this file except in compliance with the License. |
//| You may obtain a copy of the License at                          |
//|                                                                  |
//|     http://www.apache.org/licenses/LICENSE-2.0                   |
//|                                                                  |
//| Unless required by applicable law or agreed to in writing,       |
//| software distributed under the License is distributed on an      |
//| "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,     |
//| either express or implied.                                       |
//| See the License for the specific language governing permissions  |
//| and limitations under the License.                               |
//+------------------------------------------------------------------+
#property copyright "Copyright 2017, Li Ding"
#property link      "dingmaotu@hotmail.com"
#property version   "1.00"
#property strict
#property show_inputs

#include <Mql/Lang/Script.mqh>
#include <Mql/Format/Resp.mqh>
#include <Mql/Lang/Hash.mqh>
#include <Zmq/Zmq.mqh>
#include "CommandProcessor.mqh"
//+------------------------------------------------------------------+
//| A tcp client connection                                          |
//+------------------------------------------------------------------+
class TcpClient
  {
private:
   uchar             m_id[];
public:
                     TcpClient(ZmqMsg &msg)
     {
      PrintFormat(">>> Debug: client id is %d bytes",msg.size());
      msg.getData(m_id);
     }
   bool              equals(const TcpClient *client) const
     {
      return ArrayCompare(m_id, client.m_id) == 0;
     }
   int               hash() const
     {
      return (int)MurmurHash3_x86_32(m_id,0x7e34a273);
     }
  };
//+------------------------------------------------------------------+
//| For using TcpClient in a HashMap                                 |
//+------------------------------------------------------------------+
class TcpClientEqualityComparer: public EqualityComparer<TcpClient*>
  {
public:
   bool              equals(const TcpClient *left,const TcpClient *right) const
     {
      return left.equals(right);
     }
   int               hash(const TcpClient *value) const
     {
      return value.hash();
     }
  };
//+------------------------------------------------------------------+
//| Mt4ServerRaw Parameters                                          |
//+------------------------------------------------------------------+
class Mt4ServerRawParam: public AppParam
  {
   ObjectAttr(string,listenAddresss,ListenAddress);
public:
   bool              check() {return true;}
  };
//+------------------------------------------------------------------+
//| A ZMQ STREAM server that receives command from raw tcp clients   |
//| and returns the results                                          |
//| This server enables a user to use a standard Redis client (like  |
//| the redis-cli) to send commands to a mt4 terminal instance       |
//+------------------------------------------------------------------+
class Mt4ServerRaw: public Script
  {
private:
   string            m_address;
   Context           m_context;
   HashMap<TcpClient*,RespStreamParser*>m_clients;
   Socket            m_socket;

   uchar             m_commandBuffer[];
   uchar             m_replyBuffer[];

   CommandProcessor *m_processor;
public:
                     Mt4ServerRaw(Mt4ServerRawParam *param)
   :m_address(param.getListenAddress()),m_clients(new TcpClientEqualityComparer,true),m_socket(m_context,ZMQ_STREAM)
     {
      if(!m_socket.bind(m_address))
        {
         fail(StringFormat(">>> Error binding to %s: %s",m_address,Zmq::errorMessage(Zmq::errorNumber())));
         return;
        }
      m_socket.setStreamNotify(true); // notify connect/disconnect
      m_processor=new TradeCommandProcessor;
     }
                    ~Mt4ServerRaw() {delete m_processor;}
   void              main(void);
  };
//+------------------------------------------------------------------+
//| A server that receives command from the client and returns the   |
//| results                                                          |
//+------------------------------------------------------------------+
void Mt4ServerRaw::main()
  {
//  Initialize poll set
   PollItem items[1];
   m_socket.fillPollItem(items[0],ZMQ_POLLIN);
   while(!IsStopped())
     {
      ZmqMsg id;
      ZmqMsg request;
      int ret=Socket::poll(items,500);
      if(ret==-1)
        {
         Print(">>> Polling input failed: ",Zmq::errorMessage(Zmq::errorNumber()));
         continue;
        }
      if(!items[0].hasInput()) continue;

      if(!m_socket.recv(id))
        {
         Print(">>> Failed retrieve client id: ",Zmq::errorMessage(Zmq::errorNumber()));
         continue;
        }

      TcpClient *client=new TcpClient(id);
      RespStreamParser *parser=NULL;

      if(!m_clients.contains(client))
        {
         Print(">>> New client from ",id.meta("Peer-Address"));

         if(!m_socket.recv(request))
           {
            Print(">>> Failed receive connection: ",Zmq::errorMessage(Zmq::errorNumber()));
           }
         else
           {
            parser=new RespStreamParser;
            m_clients.set(client,parser);
           }
         continue;
        }
      else
        {
         parser=m_clients[client];
         if(!m_socket.recv(request))
           {
            Print(">>> Failed receive request: ",Zmq::errorMessage(Zmq::errorNumber()));
            m_clients.remove(client);
            SafeDelete(client);
            continue;
           }
         else
           {
            //--- if the client closes the connection
            if(request.size()==0)
              {
               m_clients.remove(client);
               SafeDelete(client);
               continue;
              }
           }
        }

      ArrayResize(m_commandBuffer,request.size(),100);
      request.getData(m_commandBuffer);
      parser.feed(m_commandBuffer);
      RespValue *command=parser.parse();
      RespValue *reply;
      if(command==NULL)
        {
         if(parser.getError()!=RespParseErrorNeedMoreInput)
           {
            string error=EnumToString(parser.getError());
            Print(">>> Error parsing command: ",error);
            reply=new RespError(error);
           }
         else continue;
        }
      else if(command.getType()!=RespTypeArray)
        {
         Print(">>> Invalid command: ","Command is not a RespArray");
         reply=new RespError("Command is not a RespArray");
        }
      else
        {
         RespArray *c=dynamic_cast<RespArray*>(command);
         Print(">>> Received command: ",c.toString());
         reply=m_processor.process(c);
        }

      ArrayResize(m_replyBuffer,0,100);
      //--- the client is trying to disconnect from the server if the reply is NULL
      ZmqMsg response(reply==NULL?0:reply.encode(m_replyBuffer,0));
      if(reply!=NULL)
        {
         response.setData(m_replyBuffer);
        }
      else
        {
         m_clients.remove(client);
        }
      SafeDelete(command);
      if(reply!=Nil) SafeDelete(reply);
      SafeDelete(client);

      if(!m_socket.sendMore(id) || !m_socket.send(response))
        {
         Alert(StringFormat(">>> Critical error: failed to send response to client!!! (%s)",
               Zmq::errorMessage(Zmq::errorNumber())
               ));
        }
     }
  }

BEGIN_INPUT(Mt4ServerRawParam)
   INPUT(string,ListenAddress,"tcp://127.0.0.1:6666"); // Mt4 Server Listen Address
END_INPUT

DECLARE_SCRIPT(Mt4ServerRaw,true)
//+------------------------------------------------------------------+
