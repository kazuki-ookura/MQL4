//+------------------------------------------------------------------+
//|                                                    test_ scr.mq4 |
//|                                 Copyright 2022, HeartSystem Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, HeartSystem Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   // Print()はターミナルのエキスパートタブに出力する。
   Print("Hello, world");

   // Bidは売値、Askは買値が入っている特別な変数。
   Print(" 売値 ＝", Bid, " 買値 ＝", Ask);
   
   // Openは始値、Highは高値、Lowは安値、Closeは終値、添え字の0は最新から何本過去かを表す。0は最新。
   Print("Open[0]=", Open[0], " Open[1]=", Open[1]);
   Print("High[0]=", High[0], " High[1]=", High[1]);
   Print("Low[0]=", Low[0], " Low[1]=", Low[1]);
   Print("Close[0]=", Close[0], " Close[1]=", Close[1]);
   
   Print("通貨ペア＝", _Symbol);
   Print("小数桁数＝", _Digits);
   Print("最小値幅＝", _Point);
   Print("タイムフレーム＝", _Period);
   
   int i;
   double x1;
   string Str;

   Print("i=", i);
   Print("x1=", x1);
   Print("Str=", Str);
   
   i = 10;
   x1 = 1.23;
   Str = "MetaTrader4";

   Print("i=", i);
   Print("x1=", x1);
   Print("Str=", Str);
   
   double a=1.2, b=2.5, c;
   c = MathMax(a, b);
   Print("c=", c);
   
   //　新規注文
   int ticket; //チケット番号
   ticket = OrderSend(_Symbol, OP_BUY, 0.1, Ask, 3, 0, 0); //新規買い注文
   MessageBox("チケット番号="+ticket);
}
//+------------------------------------------------------------------+
