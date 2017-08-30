//+------------------------------------------------------------------+
//| Module: Mt4ServerZMQ.mq4                                         |
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
#include <Zmq/Zmq.mqh>
#include "CommandProcessor.mqh"
//+------------------------------------------------------------------+
//| Mt4ServerZMQ Parameters                                          |
//+------------------------------------------------------------------+
class Mt4ServerZMQParam: public AppParam
  {
   ObjectAttr(string,listenAddresss,ListenAddress);
public:
   bool              check() {return true;}
  };
//+------------------------------------------------------------------+
//| A ZMQ REQ/REP server that receives command from the client and   |
//| returns the results                                              |
//| The ListenAddress can be inproc, ipc, udp or any other supported |
//| transports                                                       |
//+------------------------------------------------------------------+
class Mt4ServerZMQ: public Script
  {
private:
   string            m_address;
   Context           m_context;
   RespMsgParser     m_parser;
   Socket            m_socket;

   uchar             m_commandBuffer[];
   uchar             m_replyBuffer[];

   CommandProcessor *m_processor;
public:
                     Mt4ServerZMQ(Mt4ServerZMQParam *param)
   :m_address(param.getListenAddress()),m_socket(m_context,ZMQ_REP)
     {
      if(!m_socket.bind(m_address))
        {
         fail(StringFormat(">>> Error binding to %s: %s",m_address,Zmq::errorMessage(Zmq::errorNumber())));
         return;
        }
      m_processor=new TradeCommandProcessor;
     }
                    ~Mt4ServerZMQ() {delete m_processor;}
   void              main(void);
  };
//+------------------------------------------------------------------+
//| A server that receives command from the client and returns the   |
//| results                                                          |
//+------------------------------------------------------------------+
void Mt4ServerZMQ::main()
  {
//  Initialize poll set
   PollItem items[1];
   m_socket.fillPollItem(items[0],ZMQ_POLLIN);
   while(!IsStopped())
     {
      ZmqMsg request;
      int ret=Socket::poll(items,500);
      if(ret==-1)
        {
         Print(">>> Polling input failed: ",Zmq::errorMessage(Zmq::errorNumber()));
         continue;
        }
      if(!items[0].hasInput()) continue;

      if(!m_socket.recv(request))
        {
         Print(">>> Failed receive request: ",Zmq::errorMessage(Zmq::errorNumber()));
         continue;
        }

      ArrayResize(m_commandBuffer,request.size(),100);
      request.getData(m_commandBuffer);

      RespValue *command=m_parser.parse(m_commandBuffer);
      RespValue *reply;
      if(command==NULL)
        {
         string error=EnumToString(m_parser.getError());
         Print(">>> Error parsing command: ",error);
         reply=new RespError(error);
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
      ZmqMsg response(reply.encode(m_replyBuffer,0));
      SafeDelete(command);
      if(reply!=Nil) SafeDelete(reply);
      response.setData(m_replyBuffer);
      if(!m_socket.send(response))
        {
         Alert(StringFormat(">>> Critical error: failed to send response to client!!! (%s)",
               Zmq::errorMessage(Zmq::errorNumber())
               ));
        }
     }
  }

BEGIN_INPUT(Mt4ServerZMQParam)
   INPUT(string,ListenAddress,"tcp://127.0.0.1:6666"); // Mt4 Server Listen Address
END_INPUT

DECLARE_SCRIPT(Mt4ServerZMQ,true)
//+------------------------------------------------------------------+
