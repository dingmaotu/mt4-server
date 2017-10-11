//+------------------------------------------------------------------+
//| Module: MqlCommand.mqh                                           |
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
#include <Mql/Trade/FxSymbol.mqh>
#include <Mql/Trade/OrderPool.mqh>
#include <Mql/Trade/Account.mqh>
#include <Mql/Trade/Order.mqh>
#include <Mql/Format/Resp.mqh>
//+------------------------------------------------------------------+
//| Wraps a specific MQL command                                     |
//+------------------------------------------------------------------+
interface MqlCommand
  {
   RespValue        *call(const RespArray &command);
  };
//+------------------------------------------------------------------+
//| Get all orders in the Trade Pool                                 |
//| Syntax: ORDERS                                                   |
//| Results:                                                         |
//|   Success: Array of orders in string format                      |
//|   Success: Nil if no orders                                      |
//|   Fail:    RespError                                             |
//+------------------------------------------------------------------+
class OrdersCommand: public MqlCommand
  {
private:
   TradingPool       m_pool;
public:
   RespValue        *call(const RespArray &command)
     {
      int total=m_pool.total();
      if(total==0) return RespNil::getInstance();
      RespArray *res=new RespArray(total);
      for(int i=0; i<total;i++)
        {
         if(m_pool.select(i))
           {
            Order o;
            res.set(i,new RespString(o.toString()));
           }
         else
           {
            res.set(i,RespNil::getInstance());
           }
        }
      return res;
     }
  };
//+------------------------------------------------------------------+
//| Buy at market price                                              |
//| Syntax: BUY Symbol Lots                                          |
//| Results:                                                         |
//|   Success: Order id (RespInteger)                                |
//|   Fail:    RespError                                             |
//+------------------------------------------------------------------+
class BuyCommand: public MqlCommand
  {
public:
   RespValue        *call(const RespArray &command)
     {
      if(command.size()!=3) return new RespError("Invalid number of arguments for command BUY!");
      string symbol=dynamic_cast<RespBytes*>(command[1]).getValueAsString();
      double lots=StringToDouble(dynamic_cast<RespBytes*>(command[2]).getValueAsString());
      int id=OrderSend(symbol,OP_BUY,lots,FxSymbol::getAsk(symbol),3,0,0,NULL,0,0,clrNONE);
      if(id==-1)
        {
         int ec=Mql::getLastError();
         return new RespError(StringFormat("Failed to buy at market with error id (%d): %s",
                              ec,Mql::getErrorMessage(ec)));
        }
      else
        {
         return new RespInteger(id);
        }
     }
  };
//+------------------------------------------------------------------+
//| Sell at market price                                             |
//| Syntax: SELL Symbol Lots                                         |
//| Results:                                                         |
//|   Success: Order id (RespInteger)                                |
//|   Fail:    RespError                                             |
//+------------------------------------------------------------------+
class SellCommand: public MqlCommand
  {
public:
   RespValue        *call(const RespArray &command)
     {
      if(command.size()!=3) return new RespError("Invalid number of arguments for command SELL!");
      string symbol=dynamic_cast<RespBytes*>(command[1]).getValueAsString();
      double lots=StringToDouble(dynamic_cast<RespBytes*>(command[2]).getValueAsString());
      int id=OrderSend(symbol,OP_SELL,lots,FxSymbol::getBid(symbol),3,0,0,NULL,0,0,clrNONE);
      if(id==-1)
        {
         int ec=Mql::getLastError();
         return new RespError(StringFormat("Failed to sell at market with error id (%d): %s",
                              ec,Mql::getErrorMessage(ec)));
        }
      else
        {
         return new RespInteger(id);
        }
     }
  };
//+------------------------------------------------------------------+
//| Close a market order                                             |
//| Syntax: CLOSE Ticket Lots                                        |
//| Results:                                                         |
//|   Success: Order id (RespInteger)                                |
//|   Fail:    RespError                                             |
//+------------------------------------------------------------------+
class CloseCommand: public MqlCommand
  {
public:
   RespValue        *call(const RespArray &command)
     {
      if(command.size()!=3 && command.size()!=2) return new RespError("Invalid number of arguments for command CLOSE!");
      int ticket=(int)StringToInteger(dynamic_cast<RespBytes*>(command[1]).getValueAsString());
      if(!Order::Select(ticket))
        {
         return new RespError("Order does not exist!");
        }
      string symbol=Order::Symbol();
      int op=Order::Type();
      double lots=0;
      if(command.size()==2)
        {
         lots=Order::Lots();
        }
      else
        {
         lots=StringToDouble(dynamic_cast<RespBytes*>(command[2]).getValueAsString());
        }
      if(!OrderClose(ticket,lots,FxSymbol::priceForClose(symbol,op),3,clrNONE))
        {
         int ec=Mql::getLastError();
         return new RespError(StringFormat("Failed to close market order #%d with error id (%d): %s",
                              ticket,ec,Mql::getErrorMessage(ec)));
        }
      else
        {
         return new RespString("Ok");
        }
     }
  };
//+------------------------------------------------------------------+
//| Quit server connection                                           |
//| Syntax: QUIT                                                     |
//| Results:                                                         |
//|   The server will close the connection                           |
//+------------------------------------------------------------------+
class QuitCommand: public MqlCommand
  {
public:
   RespValue        *call(const RespArray &command)
     {
      return NULL;
     }
  };
//+------------------------------------------------------------------+
