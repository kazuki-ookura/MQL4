//+------------------------------------------------------------------+
//|                                                     test_inc.mqh |
//|                                 Copyright 2022, HeartSystem Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, HeartSystem Ltd."
#property link      ""
#property strict
//+------------------------------------------------------------------+
//| defines                                                          |
//+------------------------------------------------------------------+
// #define MacrosHello   "Hello, world!"
// #define MacrosYear    2010
//+------------------------------------------------------------------+
//| DLL imports                                                      |
//+------------------------------------------------------------------+
// #import "user32.dll"
//   int      SendMessageA(int hWnd,int Msg,int wParam,int lParam);
// #import "my_expert.dll"
//   int      ExpertRecalculate(int wParam,int lParam);
// #import
//+------------------------------------------------------------------+
//| EX5 imports                                                      |
//+------------------------------------------------------------------+
// #import "stdlib.ex5"
//   string ErrorDescription(int error_code);
// #import
//+------------------------------------------------------------------+



//+---------------------------------------------------------------------+
//                一般関数
//+---------------------------------------------------------------------+

/**
* ポイント調整
*/
double AdjustPoint(string currency)
{
    Print("AdjustPoint(string currency) start.");

    int symbolDigits = (int)MarketInfo(currency, MODE_DIGITS);
    double calculatedPoint = 0;

    if (symbolDigits == 2 || symbolDigits == 3) {
        calculatedPoint = 0.01;
    } else if (symbolDigits == 4 || symbolDigits == 5) {
        calculatedPoint = 0.0001;
    } else if (symbolDigits == 1) {
        calculatedPoint = 0.1;
    } else if (symbolDigits == 0) {
        calculatedPoint = 1;
    }

    return calculatedPoint;
}

/**
* スリッページ調整.
*/
int AdjustSlippage(string currency,int slippagePips)
{
    int calculatedSlippage = 0;
    int symbolDigits = (int)MarketInfo(currency, MODE_DIGITS);//通貨ペアの小数点以下桁数

    if (symbolDigits == 2 || symbolDigits == 3) {
        calculatedSlippage = slippagePips;
    } else if (symbolDigits == 4 || symbolDigits == 5) {
        calculatedSlippage = slippagePips * 10;
    }

    Print("calculatedSlippage = " + (string)calculatedSlippage );

    return calculatedSlippage; 
}

/**
* ロングポジション数を取得
*/
int GetLongPositionCount()
{
    int buyCount = 0;

    for (int i = 0; i < OrdersTotal(); i++) {
        if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES) == true && OrderSymbol() == Symbol() && OrderMagicNumber() == MAGIC) {
            if (OrderType() == OP_BUY) buyCount++;
        }
    }

    return buyCount;
}

/**
* ショートポジション数を取得
*/
int GetShortPositionCount()
{
    int sellCount = 0;

    for(int i = 0; i < OrdersTotal(); i++) {
        if (OrderSelect(i, SELECT_BY_POS,MODE_TRADES) == true && OrderSymbol()==Symbol() && OrderMagicNumber() == MAGIC) {
            if (OrderType() == OP_SELL) sellCount++;
        }
    }

    return sellCount;
}

//+---------------------------------------------------------------------+
//                エントリ関連関数
//+---------------------------------------------------------------------+

/**
* ポジションエントリ関数
*/
void OpenOrder(int EntryPosition)
{
    int res;
    bool modified;
    double SL;
    double TP;
    int SLP = AdjustSlippage(Symbol(), Slippage );

    //ロットサイズ調整
    Lots = LotsAdjustment(LotsAdjustPer, LotsAdjustPer2);//口座残高比率

    if( EntryPosition == 1 ) {
        //買いエントリ
        res = OrderSend(Symbol(), OP_BUY,Lots, Ask, SLP, 0, 0, "RCI_closs_double_value", MAGIC, 0, Red);

        if (OrderSelect(res, SELECT_BY_TICKET) == true) {
            if (StopLoss != 0) SL = OrderOpenPrice() - StopLoss * AdjustPoint(Symbol());
            if (TakeProfit!=0) TP = OrderOpenPrice() + TakeProfit * AdjustPoint(Symbol());
        }

        if (SL != 0 || TP != 0) modified = OrderModify(OrderTicket(), OrderOpenPrice(), SL, TP, 0, Red);

    } else if(EntryPosition == -1 ) {
        //売りエントリ
        res = OrderSend(Symbol(), OP_SELL, Lots, Bid, SLP, 0, 0, "RCI_closs_double_value", MAGIC, 0, White);

        if (OrderSelect(res, SELECT_BY_TICKET) == true) {
            if(StopLoss != 0) SL = OrderOpenPrice() + StopLoss * AdjustPoint(Symbol());
            if(TakeProfit != 0) TP = OrderOpenPrice() - TakeProfit * AdjustPoint(Symbol());
        }

        if (SL != 0 || TP != 0) modified = OrderModify(OrderTicket(), OrderOpenPrice(), SL, TP, 0, White);

    }

    return;
}

/**
* ポジション数調整関数
*/
double LotsAdjustment(double RiskRatio, int LossPips)
{
    double Risk_Amount = AccountFreeMargin() * (RiskRatio / 100);
    double LotSize = MathFloor((Risk_Amount / LossPips) / 100000 * 1000 * 1000) / 1000;

    if (Accountcurrency() == "USD") {
        LotSize = LotSize * 10;
    } else if (Accountcurrency() == "JPY") {
        LotSize = LotSize / 10;
    } else {
        Print("口座残高比率はUSD口座とJPY口座のみの対応となります");
    }

    if (MarketInfo(Symbol(), MODE_LOTSTEP) == 0.1) {
        LotSize = NormalizeDouble(LotSize, 1);
    } else if(MarketInfo(Symbol(), MODE_LOTSTEP) == 0.01) {
        LotSize = NormalizeDouble(LotSize, 2);
    }

    if (LotSize <= MarketInfo(Symbol(), MODE_MINLOT)) {
        LotSize = MarketInfo(Symbol(), MODE_MINLOT);
    } else if (LotSize >= MarketInfo(Symbol(), MODE_MAXLOT)) {
        LotSize = MarketInfo(Symbol(), MODE_MAXLOT);
    }

    return(LotSize);
}

//+---------------------------------------------------------------------+
//                エグジット関連関数
//+---------------------------------------------------------------------+

/**
* ポジションクローズ関数
*/
void CloseOrder(int ClosePosition)
{
    for(int i = OrdersTotal() - 1; i >= 0; i--) {
        int res;
        if (OrderSelect(i, SELECT_BY_POS,MODE_TRADES) == true) {
            if (OrderMagicNumber() == MAGIC && OrderSymbol() == Symbol()) {
                if(OrderType() == OP_SELL && (ClosePosition == -1 || ClosePosition==0 )) {
                    //売りポジションのクローズ
                    res = OrderClose(OrderTicket(), OrderLots(), OrderClosePrice(), 10, Silver);
                } else if(OrderType() == OP_BUY && (ClosePosition == 1 || ClosePosition == 0 ) ) {
                    //買いポジションのクローズ
                    res = OrderClose(OrderTicket(), OrderLots(), OrderClosePrice(), 10, Silver);
                }
            }
        }
    }
}

//+---------------------------------------------------------------------+
//                　インジケーター
//+---------------------------------------------------------------------+

//12-6 シグナル|RCIが一定値を超過（逆張り）
int Indicator12_6(int i, int TimeScale, int RCIper, double H, double L)
{
    int ret = 0;
    double Main = iRCI(Symbol(), TimeScale, RCIper, i);
    double Main_1 = iRCI(Symbol(), TimeScale, RCIper, i + 1);
    int sig = 0;

    if (Main > H) {
        sig = 1;
    } else if (Main < L) {
        sig = -1;
    }

    int sig1=0;

    if (Main_1 > H) {
        sig1 = 1;
    } else if(Main_1 < L) {
        sig1 = -1;
    }

    if (sig == 1 && sig1 != 1) {
        ret = -1;
    } else if(sig == -1 && sig1 != -1) {
        ret = 1;
    }

    return(ret);
}

//RCI 
double iRCI(string symbol,int timeframe,int RCIPeriod ,int i) 
{ 
    if (RCIPeriod < 2) RCIPeriod = 2;
    double numerator, denominator;
    denominator = RCIPeriod * (RCIPeriod * RCIPeriod - 1);
    numerator = 600.0;
    double ret; 

    double RankArray[][2]; 
    ArrayResize(RankArray, RCIPeriod+1);
    int j = 0, k = 0, RankEqualCount = 0; 
    double d, RankSum, RankAverage; 

    for (j = 1; j <= RCIPeriod; j++) {
        RankArray[j][0] = iClose(symbol, timeframe, i + j -1); 
        RankArray[j][1] = j;
    }

    ArraySort(RankArray, RCIPeriod, 1, MODE_DESCEND); 

    for (j = 1; j <= RCIPeriod; j = k) {
        RankEqualCount = 1;
        RankSum = j;

        for (k = j+1; k <= RCIPeriod; k++) {
            if (RankArray[k][0] == RankArray[j][0]) {
                RankEqualCount++;
                RankSum += k;
            } else {
                break;
            }
        }

        RankAverage = RankSum / RankEqualCount;
        for (k = j; k < j + RankEqualCount; k++)
        RankArray[k][0] = RankAverage;
    }

    d = 0.0;

    for (j = 1; j <= RCIPeriod; j++) {
        d += MathPow(RankArray[j][1] - RankArray[j][0], 2);
    }

    ret = 100 - numerator * d / denominator;

    return(ret); 
} 

//+---------------------------------------------------------------------+
//                イニシャル処理
//+---------------------------------------------------------------------+
void init()
{
    //テスターで表示されるインジケータを非表示にする
    HideTestIndicators(true); 

}

//+---------------------------------------------------------------------+
//                ティック毎の処理
//+---------------------------------------------------------------------+
void start()
{
    // ニューバーの発生直後以外は取引しない
    static datetime bartime = Time[0]; 

    if (Time[0] == bartime) return;

    bartime = Time[0]; 

    //各種パラメーター取得
    int EntryBuy = 0;
    int EntrySell = 0;
    int ExitBuy = 0;
    int ExitSell = 0;
    int LongNum = GetLongPositionCount();
    int ShortNum = GetShortPositionCount();

    //クローズ基準取得
    int CloseStrtagy1 = Indicator12_6(1, TimeScale1, RCI1Period, RCI1High, RCI1Low);
    
    //クローズ判定
    if (LongNum != 0 && (CloseStrtagy1 == -1)) {
        ExitBuy = 1;
        LongNum = 0;
        CloseOrder(1);
    } else if (ShortNum != 0 && (CloseStrtagy1 == 1)) {
        ExitSell = 1;
        ShortNum = 0;
        CloseOrder(-1);
    }

    //エントリ基準取得
    int Strtagy1 = Indicator12_6(Entry1,TimeScale1, RCI1Period, RCI1High, RCI1Low);
    int TotalNum = ShortNum+LongNum;
    
    //エントリ判定
    if ((TotalNum < MaxPosition ) && (Strtagy1 == 1 )) {
        EntryBuy = 1;
    } else if ((TotalNum < MaxPosition ) && (Strtagy1 == -1 )) {
        EntrySell = 1;
    }

    //クローズ処理
    if (ExitBuy != 0) {
        CloseOrder(1);
    }
    if (ExitSell != 0) {
        CloseOrder(-1);
    }

    //オープン処理
    if (EntryBuy != 0) {
        OpenOrder(1);
    }
    if (EntrySell != 0) {
        OpenOrder(-1);
    }
}

