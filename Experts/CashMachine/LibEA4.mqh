//LibEA4.mqh
#property copyright "Copyright (c) 2017, Toyolab FX"
#property link      "http://forex.toyolab.com/"
#property version   "180.315"
#property strict

#include <stderror.mqh>
#include <stdlib.mqh>

#ifndef POSITIONS
   #define POSITIONS 10  //最大ポジション数
#endif

#ifndef MAGIC
   input int MAGIC = 1;  //基本マジックナンバー
#endif

#define OP_NONE -1  //ポジションも注文もない状態

int MagicNumber[POSITIONS] = {0}; //ポジションごとのマジックナンバー
double PipPoint = _Point*10;      //1pipの値
input double SlippagePips = 1;    //許容スリッページ(pips)
int Slippage = (int)(SlippagePips*10); //許容スリッページ(point)

//ポジションの初期化
void InitPosition(int magic=0)
{
   //定義済み変数の定義
   if(_Digits == 2 || _Digits == 4)
   {
      Slippage = (int)SlippagePips;
      PipPoint = _Point;
   }

   //マジックナンバーの設定
   if(magic == 0) magic = MAGIC;
   for(int i=0; i<POSITIONS; i++) MagicNumber[i] = magic*POSITIONS+i;
}

//ポジション番号のチェック
void CheckPosID(int pos_id)
{
   if(pos_id >= POSITIONS) //pos_idエラー
   {
      Print("CheckPosID : pos_id(", pos_id, ")>=POSITIONS(", POSITIONS, ")");
      ExpertRemove();
   }
   else if(MagicNumber[pos_id] == 0) InitPosition(); //ポジションの初期化
}

//ポジションの選択
bool MyOrderSelect(int shift=0, int pos_id=0)
{
   CheckPosID(pos_id);  //ポジション番号のチェック

   if(shift == 0) //現在のポジションの選択
   {
      for(int i=0; i<OrdersTotal(); i++)
      {
         if(!OrderSelect(i, SELECT_BY_POS)) return false;
         if(OrderSymbol() != _Symbol || OrderMagicNumber() != MagicNumber[pos_id]) continue;
         return true; //正常終了
      }
   }
   if(shift > 0) //過去のポジションの選択
   {
      for(int i=OrdersHistoryTotal()-1; i>=0; i--)
      {
         if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) return false;
         if(OrderSymbol() != _Symbol || OrderMagicNumber() != MagicNumber[pos_id]) continue;
         if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;
         if(--shift > 0) continue;
         return true; //正常終了
      } 
   }
   return false; //ポジション選択なし
}

//注文の送信
bool MyOrderSend(int type, double lots, double price=0, int pos_id=0)
{
   color ArrowColor[6] = {clrBlue, clrRed, clrBlue, clrRed, clrBlue, clrRed}; //矢印の色データ

   CheckPosID(pos_id);  //ポジション番号のチェック
   if(MyOrderType(pos_id) != OP_NONE) return true; //注文済み

   price = NormalizeDouble(price, _Digits); //価格の正規化

   RefreshRates();
   if(type == OP_BUY) price = Ask;  //成行注文の買値
   if(type == OP_SELL) price = Bid; //成行注文の売値

   //注文送信
   int ret = OrderSend(_Symbol, type, lots, price, Slippage, 0, 0,
                       IntegerToString(MagicNumber[pos_id]),
                       MagicNumber[pos_id], 0, ArrowColor[type]);
   if(ret == -1) //注文エラー
   {
      int err = GetLastError();
      Print("MyOrderSend : ", err, " " , ErrorDescription(err));
      return false;
   }
   return true; //正常終了
}

//ポジションの決済
bool MyOrderClose(int pos_id=0)
{
   color ArrowColor[6] = {clrBlue, clrRed, clrBlue, clrRed, clrBlue, clrRed}; //矢印の色データ
   
   //オープンポジションがない場合
   if(MyOrderOpenLots(pos_id) == 0) return true;

   //注文送信
   bool ret = OrderClose(MyOrderTicket(pos_id), MyOrderLots(pos_id),
                         MyOrderClosePrice(pos_id), Slippage,
                         ArrowColor[MyOrderType(pos_id)]);
   if(!ret) //注文エラー
   {
      int err = GetLastError();
      Print("MyOrderClose : ", err, " ", ErrorDescription(err));
      return false;
   }
   return true; //正常終了
}

//待機注文のキャンセル
bool MyOrderDelete(int pos_id=0)
{
   int type = MyOrderType(pos_id);
   //待機注文がない場合
   if(type == OP_NONE || type == OP_BUY || type == OP_SELL) return true;

   //注文送信
   bool ret = OrderDelete(MyOrderTicket(pos_id));
   if(!ret) //注文エラー
   {
      int err = GetLastError();
      Print("MyOrderDelete : ", err, " ", ErrorDescription(err));
      return false;
   }
   return true; //正常終了
}

//注文の変更
bool MyOrderModify(double price, double sl, double tp, int pos_id=0)
{
   color ArrowColor[6] = {clrBlue, clrRed, clrBlue, clrRed, clrBlue, clrRed}; //矢印の色データ
   
   int type = MyOrderType(pos_id);
   if(type == OP_NONE) return true; //注文がない場合

   price = NormalizeDouble(price, _Digits); //価格の正規化
   sl = NormalizeDouble(sl, _Digits);       //損切り値の正規化
   tp = NormalizeDouble(tp, _Digits);       //利食い値の正規化

   if(price == 0) price = MyOrderOpenPrice(pos_id); //ポジションの価格
   if(sl == 0) sl = MyOrderStopLoss(pos_id);    //ポジションの損切り値
   if(tp == 0) tp = MyOrderTakeProfit(pos_id);  //ポジションの利食い値
   
   //損切り値、利食い値の変更がない場合
   if(MyOrderStopLoss(pos_id) == sl && MyOrderTakeProfit(pos_id) == tp)
   {
      //オープンポジションか、価格に変更がない場合
      if(type == OP_BUY || type == OP_SELL
         || MyOrderOpenPrice(pos_id) == price) return true;
   }

   //注文の送信
   bool ret = OrderModify(MyOrderTicket(pos_id), price, sl, tp, 0,
                          ArrowColor[type]);
   if(!ret) //注文エラー
   {
      int err = GetLastError();
      Print("MyOrderModify : ", err, " ", ErrorDescription(err));
      return false;
   }
   return true; //正常終了
}

//チケット番号の取得
int MyOrderTicket(int pos_id=0)
{
   int ticket = 0;
   if(MyOrderSelect(0, pos_id)) ticket = OrderTicket();
   return ticket;
}

//ポジション・注文種別の取得
int MyOrderType(int pos_id=0)
{
   int type = OP_NONE;
   if(MyOrderSelect(0, pos_id)) type = OrderType();
   return type;
}

//ポジション・注文のロット数の取得
double MyOrderLots(int pos_id=0)
{
   double lots = 0;
   if(MyOrderSelect(0, pos_id)) lots = OrderLots();
   return lots;
}

//ポジションの売買価格の取得
double MyOrderOpenPrice(int pos_id=0)
{
   double price = 0;
   if(MyOrderSelect(0, pos_id)) price = OrderOpenPrice();
   return price;   
}

//ポジションの売買時刻の取得
datetime MyOrderOpenTime(int pos_id=0)
{
   datetime opentime = 0;
   if(MyOrderSelect(0, pos_id)) opentime = OrderOpenTime();
   return opentime;   
}

//オープンポジションの決済価格の取得
double MyOrderClosePrice(int pos_id=0)
{
   double price = 0;
   if(MyOrderSelect(0, pos_id)) price = OrderClosePrice();
   return price ;
}

//ポジションに付加された損切り価格の取得
double MyOrderStopLoss(int pos_id=0)
{
   double sl = 0;
   if(MyOrderSelect(0, pos_id)) sl = OrderStopLoss();
   return sl;
}

//ポジションに付加された利食い価格の取得
double MyOrderTakeProfit(int pos_id=0)
{
   double tp = 0;
   if(MyOrderSelect(0, pos_id)) tp = OrderTakeProfit();
   return tp;
}

//オープンポジションの損益（金額）の取得
double MyOrderProfit(int pos_id=0)
{
   double profit = 0;
   if(MyOrderSelect(0, pos_id)) profit = OrderProfit();
   return profit;
}

//オープンポジションの損益（pips）の取得
double MyOrderProfitPips(int pos_id=0)
{
   double profit = 0;
   //決済価格-約定価格
   double newprofit = MyOrderClosePrice(pos_id) - MyOrderOpenPrice(pos_id);
   //買いポジション
   if(MyOrderType(pos_id) == OP_BUY) profit = newprofit;
   //売りポジション
   if(MyOrderType(pos_id) == OP_SELL) profit = -newprofit;
   return profit/PipPoint; //pips値に変換
}

//オープンポジションのロット数（符号付）の取得
double MyOrderOpenLots(int pos_id=0)
{
   double lots = 0;
   int type = MyOrderType(pos_id);
   double newlots = MyOrderLots(pos_id); 
   if(type == OP_BUY) lots = newlots;   //買いポジションはプラス
   if(type == OP_SELL) lots = -newlots; //売りポジションはマイナス
   return lots;   
}

//待機注文のロット数（符号付）の取得
double MyOrderPendingLots(int pos_id=0)
{
   double lots = 0;
   int type = MyOrderType(pos_id);
   double newlots = MyOrderLots(pos_id); 
   if(type == OP_BUYLIMIT || type == OP_BUYSTOP) lots = newlots;   //買い注文はプラス
   if(type == OP_SELLLIMIT || type == OP_SELLSTOP) lots = -newlots; //売り注文はマイナス
   return lots;   
}

//オープンポジションの一定利益となる決済価格の取得
double MyOrderShiftPrice(double sftpips, int pos_id=0) 
{
   double price = 0;
   //買いポジション
   if(MyOrderType(pos_id) == OP_BUY)
   {
      price = MyOrderOpenPrice(pos_id) + sftpips*PipPoint;
   }
   //売りポジション
   if(MyOrderType(pos_id) == OP_SELL)
   {
      price = MyOrderOpenPrice(pos_id) - sftpips*PipPoint;
   }
   return price;
}

//オープンポジションの一定価格における損益(pips)の取得
double MyOrderShiftPips(double price, int pos_id=0)
{
   double sft = 0;
   //買いポジション
   if(MyOrderType(pos_id) == OP_BUY)
   {
      sft = price - MyOrderOpenPrice(pos_id);
   }
   //売りポジション
   if(MyOrderType(pos_id) == OP_SELL)
   {
      sft = MyOrderOpenPrice(pos_id) - price;
   }
   return sft/PipPoint; //pips値に変換   
}

//ポジション情報の表示
void MyOrderPrint(int pos_id=0)
{
   //ロット数の刻み幅
   double lots_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   //ロット数の小数点以下桁数
   int lots_digits = (int)MathLog10(1.0/lots_step);
   string stype[] = {"buy", "sell", "buy limit", "sell limit",
                     "buy stop", "sell stop"};
   string s = "MyPos[";
   s = s + IntegerToString(pos_id) + "] ";  //ポジション番号
   if(MyOrderType(pos_id) == OP_NONE) s = s + "No position";
   else
   {
      s = s + "#"
            + IntegerToString(MyOrderTicket(pos_id)) //チケット番号
            + " ["
            + TimeToString(MyOrderOpenTime(pos_id)) //売買日時
            + "] "
            + stype[MyOrderType(pos_id)]  //注文タイプ
            + " "
            + DoubleToString(MyOrderLots(pos_id), lots_digits) //ロット数
            + " "
            + _Symbol //通貨ペア
            + " at " 
            + DoubleToString(MyOrderOpenPrice(pos_id), _Digits); //売買価格
      //損切り価格
      if(MyOrderStopLoss(pos_id) != 0) s = s + " sl "
         + DoubleToString(MyOrderStopLoss(pos_id), _Digits);
      //利食い価格
      if(MyOrderTakeProfit(pos_id) != 0) s = s + " tp " 
         + DoubleToString(MyOrderTakeProfit(pos_id), _Digits);
      s = s + " magic " + IntegerToString(MagicNumber[pos_id]); //マジックナンバー
   }
   Print(s); //出力
}

//前回のポジションの注文種別の取得
int MyOrderLastType(int pos_id=0)
{
   int type = OP_NONE;
   if(MyOrderSelect(1, pos_id)) type = OrderType();
   return type;
}

//前回のポジションのロット数の取得
double MyOrderLastLots(int pos_id=0)
{
   double lots = 0;
   if(MyOrderSelect(1, pos_id)) lots = OrderLots();
   return lots;   
}

//前回のポジションの売買価格の取得
double MyOrderLastOpenPrice(int pos_id=0)
{
   double price = 0;
   if(MyOrderSelect(1, pos_id)) price = OrderOpenPrice();
   return price;
}

//前回のポジションの売買時刻の取得
datetime MyOrderLastOpenTime(int pos_id=0)
{
   datetime opentime = 0;
   if(MyOrderSelect(1, pos_id)) opentime = OrderOpenTime();
   return opentime;   
}

//前回のポジションの決済価格の取得
double MyOrderLastClosePrice(int pos_id=0)
{
   double price = 0;
   if(MyOrderSelect(1, pos_id)) price = OrderClosePrice();
   return price;
}

//前回のポジションの決済時刻の取得
datetime MyOrderLastCloseTime(int pos_id=0)
{
   datetime closetime = 0;
   if(MyOrderSelect(1, pos_id)) closetime = OrderCloseTime();
   return closetime;   
}

//前回のポジションの損益（金額）の取得
double MyOrderLastProfit(int pos_id=0)
{
   double profit = 0;
   if(MyOrderSelect(1, pos_id)) profit = OrderProfit();
   return profit;
}

//前回のポジションの損益（pips）の取得
double MyOrderLastProfitPips(int pos_id=0)
{
   double profit = 0;
   //決済価格-約定価格
   double newprofit = MyOrderLastClosePrice(pos_id)
                    - MyOrderLastOpenPrice(pos_id);
   //買いポジション
   if(MyOrderLastType(pos_id) == OP_BUY) profit = newprofit;
   //売りポジション
   if(MyOrderLastType(pos_id) == OP_SELL) profit = -newprofit;
   return profit/PipPoint; //pips値に変換
}

//前回までの連続損益（金額）の取得
double MyOrderConsecutiveProfit(int pos_id=0)
{
   double profit = 0;
   for(int i=1;;i++)
   {
      if(MyOrderSelect(i, pos_id))
      {
         double p = OrderProfit();
         if(p == 0) continue;
         if(profit == 0) profit = p;
         else
         {
            if(profit * p > 0) profit += p;
            if(profit * p < 0) break;
         }
      }
      else break;
   }
   return profit;
}

//前回までの連続勝敗数の取得
int MyOrderConsecutiveWins(int pos_id=0)
{
   int wins = 0;
   for(int i=1;;i++)
   {
      if(MyOrderSelect(i, pos_id))
      {
         double p = OrderProfit();
         if(p == 0) continue;
         if(wins == 0) wins = (p>0)?1:-1;
         else
         {
            if(wins * p > 0) wins += (p>0)?1:-1;
            if(wins * p < 0) break;
         }
      }
      else break;
   }
   return wins;
}

//シグナルによる成行注文
void MyOrderSendMarket(int sig_entry, int sig_exit, double lots, int pos_id=0)
{
   //ポジション決済
   MyOrderCloseMarket(sig_entry, sig_exit, pos_id);
   //買い注文
   if(sig_entry > 0) MyOrderSend(OP_BUY, lots, 0, pos_id);
   //売り注文
   if(sig_entry < 0) MyOrderSend(OP_SELL, lots, 0, pos_id);
}

//シグナルによる待機注文
void MyOrderSendPending(int sig_entry, int sig_exit, double lots, double limit_pips, int pend_min=0, int pos_id=0)
{
   //ポジション決済
   MyOrderCloseMarket(sig_entry, sig_exit, pos_id);
   //注文キャンセル
   double pend_lots = MyOrderPendingLots(pos_id);
   if((pend_lots != 0 && pend_min > 0 && TimeCurrent() >= MyOrderOpenTime(pos_id) + pend_min*60)
      || pend_lots*sig_exit < 0) MyOrderDelete(pos_id);
   if(limit_pips > 0)
   {
      //指値買い注文
      if(sig_entry > 0) MyOrderSend(OP_BUYLIMIT, lots, Ask-limit_pips*PipPoint, pos_id);
      //指値売り注文
      if(sig_entry < 0) MyOrderSend(OP_SELLLIMIT, lots, Bid+limit_pips*PipPoint, pos_id);
   }
   else if(limit_pips < 0)
   {
      //逆指値買い注文
      if(sig_entry > 0) MyOrderSend(OP_BUYSTOP, lots, Ask-limit_pips*PipPoint, pos_id);
      //逆指値売り注文
      if(sig_entry < 0) MyOrderSend(OP_SELLSTOP, lots, Bid+limit_pips*PipPoint, pos_id);
   }
}

//シグナルによるポジション決済
void MyOrderCloseMarket(int sig_entry, int sig_exit, int pos_id=0)
{
   //同時シグナル
   if(sig_entry*sig_exit < 0) return;
   //決済注文
   if(MyOrderOpenLots(pos_id)*sig_exit < 0) MyOrderClose(pos_id);
}

//シグナル待機フィルタ
int WaitSignal(int signal, int min, int pos_id=0)
{
   int ret = 0; //シグナルの初期化
   if(MyOrderOpenLots(pos_id) != 0 //オープンポジションがある場合
      //待機時間が経過した場合
      && TimeCurrent() >= MyOrderOpenTime(pos_id) + min*60)
         ret = signal;

   return ret; //シグナルの出力
}

//売買ロット数の正規化
double NormalizeLots(double lots)
{
   //最小ロット数
   double lots_min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   //最大ロット数
   double lots_max = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   //ロット数刻み幅
   double lots_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   //ロット数の小数点以下の桁数
   int lots_digits = (int)MathLog10(1.0/lots_step);
   lots = NormalizeDouble(lots, lots_digits); //ロット数の正規化
   if(lots < lots_min) lots = lots_min; //最小ロット数を下回った場合
   if(lots > lots_max) lots = lots_max; //最大ロット数を上回った場合
   return lots;
}

//RCI
double iRCI(string symbol, int timeframe, int period, int shift){   

   double close[];
   ArrayResize(close, period); 

   for (int i = 0; i < period; i++) {
      close[i] = iClose(symbol, timeframe, shift + i);
   }

   ArraySort(close, WHOLE_ARRAY, 0, MODE_DESCEND);

   double d = 0;
   for (int i = 0; i < period; i++) {
      int rank = ArrayBsearch(close, iClose(symbol, timeframe, shift + i), WHOLE_ARRAY, 0, MODE_DESCEND);
      d += MathPow(i - rank, 2);
   }
   
   return (1 - 6 * d / (period * (MathPow(period, 2) - 1))) * 100;
}