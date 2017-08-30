//+------------------------------------------------------------------+
//| Module: CommandProcessor.mqh                                     |
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
#property strict
#include <Mql/Lang/Mql.mqh>
#include <Mql/Collection/HashMap.mqh>
#include <Mql/Format/Resp.mqh>
#include "MqlCommand.mqh"
//+------------------------------------------------------------------+
//| The interface for process incoming commands                      |
//+------------------------------------------------------------------+
interface CommandProcessor
  {
   RespValue        *process(const RespArray &command);
  };
//+------------------------------------------------------------------+
//| Trade and Account commands                                       |
//+------------------------------------------------------------------+
class TradeCommandProcessor: public CommandProcessor
  {
private:
   HashMap<string,MqlCommand*>m_commands;
public:

                     TradeCommandProcessor();

   RespValue        *process(const RespArray &command)
     {
      if(command.size()==0) {return new RespError("Command is empty!");}
      string c=dynamic_cast<RespBytes*>(command[0]).getValueAsString();
      StringToUpper(c); // command is case insensitive
      MqlCommand *cmd=m_commands[c];
      if(cmd==NULL) {return new RespError("Command is not supported!");}
      return cmd.call(command);
     }
  };
//+------------------------------------------------------------------+
//| Initialize all supported commands                                |
//+------------------------------------------------------------------+
TradeCommandProcessor::TradeCommandProcessor(void)
   :m_commands(NULL,true)
  {
   m_commands.set("ORDERS",new OrdersCommand);
   m_commands.set("BUY",new BuyCommand);
   m_commands.set("SELL",new SellCommand);
   m_commands.set("CLOSE",new CloseCommand);
   m_commands.set("QUIT",new QuitCommand);
  }
//+------------------------------------------------------------------+
