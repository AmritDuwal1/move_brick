import 'package:shared_preferences/shared_preferences.dart';

class CoinStore {
  CoinStore._();

  static const String _key = 'coins';
  static const int defaultCoins = 3;
  static const int rewardFromAd = 3;
  static const int continueCost = 1;

  static int _coins = defaultCoins;
  static bool _loaded = false;

  static int get coins => _coins;

  static Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _coins = prefs.getInt(_key) ?? defaultCoins;
    _loaded = true;
  }

  static Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, _coins);
  }

  static Future<void> add(int amount) async {
    if (amount <= 0) return;
    _coins += amount;
    await _save();
  }

  static Future<bool> spend(int amount) async {
    if (amount <= 0 || _coins < amount) return false;
    _coins -= amount;
    await _save();
    return true;
  }

  static Future<void> reset() async {
    _coins = defaultCoins;
    await _save();
  }
}
