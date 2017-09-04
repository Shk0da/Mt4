//+------------------------------------------------------------------+
//|                                                    ZigZag EA.mq4 |
//|                                                                  |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright ""
#property link      ""
#property version   "1.00"
#property strict

// ------------------------------------------------------------------------------------------------
// EXTERNAL VARIABLES
// ------------------------------------------------------------------------------------------------
extern int magic=19275;
// Configuration
extern string CommonSettings="---------------------------------------------";
extern int user_slippage=2;
extern int user_tp=50;
extern int user_sl=100;
extern bool use_basic_tp=true;
extern bool use_basic_sl=false;
extern bool use_dynamic_tp=true;
extern bool use_dynamic_sl=false;
extern string MoneyManagementSettings="---------------------------------------------";
// Money Management
extern double min_lots=0.01;
extern int risk=20;
extern double balance_limit=50;
extern int max_orders=1;
extern bool global_basket=true;
// Indicators
extern string IndicatorsSettings="---------------------------------------------";
extern int shift=1;
extern bool check_strength=true;
// Trailing stop
extern string TrailingStopSettings="---------------------------------------------";
extern bool ts_enable=true;
extern int ts_val=15;
extern int ts_step=2;
extern bool ts_only_profit=true;
// Optimization
extern string Optimization="---------------------------------------------";
extern int x1 = 24;
extern int x2 = 10;
extern int x3 = 6;
extern int x4 = 0;
extern int x5 = 3;
extern int x6 = 3;
extern int x7 = 3;
extern int x8 = 1;
extern int x9 = 1;
extern int x10 = 25;
extern int x11 = 35;
extern int x12 = 35;
extern int x13 = 45;
extern double x14 = 0.001754;
extern double x15 = 0.00150;
// ------------------------------------------------------------------+
// GLOBAL VARIABLES                                                  |
// ------------------------------------------------------------------+
string key="ZigZag EA: ";
int magic_lock=777;
int slippage=0;
int atr_period=14;
int digits=MarketInfo(Symbol(),MODE_DIGITS);
//+------------------------------------------------------------------+
//| Start                                                            |
//+------------------------------------------------------------------+
int start()
  {

   if(AccountBalance()<=balance_limit)
     {
      Alert("Balance: "+AccountBalance());
      return(0);
     }

   if(digits==4)
     {
      slippage=user_slippage;
     }
   else if(digits==5)
     {
      slippage=10*user_slippage;
     }

   if(IsTradeAllowed()==false)
     {
      Comment("Trade not allowed.");
      return(0);
     }

   Comment("\nZigZag EA is running.");
   Trade();

   return(0);
  }
//+------------------------------------------------------------------+
//| CalculateSignal                                                  |
//+------------------------------------------------------------------+
double zz_prev=0;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CalculateSignal()
  {
   if(AccountBalance()<=balance_limit)
     {
      return(0);
     }

   int aux=0;
   int strength=check_strength ? GetStrengthTrend() : 0;
   double ihigh=iHigh(Symbol(),0,x8);
   double ilow=iLow(Symbol(),0,x9);
   double diff=ihigh-ilow;

   int aux1=0;
   if(diff>x14) //0.00150 - 0.00250
     {
      double zz_cur=iCustom(Symbol(),0,"ZigZag",x1,x2,x3,x4,x5);
      if(zz_cur>0)
        {
         if(zz_cur < zz_prev && zz_prev > 0 && strength > 0) aux=1;
         if(zz_cur > zz_prev && zz_prev > 0 && strength < 0) aux1=-1;
         zz_prev=zz_cur;
        }
     }

   int aux2=0;
   if(diff>x15) //0.00150 - 0.00250
     {
      O_0(gda_328,gda_332,gia_336,gd_340);

      double iMAL=iMA(NULL,0,x6,0,MODE_LWMA,PRICE_LOW,shift);
      double bb=MathAbs(ihigh-MarketInfo(Symbol(),MODE_BID));
      if(MarketInfo(Symbol(),MODE_BID)>iMAL && bb>0 && Oo<0.0) aux2=1;

      double iMAH=iMA(NULL,0,x7,0,MODE_LWMA,PRICE_HIGH,shift);
      double sb=MathAbs(MarketInfo(Symbol(),MODE_BID)-ilow);
      if(MarketInfo(Symbol(),MODE_BID)<iMAH && sb>0 && Oo>0.0) aux2=-1;
     }

   aux = aux1+aux2;
   return((aux > 0 && strength >= 0) || (aux < 0 && strength <= 0) ? aux : 0);
  }

double Oo;
double gda_328[30];
double gda_332[30];
int gia_336[30];
double gd_340=1.0;
double gd_360;
bool gi_356;
double gd_316=0.00001;
//+------------------------------------------------------------------+
//| oOo0o0Oo Magic oOo0o0Oo                                          |
//+------------------------------------------------------------------+
void O_0(double &ada_0[30],double &ada_4[30],int &aia_8[30],double ad_12)
  {
   double ld_52;
   if(aia_8[0]==0 || MathAbs(MarketInfo(Symbol(),MODE_BID)-ada_0[0])>=ad_12*gd_316)
     {
      for(int li_20=29; li_20>0; li_20--)
        {
         ada_0[li_20] = ada_0[li_20 - 1];
         ada_4[li_20] = ada_4[li_20 - 1];
         aia_8[li_20] = aia_8[li_20 - 1];
        }
      ada_0[0] = MarketInfo(Symbol(),MODE_BID);
      ada_4[0] = MarketInfo(Symbol(),MODE_ASK);
      aia_8[0] = GetTickCount();
     }
   Oo=0;
   gi_356=FALSE;
   double ld_24=0;
   int li_32=0;
   double ld_36=0;
   int li_44=0;
   int li_unused_48=0;
   for(int li_20=1; li_20<30; li_20++)
     {
      if(aia_8[li_20]==0) break;
      ld_52=ada_0[0]-ada_0[li_20];
      if(ld_52<ld_24)
        {
         ld_24 = ld_52;
         li_32 = aia_8[0] - aia_8[li_20];
        }
      if(ld_52>ld_36)
        {
         ld_36 = ld_52;
         li_44 = aia_8[0] - aia_8[li_20];
        }
      if(ld_24<0.0 && ld_36>0.0 && ld_24<3.0 *((-ad_12)*gd_316) || ld_36>3.0 *(ad_12*gd_316))
        {
         if((-ld_24)/ld_36<0.5)
           {
            Oo=ld_36;
            gi_356=li_44;
            break;
           }
         if((-ld_36)/ld_24<0.5)
           {
            Oo=ld_24;
            gi_356=li_32;
           }
           } else {
         if(ld_36>5.0 *(ad_12*gd_316))
           {
            Oo=ld_36;
            gi_356=li_44;
              } else {
            if(ld_24<5.0 *((-ad_12)*gd_316))
              {
               Oo=ld_24;
               gi_356=li_32;
               break;
              }
           }
        }
     }
   if(gi_356==FALSE)
     {
      gd_360=0;
      return;
     }
   gd_360=1000.0*Oo/gi_356;
  }
//+------------------------------------------------------------------+
//| GetStrengthTrend                                                 |
//+------------------------------------------------------------------+
int GetStrengthTrend()
  {
   int adx_period=0;
   switch(Period())
     {
      case 1: adx_period = 15; break;
      case 5: adx_period = 60; break;
      case 15: adx_period = 240; break;
      case 30: adx_period = 24*60; break;
      case 60: adx_period = 24*60; break;
     }

   double adxMain=iADX(Symbol(),adx_period,14,PRICE_MEDIAN,MODE_MAIN,0);
   double adxDiPlus=iADX(Symbol(),adx_period,14,PRICE_MEDIAN,MODE_PLUSDI,0);
   double adxDiMinus=iADX(Symbol(),adx_period,14,PRICE_MEDIAN,MODE_MINUSDI,0);

   int strngth=0;
   if(adxMain>x10 && adxDiPlus>=25 && adxDiMinus<=15) strngth=1;
   else if(adxMain>x11 && adxDiMinus>=25 && adxDiPlus<=15) strngth=-1;
   if(adxMain>x12 && adxDiPlus>=25 && adxDiMinus<=15) strngth=2;
   else if(adxMain>x13 && adxDiMinus>=25 && adxDiPlus<=15) strngth=-2;

   return(strngth);
  }
//+------------------------------------------------------------------+
//| Trade                                                            |
//+------------------------------------------------------------------+
int direction=0;
int signal=0;
bool buy=false;
bool sell=false;
bool previous_buy=false;
bool previous_sell=false;
datetime last_open_time=TimeCurrent();
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void Trade()
  {
   RefreshRates();
   signal=CalculateSignal();
   Comment(key+signal);

   previous_buy=buy;
   previous_sell=sell;
   buy = signal>0;
   sell= signal<0;

   bool trend_changed=((buy && direction<0) || (sell && direction>0));
   double pr=GetPfofit();

   int total=0;
   int TradeList[][2];
   int ctTrade=0;
   if((trend_changed || (GetCountOrders()>max_orders)) && pr>=0 || GetCountOrders() == 0)
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
            case OP_BUY       : OrderClose(OrderTicket(),OrderLots(),MarketInfo(Symbol(),MODE_BID),slippage,clrRed);
            break;
            case OP_SELL      : OrderClose(OrderTicket(),OrderLots(),MarketInfo(Symbol(),MODE_ASK),slippage,clrRed);
            break;
            case OP_BUYLIMIT  :
            case OP_BUYSTOP   :
            case OP_SELLLIMIT :
            case OP_SELLSTOP  : OrderDelete(OrderTicket());
            break;
           }
        }
     }

   if(OrdersTotal()>0)
     {
      total=OrdersTotal();
      ctTrade=0;
      ArrayResize(TradeList,ctTrade);
      for(int k=total; k>=0; k--)
        {
         if(OrderSelect(k,SELECT_BY_POS) && OrderMagicNumber()==magic+magic_lock && (OrderType()!=OP_BUY && OrderType()!=OP_SELL))
           {
            int locker=OrderTicket();
            datetime locker_time=OrderOpenTime();
            int lockerParent=OrderComment();
            if(!OrderSelect(lockerParent,SELECT_BY_TICKET,MODE_TRADES))
              {
               ArrayResize(TradeList,++ctTrade);
               TradeList[ctTrade - 1][0] = locker_time;
               TradeList[ctTrade - 1][1] = locker;
              }
           }
        }

      if(ArraySize(TradeList)>0) ArraySort(TradeList,WHOLE_ARRAY,0,MODE_ASCEND);
      for(int i=0; i<ctTrade; i++)
        {
         if(OrderSelect(TradeList[i][1],SELECT_BY_TICKET)) OrderDelete(OrderTicket());
        }
     }

   double diff=MathAbs(TimeCurrent()-last_open_time);
   if((buy || sell) && (GetCountOrders()<max_orders && diff>=600))
     {
      double atr=iATR(Symbol(),0,atr_period,shift);
      double tp_val=atr/0.00001;
      double tp = tp_val*MarketInfo(Symbol(),MODE_POINT);
      double sl = tp*-1*(MarketInfo(Symbol(),MODE_DIGITS) >= 4 ? 3 : .5);

      double new_open_price=0;
      double limit_price=0;
      if(buy)
        {
         direction=1;
         new_open_price=MarketInfo(Symbol(),MODE_ASK);
         limit_price=NormalizeDouble(MarketInfo(Symbol(),MODE_BID)+sl*4,digits);
         int t1=OrderSend(Symbol(),OP_BUYSTOP,CalculatePips(),new_open_price,slippage,GetStopLoss(OP_BUY),GetTakeProfit(OP_BUY),key,magic,0,clrGreen);
         if(t1>0 && signal<=1)
           {
            int tl1=OrderSend(Symbol(),OP_SELLSTOP,CalculatePips(),limit_price,slippage,new_open_price,NormalizeDouble(limit_price-(new_open_price-limit_price),digits),t1,magic+magic_lock,0,clrBlue);
           }

         last_open_time=TimeCurrent();
        }
      if(sell)
        {
         direction=-1;
         new_open_price=MarketInfo(Symbol(),MODE_BID);
         limit_price=NormalizeDouble(MarketInfo(Symbol(),MODE_ASK)-sl*4,digits);
         int t2=OrderSend(Symbol(),OP_SELLSTOP,CalculatePips(),new_open_price,slippage,GetStopLoss(OP_SELL),GetTakeProfit(OP_SELL),key,magic,0,clrGreen);
         if(t2>0 && signal>=-1)
           {
            int tl2=OrderSend(Symbol(),OP_BUYSTOP,CalculatePips(),limit_price,slippage,new_open_price,NormalizeDouble(limit_price+(limit_price-new_open_price),digits),t2,magic+magic_lock,0,clrBlue);
           }

         last_open_time=TimeCurrent();
        }
     }

   if(ts_enable) TrailingStop();
  }
//+------------------------------------------------------------------+
//| GetCountOrders                                                   |
//+------------------------------------------------------------------+
int GetCountOrders()
  {
   int count=0;
   int total=OrdersTotal();
   for(int k=total-1; k>=0; k--)
     {
      if(OrderSelect(k,SELECT_BY_POS) && (OrderType()==OP_BUY || OrderType()==OP_SELL))
        {
         if(global_basket)
           {
            if((OrderMagicNumber()==magic || OrderMagicNumber()==magic+magic_lock))
              {
               count++;
              }
           }
         else
           {
            if(OrderSymbol()==Symbol() && (OrderMagicNumber()==magic || OrderMagicNumber()==magic+magic_lock))
              {
               count++;
              }
           }
        }
     }

   return(count);
  }
// ------------------------------------------------------------------------------------------------
// CALCULATE VOLUME
// ------------------------------------------------------------------------------------------------
double CalculatePips()
  {
   int n;
   double aux;
   aux=risk*AccountFreeMargin();
   aux=aux/100000;
   n=MathFloor(aux/min_lots);
   aux=n*min_lots;

   double max=GetMaxLot(risk);
   if(aux>max) aux=max;
   if(aux<min_lots) aux=min_lots;

   if(aux>MarketInfo(Symbol(),MODE_MAXLOT)) aux=MarketInfo(Symbol(),MODE_MAXLOT);
   if(aux<MarketInfo(Symbol(),MODE_MINLOT)) aux=MarketInfo(Symbol(),MODE_MINLOT);

   return(aux);
  }
//+------------------------------------------------------------------+
//| GetMaxLot                                                        |
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
      double atr=iATR(Symbol(),0,atr_period,shift)/0.00001;
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
      double atr=iATR(Symbol(),0,atr_period,shift)/0.00001*3;
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
//+------------------------------------------------------------------+
//| GetPfofit                                                        |
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
//| TrailingStop                                                     |
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
//| TrailingPositions                                                |
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
//| ModifyStopLoss                                                   |
//+------------------------------------------------------------------+
void ModifyStopLoss(double ldStopLoss)
  {
   double ldTakeProfit=ts_only_profit
                       ? OrderTakeProfit()+ts_step*MarketInfo(OrderSymbol(),MODE_POINT)*((OrderType()==OP_BUY) ? 1 : -1)
                       : OrderTakeProfit();
   OrderModify(OrderTicket(),OrderOpenPrice(),ldStopLoss,ldTakeProfit,0,CLR_NONE);
  }
//+------------------------------------------------------------------+
