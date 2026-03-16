import 'package:flutter/material.dart';
import 'services/storage_service.dart';

class SettingsProvider with ChangeNotifier {
  final StorageService _storage;

  bool? _isDarkMode;
  String _displayCurrency = 'USD';

  SettingsProvider(this._storage) {
    _loadSettings();
  }

  bool? get isDarkMode => _isDarkMode;
  String get displayCurrency => _displayCurrency;

  Future<void> _loadSettings() async {
    _isDarkMode = await _storage.getDarkMode();
    _displayCurrency = await _storage.getDisplayCurrency();
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    if (_isDarkMode == null) {
      _isDarkMode = true;
    } else if (_isDarkMode == true) {
      _isDarkMode = false;
    } else {
      _isDarkMode = null;
    }
    await _storage.saveDarkMode(_isDarkMode);
    notifyListeners();
  }

  Future<void> setDisplayCurrency(String currency) async {
    _displayCurrency = currency;
    await _storage.saveDisplayCurrency(currency);
    notifyListeners();
  }
}
