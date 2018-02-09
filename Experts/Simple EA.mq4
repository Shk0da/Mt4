//+------------------------------------------------------------------+
#define MAGICMA  20180208
#define MAGICMA2  19274
//--- Inputs
input double BalanceRisk   =10;
input double MinimumLots   =0.01;
input double SFPofit       =0.005;
input double MaximumSpread =30;
input double TP            =50;
input int    Sense         =3;
input int    MAW           =7;
input int    MAB           =63;

input bool   TSEnable      =true;
input int    TSVal         =30;
input int    TSStep        =5;

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
            if(prevsignal>=0 && signal<0 || prevsignal<=0 && signal>0 || (!TSEnable && profit>=sfprofit))
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
   if(AccountBalance()<=50)
     {
      Comment("\nSimple EA Balance: "+AccountBalance()+"!");
      return(0);
     }

   Comment("\nSimple EA");
   if(MarketInfo(Symbol(), MODE_SPREAD) > MaximumSpread * MarketInfo(Symbol(), MODE_DIGITS)) return 0;

   double bid = MarketInfo(Symbol(),MODE_BID);
   double ask = MarketInfo(Symbol(),MODE_ASK);
   double adxMain=iADX(Symbol(),0,14,PRICE_MEDIAN,MODE_MAIN,0);
   double adxDiPlus=iADX(Symbol(),0,14,PRICE_MEDIAN,MODE_PLUSDI,0);
   double adxDiMinus=iADX(Symbol(),0,14,PRICE_MEDIAN,MODE_MINUSDI,0);

   int strength=0;
   if(adxMain>25 && adxDiPlus>=25 && adxDiMinus<=15) strength=1;
   else if(adxMain>25 && adxDiMinus>=25 && adxDiPlus<=15) strength=-1;
   if(adxMain>35 && adxDiPlus>=25 && adxDiMinus<=15) strength=2;
   else if(adxMain>35 && adxDiMinus>=25 && adxDiPlus<=15) strength=-2;

   int signal=0;
   double white=iMA(Symbol(),PERIOD_H1,MAW,0,MODE_SMMA,PRICE_CLOSE,0);
   double black=iMA(Symbol(),PERIOD_H1,MAB,0,MODE_SMMA,PRICE_CLOSE,0);
   if(white>black && bid>white && strength >= 0) signal=2;
   if(black>white && ask<white && strength <= 0) signal=-2;
   if((black>white && bid<black && bid>white) || (white>black && ask>black && ask<white))
     {
      double whiteCurrent=iMA(Symbol(),0,MAW,0,MODE_SMMA,PRICE_CLOSE,0);
      double blackCurrent=iMA(Symbol(),0,MAB,0,MODE_SMMA,PRICE_CLOSE,0);

      if(whiteCurrent>blackCurrent && bid>whiteCurrent  && strength>= 0) signal=1;
      if(blackCurrent>whiteCurrent && ask<whiteCurrent && strength <= 0) signal=-1;
     }

   if(signal == 0) return 0;

   int aux1=0;
   int aux_tenkan_sen=9;
   double aux_kijun_sen=26;
   double aux_senkou_span=52;
   int aux_shift=0;
   double kt1=0,kb1=0,kt2=0,kb2=0;
   double ts1,ts2,ks1,ks2,ssA1,ssA2,ssB1,ssB2,close1,close2;
   ts1 = iIchimoku(Symbol(), 0, aux_tenkan_sen, aux_kijun_sen, aux_senkou_span, MODE_TENKANSEN, aux_shift);
   ks1 = iIchimoku(Symbol(), 0, aux_tenkan_sen, aux_kijun_sen, aux_senkou_span, MODE_KIJUNSEN, aux_shift);
   ssA1 = iIchimoku(Symbol(), 0, aux_tenkan_sen, aux_kijun_sen, aux_senkou_span, MODE_SENKOUSPANA, aux_shift);
   ssB1 = iIchimoku(Symbol(), 0, aux_tenkan_sen, aux_kijun_sen, aux_senkou_span, MODE_SENKOUSPANB, aux_shift);
   close1=iClose(Symbol(),0,aux_shift);
   ts2 = iIchimoku(Symbol(), 0, aux_tenkan_sen, aux_kijun_sen, aux_senkou_span, MODE_TENKANSEN, aux_shift+1);
   ks2 = iIchimoku(Symbol(), 0, aux_tenkan_sen, aux_kijun_sen, aux_senkou_span, MODE_KIJUNSEN, aux_shift+1);
   ssA2 = iIchimoku(Symbol(), 0, aux_tenkan_sen, aux_kijun_sen, aux_senkou_span, MODE_SENKOUSPANA, aux_shift+1);
   ssB2 = iIchimoku(Symbol(), 0, aux_tenkan_sen, aux_kijun_sen, aux_senkou_span, MODE_SENKOUSPANB, aux_shift+1);
   close2=iClose(Symbol(),0,aux_shift+1);
   if(ssA1 >= ssB1) kt1 = ssA1;
   else kt1 = ssB1;
   if(ssA1 <= ssB1) kb1 = ssA1;
   else kb1 = ssB1;
   if(ssA2 >= ssB2) kt2 = ssA2;
   else kt2 = ssB2;
   if(ssA2 <= ssB2) kb2 = ssA2;
   else kb2 = ssB2;
   if((ts1>ks1 && ts2<ks2 && ks1>kt1) || (close1>ks1 && close2<ks2 && ks1>kt1) || (close1>kt1 && close2<kt2)) aux1=1;
   if((ts1<ks1 && ts2>ks2 && ts1<kb1) || (close1<ks1 && close2>ks2 && ks1<kb1) || (close1<kb1 && close2>kb2)) aux1=-1;

   int aux2=0;
   int kg=2;
   int Slow_MACD= 18;
   int Alfa_min = 2;
   int Alfa_delta= 34;
   int Fast_MACD = 1;
   int j=0;
   int r=60/Period();
   double MA_0=iMA(Symbol(),0,Slow_MACD*r*kg,0,MODE_SMA,PRICE_OPEN,j);
   double MA_1=iMA(Symbol(),0,Slow_MACD*r*kg,0,MODE_SMA,PRICE_OPEN,j+1);
   double Alfa=((MA_0-MA_1)/MarketInfo(Symbol(),MODE_POINT))*r;
   double Fast_0=iOsMA(Symbol(),0,Fast_MACD*r,Slow_MACD*r,Slow_MACD*r,PRICE_OPEN,j);
   double Fast_1=iOsMA(Symbol(),0,Fast_MACD*r,Slow_MACD*r,Slow_MACD*r,PRICE_OPEN,j+1);
   double Slow_0=iOsMA(Symbol(),0,(Fast_MACD)*r,Slow_MACD*r,Slow_MACD*r,PRICE_OPEN,j);
   double Slow_1=iOsMA(Symbol(),0,(Fast_MACD)*r,Slow_MACD*r,Slow_MACD*r,PRICE_OPEN,j+1);
   bool trend_up=0;
   bool trend_dn=0;
   if(Alfa> Alfa_min && Alfa< (Alfa_min+Alfa_delta)) trend_up=1;
   if(Alfa<-Alfa_min && Alfa>-(Alfa_min+Alfa_delta)) trend_dn=1;
   bool longsignal=0;
   bool shortsignal=0;
   if((Fast_0-Slow_0)>0.0 && (Fast_1-Slow_1)<=0.0) longsignal=1;
   if((Fast_0-Slow_0)<0.0 && (Fast_1-Slow_1)>=0.0) shortsignal=1;
   if((((trend_up || longsignal)))) aux2=1;
   else if((((trend_dn || shortsignal)))) aux2=-1;

   int aux3=0;
   double imalow=iMA(Symbol(),0,3,0,MODE_LWMA,PRICE_LOW,0);
   double imahigh=iMA(Symbol(),0,3,0,MODE_LWMA,PRICE_HIGH,0);
   double ibandslower = iBands(Symbol(), 0, 3, 2.0, 0, PRICE_OPEN, MODE_LOWER, 0);
   double ibandsupper = iBands(Symbol(), 0, 3, 2.2, 0, PRICE_OPEN, MODE_UPPER, 0);
   double envelopeslower = iEnvelopes(Symbol(), 0, 3, MODE_LWMA, 0, PRICE_OPEN, 0.07, MODE_LOWER, 0);
   double envelopesupper = iEnvelopes(Symbol(), 0, 3, MODE_LWMA, 0, PRICE_OPEN, 0.07, MODE_UPPER, 0);
   if(bid<imalow) aux3++;
   if(bid<ibandslower) aux3++;
   if(bid<envelopeslower) aux3++;
   if(ask>imahigh) aux3--;
   if(ask>ibandsupper) aux3--;
   if(ask>envelopesupper) aux3--;

   int aux4=0;
   double xl1 = iHighest(Symbol(), 0, 0);
   double xl2 = iHighest(Symbol(), 0, 1);
   double xl3 = iHighest(Symbol(), 0, 2);
   double xls1 = iLowest(Symbol(), 0, 0);
   double xls2 = iLowest(Symbol(), 0, 1);
   double xls3 = iLowest(Symbol(), 0, 2);
   double xls1a = iClose(Symbol(), 0, 0);
   double xls2a = iClose(Symbol(), 0, 1);
   double xls3a = iClose(Symbol(), 0, 2);

   if(xl3 < xl2 < xl1 && xls3a < xls2a < xls1a) aux4=1;
   if(xls3> xls2> xls1 && xls3a> xls2a > xls1a) aux4=-1;

   int aux5=0;
   double repulseIndex7[4];
   double repulseIndex12[4];
   double repulseIndex13[4];
   for(int i=1;i<=3;i++)
     {
      repulseIndex7[i]=iMA(Symbol(),0,7,0,MODE_EMA,PRICE_CLOSE,i);
      repulseIndex12[i] = iMA(Symbol(),0,12,0,MODE_EMA,PRICE_MEDIAN,i);
      repulseIndex13[i] = iMA(Symbol(),0,13,0,MODE_EMA,PRICE_MEDIAN,i);
     }

   int vadoLong12=((repulseIndex12[2]<repulseIndex12[3]) && (repulseIndex12[2]<repulseIndex12[1])) ? 1 : 0;
   int vadoShort12=((repulseIndex12[2]>repulseIndex12[3]) && (repulseIndex12[2]>repulseIndex12[1])) ? -1 : 0;
   int vadoLong13=((repulseIndex13[2]<repulseIndex13[3]) && (repulseIndex13[2]<repulseIndex13[1])) ? 1 : 0;
   int vadoShort13=((repulseIndex13[2]>repulseIndex13[3]) && (repulseIndex13[2]>repulseIndex13[1])) ? -1 : 0;
   int vadoLong7=((repulseIndex7[2]>repulseIndex7[3]) && (repulseIndex7[2]<repulseIndex7[1])) ? 1 : 0;
   int vadoShort7=((repulseIndex7[2]<repulseIndex7[3]) && (repulseIndex7[2]>repulseIndex7[1])) ? -1 : 0;

   if((vadoLong12+vadoLong13+vadoLong7)>1) aux5=1;
   if((vadoShort12+vadoShort13+vadoShort7)<-1) aux5=-1;

   int sclpr=aux1+aux2+aux3+aux4+aux5;
   Comment("\nSimple EA: "+sclpr);

   return (signal > 0 && sclpr >= Sense ? 1 : signal < 0 && sclpr <= -Sense ? 1 : 0);
  }
//+------------------------------------------------------------------+
