import 'dart:async';
import 'package:flutter/foundation.dart';
import 'models.dart';
import 'services/storage_service.dart';
import 'services/yahoo_finance_service.dart';

enum SortField {
  custom,
  dayGain,
  totalGain,
  totalValue,
  percentChange,
  name,
  price,
}

extension SortFieldLabel on SortField {
  String get label {
    switch (this) {
      case SortField.custom:
        return 'Custom';
      case SortField.dayGain:
        return 'Day Change';
      case SortField.totalGain:
        return 'Total P&L';
      case SortField.totalValue:
        return 'Value';
      case SortField.percentChange:
        return 'Day %';
      case SortField.name:
        return 'Name';
      case SortField.price:
        return 'Price';
    }
  }
}

class PortfolioProvider with ChangeNotifier {
  final StorageService _storage;
  final YahooFinanceService _yahoo;

  List<Stock> _stocks = [];
  bool _isLoading = false;
  String _error = '';
  String _displayCurrency = 'USD';
  final Map<String, double> _exchangeRates = {};
  Timer? _refreshTimer;
  SortField _sortField = SortField.custom;
  bool _sortAscending = true;
  DisplayTerm _selectedTerm = DisplayTerm.day;
  Set<String> _selectedTypeFilters = {'All'};
  bool _showAllTime = false;

  PortfolioProvider(this._storage, this._yahoo) {
    _init();
  }

  Future<void> _init() async {
    _isLoading = true;
    notifyListeners();

    _displayCurrency = await _storage.getDisplayCurrency();
    final savedSortField = await _storage.getSortField();
    _sortField = SortField.values.firstWhere(
      (f) => f.name == savedSortField,
      orElse: () => SortField.custom,
    );
    _sortAscending = await _storage.getSortAscending();
    
    final savedTerm = await _storage.getSelectedTerm();
    _selectedTerm = DisplayTerm.values.firstWhere(
      (t) => t.name == savedTerm,
      orElse: () => DisplayTerm.day,
    );
    _selectedTypeFilters = await _storage.getSelectedTypeFilters();
    _showAllTime = await _storage.getShowAllTime();

    _stocks = await _storage.loadStocks();

    if (_stocks.isEmpty) {
      _stocks = [
        Stock(symbol: 'AAPL', isWatchlisted: true),
        Stock(symbol: 'GOOGL', isWatchlisted: true),
        Stock(symbol: 'MSFT', isWatchlisted: true),
      ];
      await _storage.saveStocks(_stocks);
    }

    await _fetchExchangeRates();
    _yahoo.authenticate().then((_) => refreshPrices());

    _refreshTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => refreshPrices(),
    );

    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // Getters
  List<Stock> get stocks => _stocks;
  SortField get sortField => _sortField;
  bool get sortAscending => _sortAscending;
  bool get isLoading => _isLoading;
  String get error => _error;
  String get displayCurrency => _displayCurrency;
  String get displayCurrencySymbol => Stock.currencySymbolFor(_displayCurrency);
  DisplayTerm get selectedTerm => _selectedTerm;
  Set<String> get selectedTypeFilters => _selectedTypeFilters;
  bool get showAllTime => _showAllTime;

  List<Stock> get portfolioStocks =>
      _applySorting(_applyFilter(_stocks.where((s) => !s.isWatchlisted).toList()));

  List<Stock> get watchlistStocks =>
      _applySorting(_applyFilter(_stocks.where((s) => s.isWatchlisted).toList()));

  List<Stock> _applyFilter(List<Stock> list) {
    if (_selectedTypeFilters.contains('All')) return list;
    if (_selectedTypeFilters.isEmpty) return list;
    return list.where((s) => _selectedTypeFilters.contains(s.typeLabel)).toList();
  }

  List<Stock> _applySorting(List<Stock> list) {
    if (_sortField == SortField.custom) return list;
    list.sort((a, b) {
      int cmp = 0;
      switch (_sortField) {
        case SortField.dayGain:
          cmp = (a.change * a.quantity).compareTo(b.change * b.quantity);
          break;
        case SortField.totalGain:
          cmp = a.totalGainLoss.compareTo(b.totalGainLoss);
          break;
        case SortField.totalValue:
          cmp = convertToDisplay(
            a.totalValue,
            a.currency,
          ).compareTo(convertToDisplay(b.totalValue, b.currency));
          break;
        case SortField.percentChange:
          cmp = a.percentChange.compareTo(b.percentChange);
          break;
        case SortField.name:
          cmp = a.symbol.compareTo(b.symbol);
          break;
        case SortField.price:
          cmp = convertToDisplay(
            a.currentPrice,
            a.currency,
          ).compareTo(convertToDisplay(b.currentPrice, b.currency));
          break;
        case SortField.custom:
          break;
      }
      return _sortAscending ? cmp : -cmp;
    });
    return list;
  }

  double convertToDisplay(double amount, String sourceCurrency) {
    if (sourceCurrency == _displayCurrency) return amount;
    final rateKey = '${sourceCurrency}_$_displayCurrency';
    final rate = _exchangeRates[rateKey];
    if (rate != null) return amount * rate;
    return amount; // Fallback
  }

  Future<void> refreshPrices({List<String>? symbols}) async {
    if (_stocks.isEmpty) return;
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      final updated = <Stock>[];
      for (var stock in _stocks) {
        if (symbols != null && !symbols.contains(stock.symbol)) {
          updated.add(stock);
          continue;
        }
        final up = await _yahoo.fetchPrice(stock);
        await _yahoo.fetchExtendedDetails(up);
        updated.add(up);
      }
      _stocks = updated;
      await _storage.saveStocks(_stocks);
    } catch (e) {
      _error = 'Failed to fetch prices: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchExchangeRates() async {
    final sourceCurrencies = _stocks
        .map((s) => s.currency)
        .where((c) => c != _displayCurrency)
        .toSet();
    if (sourceCurrencies.isEmpty) return;

    final newRates = await _yahoo.fetchExchangeRates(
      _displayCurrency,
      sourceCurrencies,
    );
    _exchangeRates.addAll(newRates);
  }

  Future<void> setDisplayCurrency(String currency) async {
    _displayCurrency = currency;
    await _fetchExchangeRates();
    notifyListeners();
  }

  // --- Portfolio Actions ---

  Future<void> addSymbol(
    String symbol, {
    double quantity = 0,
    double purchasePrice = 0,
    bool watchlist = false,
  }) async {
    final upper = symbol.toUpperCase().trim();
    if (upper.isEmpty) return;

    final existingIdx = _stocks.indexWhere((s) => s.symbol == upper);
    if (existingIdx >= 0) {
      final existing = _stocks[existingIdx];
      if (quantity > 0) {
        final newQty = existing.quantity + quantity;
        existing.purchasePrice = newQty > 0
            ? ((existing.quantity * existing.purchasePrice) +
                      (quantity * purchasePrice)) /
                  newQty
            : 0.0;
        existing.quantity = newQty;
        // If we are adding quantity, it should no longer be just a watchlist item
        existing.isWatchlisted = false;
      }
      if (watchlist) existing.isWatchlisted = true;
      await _storage.saveStocks(_stocks);
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      Stock newStock = Stock(
        symbol: upper,
        quantity: quantity,
        purchasePrice: purchasePrice,
        isWatchlisted: (watchlist || quantity == 0) && quantity == 0,
        portfolioId: 'default',
      );
      newStock = await _yahoo.fetchPrice(newStock);

      if (newStock.symbol != 'UNKNOWN') {
        _stocks.add(newStock);
        await _yahoo.fetchExtendedDetails(newStock);
        await _storage.saveStocks(_stocks);
        await _fetchExchangeRates();
      } else {
        _error = 'Invalid ticker symbol';
      }
    } catch (e) {
      _error = 'Error adding symbol: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> editStock(
    String symbol, {
    required double quantity,
    required double purchasePrice,
  }) async {
    final idx = _stocks.indexWhere((s) => s.symbol == symbol);
    if (idx >= 0) {
      _stocks[idx].quantity = quantity;
      _stocks[idx].purchasePrice = purchasePrice;
      await _storage.saveStocks(_stocks);
      notifyListeners();
    }
  }

  Future<void> toggleWatchlist(String symbol) async {
    final idx = _stocks.indexWhere((s) => s.symbol == symbol);
    if (idx >= 0) {
      _stocks[idx].isWatchlisted = !_stocks[idx].isWatchlisted;
      await _storage.saveStocks(_stocks);
      notifyListeners();
    }
  }

  Future<void> removeSymbol(String symbol) async {
    _stocks.removeWhere((s) => s.symbol == symbol);
    await _storage.deleteStock(symbol);
    notifyListeners();
  }

  void reorder(int oldIndex, int newIndex, {required bool isPortfolio}) {
    final list = isPortfolio ? portfolioStocks : watchlistStocks;
    if (oldIndex < newIndex) newIndex -= 1;
    final moving = list[oldIndex];
    final target = list[newIndex];

    final rOld = _stocks.indexOf(moving);
    final rNew = _stocks.indexOf(target);

    final stock = _stocks.removeAt(rOld);
    _stocks.insert(rNew, stock);
    _storage.saveStocks(_stocks);
    notifyListeners();
  }

  Future<bool> authenticateYahoo() async {
    final success = await _yahoo.authenticate();
    if (success) {
      for (var s in _stocks) {
        await _yahoo.fetchExtendedDetails(s);
      }
      await _storage.saveStocks(_stocks);
    }
    notifyListeners();
    return success;
  }

  // Statistics (Getters)
  double get totalPortfolioValue => portfolioStocks.fold(
    0,
    (sum, s) => sum + convertToDisplay(s.totalValue, s.currency),
  );
  double get totalPortfolioCost => portfolioStocks.fold(
    0,
    (sum, s) => sum + convertToDisplay(s.totalCost, s.currency),
  );
  double get totalPortfolioGainLoss => totalPortfolioValue - totalPortfolioCost;
  double get totalPortfolioGainLossPct => totalPortfolioCost > 0
      ? (totalPortfolioGainLoss / totalPortfolioCost * 100)
      : 0.0;

  double get totalPortfolioDayChange => portfolioStocks.fold(
    0.0,
    (sum, s) => sum + convertToDisplay(s.change * s.quantity, s.currency),
  );

  double get totalPortfolioDayChangePct {
    final prevValue = totalPortfolioValue - totalPortfolioDayChange;
    return prevValue > 0 ? (totalPortfolioDayChange / prevValue * 100) : 0.0;
  }

  double get selectedTermReturn => portfolioStocks.fold(
    0.0,
    (sum, s) => sum + convertToDisplay(s.getReturnValue(_selectedTerm), s.currency),
  );

  double get selectedTermReturnPct {
    final termReturn = selectedTermReturn;
    final baseValue = totalPortfolioValue - termReturn;
    return baseValue > 0 ? (termReturn / baseValue * 100) : 0.0;
  }

  Map<String, double> get allocationBySector {
    final map = <String, double>{};
    for (var s in portfolioStocks) {
      final val = convertToDisplay(s.totalValue, s.currency);
      if (s.instrumentType == 'ETF' && s.etfSectorWeights.isNotEmpty) {
        for (var entry in s.etfSectorWeights.entries) {
          final sectorName = Stock.prettySectorName(entry.key);
          final weight = entry.value;
          final weightedVal = val * weight;
          map[sectorName] = (map[sectorName] ?? 0) + weightedVal;
        }
      } else {
        final sector = s.sectorLabel;
        map[sector] = (map[sector] ?? 0) + val;
      }
    }
    return map;
  }

  // ... other allocation methods (omitted for brevity in this scratch tool call, but I will include them in the real write)
  Map<String, double> get allocationByType {
    final map = <String, double>{};
    for (final s in portfolioStocks) {
      final val = convertToDisplay(s.totalValue, s.currency);
      map[s.typeLabel] = (map[s.typeLabel] ?? 0) + val;
    }
    return map;
  }

  Map<String, double> get allocationByExchange {
    final map = <String, double>{};
    for (final s in portfolioStocks) {
      final val = convertToDisplay(s.totalValue, s.currency);
      final exch = s.exchangeLabel;
      map[exch] = (map[exch] ?? 0) + val;
    }
    return map;
  }

  Map<String, double> get allocationByCountry {
    final map = <String, double>{};
    for (final s in portfolioStocks) {
      final val = convertToDisplay(s.totalValue, s.currency);
      map[s.exchangeCountry] = (map[s.exchangeCountry] ?? 0) + val;
    }
    return map;
  }

  Map<String, double> get allocationByCurrency {
    final map = <String, double>{};
    for (final s in portfolioStocks) {
      final val = convertToDisplay(s.totalValue, s.currency);
      map[s.currency] = (map[s.currency] ?? 0) + val;
    }
    return map;
  }

  double get weightedBeta {
    final total = totalPortfolioValue;
    if (total <= 0) return 0.0;
    double weightedSum = 0;
    for (final s in portfolioStocks) {
      if (s.beta > 0) {
        final val = convertToDisplay(s.totalValue, s.currency);
        weightedSum += s.beta * val;
      }
    }
    return weightedSum / total;
  }

  double get weightedPE {
    final total = totalPortfolioValue;
    if (total <= 0) return 0.0;
    double weightedSum = 0;
    double weightedWeight = 0;
    for (final s in portfolioStocks) {
      if (s.peRatio > 0) {
        final val = convertToDisplay(s.totalValue, s.currency);
        weightedSum += s.peRatio * val;
        weightedWeight += val;
      }
    }
    return weightedWeight > 0 ? weightedSum / weightedWeight : 0.0;
  }

  double get weightedYield {
    final total = totalPortfolioValue;
    if (total <= 0) return 0.0;
    double weightedSum = 0;
    for (final s in portfolioStocks) {
      if (s.yieldPct > 0) {
        final val = convertToDisplay(s.totalValue, s.currency);
        weightedSum += s.yieldPct * val;
      }
    }
    return weightedSum / total;
  }

  int get holdingsCount => portfolioStocks.length;

  Future<List<TickerSuggestion>> searchTickers(String query) async {
    return _yahoo.searchTickers(query);
  }

  void clearError() {
    _error = '';
    notifyListeners();
  }

  void setSortField(SortField field) {
    if (_sortField == field && field != SortField.custom) {
      _sortAscending = !_sortAscending;
    } else {
      _sortField = field;
      _sortAscending = field == SortField.name;
    }
    _storage.saveSortField(_sortField.name);
    _storage.saveSortAscending(_sortAscending);
    notifyListeners();
  }

  void setSelectedTerm(DisplayTerm term) {
    _selectedTerm = term;
    _storage.saveSelectedTerm(term.name);
    notifyListeners();
  }

  void toggleTypeFilter(String filter) {
    if (filter == 'All') {
      _selectedTypeFilters = {'All'};
    } else {
      _selectedTypeFilters.remove('All');
      if (_selectedTypeFilters.contains(filter)) {
        _selectedTypeFilters.remove(filter);
        if (_selectedTypeFilters.isEmpty) {
          _selectedTypeFilters.add('All');
        }
      } else {
        _selectedTypeFilters.add(filter);
      }
    }
    _storage.saveSelectedTypeFilters(_selectedTypeFilters);
    notifyListeners();
  }

  void toggleShowAllTime() {
    _showAllTime = !_showAllTime;
    _storage.saveShowAllTime(_showAllTime);
    notifyListeners();
  }

  List<String> get availableTypes {
    final types = _stocks.map((s) => s.typeLabel).toSet().toList();
    types.sort();
    return ['All', ...types];
  }
}
