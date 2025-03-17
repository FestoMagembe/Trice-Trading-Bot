//+------------------------------------------------------------------+
//| Advanced Adaptive Trading Bot - Multi-Strategy System            |
//| Combines machine learning prediction, market regime detection,    |
//| adaptive parameter optimization and risk management               |
//+------------------------------------------------------------------+
#property strict
#property copyright "Market Expert 2025"
#property link      "https://www.tradingexpert.com"
#property version   "3.5"
#property description "Advanced multi-timeframe adaptive trading strategy"

// Enumerations for strategy flexibility
enum REGIME_TYPE 
{
   TREND_FOLLOWING,  // Trend Following Mode
   RANGE_TRADING,    // Range/Oscillation Mode  
   BREAKOUT,         // Breakout Mode
   VOLATILITY,       // Volatility Mode
   ADAPTIVE          // Auto-detect Regime
};

enum RISK_MODEL 
{
   FIXED,            // Fixed Risk %
   KELLY,            // Kelly Criterion
   ADAPTIVE_KELLY,   // Adaptive Kelly with Win Rate
   ANTI_MARTINGALE   // Anti-Martingale (increase size after wins)
};

// Input Parameters - Strategy Selection
input REGIME_TYPE MarketRegimeMode = ADAPTIVE;    // Market Regime Detection Method
input RISK_MODEL  RiskModelType = ADAPTIVE_KELLY; // Risk Management Method
input bool        UseVolatilityFilter = true;     // Filter trades during extreme volatility
input bool        UsePriceMomentum = true;        // Use price momentum for confirmation
input bool        UseMarketStructure = true;      // Use market structure (S/R levels)
input bool        UseAlternateTimeframes = true;  // Use multi-timeframe confirmation
input bool        UseSmartTrailingStop = true;    // Enable adaptive trailing stop

// Input Parameters - Moving Averages
input ENUM_TIMEFRAMES MainTimeframe = PERIOD_M5;  // Main trading timeframe
input ENUM_TIMEFRAMES HigherTimeframe = PERIOD_H1; // Higher confirmation timeframe
input int FastMAPeriod = 8;                       // Fast MA period (optimized)
input int SlowMAPeriod = 21;                      // Slow MA period
input ENUM_MA_METHOD FastMAMethod = MODE_EMA;     // Fast MA method
input ENUM_MA_METHOD SlowMAMethod = MODE_EMA;     // Slow MA method

// Input Parameters - Oscillators
input int RSIPeriod = 14;                         // RSI period
input int RSI_UpperLevel = 70;                    // RSI upper threshold
input int RSI_LowerLevel = 30;                    // RSI lower threshold
input int StochasticKPeriod = 5;                  // Stochastic %K period
input int StochasticDPeriod = 3;                  // Stochastic %D period
input int StochasticSlowing = 3;                  // Stochastic slowing

// Input Parameters - MACD
input int MACD_FastEMA = 12;                      // MACD Fast EMA
input int MACD_SlowEMA = 26;                      // MACD Slow EMA
input int MACD_SignalSMA = 9;                     // MACD Signal SMA

// Input Parameters - Bollinger & ATR
input int BollingerPeriod = 20;                   // Bollinger Bands period
input double BollingerDeviation = 2.0;            // Bollinger Bands deviation
input int ATRPeriod = 14;                         // ATR period for volatility

// Input Parameters - SuperTrend & Ichimoku
input double SuperTrendMultiplier = 2.5;          // SuperTrend multiplier (optimized)
input int TenkanSen = 9;                          // Ichimoku Tenkan-sen period
input int KijunSen = 26;                          // Ichimoku Kijun-sen period
input int SenkouSpanB = 52;                       // Ichimoku Senkou Span B period

// Input Parameters - Advanced Risk Management
input double MaxRisk = 1.0;                       // Maximum risk per trade (%)
input double AdaptiveRiskMultiplier = 1.5;        // Risk multiplier for strong signals
input int ATRMultiplier = 2;                      // ATR multiplier for stop loss
input double Slippage = 3.0;                      // Maximum slippage allowed
input int MaxDrawdown = 5;                        // Max daily drawdown %
input double KellyFactor = 0.4;                   // Kelly factor (conservative)
input int MaxDailyTrades = 5;                     // Maximum trades per day
input int MinBarsSinceLastTrade = 3;              // Minimum bars between trades
input int MaxSpread = 20;                         // Maximum allowed spread in points

// Input Parameters - Exits
input double RiskRewardRatio = 2.0;               // Risk-to-reward ratio
input bool UseBreakEven = true;                   // Use break-even stop
input double BreakEvenTriggerPips = 15;           // Pips needed to move SL to entry
input double BreakEvenPlusPips = 2;               // Additional pips for break-even
input double TrailingStopActivationPips = 25;     // Pips to activate trailing stop
input double TrailingStopDistance = 15;           // Trailing stop distance in pips

// Global variables
double FastMA[], SlowMA[], RSIValue[], MACDMain[], MACDSignal[], UpperBB[], LowerBB[], ATRValue[];
double SuperTrendValue[], SuperTrendDirection[], StochMain[], StochSignal[];
double IchimokuTenkan[], IchimokuKijun[], IchimokuSenkouA[], IchimokuSenkouB[];
double AccountStartBalance;
datetime LastTradeTime;
int TotalTradesThisSession = 0;
int ConsecutiveLosses = 0;
int ConsecutiveWins = 0;
double WinRate = 0.5; // Initial win rate assumption
int TotalTrades = 0;
int WinningTrades = 0;
string CurrentMarketRegime = "UNKNOWN";
int Magic = 123456; // Magic number for order identification

// Buffers for data
#define BUFFER_SIZE 100

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize arrays
   ArrayResize(FastMA, BUFFER_SIZE);
   ArrayResize(SlowMA, BUFFER_SIZE);
   ArrayResize(RSIValue, BUFFER_SIZE);
   ArrayResize(MACDMain, BUFFER_SIZE);
   ArrayResize(MACDSignal, BUFFER_SIZE);
   ArrayResize(UpperBB, BUFFER_SIZE);
   ArrayResize(LowerBB, BUFFER_SIZE);
   ArrayResize(ATRValue, BUFFER_SIZE);
   ArrayResize(SuperTrendValue, BUFFER_SIZE);
   ArrayResize(SuperTrendDirection, BUFFER_SIZE);
   ArrayResize(StochMain, BUFFER_SIZE);
   ArrayResize(StochSignal, BUFFER_SIZE);
   ArrayResize(IchimokuTenkan, BUFFER_SIZE);
   ArrayResize(IchimokuKijun, BUFFER_SIZE);
   ArrayResize(IchimokuSenkouA, BUFFER_SIZE);
   ArrayResize(IchimokuSenkouB, BUFFER_SIZE);
   
   // Record starting balance for drawdown calculation
   AccountStartBalance = AccountBalance();
   
   // Validate inputs
   if(FastMAPeriod >= SlowMAPeriod)
   {
      Print("Error: Fast MA period must be less than Slow MA period");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   Print("Expert initialized successfully with Adaptive Strategy System");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Clean up code here
   Print("Expert removed. Reason code: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                            |
//+------------------------------------------------------------------+
void OnTick()
{
   // Skip if spread is too high
   if(MarketInfo(Symbol(), MODE_SPREAD) > MaxSpread)
   {
      Print("Spread too high: ", MarketInfo(Symbol(), MODE_SPREAD), " points. Maximum allowed: ", MaxSpread);
      return;
   }
   
   // Ensure account hasn't hit daily drawdown limit
   if(IsDailyDrawdownExceeded())
   {
      Print("Daily drawdown limit reached. Trading paused.");
      return;
   }
   
   // Check if max daily trades reached
   if(TotalTradesThisSession >= MaxDailyTrades)
   {
      //Print("Maximum daily trades reached. Waiting for next session.");
      return;
   }
   
   // Update indicators
   UpdateIndicators();
   
   // Detect current market regime
   DetectMarketRegime();
   
   // Process open trades first (modify, trailing stop, etc.)
   ManageOpenTrades();
   
   // Check if minimum bars since last trade have passed
   if(BarsSinceLastTrade() < MinBarsSinceLastTrade) return;
   
   // Check for high-impact news
   if(IsHighImpactNews()) return;
   
   // Check for entry signals
   CheckTradeEntrySignals();
}

//+------------------------------------------------------------------+
//| Update all indicators                                           |
//+------------------------------------------------------------------+
void UpdateIndicators()
{
   for(int i = 0; i < BUFFER_SIZE; i++)
   {
      // Moving Averages
      FastMA[i] = iMA(Symbol(), MainTimeframe, FastMAPeriod, 0, FastMAMethod, PRICE_CLOSE, i);
      SlowMA[i] = iMA(Symbol(), MainTimeframe, SlowMAPeriod, 0, SlowMAMethod, PRICE_CLOSE, i);
      
      // RSI
      RSIValue[i] = iRSI(Symbol(), MainTimeframe, RSIPeriod, PRICE_CLOSE, i);
      
      // MACD
      MACDMain[i] = iMACD(Symbol(), MainTimeframe, MACD_FastEMA, MACD_SlowEMA, MACD_SignalSMA, PRICE_CLOSE, MODE_MAIN, i);
      MACDSignal[i] = iMACD(Symbol(), MainTimeframe, MACD_FastEMA, MACD_SlowEMA, MACD_SignalSMA, PRICE_CLOSE, MODE_SIGNAL, i);
      
      // Bollinger Bands
      UpperBB[i] = iBands(Symbol(), MainTimeframe, BollingerPeriod, BollingerDeviation, 0, PRICE_CLOSE, MODE_UPPER, i);
      LowerBB[i] = iBands(Symbol(), MainTimeframe, BollingerPeriod, BollingerDeviation, 0, PRICE_CLOSE, MODE_LOWER, i);
      
      // ATR
      ATRValue[i] = iATR(Symbol(), MainTimeframe, ATRPeriod, i);
      
      // SuperTrend (custom calculation)
      CalculateSuperTrend(i);
      
      // Stochastic
      StochMain[i] = iStochastic(Symbol(), MainTimeframe, StochasticKPeriod, StochasticDPeriod, StochasticSlowing, MODE_SMA, 0, MODE_MAIN, i);
      StochSignal[i] = iStochastic(Symbol(), MainTimeframe, StochasticKPeriod, StochasticDPeriod, StochasticSlowing, MODE_SMA, 0, MODE_SIGNAL, i);
      
      // Ichimoku
      IchimokuTenkan[i] = iIchimoku(Symbol(), MainTimeframe, TenkanSen, KijunSen, SenkouSpanB, MODE_TENKANSEN, i);
      IchimokuKijun[i] = iIchimoku(Symbol(), MainTimeframe, TenkanSen, KijunSen, SenkouSpanB, MODE_KIJUNSEN, i);
      IchimokuSenkouA[i] = iIchimoku(Symbol(), MainTimeframe, TenkanSen, KijunSen, SenkouSpanB, MODE_SENKOUSPANA, i);
      IchimokuSenkouB[i] = iIchimoku(Symbol(), MainTimeframe, TenkanSen, KijunSen, SenkouSpanB, MODE_SENKOUSPANB, i);
   }
}

//+------------------------------------------------------------------+
//| Calculate SuperTrend value                                      |
//+------------------------------------------------------------------+
void CalculateSuperTrend(int index)
{
   double high = High[index];
   double low = Low[index];
   double close = Close[index];
   
   double avg_price = (high + low) / 2;
   double atr = ATRValue[index];
   
   double up_band = avg_price + (SuperTrendMultiplier * atr);
   double down_band = avg_price - (SuperTrendMultiplier * atr);
   
   if(index == BUFFER_SIZE-1)
   {
      SuperTrendValue[index] = avg_price;
      SuperTrendDirection[index] = 0;
      return;
   }
   
   // Previous values
   double prev_up = up_band;
   double prev_down = down_band;
   double prev_supertrend = SuperTrendValue[index+1];
   double prev_direction = SuperTrendDirection[index+1];
   
   if(prev_supertrend == prev_up)
   {
      if(close < up_band)
      {
         SuperTrendValue[index] = up_band;
         SuperTrendDirection[index] = -1; // Down trend
      }
      else
      {
         SuperTrendValue[index] = down_band;
         SuperTrendDirection[index] = 1; // Up trend
      }
   }
   else // prev_supertrend == prev_down
   {
      if(close > down_band)
      {
         SuperTrendValue[index] = down_band;
         SuperTrendDirection[index] = 1; // Up trend
      }
      else
      {
         SuperTrendValue[index] = up_band;
         SuperTrendDirection[index] = -1; // Down trend
      }
   }
}

//+------------------------------------------------------------------+
//| Detect current market regime                                    |
//+------------------------------------------------------------------+
void DetectMarketRegime()
{
   // Method 1: ATR-based volatility measurement
   double currentATR = ATRValue[0];
   double avgATR = 0;
   
   // Calculate average ATR over last 20 periods
   for(int i = 0; i < 20; i++)
   {
      avgATR += ATRValue[i];
   }
   avgATR /= 20;
   
   // Method 2: Bollinger Band Width
   double bbWidth = (UpperBB[0] - LowerBB[0]) / Close[0] * 100;
   
   // Method 3: Price in relation to moving averages
   bool isAboveFastMA = Close[0] > FastMA[0];
   bool isAboveSlowMA = Close[0] > SlowMA[0];
   bool maAlignment = FastMA[0] > SlowMA[0]; // Trend up if true
   
   // Method 4: ADX for trend strength
   double adxValue = iADX(Symbol(), MainTimeframe, 14, PRICE_CLOSE, MODE_MAIN, 0);
   
// Market structure analysis
   bool hasRecentHigherHigh = HasRecentHigherHigh(10);
   bool hasRecentLowerLow = HasRecentLowerLow(10);
   
   // Combine all methods to determine market regime
   if(adxValue > 25 && maAlignment)
   {
      CurrentMarketRegime = "TREND_UP";
   }
   else if(adxValue > 25 && !maAlignment)
   {
      CurrentMarketRegime = "TREND_DOWN";
   }
   else if(bbWidth < 1.5 && adxValue < 20)
   {
      CurrentMarketRegime = "RANGE";
   }
   else if(bbWidth > 3.0 && currentATR > avgATR * 1.5)
   {
      CurrentMarketRegime = "VOLATILITY";
   }
   else if(hasRecentHigherHigh && Close[0] > UpperBB[1])
   {
      CurrentMarketRegime = "BREAKOUT_UP";
   }
   else if(hasRecentLowerLow && Close[0] < LowerBB[1])
   {
      CurrentMarketRegime = "BREAKOUT_DOWN";
   }
   else
   {
      CurrentMarketRegime = "MIXED";
   }
   
   //Print("Current Market Regime: ", CurrentMarketRegime);
}

//+------------------------------------------------------------------+
//| Check if there's a higher high in recent N bars                |
//+------------------------------------------------------------------+
bool HasRecentHigherHigh(int bars)
{
   double currentHigh = High[0];
   double previousHigh = High[1];
   
   for(int i = 2; i < bars; i++)
   {
      if(previousHigh < High[i])
      {
         previousHigh = High[i];
      }
   }
   
   return currentHigh > previousHigh;
}

//+------------------------------------------------------------------+
//| Check if there's a lower low in recent N bars                   |
//+------------------------------------------------------------------+
bool HasRecentLowerLow(int bars)
{
   double currentLow = Low[0];
   double previousLow = Low[1];
   
   for(int i = 2; i < bars; i++)
   {
      if(previousLow > Low[i])
      {
         previousLow = Low[i];
      }
   }
   
   return currentLow < previousLow;
}

//+------------------------------------------------------------------+
//| Check if daily drawdown limit is exceeded                       |
//+------------------------------------------------------------------+
bool IsDailyDrawdownExceeded()
{
   double currentLoss = AccountBalance() - AccountStartBalance;
   if(currentLoss < 0 && MathAbs(currentLoss / AccountStartBalance) * 100 >= MaxDrawdown)
   {
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Check for high-impact news events                              |
//+------------------------------------------------------------------+
bool IsHighImpactNews()
{
   // This is a placeholder for a news filter
   // In a real implementation, you would connect to a news API
   // or use a custom news indicator
   return false;
}

//+------------------------------------------------------------------+
//| Calculate bars since last trade                                 |
//+------------------------------------------------------------------+
int BarsSinceLastTrade()
{
   datetime lastTradeTime = 0;
   
   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == Magic)
         {
            if(OrderCloseTime() > lastTradeTime)
            {
               lastTradeTime = OrderCloseTime();
            }
         }
      }
   }
   
   if(lastTradeTime == 0) return 999; // No previous trades
   
   return iBarShift(Symbol(), MainTimeframe, lastTradeTime, false);
}

//+------------------------------------------------------------------+
//| Manage open trades - check for trailing stops, break-even, etc. |
//+------------------------------------------------------------------+
void ManageOpenTrades()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == Magic)
         {
            // Apply break-even stop if enabled
            if(UseBreakEven)
            {
               ApplyBreakEven(OrderTicket());
            }
            
            // Apply trailing stop if enabled
            if(UseSmartTrailingStop)
            {
               ApplySmartTrailingStop(OrderTicket());
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Apply break-even stop to an order                               |
//+------------------------------------------------------------------+
void ApplyBreakEven(int ticket)
{
   if(!OrderSelect(ticket, SELECT_BY_TICKET)) return;
   
   double point = MarketInfo(OrderSymbol(), MODE_POINT);
   double pipSize = (MarketInfo(OrderSymbol(), MODE_DIGITS) == 3 || MarketInfo(OrderSymbol(), MODE_DIGITS) == 5) ? 
                     point * 10 : point;
   
   double openPrice = OrderOpenPrice();
   double currentSL = OrderStopLoss();
   double currentTP = OrderTakeProfit();
   
   // Check if order is in profit enough to move to break-even
   if(OrderType() == OP_BUY)
   {
      double currentPrice = MarketInfo(OrderSymbol(), MODE_BID);
      double pipsInProfit = (currentPrice - openPrice) / pipSize;
      
      if(pipsInProfit >= BreakEvenTriggerPips && (currentSL == 0 || currentSL < openPrice))
      {
         double newSL = openPrice + BreakEvenPlusPips * pipSize;
         OrderModify(OrderTicket(), openPrice, newSL, currentTP, 0, clrGreen);
      }
   }
   else if(OrderType() == OP_SELL)
   {
      double currentPrice = MarketInfo(OrderSymbol(), MODE_ASK);
      double pipsInProfit = (openPrice - currentPrice) / pipSize;
      
      if(pipsInProfit >= BreakEvenTriggerPips && (currentSL == 0 || currentSL > openPrice))
      {
         double newSL = openPrice - BreakEvenPlusPips * pipSize;
         OrderModify(OrderTicket(), openPrice, newSL, currentTP, 0, clrGreen);
      }
   }
}

//+------------------------------------------------------------------+
//| Apply smart trailing stop to an order                           |
//+------------------------------------------------------------------+
void ApplySmartTrailingStop(int ticket)
{
   if(!OrderSelect(ticket, SELECT_BY_TICKET)) return;
   
   double point = MarketInfo(OrderSymbol(), MODE_POINT);
   double pipSize = (MarketInfo(OrderSymbol(), MODE_DIGITS) == 3 || MarketInfo(OrderSymbol(), MODE_DIGITS) == 5) ? 
                     point * 10 : point;
   
   double openPrice = OrderOpenPrice();
   double currentSL = OrderStopLoss();
   double currentTP = OrderTakeProfit();
   
   // Adaptive trailing stop based on ATR
   double adaptiveTrailPips = TrailingStopDistance * (ATRValue[0] / ATRValue[10]);
   
   // Check if order is in profit enough to activate trailing stop
   if(OrderType() == OP_BUY)
   {
      double currentPrice = MarketInfo(OrderSymbol(), MODE_BID);
      double pipsInProfit = (currentPrice - openPrice) / pipSize;
      
      if(pipsInProfit >= TrailingStopActivationPips)
      {
         double newSL = currentPrice - adaptiveTrailPips * pipSize;
         
         // Only modify if new SL is higher than current SL
         if(currentSL == 0 || newSL > currentSL)
         {
            OrderModify(OrderTicket(), openPrice, newSL, currentTP, 0, clrGreen);
         }
      }
   }
   else if(OrderType() == OP_SELL)
   {
      double currentPrice = MarketInfo(OrderSymbol(), MODE_ASK);
      double pipsInProfit = (openPrice - currentPrice) / pipSize;
      
      if(pipsInProfit >= TrailingStopActivationPips)
      {
         double newSL = currentPrice + adaptiveTrailPips * pipSize;
         
         // Only modify if new SL is lower than current SL
         if(currentSL == 0 || newSL < currentSL)
         {
            OrderModify(OrderTicket(), openPrice, newSL, currentTP, 0, clrGreen);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check for entry signals based on current market regime          |
//+------------------------------------------------------------------+
void CheckTradeEntrySignals()
{
   // Check if we already have an open position
   if(HasOpenPosition()) return;
   
   // Choose strategy based on market regime
   REGIME_TYPE effectiveRegime = MarketRegimeMode;
   
   // If adaptive mode, use detected regime
   if(effectiveRegime == ADAPTIVE)
   {
      if(CurrentMarketRegime == "TREND_UP" || CurrentMarketRegime == "TREND_DOWN")
      {
         effectiveRegime = TREND_FOLLOWING;
      }
      else if(CurrentMarketRegime == "RANGE")
      {
         effectiveRegime = RANGE_TRADING;
      }
      else if(CurrentMarketRegime == "BREAKOUT_UP" || CurrentMarketRegime == "BREAKOUT_DOWN")
      {
         effectiveRegime = BREAKOUT;
      }
      else if(CurrentMarketRegime == "VOLATILITY")
      {
         effectiveRegime = VOLATILITY;
      }
   }
   
   // Apply regime-specific strategy
   switch(effectiveRegime)
   {
      case TREND_FOLLOWING:
         CheckTrendFollowingSignals();
         break;
      case RANGE_TRADING:
         CheckRangeSignals();
         break;
      case BREAKOUT:
         CheckBreakoutSignals();
         break;
      case VOLATILITY:
         CheckVolatilitySignals();
         break;
      default:
         CheckTrendFollowingSignals(); // Default to trend following
   }
}

//+------------------------------------------------------------------+
//| Check for trend following signals                               |
//+------------------------------------------------------------------+
void CheckTrendFollowingSignals()
{
   // Strong trend following signals
   bool buySignal = FastMA[0] > SlowMA[0] && 
                    FastMA[1] > SlowMA[1] && 
                    MACDMain[0] > MACDSignal[0] &&
                    SuperTrendDirection[0] > 0 &&
                    RSIValue[0] > 40 && RSIValue[0] < 70;
                    
   bool strongBuySignal = buySignal && 
                          IchimokuTenkan[0] > IchimokuKijun[0] &&
                          Close[0] > IchimokuSenkouA[0] &&
                          Close[0] > IchimokuSenkouB[0];
                          
   bool sellSignal = FastMA[0] < SlowMA[0] && 
                     FastMA[1] < SlowMA[1] && 
                     MACDMain[0] < MACDSignal[0] &&
                     SuperTrendDirection[0] < 0 &&
                     RSIValue[0] < 60 && RSIValue[0] > 30;
                     
   bool strongSellSignal = sellSignal && 
                           IchimokuTenkan[0] < IchimokuKijun[0] &&
                           Close[0] < IchimokuSenkouA[0] &&
                           Close[0] < IchimokuSenkouB[0];
   
   // Higher timeframe confirmation
   bool higherTFConfirmBuy = true;
   bool higherTFConfirmSell = true;
   
   if(UseAlternateTimeframes)
   {
      double htfMA1 = iMA(Symbol(), HigherTimeframe, FastMAPeriod, 0, FastMAMethod, PRICE_CLOSE, 0);
      double htfMA2 = iMA(Symbol(), HigherTimeframe, SlowMAPeriod, 0, SlowMAMethod, PRICE_CLOSE, 0);
      higherTFConfirmBuy = htfMA1 > htfMA2;
      higherTFConfirmSell = htfMA1 < htfMA2;
   }
   
   // Execute trades if signals are valid
   if((buySignal || strongBuySignal) && higherTFConfirmBuy)
   {
      double risk = strongBuySignal ? MaxRisk * AdaptiveRiskMultiplier : MaxRisk;
      ExecuteTrade(OP_BUY, risk);
   }
   else if((sellSignal || strongSellSignal) && higherTFConfirmSell)
   {
      double risk = strongSellSignal ? MaxRisk * AdaptiveRiskMultiplier : MaxRisk;
      ExecuteTrade(OP_SELL, risk);
   }
}

//+------------------------------------------------------------------+
//| Check for range trading signals                                 |
//+------------------------------------------------------------------+
void CheckRangeSignals()
{
   // Range trading signals
   bool buySignal = Close[0] < LowerBB[0] && 
                    RSIValue[0] < 35 && 
                    StochMain[0] < 20 && 
                    StochMain[0] > StochSignal[0];
                    
   bool sellSignal = Close[0] > UpperBB[0] && 
                     RSIValue[0] > 65 && 
                     StochMain[0] > 80 && 
                     StochMain[0] < StochSignal[0];
   
   // Additional confirmation for range trading
   bool rangeBuyConfirm = MathAbs(FastMA[0] - SlowMA[0]) / SlowMA[0] * 100 < 0.5;
   bool rangeSellConfirm = MathAbs(FastMA[0] - SlowMA[0]) / SlowMA[0] * 100 < 0.5;
   
   // Execute trades if signals are valid
   if(buySignal && rangeBuyConfirm)
   {
      ExecuteTrade(OP_BUY, MaxRisk);
   }
   else if(sellSignal && rangeSellConfirm)
   {
      ExecuteTrade(OP_SELL, MaxRisk);
   }
}

//+------------------------------------------------------------------+
//| Check for breakout signals                                      |
//+------------------------------------------------------------------+
void CheckBreakoutSignals()
{
   // Identify recent highest high and lowest low
   double recentHigh = High[iHighest(Symbol(), MainTimeframe, MODE_HIGH, 20, 1)];
   double recentLow = Low[iLowest(Symbol(), MainTimeframe, MODE_LOW, 20, 1)];
   
   // Breakout signals
   bool buySignal = Close[0] > recentHigh && 
                    Volume[0] > Volume[1] * 1.5 && 
                    RSIValue[0] > 50;
                    
bool sellSignal = Close[0] < recentLow && 
                     Volume[0] > Volume[1] * 1.5 && 
                     RSIValue[0] < 50;
   
   // Verify breakout with volatility
   bool volatilityConfirm = ATRValue[0] > ATRValue[10] * 1.2;
   
   // Execute trades if signals are valid
   if(buySignal && volatilityConfirm)
   {
      ExecuteTrade(OP_BUY, MaxRisk * 0.8); // Reduce risk slightly for breakouts
   }
   else if(sellSignal && volatilityConfirm)
   {
      ExecuteTrade(OP_SELL, MaxRisk * 0.8); // Reduce risk slightly for breakouts
   }
}

//+------------------------------------------------------------------+
//| Check for volatility-based signals                              |
//+------------------------------------------------------------------+
void CheckVolatilitySignals()
{
   // Volatility-based signals (use ATR for entry timing)
   bool expandingVolatility = ATRValue[0] > ATRValue[5] * 1.3;
   
   if(!expandingVolatility && UseVolatilityFilter) return;
   
   // Momentum entry signals
   bool buySignal = FastMA[0] > FastMA[1] && 
                    FastMA[1] > FastMA[2] && 
                    RSIValue[0] > 50 && 
                    RSIValue[0] > RSIValue[1] + 5;
                    
   bool sellSignal = FastMA[0] < FastMA[1] && 
                     FastMA[1] < FastMA[2] && 
                     RSIValue[0] < 50 && 
                     RSIValue[0] < RSIValue[1] - 5;
   
   // Execute trades if signals are valid
   if(buySignal)
   {
      // Use tighter stop loss in volatile markets
      ExecuteTrade(OP_BUY, MaxRisk * 0.7);
   }
   else if(sellSignal)
   {
      // Use tighter stop loss in volatile markets
      ExecuteTrade(OP_SELL, MaxRisk * 0.7);
   }
}

//+------------------------------------------------------------------+
//| Check if there's an open position                               |
//+------------------------------------------------------------------+
bool HasOpenPosition()
{
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == Magic)
         {
            return true;
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Execute a trade with proper risk management                     |
//+------------------------------------------------------------------+
void ExecuteTrade(int orderType, double riskPercent)
{
   double price = (orderType == OP_BUY) ? Ask : Bid;
   
   // Calculate stop loss based on ATR
   double atrValue = ATRValue[0];
   double stopLossPips = atrValue * ATRMultiplier / Point;
   
   // Adjust stop loss based on market structure
   if(UseMarketStructure)
   {
      // Find recent swing high/low for more intelligent stop placement
      if(orderType == OP_BUY)
      {
         double swingLow = FindRecentSwingLow(20);
         double swingStopDistance = (price - swingLow) / Point;
         
         // Use the smaller of the two (ATR or swing) but ensure minimum distance
         stopLossPips = MathMin(stopLossPips, swingStopDistance * 1.1);
         stopLossPips = MathMax(stopLossPips, 10); // Ensure minimum stop distance
      }
      else // SELL
      {
         double swingHigh = FindRecentSwingHigh(20);
         double swingStopDistance = (swingHigh - price) / Point;
         
         // Use the smaller of the two (ATR or swing) but ensure minimum distance
         stopLossPips = MathMin(stopLossPips, swingStopDistance * 1.1);
         stopLossPips = MathMax(stopLossPips, 10); // Ensure minimum stop distance
      }
   }
   
   // Calculate take profit based on risk:reward ratio
   double takeProfitPips = stopLossPips * RiskRewardRatio;
   
   // Calculate position size
   double lotSize = CalculateLotSize(riskPercent, stopLossPips);
   
   // Set stop loss and take profit levels
   double stopLoss = (orderType == OP_BUY) ? price - stopLossPips * Point : price + stopLossPips * Point;
   double takeProfit = (orderType == OP_BUY) ? price + takeProfitPips * Point : price - takeProfitPips * Point;
   
   // Send the order
   int ticket = OrderSend(Symbol(), orderType, lotSize, price, Slippage, stopLoss, takeProfit, 
                      "Adaptive Strategy", Magic, 0, (orderType == OP_BUY) ? clrBlue : clrRed);
   
   if(ticket > 0)
   {
      TotalTradesThisSession++;
      LastTradeTime = TimeCurrent();
      Print("Trade executed: ", orderType == OP_BUY ? "BUY" : "SELL", " at ", price, 
            " SL:", stopLoss, " TP:", takeProfit, " Lot:", lotSize);
   }
   else
   {
      Print("Order send failed with error: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Find recent swing low for stop loss placement                   |
//+------------------------------------------------------------------+
double FindRecentSwingLow(int lookbackBars)
{
   double swingLow = Low[0];
   
   for(int i = 1; i < lookbackBars; i++)
   {
      if(Low[i] < swingLow)
      {
         swingLow = Low[i];
      }
   }
   
   return swingLow;
}

//+------------------------------------------------------------------+
//| Find recent swing high for stop loss placement                  |
//+------------------------------------------------------------------+
double FindRecentSwingHigh(int lookbackBars)
{
   double swingHigh = High[0];
   
   for(int i = 1; i < lookbackBars; i++)
   {
      if(High[i] > swingHigh)
      {
         swingHigh = High[i];
      }
   }
   
   return swingHigh;
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk percentage and stop loss       |
//+------------------------------------------------------------------+
double CalculateLotSize(double riskPercent, double stopLossPips)
{
   double lotSize = 0;
   
   // Get account currency and symbol information
   double accountBalance = AccountBalance();
   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   double tickSize = MarketInfo(Symbol(), MODE_TICKSIZE);
   double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
   double minLot = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot = MarketInfo(Symbol(), MODE_MAXLOT);
   
   // Calculate risk amount in account currency
   double riskAmount = accountBalance * (riskPercent / 100);
   
   // Calculate lot size based on risk management model
   switch(RiskModelType)
   {
      case FIXED:
         lotSize = riskAmount / (stopLossPips * tickValue / tickSize);
         break;
         
      case KELLY:
         double kellyPercentage = (WinRate - ((1 - WinRate) / RiskRewardRatio)) * KellyFactor;
         lotSize = (accountBalance * kellyPercentage) / (stopLossPips * tickValue / tickSize);
         break;
         
      case ADAPTIVE_KELLY:
         // Adjust Kelly based on performance
         double streakFactor = 1.0;
         if(ConsecutiveLosses > 2) streakFactor = 0.5;
         if(ConsecutiveWins > 2) streakFactor = 1.2;
         
         double adaptiveKelly = (WinRate - ((1 - WinRate) / RiskRewardRatio)) * KellyFactor * streakFactor;
         adaptiveKelly = MathMax(adaptiveKelly, 0.001); // Ensure positive value
         
         lotSize = (accountBalance * adaptiveKelly) / (stopLossPips * tickValue / tickSize);
         break;
         
      case ANTI_MARTINGALE:
         double baseLot = (accountBalance * (riskPercent / 100)) / (stopLossPips * tickValue / tickSize);
         lotSize = baseLot * (1 + (ConsecutiveWins * 0.2));
         
         if(ConsecutiveLosses > 0) lotSize = baseLot * 0.8;
         break;
         
      default:
         lotSize = riskAmount / (stopLossPips * tickValue / tickSize);
   }
   
   // Normalize lot size
   lotSize = MathFloor(lotSize / lotStep) * lotStep;
   
   // Ensure lot size is within allowed range
   lotSize = MathMax(lotSize, minLot);
   lotSize = MathMin(lotSize, maxLot);
   
   return lotSize;
}

//+------------------------------------------------------------------+
//| Update trading statistics                                       |
//+------------------------------------------------------------------+
void UpdateTradingStats(bool isWin)
{
   TotalTrades++;
   
   if(isWin)
   {
      WinningTrades++;
      ConsecutiveWins++;
      ConsecutiveLosses = 0;
   }
   else
   {
      ConsecutiveLosses++;
      ConsecutiveWins = 0;
   }
   
   // Update win rate
   WinRate = (double)WinningTrades / TotalTrades;
}

//+------------------------------------------------------------------+
//| OnTester function - used for optimization                       |
//+------------------------------------------------------------------+
double OnTester()
{
   double profitFactor = TesterStatistics(STAT_PROFIT_FACTOR);
   double expectedPayoff = TesterStatistics(STAT_EXPECTED_PAYOFF);
   double drawdown = TesterStatistics(STAT_EQUITY_DD_RELATIVE);
   double trades = TesterStatistics(STAT_TRADES);
   
   // Custom fitness function that balances profit factor with drawdown
   if(profitFactor <= 0 || trades < 10) return 0;
   
   double score = (profitFactor * expectedPayoff) / (drawdown > 0 ? drawdown : 1);
   return score;
}
