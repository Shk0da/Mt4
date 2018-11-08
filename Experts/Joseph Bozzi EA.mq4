//+------------------------------------------------------------------+
#define MAGICMA  20181031
//--- Inputs
input double BalanceRisk   =30;
input double BalanceLimit  =50;
input double MinimumLots   =0.01;
input double SFPofit       =0.0031;
input double MaximumSpread =30;
input double TP            =0;
input double SL            =0;

input bool   TSEnable      =true;
input int    TSVal         =30;
input int    TSStep        =5;

extern string linearregressionRrealIndicator="linearregression-real.mq4";
extern int lrlPeriod=10;
extern string rSquaredV1Indicator="r-squared_v1.mq4";
extern int price=1;
extern int length=13;
extern int smooth=17;
extern string iRegrIndicator="i-Regr.mq4";
extern int degree=1;
extern double kstd=1.0;
extern int bars=14;
extern int shift=0;

enum Signal {UP,DOWN,CLOSE,NONE};
Signal prevsignal=NONE;
static datetime LastBarOpenAt;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
   Signal signal=NONE;
   if(LastBarOpenAt!=Time[0])
     {
      LastBarOpenAt=Time[0];
      signal=CalculaSignal();
     }
   int ordenes=0;
   double sfprofit=AccountBalance()*SFPofit;
   for(int i=0; i<OrdersTotal(); i++)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
        {
         if(OrderSymbol()==Symbol() && OrderMagicNumber()==MAGICMA && (OrderType()==OP_BUY || OrderType()==OP_SELL))
           {
            if(prevsignal==NONE)
              {
               if(OrderType()==OP_BUY) prevsignal=UP;
               if(OrderType()==OP_SELL) prevsignal=DOWN;
              }
            double profit=OrderProfit()+OrderSwap()-OrderCommission();
            if((((prevsignal==UP && signal==DOWN) || (prevsignal==DOWN && signal==UP)) && profit>0) || (profit>=sfprofit) || signal==CLOSE)
              {
               if(OrderType()==OP_BUY && OrderClose(OrderTicket(),OrderLots(),Bid,3,Red)) {};
               if(OrderType()==OP_SELL && OrderClose(OrderTicket(),OrderLots(),Ask,3,Red)) {};
              }
            else
              {
               ordenes++;
               if(TSEnable) TrailingPositions();
              }
           }
        }
     }

   if(signal == NONE) return;

   double tp=TP*MarketInfo(Symbol(),MODE_POINT);
   double sl=SL*MarketInfo(Symbol(),MODE_POINT);
   double spread=MarketInfo(Symbol(),MODE_ASK)-MarketInfo(Symbol(),MODE_BID);
   if(ordenes==0 && signal==UP)
     {
      if(OrderSend(Symbol(),OP_BUY,CalcularVolumen(),Ask,0,sl!=0?Ask-sl:0,tp!=0?Ask+spread+tp:0,"",MAGICMA,0,Blue))
        {
         prevsignal=signal;
        }
     }

   if(ordenes==0 && signal==DOWN)
     {
      if(OrderSend(Symbol(),OP_SELL,CalcularVolumen(),Bid,0,sl!=0?Bid+sl:0,tp!=0?Bid-spread-tp:0,"",MAGICMA,0,Red))
        {
         prevsignal=signal;
        }
     }
  }
//+------------------------------------------------------------------+
double CalcularVolumen()
  {
   double aux=MinimumLots*MathFloor(BalanceRisk*AccountFreeMargin()/100000/MinimumLots);

   double free=AccountFreeMargin();
   double margin=MarketInfo(Symbol(),MODE_MARGINREQUIRED);
   double step= MarketInfo(Symbol(),MODE_LOTSTEP);
   double lot = MathFloor(free*BalanceRisk/100/margin/step)*step;
   double max=(lot*margin>free) ? 0 : lot;

   if(aux>max) aux=max;
   if(aux<MinimumLots) aux=MinimumLots;
   if(aux>MarketInfo(Symbol(),MODE_MAXLOT)) aux=MarketInfo(Symbol(),MODE_MAXLOT);
   if(aux<MarketInfo(Symbol(),MODE_MINLOT)) aux=MarketInfo(Symbol(),MODE_MINLOT);

   return(aux);
  }
//+------------------------------------------------------------------+
void TrailingPositions()
  {
   double pBid,pAsk;
   double val=TSVal;
   double pp=MarketInfo(OrderSymbol(),MODE_POINT);
   int stop_level=MarketInfo(Symbol(),MODE_STOPLEVEL)+MarketInfo(Symbol(),MODE_SPREAD);
   if(OrderType()==OP_BUY)
     {
      pBid=MarketInfo(OrderSymbol(),MODE_BID);
      if((pBid-OrderOpenPrice())>val*pp)
        {
         if(OrderStopLoss()<pBid-(val+TSStep-1)*pp)
           {
            double ldStopLossBuy=pBid-val*pp;
            double ldTakeProfitBuy=OrderTakeProfit()>0 ? OrderTakeProfit()+TSStep*MarketInfo(OrderSymbol(),MODE_POINT) : 0;
            if(OrderModify(OrderTicket(),OrderOpenPrice(),ldStopLossBuy,ldTakeProfitBuy,0,CLR_NONE)){};
            return;
           }
        }
     }
   if(OrderType()==OP_SELL)
     {
      pAsk=MarketInfo(OrderSymbol(),MODE_ASK);
      if(OrderOpenPrice()-pAsk>val*pp)
        {
         if(OrderStopLoss()>pAsk+(val+TSStep-1)*pp || OrderStopLoss()==0)
           {
            double ldStopLossSell=pAsk+val*pp;
            double ldTakeProfitSell=OrderTakeProfit()>0 ? OrderTakeProfit()+TSStep*MarketInfo(OrderSymbol(),MODE_POINT)*-1 : 0;
            if(OrderModify(OrderTicket(),OrderOpenPrice(),ldStopLossSell,ldTakeProfitSell,0,CLR_NONE)) {};
            return;
           }
        }
     }
  }
//+------------------------------------------------------------------+
Signal CalculaSignal()
  {
   if(AccountBalance()<=BalanceLimit) return NONE;
   if(MarketInfo(Symbol(), MODE_SPREAD) > MaximumSpread * MarketInfo(Symbol(), MODE_DIGITS)) return NONE;

   double linearPrev2=iCustom(Symbol(),0,"linearregression-real",lrlPeriod,0,2);
   double linearPrev1=iCustom(Symbol(),0,"linearregression-real",lrlPeriod,0,1);
   double linear=iCustom(Symbol(),0,"linearregression-real",lrlPeriod,0,0);

   double squaredPrev1=iCustom(Symbol(),0,"r-squared_v1",price,length,smooth,0,1);
   double squared=iCustom(Symbol(),0,"r-squared_v1",price,length,smooth,0,0);

   double iRegr1=iCustom(Symbol(),0,"i-Regr",degree,kstd,bars,shift,0,0);
   double iRegr2=iCustom(Symbol(),0,"i-Regr",degree,kstd,bars,shift,1,0);
   double iRegr3=iCustom(Symbol(),0,"i-Regr",degree,kstd,bars,shift,2,0);

   Signal signal=NONE;
   if(squared<5 && squared<squaredPrev1)
     {
      if(linearPrev2<linearPrev1 && linearPrev1<linear && linear <= iRegr2) signal=UP;
      if(linearPrev2>linearPrev1 && linearPrev1>linear && linear >= iRegr2) signal=DOWN;
     }
   if(signal==NONE)
     {
      if(prevsignal == UP && linear >= iRegr1 && linearPrev1>linear) signal=DOWN;
      if(prevsignal == DOWN && linear <= iRegr3 && linearPrev1<linear) signal=UP;
     }
   if(signal==NONE && squared<50)
     {
      if(linearPrev2<linearPrev1 && linearPrev1>linear && linear >= iRegr1) signal=DOWN;
      if(linearPrev2>linearPrev1 && linearPrev1<linear && linear <= iRegr3) signal=UP;
     }

   return signal;
  }
//+------------------------------------------------------------------+
