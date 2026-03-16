import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:retry/retry.dart';
import '../models.dart';

class YahooFinanceService {
  static const Map<String, String> _defaultHeaders = {
    'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36',
  };

  String _yahooCrumb = '';
  String _yahooCookie = '';

  bool get isAuthenticated => _yahooCrumb.isNotEmpty && _yahooCookie.isNotEmpty;

  Map<String, String> get _authHeaders => {
    ..._defaultHeaders,
    if (_yahooCookie.isNotEmpty) 'Cookie': _yahooCookie,
  };

  Future<bool> authenticate() async {
    try {
      final client = HttpClient();
      client.userAgent = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36';

      // Step 1: Get cookie from fc.yahoo.com
      final req1 = await client.getUrl(Uri.parse('https://fc.yahoo.com/'));
      final resp1 = await req1.close();
      await resp1.drain<void>();

      final cookies = resp1.cookies;
      if (cookies.isEmpty) {
        debugPrint('Yahoo auth: no cookies received');
        client.close();
        return false;
      }
      final cookieStr = cookies.map((c) => '${c.name}=${c.value}').join('; ');

      // Step 2: Get crumb using those cookies
      final req2 = await client.getUrl(
        Uri.parse('https://query2.finance.yahoo.com/v1/test/getcrumb'),
      );
      req2.headers.set(HttpHeaders.cookieHeader, cookieStr);
      final resp2 = await req2.close();
      final crumb = await resp2.transform(utf8.decoder).join();

      client.close();

      if (crumb.isNotEmpty && !crumb.contains('Unauthorized')) {
        _yahooCrumb = crumb.trim();
        _yahooCookie = cookieStr;
        return true;
      }
    } catch (e) {
      debugPrint('Yahoo auth failed: $e');
    }
    return false;
  }

  Future<Stock> fetchPrice(Stock stock) async {
    final url = Uri.parse(
      'https://query1.finance.yahoo.com/v8/finance/chart/${stock.symbol}?interval=15m&range=1d',
    );

    final response = await retry(
      () => http
          .get(url, headers: _defaultHeaders)
          .timeout(const Duration(seconds: 10)),
      retryIf: (e) => e is SocketException || e is TimeoutException,
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return Stock.fromYahooJson(
        data,
        qty: stock.quantity,
        price: stock.purchasePrice,
        watchlisted: stock.isWatchlisted,
        portfolioId: stock.portfolioId,
        existingBeta: stock.beta,
        existingSector: stock.sector,
        existingIndustry: stock.industry,
        existingEtfSectorWeights: stock.etfSectorWeights,
        existingEtfTopHoldings: stock.etfTopHoldings,
        existingEtfGeographicWeights: stock.etfGeographicWeights,
        existingPeRatio: stock.peRatio,
        existingYieldPct: stock.yieldPct,
        existingYtdReturn: stock.ytdReturn,
        existingExpenseRatio: stock.expenseRatio,
        existingNetAssets: stock.netAssets,
        existingNav: stock.nav,
      );
    }
    return stock;
  }

  Future<Map<String, double>> fetchExchangeRates(
    String displayCurrency,
    Set<String> sourceCurrencies,
  ) async {
    final rates = <String, double>{};
    for (final src in sourceCurrencies) {
      try {
        final pair = '$src$displayCurrency=X';
        final url = Uri.parse(
          'https://query1.finance.yahoo.com/v8/finance/chart/$pair?interval=1d&range=1d',
        );
        final response = await retry(
          () => http
              .get(url, headers: _defaultHeaders)
              .timeout(const Duration(seconds: 10)),
          retryIf: (e) => e is SocketException || e is TimeoutException,
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['chart']['result'] != null &&
              (data['chart']['result'] as List).isNotEmpty) {
            final rate =
                (data['chart']['result'][0]['meta']['regularMarketPrice'] ??
                        0.0)
                    .toDouble();
            rates['${src}_$displayCurrency'] = rate;
          }
        }
      } catch (_) {}
    }
    return rates;
  }

  Future<void> fetchExtendedDetails(Stock stock) async {
    // 1. Fetch Key Statistics using v7 quote endpoint (more reliable, no auth needed)
    try {
      final url = Uri.parse(
        'https://query1.finance.yahoo.com/v7/finance/quote?symbols=${stock.symbol}&fields=beta,trailingPE,forwardPE,trailingAnnualDividendYield,dividendYield,marketCap,averageDailyVolume3Month,averageDailyVolume10Day,ytdReturn,bid,ask,bidSize,askSize',
      );
      final response = await retry(
        () => http
            .get(url, headers: _defaultHeaders)
            .timeout(const Duration(seconds: 10)),
        retryIf: (e) => e is SocketException || e is TimeoutException,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final result = data['quoteResponse']?['result'];
        if (result != null && (result as List).isNotEmpty) {
          final quote = result[0];
          stock.beta = (quote['beta'] as num? ?? stock.beta).toDouble();
          stock.peRatio =
              (quote['trailingPE'] as num? ??
                      quote['forwardPE'] as num? ??
                      stock.peRatio)
                  .toDouble();
          stock.yieldPct =
              (quote['trailingAnnualDividendYield'] as num? ??
                      quote['dividendYield'] as num? ??
                      0.0)
                  .toDouble() *
              100.0;
          stock.averageVolume =
              (quote['averageDailyVolume3Month'] as num? ??
                      quote['averageDailyVolume10Day'] as num? ??
                      stock.averageVolume)
                  .toInt();

          stock.bid = (quote['bid'] as num? ?? stock.bid).toDouble();
          stock.ask = (quote['ask'] as num? ?? stock.ask).toDouble();
          stock.bidSize = (quote['bidSize'] as num? ?? stock.bidSize).toInt();
          stock.askSize = (quote['askSize'] as num? ?? stock.askSize).toInt();

          if (stock.instrumentType == 'ETF' ||
              stock.instrumentType == 'MUTUALFUND') {
            stock.ytdReturn = (quote['ytdReturn'] ?? stock.ytdReturn)
                .toDouble();
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to fetch v7 stats for ${stock.symbol}: $e');
    }

    // 2. Fetch ETF details using quoteSummary (requires auth)
    if (!isAuthenticated) return;

    try {
      final url = Uri.parse(
        'https://query1.finance.yahoo.com/v10/finance/quoteSummary/${stock.symbol}?modules=topHoldings,defaultKeyStatistics,summaryDetail,assetProfile&crumb=$_yahooCrumb',
      );
      final response = await retry(
        () => http
            .get(url, headers: _authHeaders)
            .timeout(const Duration(seconds: 10)),
        retryIf: (e) => e is SocketException || e is TimeoutException,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final result = data['quoteSummary']?['result'];
        if (result != null && (result as List).isNotEmpty) {
          final summary = result[0];

          // Sector & Industry
          final assetProfile = summary['assetProfile'];
          if (assetProfile != null) {
            stock.sector = assetProfile['sector'] ?? stock.sector;
            stock.industry = assetProfile['industry'] ?? stock.industry;
          }

          // Beta
          final stats = summary['defaultKeyStatistics'];
          if (stats != null) {
            stock.beta =
                (stats['beta']?['raw'] ?? stats['beta3Year']?['raw'] ?? 0.0)
                    .toDouble();
            if (stock.beta == 0.0) {
              stock.beta = (stats['beta5Year']?['raw'] ?? 0.0).toDouble();
            }
          }

          // ETF Details
          if (stock.instrumentType == 'ETF' && stock.etfSectorWeights.isEmpty) {
            final topHoldings = summary['topHoldings'];
            if (topHoldings != null) {
              final sectorWeightings =
                  topHoldings['sectorWeightings'] as List? ?? [];
              final sectorMap = <String, double>{};
              for (final sector in sectorWeightings) {
                if (sector is Map) {
                  for (final entry in sector.entries) {
                    final weight = entry.value;
                    if (weight is Map && weight.containsKey('raw')) {
                      sectorMap[entry.key.toString()] = (weight['raw'] as num)
                          .toDouble();
                    }
                  }
                }
              }
              stock.etfSectorWeights = sectorMap;

              final holdings = topHoldings['holdings'] as List? ?? [];
              final holdingsMap = <String, double>{};
              for (final h in holdings) {
                final symbol = h['symbol'] ?? '';
                final pct = h['holdingPercent']?['raw'] ?? 0.0;
                if (symbol.isNotEmpty) {
                  holdingsMap[symbol.toString()] = (pct as num).toDouble();
                }
              }
              stock.etfTopHoldings = holdingsMap;
            }
          }

          if (stock.instrumentType == 'ETF' &&
              stock.etfGeographicWeights.isEmpty) {
            stock.etfGeographicWeights = await _computeGeographicWeights(
              stock.symbol,
            );
          }

          final detail = summary['summaryDetail'];
          if (detail != null) {
            stock.peRatio =
                (detail['trailingPE']?['raw'] ??
                        stats?['trailingPE']?['raw'] ??
                        0.0)
                    .toDouble();
            stock.yieldPct =
                (detail['dividendYield']?['raw'] ??
                        detail['yield']?['raw'] ??
                        stats?['dividendYield']?['raw'] ??
                        0.0)
                    .toDouble() *
                100.0;
            stock.ytdReturn =
                (detail['ytdReturn']?['raw'] ??
                        stats?['ytdReturn']?['raw'] ??
                        0.0)
                    .toDouble() *
                100.0;
            stock.bid = (detail['bid']?['raw'] ?? stock.bid).toDouble();
            stock.ask = (detail['ask']?['raw'] ?? stock.ask).toDouble();
            stock.bidSize = (detail['bidSize']?['raw'] ?? stock.bidSize)
                .toInt();
            stock.askSize = (detail['askSize']?['raw'] ?? stock.askSize)
                .toInt();
            stock.averageVolume =
                (detail['averageDailyVolume3Month']?['raw'] ??
                        detail['averageVolume']?['raw'] ??
                        stock.averageVolume)
                    .toInt();

            if (stock.instrumentType == 'ETF' ||
                stock.instrumentType == 'MUTUALFUND') {
              stock.expenseRatio =
                  (detail['expenseRatio']?['raw'] ?? 0.0).toDouble() * 100.0;
              stock.netAssets = (detail['totalAssets']?['raw'] ?? 0.0)
                  .toDouble();
              stock.nav = (detail['navPrice']?['raw'] ?? 0.0).toDouble();
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to fetch extended details for ${stock.symbol}: $e');
    }

    // 3. Fetch Historical Data for Returns
    await fetchHistoricalReturns(stock);
  }

  Future<void> fetchHistoricalReturns(Stock stock) async {
    try {
      final url = Uri.parse(
        'https://query1.finance.yahoo.com/v8/finance/chart/${stock.symbol}?interval=1d&range=1y',
      );
      final response = await retry(
        () => http.get(url, headers: _defaultHeaders).timeout(const Duration(seconds: 10)),
        retryIf: (e) => e is SocketException || e is TimeoutException,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final result = data['chart']?['result'];
        if (result != null && (result as List).isNotEmpty) {
          final chartData = result[0];
          final timestamps = (chartData['timestamp'] as List? ?? []).cast<int>();
          final indicators = chartData['indicators']?['quote']?[0];
          final adjClose = (chartData['indicators']?['adjclose']?[0]?['adjclose'] as List? ?? []).cast<num?>();
          final close = (indicators?['close'] as List? ?? []).cast<num?>();

          final prices = adjClose.isNotEmpty ? adjClose : close;
          if (prices.isEmpty || timestamps.isEmpty) return;

          final currentPrice = stock.currentPrice;
          if (currentPrice <= 0) return;

          final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

          double calculateReturn(int secondsBack) {
            final targetTs = now - secondsBack;
            int bestIdx = -1;
            int minDiff = 0x7FFFFFFF;

            for (int i = 0; i < timestamps.length; i++) {
              final diff = (timestamps[i] - targetTs).abs();
              if (diff < minDiff) {
                minDiff = diff;
                bestIdx = i;
              }
            }

            if (bestIdx != -1 && prices[bestIdx] != null) {
              final oldPrice = prices[bestIdx]!.toDouble();
              if (oldPrice > 0) {
                return ((currentPrice - oldPrice) / oldPrice) * 100.0;
              }
            }
            return 0.0;
          }

          stock.historicalReturns[DisplayTerm.oneWeek] = calculateReturn(7 * 24 * 3600);
          stock.historicalReturns[DisplayTerm.oneMonth] = calculateReturn(30 * 24 * 3600);
          stock.historicalReturns[DisplayTerm.threeMonths] = calculateReturn(90 * 24 * 3600);
          stock.historicalReturns[DisplayTerm.sixMonths] = calculateReturn(180 * 24 * 3600);
          stock.historicalReturns[DisplayTerm.oneYear] = calculateReturn(365 * 24 * 3600);
        }
      }
    } catch (e) {
      debugPrint('Failed to fetch historical returns for ${stock.symbol}: $e');
    }
  }

  Future<Map<String, double>> _computeGeographicWeights(
    String symbol, {
    int depth = 0,
    String? parentSuffix,
  }) async {
    if (depth > 2) return {};

    final currentSuffix = symbol.contains('.')
        ? symbol.substring(symbol.indexOf('.'))
        : parentSuffix;
    final lookupSymbol = (!symbol.contains('.') && parentSuffix != null)
        ? '$symbol$parentSuffix'
        : symbol;

    try {
      final url = Uri.parse(
        'https://query1.finance.yahoo.com/v10/finance/quoteSummary/$lookupSymbol?modules=topHoldings,assetProfile,quoteType&crumb=$_yahooCrumb',
      );
      final response = await retry(
        () => http
            .get(url, headers: _authHeaders)
            .timeout(const Duration(seconds: 10)),
        retryIf: (e) => e is SocketException || e is TimeoutException,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final result = data['quoteSummary']?['result'];
        if (result != null && (result as List).isNotEmpty) {
          final summary = result[0];
          final quoteType = summary['quoteType']?['quoteType'] ?? 'EQUITY';

          if (quoteType == 'ETF' || quoteType == 'MUTUALFUND') {
            final topHoldings =
                summary['topHoldings']?['holdings'] as List? ?? [];
            final geoWeights = <String, double>{};
            for (final h in topHoldings) {
              final subSymbol = h['symbol'] ?? '';
              final pct = (h['holdingPercent']?['raw'] ?? 0.0) as num;
              if (subSymbol.isNotEmpty && pct > 0) {
                final subGeo = await _computeGeographicWeights(
                  subSymbol.toString(),
                  depth: depth + 1,
                  parentSuffix: currentSuffix,
                );
                for (final entry in subGeo.entries) {
                  geoWeights[entry.key] =
                      (geoWeights[entry.key] ?? 0) +
                      (entry.value * pct.toDouble());
                }
              }
            }
            if (geoWeights.isEmpty) {
              final country = summary['assetProfile']?['country'] ?? 'Unknown';
              return {country: 1.0};
            }
            double sum = geoWeights.values.fold(0, (p, c) => p + c);
            if (sum > 0) {
              for (final k in geoWeights.keys.toList()) {
                geoWeights[k] = geoWeights[k]! / sum;
              }
            }
            return geoWeights;
          } else {
            final country = summary['assetProfile']?['country'] ?? 'Unknown';
            return {country: 1.0};
          }
        }
      }
    } catch (_) {}
    return {'Unknown': 1.0};
  }

  Future<List<TickerSuggestion>> searchTickers(String query) async {
    if (query.isEmpty) return [];
    try {
      final url = Uri.parse(
        'https://query2.finance.yahoo.com/v1/finance/search?q=$query&quotesCount=6&newsCount=0&listsCount=0',
      );
      final response = await http.get(url, headers: _defaultHeaders);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final quotes = data['quotes'] as List? ?? [];
        return quotes
            .map(
              (q) => TickerSuggestion(
                symbol: q['symbol'] ?? '',
                name: q['longname'] ?? q['shortname'] ?? q['symbol'] ?? '',
                exchange: q['exchDisp'] ?? q['exchange'] ?? '',
                type: q['quoteType'] ?? '',
                sector: q['sectorDisp'] ?? q['sector'] ?? '',
                industry: q['industryDisp'] ?? q['industry'] ?? '',
              ),
            )
            .where((s) => s.symbol.isNotEmpty)
            .toList();
      }
    } catch (_) {}
    return [];
  }
}
