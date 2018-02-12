//+------------------------------------------------------------------+
#define MAGICMA  20180208
#define MAGICMA2  19274
//--- Inputs
input double BalanceRisk   =30;
input double BalanceLimit  =50;
input double MinimumLots   =0.01;
input double SFPofit       =0.0025;
input double MaximumSpread =30;
input double TP            =40;
input int    MAW           =7;
input int    MAB           =63;

input bool   TSEnable      =true;
input int    TSVal         =40;
input int    TSStep        =12;

int prevsignal=0;
//+------------------------------------------------------------------+
void OnTick()
  {
   int signal=CalculaSignal();

   int ordenes=0;
   double sfprofit=AccountBalance()*SFPofit;
   for(int i=0; i<OrdersTotal(); i++)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
        {
         if(OrderSymbol()==Symbol() && (OrderMagicNumber()==MAGICMA || OrderMagicNumber()==MAGICMA2) && (OrderType()==OP_BUY || OrderType()==OP_SELL))
           {
            if(prevsignal==0)
              {
               if(OrderType()==OP_BUY) prevsignal=1;
               if(OrderType()==OP_SELL) prevsignal=-1;
              }
            double profit=OrderProfit()+OrderSwap()-OrderCommission();
            if((prevsignal>0 && signal<0 || prevsignal<0 && signal>0) || (profit>=sfprofit))
              {
               if(OrderType()==OP_BUY) OrderClose(OrderTicket(),OrderLots(),Bid,3,Red);
               if(OrderType()==OP_SELL) OrderClose(OrderTicket(),OrderLots(),Ask,3,Red);
              }
            else
              {
               ordenes++;
               if(TSEnable) TrailingPositions();
              }
           }
        }
     }

   if(signal == 0) return;

   double tp=TP*MarketInfo(Symbol(),MODE_POINT);
   double spread=MarketInfo(Symbol(),MODE_ASK)-MarketInfo(Symbol(),MODE_BID);
   if(ordenes==0 && signal>0)
     {
      if(OrderSend(Symbol(),OP_BUY,CalcularVolumen(),Ask,0,0,Ask+spread+tp,"",MAGICMA,0,Blue))
        {
         prevsignal=signal;
        }
     }

   if(ordenes==0 && signal<0)
     {
      if(OrderSend(Symbol(),OP_SELL,CalcularVolumen(),Bid,0,0,Bid-spread-tp,"",MAGICMA,0,Red))
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
            double ldTakeProfitBuy=OrderTakeProfit()+TSStep*MarketInfo(OrderSymbol(),MODE_POINT);
            OrderModify(OrderTicket(),OrderOpenPrice(),ldStopLossBuy,ldTakeProfitBuy,0,CLR_NONE);
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
            double ldTakeProfitSell=OrderTakeProfit()+TSStep*MarketInfo(OrderSymbol(),MODE_POINT)*-1;
            OrderModify(OrderTicket(),OrderOpenPrice(),ldStopLossSell,ldTakeProfitSell,0,CLR_NONE);
            return;
           }
        }
     }
  }
//+------------------------------------------------------------------+
double CalculaSignal()
  {
   if(AccountBalance()<=BalanceLimit) return(0);

   double adxMain=iADX(Symbol(),PERIOD_M15,14,PRICE_MEDIAN,MODE_MAIN,0);
   if(adxMain < 18 || adxMain > 38 || MarketInfo(Symbol(), MODE_SPREAD) > MaximumSpread * MarketInfo(Symbol(), MODE_DIGITS)) return 0;

   double ma3=iMA(Symbol(),0,5,0,MODE_SMA,PRICE_CLOSE,0);

   int signal=0;
   double white=iMA(Symbol(),PERIOD_H1,MAW,0,MODE_SMMA,PRICE_CLOSE,0);
   double black=iMA(Symbol(),PERIOD_H1,MAB,0,MODE_SMMA,PRICE_CLOSE,0);
   if((black>white && ma3<black && ma3>white) || (white>black && ma3>black && ma3<white))
     {
      double adxDiPlus=iADX(Symbol(),0,14,PRICE_MEDIAN,MODE_PLUSDI,0);
      double adxDiMinus=iADX(Symbol(),0,14,PRICE_MEDIAN,MODE_MINUSDI,0);
      
      int strngth=0;
      if(adxMain>20 && adxDiPlus>=25 && adxDiMinus<=15) strngth=1;
      if(adxMain>25 && adxDiMinus>=25 && adxDiPlus<=15) strngth=-1;
      if(adxMain>25 && adxDiPlus>=25 && adxDiMinus<=15) strngth=2;
      if(adxMain>30 && adxDiMinus>=25 && adxDiPlus<=15) strngth=-2;

      double imalow=iMA(Symbol(),0,3,0,MODE_LWMA,PRICE_LOW,0);
      double imahigh=iMA(Symbol(),0,3,0,MODE_LWMA,PRICE_HIGH,0);
      double ibandslower = iBands(Symbol(), 0, 3, 2.0, 0, PRICE_OPEN, MODE_LOWER, 0);
      double ibandsupper = iBands(Symbol(), 0, 3, 2.2, 0, PRICE_OPEN, MODE_UPPER, 0);
      double envelopeslower = iEnvelopes(Symbol(), 0, 3, MODE_LWMA, 0, PRICE_OPEN, 0.07, MODE_LOWER, 0);
      double envelopesupper = iEnvelopes(Symbol(), 0, 3, MODE_LWMA, 0, PRICE_OPEN, 0.07, MODE_UPPER, 0);

      int result=0;
      if(ma3<imalow) result++;
      if(ma3<ibandslower) result++;
      if(ma3<envelopeslower) result++;
      if(ma3>imahigh) result--;
      if(ma3>ibandsupper) result--;
      if(ma3>envelopesupper) result--;
      
      double whiteCurrent=iMA(Symbol(),0,MAW,0,MODE_SMMA,PRICE_CLOSE,0);
      double blackCurrent=iMA(Symbol(),0,MAB,0,MODE_SMMA,PRICE_CLOSE,0);

      if(whiteCurrent>blackCurrent && ma3>whiteCurrent && strngth>0 && result>=0) signal=1;
      if(blackCurrent>whiteCurrent && ma3<whiteCurrent && strngth<0 && result<=0) signal=-1;
     }

   double macd=iMACD(Symbol(),0,15,26,2,PRICE_CLOSE,MODE_MAIN,0);
   double macdPrev=iMACD(Symbol(),0,15,26,2,PRICE_CLOSE,MODE_MAIN,1);
   double ma1=iMA(Symbol(),0,85,0,MODE_SMA,PRICE_LOW,0);
   double ma2=iMA(Symbol(),0,75,0,MODE_SMA,PRICE_LOW,0);

   if(macd > 0 && macdPrev <= 0 && ma3 >= ma2 && ma3 >= ma1 && ma2 >= ma1 && signal > 0) return 1;
   if(macd < 0 && macdPrev >= 0 && ma3 <= ma2 && ma3 <= ma1 && ma2 <= ma1 && signal < 0) return -1;

   return 0;
  }
//+------------------------------------------------------------------+
