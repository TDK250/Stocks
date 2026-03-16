import 'format_utils.dart';

enum DisplayTerm {
  day,
  oneWeek,
  oneMonth,
  threeMonths,
  sixMonths,
  ytd,
  oneYear,
  total,
}

extension DisplayTermLabel on DisplayTerm {
  String get label {
    switch (this) {
      case DisplayTerm.day:
        return 'Day';
      case DisplayTerm.oneWeek:
        return '1W';
      case DisplayTerm.oneMonth:
        return '1M';
      case DisplayTerm.threeMonths:
        return '3M';
      case DisplayTerm.sixMonths:
        return '6M';
      case DisplayTerm.ytd:
        return 'YTD';
      case DisplayTerm.oneYear:
        return '1Y';
      case DisplayTerm.total:
        return 'Total';
    }
  }
}


class Stock {
  final String symbol;
  String companyName;
  String currency;
  String exchangeName;
  String instrumentType;
  String sector;
  String industry;
  double currentPrice;
  double change;
  double percentChange;
  double dayHigh;
  double dayLow;
  double fiftyTwoWeekHigh;
  double fiftyTwoWeekLow;
  int volume;
  double quantity;
  double purchasePrice;
  bool isWatchlisted;
  Map<String, double> etfSectorWeights;
  Map<String, double> etfTopHoldings;
  Map<String, double> etfGeographicWeights;
  Map<DisplayTerm, double> historicalReturns; // Percentage returns
  double beta;
  double open;
  double previousClose;
  double peRatio;
  double yieldPct;
  double ytdReturn;
  double expenseRatio;
  double netAssets;
  double nav;
  String portfolioId;
  double bid;
  double ask;
  int bidSize;
  int askSize;
  int averageVolume;
  List<double> sparklineData;

  Stock({
    required this.symbol,
    this.companyName = '',
    this.currency = 'USD',
    this.exchangeName = '',
    this.instrumentType = 'EQUITY',
    this.sector = '',
    this.industry = '',
    this.currentPrice = 0.0,
    this.change = 0.0,
    this.percentChange = 0.0,
    this.dayHigh = 0.0,
    this.dayLow = 0.0,
    this.fiftyTwoWeekHigh = 0.0,
    this.fiftyTwoWeekLow = 0.0,
    this.volume = 0,
    this.quantity = 0.0,
    this.purchasePrice = 0.0,
    this.isWatchlisted = false,
    this.beta = 0.0,
    this.open = 0.0,
    this.previousClose = 0.0,
    this.peRatio = 0.0,
    this.yieldPct = 0.0,
    this.ytdReturn = 0.0,
    this.expenseRatio = 0.0,
    this.netAssets = 0.0,
    this.nav = 0.0,
    this.bid = 0.0,
    this.ask = 0.0,
    this.bidSize = 0,
    this.askSize = 0,
    this.averageVolume = 0,
    this.portfolioId = 'default',
    Map<String, double>? etfSectorWeights,
    Map<String, double>? etfTopHoldings,
    Map<String, double>? etfGeographicWeights,
    Map<DisplayTerm, double>? historicalReturns,
    this.sparklineData = const [],
  }) : etfSectorWeights = etfSectorWeights ?? {},
       etfTopHoldings = etfTopHoldings ?? {},
       etfGeographicWeights = etfGeographicWeights ?? {},
       historicalReturns = historicalReturns ?? {};

  bool get isInPortfolio => quantity > 0;

  String get typeLabel {
    switch (instrumentType) {
      case 'EQUITY':
        return 'Stock';
      case 'ETF':
        return 'ETF';
      case 'MUTUALFUND':
        return 'Fund';
      case 'CRYPTOCURRENCY':
        return 'Crypto';
      case 'FUTURE':
        return 'Future';
      case 'INDEX':
        return 'Index';
      case 'OPTION':
        return 'Option';
      default:
        return instrumentType;
    }
  }

  String get etfCategory {
    final n = companyName.toLowerCase();
    if (n.contains('bond') ||
        n.contains('fixed income') ||
        n.contains('aggregate')) {
      return 'Bonds';
    }
    if (n.contains('all-equity') ||
        n.contains('all equity') ||
        n.contains('total stock') ||
        n.contains('total market')) {
      return 'All Equity';
    }
    if (n.contains('growth')) return 'Growth';
    if (n.contains('balanced') || n.contains('balance')) return 'Balanced';
    if (n.contains('dividend') || n.contains('income')) {
      return 'Dividend/Income';
    }
    if (n.contains('s&p 500') || n.contains('s&p500')) return 'S&P 500';
    if (n.contains('nasdaq') || n.contains('qqq')) return 'NASDAQ';
    if (n.contains('emerging') || n.contains('em ')) return 'Emerging Mkts';
    if (n.contains('international') ||
        n.contains('intl') ||
        n.contains('global') ||
        n.contains('world') ||
        n.contains('developed')) {
      return 'International';
    }
    if (n.contains('tech') || n.contains('technology')) return 'Technology';
    if (n.contains('health') || n.contains('biotech')) return 'Healthcare';
    if (n.contains('energy')) return 'Energy';
    if (n.contains('real estate') || n.contains('reit')) return 'Real Estate';
    if (n.contains('financ')) return 'Financials';
    if (n.contains('material') || n.contains('commodity')) return 'Materials';
    if (n.contains('small') || n.contains('mid')) return 'Small/Mid Cap';
    return 'Other ETF';
  }

  String get sectorLabel {
    if (instrumentType == 'ETF') return etfCategory;
    return sector.isNotEmpty ? sector : 'Other';
  }

  String get industryLabel => industry.isNotEmpty ? industry : 'Other';

  String get exchangeCountry {
    final ex = exchangeName.toUpperCase();
    if (ex.contains('NASDAQ') ||
        ex.contains('NMS') ||
        ex.contains('NYSE') ||
        ex.contains('ARCA') ||
        ex.contains('AMEX') ||
        ex.contains('BATS') ||
        ex.contains('PCX')) {
      return 'US';
    }
    if (ex.contains('TOR') ||
        ex.contains('TSX') ||
        ex.contains('CNSX') ||
        ex.contains('NEO')) {
      return 'CA';
    }
    if (ex.contains('LSE') || ex.contains('LON')) return 'GB';
    if (ex.contains('FRA') || ex.contains('XETRA')) return 'DE';
    if (ex.contains('PAR')) return 'FR';
    if (ex.contains('TYO') || ex.contains('JPX')) return 'JP';
    if (ex.contains('HKG')) return 'HK';
    if (ex.contains('SHA') || ex.contains('SHE')) return 'CN';
    if (ex.contains('BSE') || ex.contains('NSE')) return 'IN';
    if (ex.contains('ASX')) return 'AU';
    if (ex.contains('STO')) return 'SE';
    if (ex.contains('KOS') || ex.contains('KSC')) return 'KR';
    return 'Other';
  }

  String get exchangeLabel {
    final full = exchangeName;
    if (full.isEmpty) return 'Unknown';
    if (full.contains('NasdaqG') || full.contains('NMS')) return 'NASDAQ';
    if (full.contains('NYSE')) return 'NYSE';
    if (full.contains('PCX') || full.contains('NYSEArca')) return 'NYSE Arca';
    if (full.contains('Toronto') ||
        full.contains('TSX') ||
        full.contains('TOR')) {
      return 'TSX';
    }
    if (full.contains('NEO')) return 'NEO';
    return full.length > 14 ? full.substring(0, 14) : full;
  }

  static const _sectorDisplayNames = {
    'realestate': 'Real Estate',
    'healthcare': 'Healthcare',
    'technology': 'Technology',
    'financial_services': 'Financials',
    'consumer_cyclical': 'Consumer Cyclical',
    'consumer_defensive': 'Consumer Defensive',
    'industrials': 'Industrials',
    'energy': 'Energy',
    'utilities': 'Utilities',
    'communication_services': 'Communication',
    'basic_materials': 'Materials',
  };

  static String prettySectorName(String raw) {
    return _sectorDisplayNames[raw] ?? raw;
  }

  static String currencySymbolFor(String cur) {
    switch (cur) {
      case 'USD':
        return '\$';
      case 'CAD':
        return 'C\$';
      case 'EUR':
        return '\u20AC';
      case 'GBP':
        return '\u00A3';
      case 'GBp':
        return 'p';
      case 'JPY':
        return '\u00A5';
      case 'CNY':
        return '\u00A5';
      case 'KRW':
        return '\u20A9';
      case 'INR':
        return '\u20B9';
      case 'CHF':
        return 'CHF ';
      case 'AUD':
        return 'A\$';
      case 'HKD':
        return 'HK\$';
      case 'SEK':
        return 'kr ';
      case 'NOK':
        return 'kr ';
      case 'DKK':
        return 'kr ';
      case 'BRL':
        return 'R\$';
      default:
        return '$cur ';
    }
  }

  String get currencySymbol => currencySymbolFor(currency);

  factory Stock.fromYahooJson(
    Map<String, dynamic> json, {
    double qty = 0.0,
    double price = 0.0,
    bool watchlisted = false,
    String portfolioId = 'default',
    double existingBeta = 0.0,
    String existingSector = '',
    String existingIndustry = '',
    Map<String, double>? existingEtfSectorWeights,
    Map<String, double>? existingEtfTopHoldings,
    Map<String, double>? existingEtfGeographicWeights,
    double existingPeRatio = 0.0,
    double existingYieldPct = 0.0,
    double existingYtdReturn = 0.0,
    double existingExpenseRatio = 0.0,
    double existingNetAssets = 0.0,
    double existingNav = 0.0,
  }) {
    if (json.containsKey('chart') &&
        json['chart']['result'] != null &&
        (json['chart']['result'] as List).isNotEmpty) {
      final meta = json['chart']['result'][0]['meta'];
      final regularPrice = (meta['regularMarketPrice'] ?? 0.0).toDouble();
      final previousClose =
          (meta['chartPreviousClose'] ?? meta['previousClose'] ?? 0.0)
              .toDouble();
      final dayChange = regularPrice - previousClose;
      final dayPctChange = previousClose > 0
          ? (dayChange / previousClose * 100)
          : 0.0;

      final indicators = json['chart']['result'][0]['indicators'] ?? {};
      final quote = (indicators['quote'] as List).first ?? {};
      final closePrices = (quote['close'] as List)
          .map((e) => (e as num?)?.toDouble())
          .whereType<double>()
          .toList();

      return Stock(
        symbol: (meta['symbol'] ?? '').toString(),
        companyName:
            (meta['longName'] ?? meta['shortName'] ?? meta['symbol'] ?? '')
                .toString(),
        currency: (meta['currency'] ?? 'USD').toString(),
        exchangeName: (meta['fullExchangeName'] ?? meta['exchangeName'] ?? '')
            .toString(),
        instrumentType: (meta['instrumentType'] ?? 'EQUITY').toString(),
        sector: existingSector,
        industry: existingIndustry,
        currentPrice: regularPrice,
        change: dayChange,
        percentChange: dayPctChange,
        dayHigh: (meta['regularMarketDayHigh'] ?? 0.0).toDouble(),
        dayLow: (meta['regularMarketDayLow'] ?? 0.0).toDouble(),
        fiftyTwoWeekHigh: (meta['fiftyTwoWeekHigh'] ?? 0.0).toDouble(),
        fiftyTwoWeekLow: (meta['fiftyTwoWeekLow'] ?? 0.0).toDouble(),
        volume: (meta['regularMarketVolume'] ?? 0).toInt(),
        quantity: qty,
        purchasePrice: price,
        isWatchlisted: watchlisted,
        portfolioId: portfolioId,
        beta: existingBeta,
        open: (meta['regularMarketOpen'] ?? 0.0).toDouble(),
        previousClose: previousClose,
        etfSectorWeights: existingEtfSectorWeights,
        etfTopHoldings: existingEtfTopHoldings,
        etfGeographicWeights: existingEtfGeographicWeights,
        peRatio: existingPeRatio,
        yieldPct: existingYieldPct,
        ytdReturn: existingYtdReturn,
        expenseRatio: existingExpenseRatio,
        netAssets: existingNetAssets,
        nav: existingNav,
        bid: (meta['regularMarketBid'] ?? 0.0).toDouble(),
        ask: (meta['regularMarketAsk'] ?? 0.0).toDouble(),
        bidSize: (meta['regularMarketBidSize'] ?? 0).toInt(),
        askSize: (meta['regularMarketAskSize'] ?? 0).toInt(),
        averageVolume:
            (meta['averageDailyVolume3Month'] ??
                    meta['averageDailyVolume10Day'] ??
                    0)
                .toInt(),
        sparklineData: closePrices,
      );
    }
    return Stock(symbol: 'UNKNOWN');
  }

  factory Stock.fromStorageJson(Map<String, dynamic> json) {
    return Stock(
      symbol: json['symbol'] ?? 'UNKNOWN',
      companyName: json['companyName'] ?? '',
      currency: json['currency'] ?? 'USD',
      exchangeName: json['exchangeName'] ?? '',
      instrumentType: json['instrumentType'] ?? 'EQUITY',
      sector: json['sector'] ?? '',
      industry: json['industry'] ?? '',
      currentPrice: (json['currentPrice'] ?? 0.0).toDouble(),
      change: (json['change'] ?? 0.0).toDouble(),
      percentChange: (json['percentChange'] ?? 0.0).toDouble(),
      dayHigh: (json['dayHigh'] ?? 0.0).toDouble(),
      dayLow: (json['dayLow'] ?? 0.0).toDouble(),
      fiftyTwoWeekHigh: (json['fiftyTwoWeekHigh'] ?? 0.0).toDouble(),
      fiftyTwoWeekLow: (json['fiftyTwoWeekLow'] ?? 0.0).toDouble(),
      volume: (json['volume'] ?? 0).toInt(),
      quantity: (json['quantity'] ?? 0.0).toDouble(),
      purchasePrice: (json['purchasePrice'] ?? 0.0).toDouble(),
      isWatchlisted: json['isWatchlisted'] ?? false,
      etfSectorWeights: json['etfSectorWeights'] != null
          ? Map<String, double>.from(
              (json['etfSectorWeights'] as Map).map(
                (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
              ),
            )
          : null,
      etfTopHoldings: json['etfTopHoldings'] != null
          ? Map<String, double>.from(
              (json['etfTopHoldings'] as Map).map(
                (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
              ),
            )
          : null,
      etfGeographicWeights: json['etfGeographicWeights'] != null
          ? Map<String, double>.from(
              (json['etfGeographicWeights'] as Map).map(
                (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
              ),
            )
          : null,
      beta: (json['beta'] ?? 0.0).toDouble(),
      open: (json['open'] ?? 0.0).toDouble(),
      previousClose: (json['previousClose'] ?? 0.0).toDouble(),
      peRatio: (json['peRatio'] ?? 0.0).toDouble(),
      yieldPct: (json['yieldPct'] ?? 0.0).toDouble(),
      ytdReturn: (json['ytdReturn'] ?? 0.0).toDouble(),
      expenseRatio: (json['expenseRatio'] ?? 0.0).toDouble(),
      netAssets: (json['netAssets'] ?? 0.0).toDouble(),
      nav: (json['nav'] ?? 0.0).toDouble(),
      bid: (json['bid'] ?? 0.0).toDouble(),
      ask: (json['ask'] ?? 0.0).toDouble(),
      bidSize: (json['bidSize'] ?? 0).toInt(),
      askSize: (json['askSize'] ?? 0).toInt(),
      averageVolume: (json['averageVolume'] ?? 0).toInt(),
      portfolioId: json['portfolioId'] ?? 'default',
      sparklineData: json['sparklineData'] != null
          ? List<double>.from(
              (json['sparklineData'] as List).map((e) => (e as num).toDouble()),
            )
          : const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'symbol': symbol,
      'companyName': companyName,
      'currency': currency,
      'exchangeName': exchangeName,
      'instrumentType': instrumentType,
      'sector': sector,
      'industry': industry,
      'currentPrice': currentPrice,
      'change': change,
      'percentChange': percentChange,
      'dayHigh': dayHigh,
      'dayLow': dayLow,
      'fiftyTwoWeekHigh': fiftyTwoWeekHigh,
      'fiftyTwoWeekLow': fiftyTwoWeekLow,
      'volume': volume,
      'quantity': quantity,
      'purchasePrice': purchasePrice,
      'isWatchlisted': isWatchlisted,
      'beta': beta,
      'open': open,
      'previousClose': previousClose,
      'peRatio': peRatio,
      'yieldPct': yieldPct,
      'ytdReturn': ytdReturn,
      'expenseRatio': expenseRatio,
      'netAssets': netAssets,
      'nav': nav,
      'bid': bid,
      'ask': ask,
      'bidSize': bidSize,
      'askSize': askSize,
      'averageVolume': averageVolume,
      'portfolioId': portfolioId,
      if (etfSectorWeights.isNotEmpty) 'etfSectorWeights': etfSectorWeights,
      if (etfTopHoldings.isNotEmpty) 'etfTopHoldings': etfTopHoldings,
      if (etfGeographicWeights.isNotEmpty)
        'etfGeographicWeights': etfGeographicWeights,
      'sparklineData': sparklineData,
    };
  }

  double get totalValue => quantity * currentPrice;
  double get totalGainLoss => (currentPrice - purchasePrice) * quantity;
  double get totalGainLossPct => purchasePrice > 0
      ? ((currentPrice - purchasePrice) / purchasePrice * 100)
      : 0.0;

  double getReturnPercent(DisplayTerm term) {
    if (historicalReturns.containsKey(term)) {
      return historicalReturns[term]!;
    }
    switch (term) {
      case DisplayTerm.day:
        return percentChange;
      case DisplayTerm.ytd:
        return ytdReturn;
      case DisplayTerm.total:
        return totalGainLossPct;
      default:
        return 0.0;
    }
  }

  double getReturnValue(DisplayTerm term) {
    final pct = getReturnPercent(term);
    if (term == DisplayTerm.total) return totalGainLoss;
    // For other terms, we calculate the dollar change relative to current value
    // Value_start = Value_end / (1 + pct/100)
    // Change = Value_end - Value_start = Value_end * (1 - 1/(1 + pct/100)) = Value_end * (pct / (100 + pct))
    return totalValue * (pct / (100 + pct));
  }

  double get totalCost => quantity * purchasePrice;
  String get formattedVolume => formatLargeNumber(volume);

  static String formatLargeNumber(num value) {
    return FormatUtils.formatLargeNumber(value);
  }
}

class TickerSuggestion {
  final String symbol;
  final String name;
  final String exchange;
  final String type;
  final String sector;
  final String industry;

  TickerSuggestion({
    required this.symbol,
    required this.name,
    this.exchange = '',
    this.type = '',
    this.sector = '',
    this.industry = '',
  });
}
