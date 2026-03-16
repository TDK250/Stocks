import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models.dart';

class StorageService {
  static Database? _db;
  static const String _dbName = 'stocks.db';
  static const int _version = 2;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), _dbName);
    return openDatabase(
      path,
      version: _version,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE stocks (
            symbol TEXT PRIMARY KEY,
            companyName TEXT,
            currency TEXT,
            exchangeName TEXT,
            instrumentType TEXT,
            sector TEXT,
            industry TEXT,
            currentPrice REAL,
            change REAL,
            percentChange REAL,
            dayHigh REAL,
            dayLow REAL,
            fiftyTwoWeekHigh REAL,
            fiftyTwoWeekLow REAL,
            volume INTEGER,
            marketCap INTEGER,
            quantity REAL,
            purchasePrice REAL,
            isWatchlisted INTEGER,
            beta REAL,
            open REAL,
            previousClose REAL,
            peRatio REAL,
            yieldPct REAL,
            ytdReturn REAL,
            expenseRatio REAL,
            netAssets REAL,
            nav REAL,
            portfolioId TEXT,
            bid REAL,
            ask REAL,
            bidSize INTEGER,
            askSize INTEGER,
            averageVolume INTEGER,
            sparklineData TEXT,
            etfSectorWeights TEXT,
            etfTopHoldings TEXT,
            etfGeographicWeights TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE stocks ADD COLUMN marketCap INTEGER DEFAULT 0',
          );
          await db.execute('ALTER TABLE stocks ADD COLUMN sparklineData TEXT');
        }
      },
    );
  }

  Future<void> saveStocks(List<Stock> stocks) async {
    final db = await database;
    final batch = db.batch();
    for (var stock in stocks) {
      final json = stock.toJson();
      // Handle the complex map fields by converting them to JSON strings
      if (json.containsKey('etfSectorWeights')) {
        json['etfSectorWeights'] = jsonEncode(json['etfSectorWeights']);
      }
      if (json.containsKey('etfTopHoldings')) {
        json['etfTopHoldings'] = jsonEncode(json['etfTopHoldings']);
      }
      if (json.containsKey('etfGeographicWeights')) {
        json['etfGeographicWeights'] = jsonEncode(json['etfGeographicWeights']);
      }
      if (json.containsKey('sparklineData')) {
        json['sparklineData'] = jsonEncode(json['sparklineData']);
      }

      // Convert boolean to integer for SQLite
      if (json.containsKey('isWatchlisted')) {
        json['isWatchlisted'] = json['isWatchlisted'] == true ? 1 : 0;
      }

      batch.insert(
        'stocks',
        json,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Stock>> loadStocks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('stocks');

    return maps.map((map) {
      final mutableMap = Map<String, dynamic>.from(map);
      // Convert JSON strings back to maps
      if (mutableMap['etfSectorWeights'] != null) {
        mutableMap['etfSectorWeights'] = jsonDecode(
          mutableMap['etfSectorWeights'],
        );
      }
      if (mutableMap['etfTopHoldings'] != null) {
        mutableMap['etfTopHoldings'] = jsonDecode(mutableMap['etfTopHoldings']);
      }
      if (mutableMap['etfGeographicWeights'] != null) {
        mutableMap['etfGeographicWeights'] = jsonDecode(
          mutableMap['etfGeographicWeights'],
        );
      }
      if (mutableMap['sparklineData'] != null) {
        mutableMap['sparklineData'] = jsonDecode(mutableMap['sparklineData']);
      }
      // SQLite stores booleans as 0 or 1
      mutableMap['isWatchlisted'] = mutableMap['isWatchlisted'] == 1;

      return Stock.fromStorageJson(mutableMap);
    }).toList();
  }

  Future<void> deleteStock(String symbol) async {
    final db = await database;
    await db.delete('stocks', where: 'symbol = ?', whereArgs: [symbol]);
  }

  // --- Legacy Support & Settings ---

  Future<bool?> getDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey('theme_is_dark')) {
      return prefs.getBool('theme_is_dark');
    }
    return null;
  }

  Future<void> saveDarkMode(bool? isDark) async {
    final prefs = await SharedPreferences.getInstance();
    if (isDark == null) {
      await prefs.remove('theme_is_dark');
    } else {
      await prefs.setBool('theme_is_dark', isDark);
    }
  }

  Future<String> getDisplayCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('display_currency') ?? 'USD';
  }

  Future<void> saveDisplayCurrency(String currency) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('display_currency', currency);
  }

  Future<List<String>> getAvailablePortfolios() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('available_portfolios') ?? ['default'];
  }

  Future<void> saveAvailablePortfolios(List<String> portfolios) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('available_portfolios', portfolios);
  }

  Future<String> getCurrentPortfolioId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('current_portfolio_id') ?? 'default';
  }

  Future<void> saveCurrentPortfolioId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_portfolio_id', id);
  }

  Future<bool> getAggregateMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('aggregate_mode') ?? true;
  }

  Future<void> saveAggregateMode(bool mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('aggregate_mode', mode);
  }

  Future<String> getSortField() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('sort_field') ?? 'custom';
  }

  Future<void> saveSortField(String field) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sort_field', field);
  }

  Future<bool> getSortAscending() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('sort_ascending') ?? true;
  }

  Future<void> saveSortAscending(bool ascending) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sort_ascending', ascending);
  }

  Future<String> getSelectedTerm() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('selected_term') ?? 'day';
  }

  Future<void> saveSelectedTerm(String term) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_term', term);
  }

  Future<Set<String>> getSelectedTypeFilters() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('selected_type_filters');
    if (json != null) {
      try {
        final list = jsonDecode(json) as List;
        return list.map((e) => e.toString()).toSet();
      } catch (_) {
        return {'All'};
      }
    }
    return {'All'};
  }

  Future<void> saveSelectedTypeFilters(Set<String> filters) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_type_filters', jsonEncode(filters.toList()));
  }

  Future<bool> getShowAllTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('show_all_time') ?? false;
  }

  Future<void> saveShowAllTime(bool show) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_all_time', show);
  }
}
