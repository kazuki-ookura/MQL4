//本書ライブラリ
#include "LibEA4.mqh"

input int FastRCIPeriod = 17; //短期移動平均の期間
input int SlowRCIPeriod = 41; //長期移動平均の期間
input int BuyOrderRCIValue = -80; //買いを仕掛ける値
input int BuyCloseRCIValue = 80; //買いを手仕舞いする値
input double Lots = 0.1; //売買ロット数

//ティック時実行関数
void OnTick()
{
   int sig_entry = EntrySignal(); //仕掛けシグナル
   int sig_exit = ExitSignal(); //手仕舞いシグナル
   //成行売買
   MyOrderSendMarket(sig_entry, sig_exit, Lots);
}

//仕掛けシグナル関数
int EntrySignal()
{
   //１本前と２本前の移動平均
   double FastRCI1 = iRCI(_Symbol, PERIOD_M5, FastRCIPeriod, 1);
   double FastRCI2 = iRCI(_Symbol, PERIOD_M5, FastRCIPeriod, 2);

   int ret = 0; //シグナルの初期化

   //買いシグナル
   if (FastRCI2 <= BuyOrderRCIValue && FastRCI1 > BuyOrderRCIValue) ret = 1;
   //売りシグナル
   //if (SlowRCI2 >= 80 && SlowRCI1 < 80) ret = -1;

   return ret; //シグナルの出力
}

//手仕舞いシグナル関数
int ExitSignal()
{
   //１本前のRCI
   double SlowRCI1 = iRCI(_Symbol, PERIOD_M5, SlowRCIPeriod, 1);
   //double SlowRCI2 = iRCI(_Symbol, 0, SlowRCIPeriod, 2);

   int ret = 0; //シグナルの初期化

   //買いシグナル
   //if (RCI1 < -75) ret = 1;
   //売りシグナル
   if (SlowRCI1 > BuyCloseRCIValue) ret = -1;

   return ret; //シグナルの出力
}

//カスタム評価関数
double OnTester()
{
   //（リカバリーファクター）－（プロフィットファクター）
   return TesterStatistics(STAT_PROFIT) / TesterStatistics(STAT_BALANCE_DD) - TesterStatistics(STAT_PROFIT_FACTOR);
}