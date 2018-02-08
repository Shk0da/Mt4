//+------------------------------------------------------------------+
#define MAGICMA  20180208
//--- Inputs
input double BalanceRisk   =10;
input double MinimumLots   =0.01;
input double SFPofit       =0.005;
input double MaximumSpread =30;
input double TP            =50;
input int    Sense         =2;
input int    MAW           =7;
input int    MAB           =63;
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
         if(OrderSymbol()==Symbol() && OrderMagicNumber()==MAGICMA && (OrderType()==OP_BUY || OrderType()==OP_SELL))
           {
            double profit = OrderProfit()+OrderSwap()-OrderCommission();
            if(prevsignal>=0 && signal<0 || prevsignal<=0 && signal>0 || profit >= sfprofit)
              {
               if(OrderType()==OP_BUY)
                 {
                  OrderClose(OrderTicket(),OrderLots(),Bid,3,Red);
                 }
               if(OrderType()==OP_SELL)
                 {
                  OrderClose(OrderTicket(),OrderLots(),Ask,3,Red);
                 }
              }
            else
              {
               ordenes++;
              }
           }
        }
     }

   if(signal == 0) return;

   double tp=TP*MarketInfo(Symbol(),MODE_POINT);
   double spread=MarketInfo(Symbol(),MODE_ASK)-MarketInfo(Symbol(),MODE_BID);
   if(ordenes==0 && signal>0)
     {
      if(OrderSend(Symbol(),OP_BUY,CalcularVolumen(),Ask,3,0,MarketInfo(Symbol(),MODE_ASK)+spread+tp,"",MAGICMA,0,Blue)) 
        {
         prevsignal=signal;
        }
     }

   if(ordenes==0 && signal<0)
     {
      if(OrderSend(Symbol(),OP_SELL,CalcularVolumen(),Bid,3,0,MarketInfo(Symbol(),MODE_BID)-spread-tp,"",MAGICMA,0,Red)) 
        {
         prevsignal=signal;
        }
     }
  }
//+------------------------------------------------------------------+
double CalcularVolumen()
  {
   int n=MathFloor(BalanceRisk*AccountFreeMargin()/100000/MinimumLots);
   double aux=n*MinimumLots;

   double Free=AccountFreeMargin();
   double margin=MarketInfo(Symbol(),MODE_MARGINREQUIRED);
   double Step= MarketInfo(Symbol(),MODE_LOTSTEP);
   double Lot = MathFloor(Free*BalanceRisk/100/margin/Step)*Step;
   double max=(Lot*margin>Free) ? 0 : Lot;

   if(aux>max) aux=max;
   if(aux<MinimumLots) aux=MinimumLots;
   if(aux>MarketInfo(Symbol(),MODE_MAXLOT)) aux=MarketInfo(Symbol(),MODE_MAXLOT);
   if(aux<MarketInfo(Symbol(),MODE_MINLOT)) aux=MarketInfo(Symbol(),MODE_MINLOT);

   return(aux);
  }
//+------------------------------------------------------------------+
double CalculaSignal()
  {
   if(AccountBalance()<=50)
     {
      return(0);
     }

   if(MarketInfo(Symbol(), MODE_SPREAD) > MaximumSpread * MarketInfo(Symbol(), MODE_DIGITS)) return 0;

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

   double white=iMA(Symbol(),PERIOD_H1,MAW,0,MODE_SMMA,PRICE_CLOSE,0);
   double black=iMA(Symbol(),PERIOD_H1,MAB,0,MODE_SMMA,PRICE_CLOSE,0);

   double adxMain=iADX(Symbol(),PERIOD_M15,14,PRICE_MEDIAN,MODE_MAIN,0);
   double adxDiPlus=iADX(Symbol(),PERIOD_M15,14,PRICE_MEDIAN,MODE_PLUSDI,0);
   double adxDiMinus=iADX(Symbol(),PERIOD_M15,14,PRICE_MEDIAN,MODE_MINUSDI,0);

   int strngth=0;
   if(adxMain>25 && adxDiPlus>=25 && adxDiMinus<=15) strngth=1;
   else if(adxMain>25 && adxDiMinus>=25 && adxDiPlus<=15) strngth=-1;
   if(adxMain>35 && adxDiPlus>=25 && adxDiMinus<=15) strngth=2;
   else if(adxMain>35 && adxDiMinus>=25 && adxDiPlus<=15) strngth=-2;

   int signal=0;
   if(result>=Sense && white>black && bid>white && strngth > 0) signal=2;
   if(result<=-Sense && black>white && ask<white && strngth < 0) signal=-2;

   if((black>white && bid<black && bid>white) || (white>black && ask>black && ask<white))
     {
      double whiteCurrent=iMA(Symbol(),0,MAW,0,MODE_SMMA,PRICE_CLOSE,0);
      double blackCurrent=iMA(Symbol(),0,MAB,0,MODE_SMMA,PRICE_CLOSE,0);

      if(result>=Sense && whiteCurrent>blackCurrent && bid>whiteCurrent  && strngth > 0) signal=1;
      if(result<=-Sense && blackCurrent>whiteCurrent && ask<whiteCurrent && strngth < 0) signal=-1;

     }

   return signal;
  }
//+------------------------------------------------------------------+
