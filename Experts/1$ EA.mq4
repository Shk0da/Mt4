//+------------------------------------------------------------------+
//|                                                            1$ EA |
//|                                           Copyright 2017, Shk0da |
//|                                    https://github.com/Shk0da/mt4 |
//+------------------------------------------------------------------+
#include <stdlib.mqh>
#include <stderror.mqh> 
#property copyright ""
#property link ""

// ------------------------------------------------------------------------------------------------
// EXTERNAL VARIABLES
// ------------------------------------------------------------------------------------------------

extern int magic=19274;
int magic_lock=777;
// Configuration
extern string CommonSettings="---------------------------------------------";
extern int user_slippage=2;
extern int user_tp=20;
extern int user_sl=100;
extern bool use_basic_tp=true;
extern bool use_basic_sl=false;
extern bool use_dynamic_tp=false;
extern bool use_dynamic_sl=false;
extern string MoneyManagementSettings="---------------------------------------------";
// Money Management
extern double min_lots=0.01;
extern int risk=50;
extern int martin_aver_k=2;
extern double balance_limit=50;
extern int max_orders=1;
extern int surfing=0;
extern bool close_loss_orders=false;
extern bool global_basket=false;
extern bool safety=false;
extern bool use_reverse_orders=false;
// Trailing stop
extern string TrailingStopSettings="---------------------------------------------";
extern bool ts_enable=false;
extern int ts_val=19;
extern int ts_step=4;
extern bool ts_only_profit=true;
// Optimization
extern string Optimization="---------------------------------------------";
// Indicators
extern int shift=1;
extern int atr_period=14;
extern int atr_tpk=1;
extern int atr_slk=1;
// ------------------------------------------------------------------------------------------------
// GLOBAL VARIABLES
// ------------------------------------------------------------------------------------------------

string key="Ichimoku EA: ";
int DAY=86400;
int order_ticket;
double order_lots;
double order_price;
double order_profit;
double order_sl;
double order_tp;
int order_magic;
int order_time;
int orders=0;
int direction=0;
double max_profit=0;
double close_profit=0;
double last_order_profit=0;
double last_order_lots=0;
double last_order_price=0;
double last_close_price=0;
color c=Black;
double balance;
double equity;
int slippage=0;
// OrderReliable
int retry_attempts= 10;
double sleep_time = 4.0;
double sleep_maximum=25.0;  // in seconds
string OrderReliable_Fname="OrderReliable fname unset";
static int _OR_err=0;
string OrderReliableVersion="V1_1_1";
// ------------------------------------------------------------------------------------------------
// START
// ------------------------------------------------------------------------------------------------
int start()
  {

   if(FileIsExist("Ichimoku EA.tpl"))
     {
      ChartApplyTemplate(0,"\\Templates\\Ichimoku EA.tpl");
     }

   if(AccountBalance()<=balance_limit)
     {
      Alert("Balance: "+AccountBalance());
      return(0);
     }

   if(MarketInfo(Symbol(),MODE_DIGITS)==4)
     {
      slippage=user_slippage;
     }
   else if(MarketInfo(Symbol(),MODE_DIGITS)==5)
     {
      slippage=10*user_slippage;
     }

   if(IsTradeAllowed()==false)
     {
      Comment("Trade not allowed.");
      return(0);
     }

   Comment("\nIchimoku EA is running.");

   return(0);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
   InicializarVariables();
   ActualizarOrdenes();
   Trade();
  }
//+------------------------------------------------------------------+
//| Суммарный профит открытых позиций                                |
//+------------------------------------------------------------------+
double GetPfofit()
  {
   double profit=0;
   int i;

   for(i=0; i<OrdersTotal(); i++)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
        {
         if(global_basket)
           {
            if((OrderMagicNumber()==magic || OrderMagicNumber()==magic+magic_lock) && (OrderType()==OP_BUY || OrderType()==OP_SELL))
              {
               profit+=OrderProfit()+OrderSwap()-OrderCommission();
              }
           }
         else
           {
            if(OrderSymbol()==Symbol() && (OrderMagicNumber()==magic || OrderMagicNumber()==magic+magic_lock) && (OrderType()==OP_BUY || OrderType()==OP_SELL))
              {
               profit+=OrderProfit()+OrderSwap()-OrderCommission();
              }
           }
        }
     }
   return(profit);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void TrailingStop()
  {
   for(int i=0; i<OrdersTotal(); i++)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
        {
         if(OrderSymbol()==Symbol() && (OrderMagicNumber()==magic || OrderMagicNumber()==magic+magic_lock))
           {
            TrailingPositions();
           }
        }
     }
  }
//+------------------------------------------------------------------+
//| Position maintenance simple trawl                             |
//+------------------------------------------------------------------+
void TrailingPositions()
  {
   double pBid,pAsk,pp;
//----
   pp=MarketInfo(OrderSymbol(),MODE_POINT);

   double val;
   int stop_level=MarketInfo(Symbol(),MODE_STOPLEVEL)+MarketInfo(Symbol(),MODE_SPREAD);
   if(use_dynamic_sl==1)
     {
      double atr=iATR(Symbol(),0,atr_period,shift)/0.00001;
      if(atr<stop_level) atr=stop_level;
      val=atr;
        } else {
      if(ts_val<stop_level) ts_val=stop_level;
      val=ts_val;
     }

   if(OrderType()==OP_BUY)
     {
      pBid=MarketInfo(OrderSymbol(),MODE_BID);
      if(!ts_only_profit || (pBid-OrderOpenPrice())>val*pp)
        {
         if(OrderStopLoss()<pBid-(val+ts_step-1)*pp)
           {
            ModifyStopLoss(pBid-val*pp);
            return;
           }
        }
     }
   if(OrderType()==OP_SELL)
     {
      pAsk=MarketInfo(OrderSymbol(),MODE_ASK);
      if(!ts_only_profit || OrderOpenPrice()-pAsk>val*pp)
        {
         if(OrderStopLoss()>pAsk+(val+ts_step-1)*pp || OrderStopLoss()==0)
           {
            ModifyStopLoss(pAsk+val*pp);
            return;
           }
        }
     }
  }
//+------------------------------------------------------------------+
//| The transfer of the StopLoss level                                          |
//| Settings:                                                       |
//|   ldStopLoss - level StopLoss                                  |
//+------------------------------------------------------------------+
void ModifyStopLoss(double ldStopLoss)
  {
   double ldTakeProfit=ts_only_profit
                       ? OrderTakeProfit()+ts_step*MarketInfo(OrderSymbol(),MODE_POINT)*((OrderType()==OP_BUY) ? 1 : -1)
                       : OrderTakeProfit();
   OrderModify(OrderTicket(),OrderOpenPrice(),ldStopLoss,ldTakeProfit,0,CLR_NONE);
  }
//+------------------------------------------------------------------+

// ------------------------------------------------------------------------------------------------
// INITIALIZE VARIABLES
// ------------------------------------------------------------------------------------------------
void InicializarVariables()
  {
   orders=0;
   direction=0;
   order_ticket=0;
   order_lots=0;
   order_price= 0;
   order_time = 0;
   order_profit=0;
   order_sl=0;
   order_tp=0;
   order_magic=0;
   last_order_profit=0;
   last_order_lots=0;
  }
// ------------------------------------------------------------------------------------------------
// ACTUALIZAR ORDENES
// ------------------------------------------------------------------------------------------------
void ActualizarOrdenes()
  {
   int ordenes=0;
   bool encontrada;

   for(int i=0; i<OrdersTotal(); i++)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
        {
         if(((!global_basket && OrderSymbol()==Symbol()) || global_basket) && (OrderMagicNumber()==magic || OrderMagicNumber()==magic+magic_lock) && (OrderType()==OP_BUY || OrderType()==OP_SELL))
           {
            ordenes++;
           }

         if(OrderSymbol()==Symbol() && (OrderMagicNumber()==magic || OrderMagicNumber()==magic+magic_lock) && (OrderType()==OP_BUY || OrderType()==OP_SELL))
           {
            order_ticket=OrderTicket();
            order_lots=OrderLots();
            order_price= OrderOpenPrice();
            order_time = OrderOpenTime();
            order_profit=OrderProfit();
            order_sl=OrderStopLoss();
            order_tp=OrderTakeProfit();
            order_magic=OrderMagicNumber();

            if(OrderType()==OP_BUY) direction=1;
            if(OrderType()==OP_SELL) direction=2;
           }
        }
     }
   orders=ordenes;

   if(OrdersHistoryTotal()>0)
     {
      i=1;
      while(i<=100 && encontrada==FALSE)
        {
         int n=OrdersHistoryTotal()-i;
         if(OrderSelect(n,SELECT_BY_POS,MODE_HISTORY) && (OrderMagicNumber()==magic || OrderMagicNumber()==magic+magic_lock))
           {
            last_order_profit=OrderProfit();
            last_order_lots=OrderLots();
            last_order_price=OrderOpenPrice();
            last_close_price=OrderClosePrice();
           }
         i++;
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetMaxLot(int Risk)
  {
   double Free=AccountFreeMargin();
   double margin=MarketInfo(Symbol(),MODE_MARGINREQUIRED);
   double Step= MarketInfo(Symbol(),MODE_LOTSTEP);
   double Lot = MathFloor(Free*Risk/100/margin/Step)*Step;
   if(Lot*margin>Free) return(0);
   return(Lot);
  }
// ------------------------------------------------------------------------------------------------
// CALCULATE VOLUME
// ------------------------------------------------------------------------------------------------
double CalcularVolumen()
  {
   int n;
   double aux;

   aux=risk*AccountFreeMargin();
   aux=aux/100000;
   n=MathFloor(aux/min_lots);
   aux=n*min_lots;

   if(surfing>0)
     {
      aux=last_order_lots+min_lots;
      if(aux>surfing*MarketInfo(Symbol(),MODE_LOTSTEP)) aux=min_lots;
     }

   double max=GetMaxLot(risk);
   if(aux>max) aux=max;
   if(aux<min_lots) aux=min_lots;

   if(last_order_profit<0)
     {
      aux=last_order_lots*martin_aver_k;
      last_order_profit=0;
     }

   if(aux>MarketInfo(Symbol(),MODE_MAXLOT)) aux=MarketInfo(Symbol(),MODE_MAXLOT);
   if(aux<MarketInfo(Symbol(),MODE_MINLOT)) aux=MarketInfo(Symbol(),MODE_MINLOT);

   return(aux);
  }
// ------------------------------------------------------------------------------------------------
// CALCULATED TAKE PROFIT
// ------------------------------------------------------------------------------------------------
double GetTakeProfit(int op)
  {
   if(use_basic_tp == 0) return(0);

   double aux_take_profit=0;
   double spread=MarketInfo(Symbol(),MODE_ASK)-MarketInfo(Symbol(),MODE_BID);
   double val;

   int stop_level=MarketInfo(Symbol(),MODE_STOPLEVEL)+MarketInfo(Symbol(),MODE_SPREAD);
   if(use_dynamic_tp==1)
     {
      double atr=iATR(Symbol(),0,atr_period,shift)/0.00001*(MarketInfo(Symbol(),MODE_DIGITS)>=4 ? 1 : .5)*atr_tpk;
      if(atr<stop_level) atr=stop_level;
      val=atr*MarketInfo(Symbol(),MODE_POINT);
        } else {
      if(user_tp<stop_level) user_tp=stop_level;
      val=user_tp*MarketInfo(Symbol(),MODE_POINT);
     }

   if(op==OP_BUY)
     {
      aux_take_profit=MarketInfo(Symbol(),MODE_ASK)+spread+val;
        } else if(op==OP_SELL) {
      aux_take_profit=MarketInfo(Symbol(),MODE_BID)-spread-val;
     }

   return(aux_take_profit);
  }
// ------------------------------------------------------------------------------------------------
// CALCULATES STOP LOSS
// ------------------------------------------------------------------------------------------------
double GetStopLoss(int op)
  {
   if(use_basic_sl == 0) return(0);

   double aux_stop_loss=0;

   double val;
   int stop_level=MarketInfo(Symbol(),MODE_STOPLEVEL)+MarketInfo(Symbol(),MODE_SPREAD);
   if(use_dynamic_sl==1)
     {
      double atr=iATR(Symbol(),0,atr_period,shift)/0.00001*(MarketInfo(Symbol(),MODE_DIGITS)>=4 ? 2 : 1)*atr_slk;
      if(atr<stop_level) atr=stop_level;
      val=atr*MarketInfo(Symbol(),MODE_POINT);
        } else {
      if(user_sl<stop_level) user_sl=stop_level;
      val=user_sl*MarketInfo(Symbol(),MODE_POINT);
     }

   if(op==OP_BUY)
     {
      aux_stop_loss=MarketInfo(Symbol(),MODE_ASK)-val;
     }
   else if(op==OP_SELL)
     {
      aux_stop_loss=MarketInfo(Symbol(),MODE_BID)+val;
     }

   return(aux_stop_loss);
  }

int UpTo30Counter=0;
double Array_spread[30];
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnInit()
  {
   ArrayInitialize(Array_spread,0);
  }
// ------------------------------------------------------------------------------------------------
// CALCULATED SIGNAL 
// ------------------------------------------------------------------------------------------------
double CalculaSignal()
  {
   if(AccountBalance()<=balance_limit)
     {
      return(0);
     }

   double bid = MarketInfo(Symbol(),MODE_BID);
   double ask = MarketInfo(Symbol(),MODE_ASK);

   double imalow=iMA(Symbol(),0,3,0,MODE_LWMA,PRICE_LOW,0);
   double imahigh=iMA(Symbol(),0,3,0,MODE_LWMA,PRICE_HIGH,0);

   double ibandslower = iBands(Symbol(), 0, 3, 2.0, 0, PRICE_OPEN, MODE_LOWER, 0);
   double ibandsupper = iBands(Symbol(), 0, 3, 2.2, 0, PRICE_OPEN, MODE_UPPER, 0);

   double envelopeslower = iEnvelopes(Symbol(), 0, 3, MODE_LWMA, 0, PRICE_OPEN, 0.07, MODE_LOWER, 0);
   double envelopesupper = iEnvelopes(Symbol(), 0, 3, MODE_LWMA, 0, PRICE_OPEN, 0.07, MODE_UPPER, 0);

   int result=0;
   if(bid<imalow) result++;
   if(bid<ibandslower) result++;
   if(bid<envelopeslower) result++;

   if(ask>imahigh) result--;
   if(ask>ibandsupper) result--;
   if(ask>envelopesupper) result--;

   double white2=iMA(Symbol(),0,7,0,MODE_SMMA,PRICE_CLOSE,0);
   double black2=iMA(Symbol(),0,56,0,MODE_SMMA,PRICE_CLOSE,0);

   if(white2<black2) result++;
   if(white2>black2) result--;

   double white=iMA(Symbol(),PERIOD_H1,7,0,MODE_SMMA,PRICE_CLOSE,0);
   double black=iMA(Symbol(),PERIOD_H1,56,0,MODE_SMMA,PRICE_CLOSE,0);

    if(white>black && ask>white && result>=0)
     {
      return 2;
     }

   if(white<black && bid<white && result<=0)
     {
      return -2;
     }

   return((result > 3 && white>black) ? 1 : (result < -3 && white<black) ? -1 : 0);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int GetStrengthTrend()
  {
   double adxMain=iADX(Symbol(),PERIOD_M15,14,PRICE_MEDIAN,MODE_MAIN,0);
   double adxDiPlus=iADX(Symbol(),PERIOD_M15,14,PRICE_MEDIAN,MODE_PLUSDI,0);
   double adxDiMinus=iADX(Symbol(),PERIOD_M15,14,PRICE_MEDIAN,MODE_MINUSDI,0);

   int strngth=0;
   if(adxMain>25 && adxDiPlus>=25 && adxDiMinus<=15) strngth=1;
   else if(adxMain>25 && adxDiMinus>=25 && adxDiPlus<=15) strngth=-1;
   if(adxMain>35 && adxDiPlus>=25 && adxDiMinus<=15) strngth=2;
   else if(adxMain>35 && adxDiMinus>=25 && adxDiPlus<=15) strngth=-2;

   return(strngth);
  }

// ------------------------------------------------------------------------------------------------
// Trade
// ------------------------------------------------------------------------------------------------
int ordersToLock[];
double signal=0;
int strength=0;
bool buy=false;
bool sell=false;
bool previous_buy=false;
bool previous_sell=false;
double last_open_price=0;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void Trade()
  {
   RefreshRates();
   signal=CalculaSignal();
   string comment=key+signal+"; Trend: "+strength+"; TF: "+Period();

   Comment("\n"+comment);

   previous_buy=buy;
   previous_sell=sell;
   buy = signal>0;
   sell= signal<0;

   double pr=GetPfofit();
   double atr=iATR(Symbol(),0,atr_period+orders,0);
   double tp_val=(use_dynamic_tp==1) ? atr/0.00001 : user_tp;
   double tp = tp_val*MarketInfo(Symbol(),MODE_POINT)*(MarketInfo(Symbol(),MODE_DIGITS) >= 4 ? 2 : 1);
   double sl = tp*-1;
   bool trend_changed=((buy && direction==2) || (sell && direction==1));
   double satisfactorily_tp=((MarketInfo(Symbol(),MODE_BID)+MarketInfo(Symbol(),MODE_ASK))/2-tp)*(CalcularVolumen()/min_lots)/2;

   int total=0;
   int TradeList[][2];
   int ctTrade= 0;
   if((orders>=0 &&((pr>=satisfactorily_tp && (safety || !use_basic_tp))||((trend_changed||(orders>=max_orders && max_orders>1)) && pr>=0))) || (orders == 1 && (TimeCurrent() - OrderOpenTime() > DAY) && pr>=-1))
     {
      total=OrdersTotal();
      ctTrade=0;
      ArrayResize(TradeList,ctTrade);

      for(int k=total-1; k>=0; k--)
        {
         if(OrderSelect(k,SELECT_BY_POS))
           {
            if(global_basket)
              {
               if((OrderMagicNumber()==magic || OrderMagicNumber()==magic+magic_lock))
                 {
                  ArrayResize(TradeList,++ctTrade);
                  TradeList[ctTrade - 1][0] = OrderOpenTime();
                  TradeList[ctTrade - 1][1] = OrderTicket();
                 }
              }
            else
              {
               if(OrderSymbol()==Symbol() && (OrderMagicNumber()==magic || OrderMagicNumber()==magic+magic_lock))
                 {
                  ArrayResize(TradeList,++ctTrade);
                  TradeList[ctTrade - 1][0] = OrderOpenTime();
                  TradeList[ctTrade - 1][1] = OrderTicket();
                 }
              }
           }
        }

      if(ArraySize(TradeList)>0) ArraySort(TradeList,WHOLE_ARRAY,0,MODE_ASCEND);
      for(int i=0; i<ctTrade; i++)
        {
         OrderSelect(TradeList[i][1],SELECT_BY_TICKET);
         switch(OrderType())
           {
            case OP_BUY       : OrderCloseReliable(OrderTicket(),OrderLots(),MarketInfo(Symbol(),MODE_BID),slippage,Red);
            break;
            case OP_SELL      : OrderCloseReliable(OrderTicket(),OrderLots(),MarketInfo(Symbol(),MODE_ASK),slippage,Red);
            break;
            case OP_BUYLIMIT  :
            case OP_BUYSTOP   :
            case OP_SELLLIMIT :
            case OP_SELLSTOP  : OrderDelete(OrderTicket());
            break;
           }
         if((OrderMagicNumber()==magic || OrderMagicNumber()==magic+magic_lock)) orders--;
        }
     }

   if(!use_basic_sl && close_loss_orders && trend_changed)
     {
      total=OrdersTotal();
      ctTrade=0;
      ArrayResize(TradeList,ctTrade);

      for(k=total-1; k>=0; k--)
        {
         OrderSelect(k,SELECT_BY_POS);
         if(OrderSymbol()!=Symbol()) continue;
         if(OrderType()==OP_BUY)
           {
            double prb=(MarketInfo(Symbol(),MODE_ASK)-OrderOpenPrice());
            if(prb<sl)
              {
               ArrayResize(TradeList,++ctTrade);
               TradeList[ctTrade - 1][0] = OrderOpenTime();
               TradeList[ctTrade - 1][1] = OrderTicket();
              }
           }
         if(OrderType()==OP_SELL)
           {
            double prs=(OrderOpenPrice()-MarketInfo(Symbol(),MODE_BID));
            if(prs<sl)
              {
               ArrayResize(TradeList,++ctTrade);
               TradeList[ctTrade - 1][0] = OrderOpenTime();
               TradeList[ctTrade - 1][1] = OrderTicket();
              }
           }
        }

      if(ArraySize(TradeList)>0) ArraySort(TradeList,WHOLE_ARRAY,0,MODE_ASCEND);
      for(i=0; i<ctTrade; i++)
        {
         if(OrderSelect(TradeList[i][1],SELECT_BY_TICKET))
           {
            if(OrderType()==OP_BUY) OrderCloseReliable(OrderTicket(),OrderLots(),MarketInfo(Symbol(),MODE_BID),slippage,Red);
            if(OrderType()==OP_SELL) OrderCloseReliable(OrderTicket(),OrderLots(),MarketInfo(Symbol(),MODE_ASK),slippage,Red);
            if((OrderMagicNumber()==magic || OrderMagicNumber()==magic+magic_lock)) orders--;
           }
        }
     }

   total=OrdersTotal();
   if(total>0)
     {
      ctTrade=0;
      ArrayResize(TradeList,ctTrade);
      for(k=total; k>=0; k--)
        {
         if(OrderSelect(k,SELECT_BY_POS) && OrderMagicNumber()==magic+magic_lock)
           {
            if(OrderType()!=OP_BUY && OrderType()!=OP_SELL)
              {
               int locker=OrderTicket();
               datetime locker_time=OrderOpenTime();
               int lockerParent=OrderComment();
               if(OrderSelect(lockerParent,SELECT_BY_TICKET))
                 {
                  double profit=OrderProfit()+OrderSwap()-OrderCommission();
                  if((profit>0 && GetStrengthTrend()!=0) || profit>=1)
                    {
                     ArrayResize(TradeList,++ctTrade);
                     TradeList[ctTrade - 1][0] = locker_time;
                     TradeList[ctTrade - 1][1] = locker;
                    }
                 }
              }
            else
              {
               lockerParent=OrderComment();
               if(OrderSelect(lockerParent,SELECT_BY_TICKET) && OrderType()!=OP_BUY && OrderType()!=OP_SELL)
                 {
                  profit=OrderProfit()+OrderSwap()-OrderCommission();
                  if(profit>0 && GetStrengthTrend()!=0)
                    {
                     ArrayResize(TradeList,++ctTrade);
                     TradeList[ctTrade - 1][0] = OrderOpenTime();
                     TradeList[ctTrade - 1][1] = OrderTicket();
                    }
                 }
              }
           }
        }

      if(ArraySize(TradeList)>0) ArraySort(TradeList,WHOLE_ARRAY,0,MODE_ASCEND);
      for(i=0; i<ctTrade; i++)
        {
         if(OrderSelect(TradeList[i][1],SELECT_BY_TICKET)) OrderDelete(OrderTicket());
        }
     }

   ActualizarOrdenes();

   if(buy || sell)
     {
      double new_sl=0;
      double new_open_price=0;
      double limit_price=0;
      if(buy)
        {
         new_sl=GetStopLoss(OP_BUY);
         new_open_price=MarketInfo(Symbol(),MODE_ASK);
         limit_price=new_sl!=0 ? new_sl : MarketInfo(Symbol(),MODE_BID)+sl;
        }
      if(sell)
        {
         new_sl=GetStopLoss(OP_SELL);
         new_open_price=MarketInfo(Symbol(),MODE_BID);
         limit_price=new_sl!=0 ? new_sl : MarketInfo(Symbol(),MODE_ASK)-sl;
        }
      double diff=MathAbs(new_open_price-last_open_price);

      if(orders>=0 && orders<max_orders && ((!trend_changed && diff>=tp) || trend_changed))
        {
         double val=CalcularVolumen();
         if(buy)
           {
            int t1=OrderSendReliable(Symbol(),OP_BUY,val,new_open_price,slippage,new_sl,GetTakeProfit(OP_BUY),comment,magic,0,Blue);
            direction=1;
            last_open_price=new_open_price;

            if(use_reverse_orders && t1>0 && signal<=1)
              {
               int tl1=OrderSendReliable(Symbol(),OP_SELLSTOP,val,limit_price,slippage,new_open_price-sl,limit_price-(new_open_price-limit_price),t1,magic+magic_lock,0,Red);
              }
           }
         if(sell)
           {
            int t2=OrderSendReliable(Symbol(),OP_SELL,val,new_open_price,slippage,new_sl,GetTakeProfit(OP_SELL),comment,magic,0,Red);
            direction=2;
            last_open_price=new_open_price;

            if(use_reverse_orders && t2>0 && signal>=-1)
              {
               int tl2=OrderSendReliable(Symbol(),OP_BUYSTOP,val,limit_price,slippage,new_open_price+sl,limit_price+(limit_price-new_open_price),t2,magic+magic_lock,0,Blue);
              }
           }
        }
     }

   if(ts_enable) TrailingStop();
  }
//=============================================================================
//							 OrderSendReliable()
//
//	This is intended to be a drop-in replacement for OrderSend() which, 
//	one hopes, is more resistant to various forms of errors prevalent 
//	with MetaTrader.
//			  
//	RETURN VALUE: 
//
//	Ticket number or -1 under some error conditions.  Check
// final error returned by Metatrader with OrderReliableLastErr().
// This will reset the value from GetLastError(), so in that sense it cannot
// be a total drop-in replacement due to Metatrader flaw. 
//
//	FEATURES:
//
//		 * Re-trying under some error conditions, sleeping a random 
//		   time defined by an exponential probability distribution.
//
//		 * Automatic normalization of Digits
//
//		 * Automatically makes sure that stop levels are more than
//		   the minimum stop distance, as given by the server. If they
//		   are too close, they are adjusted.
//
//		 * Automatically converts stop orders to market orders 
//		   when the stop orders are rejected by the server for 
//		   being to close to market.  NOTE: This intentionally
//       applies only to OP_BUYSTOP and OP_SELLSTOP, 
//       OP_BUYLIMIT and OP_SELLLIMIT are not converted to market
//       orders and so for prices which are too close to current
//       this function is likely to loop a few times and return
//       with the "invalid stops" error message. 
//       Note, the commentary in previous versions erroneously said
//       that limit orders would be converted.  Note also
//       that entering a BUYSTOP or SELLSTOP new order is distinct
//       from setting a stoploss on an outstanding order; use
//       OrderModifyReliable() for that. 
//
//		 * Displays various error messages on the log for debugging.
//
//
//	Matt Kennel, 2006-05-28 and following
//
//=============================================================================
int OrderSendReliable(string symbol,int cmd,double volume,double price,
                      int slippage,double stoploss,double takeprofit,
                      string comment,int magic,datetime expiration=0,
                      color arrow_color=CLR_NONE)
  {

// ------------------------------------------------
// Check basic conditions see if trade is possible. 
// ------------------------------------------------
   OrderReliable_Fname="OrderSendReliable";
   OrderReliablePrint(" attempted "+OrderReliable_CommandString(cmd)+" "+volume+
                      " lots @"+price+" sl:"+stoploss+" tp:"+takeprofit);
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   if(IsStopped())
     {
      OrderReliablePrint("error: IsStopped() == true");
      _OR_err=ERR_COMMON_ERROR;
      return(-1);
     }

   int cnt=0;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   while(!IsTradeAllowed() && cnt<retry_attempts)
     {
      OrderReliable_SleepRandomTime(sleep_time,sleep_maximum);
      cnt++;
     }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   if(!IsTradeAllowed())
     {
      OrderReliablePrint("error: no operation possible because IsTradeAllowed()==false, even after retries.");
      _OR_err=ERR_TRADE_CONTEXT_BUSY;

      return(-1);
     }

// Normalize all price / stoploss / takeprofit to the proper # of digits.
   int digits=MarketInfo(symbol,MODE_DIGITS);
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   if(digits>0)
     {
      price=NormalizeDouble(price,digits);
      stoploss=NormalizeDouble(stoploss,digits);
      takeprofit=NormalizeDouble(takeprofit,digits);
     }

   if(stoploss!=0)
      OrderReliable_EnsureValidStop(symbol,price,stoploss);

   int err=GetLastError(); // clear the global variable.  
   err=0;
   _OR_err=0;
   bool exit_loop=false;
   bool limit_to_market=false;

// limit/stop order. 
   int ticket=-1;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   if((cmd==OP_BUYSTOP) || (cmd==OP_SELLSTOP) || (cmd==OP_BUYLIMIT) || (cmd==OP_SELLLIMIT))
     {
      cnt=0;
      while(!exit_loop)
        {
         if(IsTradeAllowed())
           {
            ticket=OrderSend(symbol,cmd,volume,price,slippage,stoploss,
                             takeprofit,comment,magic,expiration,arrow_color);
            err=GetLastError();
            _OR_err=err;
           }
         else
           {
            cnt++;
           }

         switch(err)
           {
            case ERR_NO_ERROR:
               exit_loop=true;
               break;

               // retryable errors
            case ERR_SERVER_BUSY:
            case ERR_NO_CONNECTION:
            case ERR_INVALID_PRICE:
            case ERR_OFF_QUOTES:
            case ERR_BROKER_BUSY:
            case ERR_TRADE_CONTEXT_BUSY:
               cnt++;
               break;

            case ERR_PRICE_CHANGED:
            case ERR_REQUOTE:
               RefreshRates();
               continue;   // we can apparently retry immediately according to MT docs.

            case ERR_INVALID_STOPS:
               double servers_min_stop=MarketInfo(symbol,MODE_STOPLEVEL)*MarketInfo(symbol,MODE_POINT);
               if(cmd==OP_BUYSTOP)
                 {
                  // If we are too close to put in a limit/stop order so go to market.
                  if(MathAbs(MarketInfo(symbol,MODE_ASK)-price)<=servers_min_stop)
                     limit_to_market=true;

                 }
               else if(cmd==OP_SELLSTOP)
                 {
                  // If we are too close to put in a limit/stop order so go to market.
                  if(MathAbs(MarketInfo(symbol,MODE_BID)-price)<=servers_min_stop)
                     limit_to_market=true;
                 }
               exit_loop=true;
               break;

            default:
               // an apparently serious error.
               exit_loop=true;
               break;

           }  // end switch 

         if(cnt>retry_attempts)
            exit_loop=true;

         if(exit_loop)
           {
            if(err!=ERR_NO_ERROR)
              {
               OrderReliablePrint("non-retryable error: "+OrderReliableErrTxt(err));
              }
            if(cnt>retry_attempts)
              {
               OrderReliablePrint("retry attempts maxed at "+retry_attempts);
              }
           }

         if(!exit_loop)
           {
            OrderReliablePrint("retryable error ("+cnt+"/"+retry_attempts+
                               "): "+OrderReliableErrTxt(err));
            OrderReliable_SleepRandomTime(sleep_time,sleep_maximum);
            RefreshRates();
           }
        }

      // We have now exited from loop. 
      if(err==ERR_NO_ERROR)
        {
         OrderReliablePrint("apparently successful OP_BUYSTOP or OP_SELLSTOP order placed, details follow.");
         OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES);
         OrderPrint();
         return(ticket); // SUCCESS! 
        }
      if(!limit_to_market)
        {
         OrderReliablePrint("failed to execute stop or limit order after "+cnt+" retries");
         OrderReliablePrint("failed trade: "+OrderReliable_CommandString(cmd)+" "+symbol+
                            "@"+price+" tp@"+takeprofit+" sl@"+stoploss);
         OrderReliablePrint("last error: "+OrderReliableErrTxt(err));
         return(-1);
        }
     }  // end	  
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   if(limit_to_market)
     {
      OrderReliablePrint("going from limit order to market order because market is too close.");
      if((cmd==OP_BUYSTOP) || (cmd==OP_BUYLIMIT))
        {
         cmd=OP_BUY;
         price=MarketInfo(symbol,MODE_ASK);
        }
      else if((cmd==OP_SELLSTOP) || (cmd==OP_SELLLIMIT))
        {
         cmd=OP_SELL;
         price=MarketInfo(symbol,MODE_BID);
        }
     }

// we now have a market order.
   err=GetLastError(); // so we clear the global variable.  
   err= 0;
   _OR_err= 0;
   ticket = -1;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   if((cmd==OP_BUY) || (cmd==OP_SELL))
     {
      cnt=0;
      while(!exit_loop)
        {
         if(IsTradeAllowed())
           {
            ticket=OrderSend(symbol,cmd,volume,price,slippage,
                             stoploss,takeprofit,comment,magic,
                             expiration,arrow_color);
            err=GetLastError();
            _OR_err=err;
           }
         else
           {
            cnt++;
           }
         switch(err)
           {
            case ERR_NO_ERROR:
               exit_loop=true;
               break;

            case ERR_SERVER_BUSY:
            case ERR_NO_CONNECTION:
            case ERR_INVALID_PRICE:
            case ERR_OFF_QUOTES:
            case ERR_BROKER_BUSY:
            case ERR_TRADE_CONTEXT_BUSY:
               cnt++; // a retryable error
               break;

            case ERR_PRICE_CHANGED:
            case ERR_REQUOTE:
               RefreshRates();
               continue; // we can apparently retry immediately according to MT docs.

            default:
               // an apparently serious, unretryable error.
               exit_loop=true;
               break;

           }  // end switch 

         if(cnt>retry_attempts)
            exit_loop=true;

         if(!exit_loop)
           {
            OrderReliablePrint("retryable error ("+cnt+"/"+
                               retry_attempts+"): "+OrderReliableErrTxt(err));
            OrderReliable_SleepRandomTime(sleep_time,sleep_maximum);
            RefreshRates();
           }

         if(exit_loop)
           {
            if(err!=ERR_NO_ERROR)
              {
               OrderReliablePrint("non-retryable error: "+OrderReliableErrTxt(err));
              }
            if(cnt>retry_attempts)
              {
               OrderReliablePrint("retry attempts maxed at "+retry_attempts);
              }
           }
        }

      // we have now exited from loop. 
      if(err==ERR_NO_ERROR)
        {
         OrderReliablePrint("apparently successful OP_BUY or OP_SELL order placed, details follow.");
         OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES);
         OrderPrint();
         return(ticket); // SUCCESS! 
        }
      OrderReliablePrint("failed to execute OP_BUY/OP_SELL, after "+cnt+" retries");
      OrderReliablePrint("failed trade: "+OrderReliable_CommandString(cmd)+" "+symbol+
                         "@"+price+" tp@"+takeprofit+" sl@"+stoploss);
      OrderReliablePrint("last error: "+OrderReliableErrTxt(err));
      return(-1);
     }
  }
//=============================================================================
//							 OrderCloseReliable()
//
//	This is intended to be a drop-in replacement for OrderClose() which, 
//	one hopes, is more resistant to various forms of errors prevalent 
//	with MetaTrader.
//			  
//	RETURN VALUE: 
//
//		TRUE if successful, FALSE otherwise
//
//
//	FEATURES:
//
//		 * Re-trying under some error conditions, sleeping a random 
//		   time defined by an exponential probability distribution.
//
//		 * Displays various error messages on the log for debugging.
//
//
//	Derk Wehler, ashwoods155@yahoo.com  	2006-07-19
//
//=============================================================================
bool OrderCloseReliable(int ticket,double lots,double price,
                        int slippage,color arrow_color=CLR_NONE)
  {
   int nOrderType;
   string strSymbol;
   OrderReliable_Fname="OrderCloseReliable";

   OrderReliablePrint(" attempted close of #"+ticket+" price:"+price+
                      " lots:"+lots+" slippage:"+slippage);
// collect details of order so that we can use GetMarketInfo later if needed
   if(!OrderSelect(ticket,SELECT_BY_TICKET))
     {
      _OR_err=GetLastError();
      OrderReliablePrint("error: "+ErrorDescription(_OR_err));
      return(false);
     }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   else
     {
      nOrderType= OrderType();
      strSymbol = OrderSymbol();
     }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   if(nOrderType!=OP_BUY && nOrderType!=OP_SELL)
     {
      _OR_err=ERR_INVALID_TICKET;
      OrderReliablePrint("error: trying to close ticket #"+ticket+", which is "+OrderReliable_CommandString(nOrderType)+", not OP_BUY or OP_SELL");
      return(false);
     }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   if(IsStopped())
     {
      OrderReliablePrint("error: IsStopped() == true");
      return(false);
     }

   int cnt=0;

   int err=GetLastError(); // so we clear the global variable.  
   err=0;
   _OR_err=0;
   bool exit_loop=false;
   cnt=0;
   bool result=false;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   while(!exit_loop)
     {
      if(IsTradeAllowed())
        {
         result=OrderClose(ticket,lots,price,slippage,arrow_color);
         err=GetLastError();
         _OR_err=err;
        }
      else
         cnt++;

      if(result==true)
         exit_loop=true;

      switch(err)
        {
         case ERR_NO_ERROR:
            exit_loop=true;
            break;

         case ERR_SERVER_BUSY:
         case ERR_NO_CONNECTION:
         case ERR_INVALID_PRICE:
         case ERR_OFF_QUOTES:
         case ERR_BROKER_BUSY:
         case ERR_TRADE_CONTEXT_BUSY:
         case ERR_TRADE_TIMEOUT:      // for modify this is a retryable error, I hope. 
            cnt++;    // a retryable error
            break;

         case ERR_PRICE_CHANGED:
         case ERR_REQUOTE:
            continue;    // we can apparently retry immediately according to MT docs.

         default:
            // an apparently serious, unretryable error.
            exit_loop=true;
            break;

        }  // end switch 

      if(cnt>retry_attempts)
         exit_loop=true;

      if(!exit_loop)
        {
         OrderReliablePrint("retryable error ("+cnt+"/"+retry_attempts+
                            "): "+OrderReliableErrTxt(err));
         OrderReliable_SleepRandomTime(sleep_time,sleep_maximum);
         // Added by Paul Hampton-Smith to ensure that price is updated for each retry
         if(nOrderType == OP_BUY)  price = NormalizeDouble(MarketInfo(strSymbol,MODE_BID),MarketInfo(strSymbol,MODE_DIGITS));
         if(nOrderType == OP_SELL) price = NormalizeDouble(MarketInfo(strSymbol,MODE_ASK),MarketInfo(strSymbol,MODE_DIGITS));
        }

      if(exit_loop)
        {
         if((err!=ERR_NO_ERROR) && (err!=ERR_NO_RESULT))
            OrderReliablePrint("non-retryable error: "+OrderReliableErrTxt(err));

         if(cnt>retry_attempts)
            OrderReliablePrint("retry attempts maxed at "+retry_attempts);
        }
     }
// we have now exited from loop. 
   if((result==true) || (err==ERR_NO_ERROR))
     {
      OrderReliablePrint("apparently successful close order, updated trade details follow.");
      OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES);
      OrderPrint();
      return(true); // SUCCESS! 
     }

   OrderReliablePrint("failed to execute close after "+cnt+" retries");
   OrderReliablePrint("failed close: Ticket #"+ticket+", Price: "+
                      price+", Slippage: "+slippage);
   OrderReliablePrint("last error: "+OrderReliableErrTxt(err));

   return(false);
  }
//=============================================================================
//=============================================================================
//								Utility Functions
//=============================================================================
//=============================================================================



int OrderReliableLastErr()
  {
   return (_OR_err);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string OrderReliableErrTxt(int err)
  {
   return ("" + err + ":" + ErrorDescription(err));
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OrderReliablePrint(string s)
  {
// Print to log prepended with stuff;
   if(!(IsTesting() || IsOptimization())) Print(OrderReliable_Fname+" "+OrderReliableVersion+":"+s);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string OrderReliable_CommandString(int cmd)
  {
   if(cmd==OP_BUY)
      return("OP_BUY");

   if(cmd==OP_SELL)
      return("OP_SELL");

   if(cmd==OP_BUYSTOP)
      return("OP_BUYSTOP");

   if(cmd==OP_SELLSTOP)
      return("OP_SELLSTOP");

   if(cmd==OP_BUYLIMIT)
      return("OP_BUYLIMIT");

   if(cmd==OP_SELLLIMIT)
      return("OP_SELLLIMIT");

   return("(CMD==" + cmd + ")");
  }
//=============================================================================
//
//						 OrderReliable_EnsureValidStop()
//
// 	Adjust stop loss so that it is legal.
//
//	Matt Kennel 
//
//=============================================================================
void OrderReliable_EnsureValidStop(string symbol,double price,double &sl)
  {
// Return if no S/L
   if(sl==0)
      return;

   double servers_min_stop=MarketInfo(symbol,MODE_STOPLEVEL)*MarketInfo(symbol,MODE_POINT);
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   if(MathAbs(price-sl)<=servers_min_stop)
     {
      // we have to adjust the stop.
      if(price>sl)
         sl=price-servers_min_stop;   // we are long

      else if(price<sl)
         sl=price+servers_min_stop;   // we are short

      else
         OrderReliablePrint("EnsureValidStop: error, passed in price == sl, cannot adjust");

      sl=NormalizeDouble(sl,MarketInfo(symbol,MODE_DIGITS));
     }
  }
//=============================================================================
//
//						 OrderReliable_SleepRandomTime()
//
//	This sleeps a random amount of time defined by an exponential 
//	probability distribution. The mean time, in Seconds is given 
//	in 'mean_time'.
//
//	This is the back-off strategy used by Ethernet.  This will 
//	quantize in tenths of seconds, so don't call this with a too 
//	small a number.  This returns immediately if we are backtesting
//	and does not sleep.
//
//	Matt Kennel mbkennelfx@gmail.com.
//
//=============================================================================
void OrderReliable_SleepRandomTime(double mean_time,double max_time)
  {
   if(IsTesting())
      return;    // return immediately if backtesting.

   double tenths=MathCeil(mean_time/0.1);
   if(tenths<=0)
      return;

   int maxtenths=MathRound(max_time/0.1);
   double p=1.0-1.0/tenths;

   Sleep(100);    // one tenth of a second PREVIOUS VERSIONS WERE STUPID HERE. 

   for(int i=0; i<maxtenths; i++)
      //+------------------------------------------------------------------+
      //|                                                                  |
      //+------------------------------------------------------------------+
      //+------------------------------------------------------------------+
      //|                                                                  |
      //+------------------------------------------------------------------+
      //+------------------------------------------------------------------+
      //|                                                                  |
      //+------------------------------------------------------------------+
     {
      if(MathRand()>p*32768)
         break;

      // MathRand() returns in 0..32767
      Sleep(100);
     }
  }
//+------------------------------------------------------------------+
