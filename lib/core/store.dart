import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Tiny synchronous key/value store on top of SharedPreferences.
/// Everything stays on the device; the app never needs a network connection.
class Store {
  static late SharedPreferences _p;

  static Future<void> init() async => _p = await SharedPreferences.getInstance();

  static String str(String k, [String d = '']) => _p.getString(k) ?? d;
  static int integer(String k, [int d = 0]) => _p.getInt(k) ?? d;
  static bool flag(String k, [bool d = false]) => _p.getBool(k) ?? d;
  static List<String> list(String k) => List<String>.from(_p.getStringList(k) ?? const []);

  static void setStr(String k, String v) => _p.setString(k, v);
  static void setInt(String k, int v) => _p.setInt(k, v);
  static void setFlag(String k, bool v) => _p.setBool(k, v);
  static void setList(String k, List<String> v) => _p.setStringList(k, v);

  static dynamic json(String k) {
    final s = _p.getString(k);
    if (s == null) return null;
    try {
      return jsonDecode(s);
    } catch (_) {
      return null;
    }
  }

  static void setJson(String k, Object v) => _p.setString(k, jsonEncode(v));
}

/// Personal best per game.
class Scores {
  static int? best(String id) => Store._p.getInt('best.$id');

  /// Records [score]; returns true when it is a new personal best.
  static bool submit(String id, int score, {bool lowerIsBetter = false}) {
    final old = best(id);
    if (old == null || (lowerIsBetter ? score < old : score > old)) {
      Store.setInt('best.$id', score);
      return true;
    }
    return false;
  }
}

/// Consecutive-days-used counter shown on the home screen.
class Streak {
  static int get days => Store.integer('streak.n');
  static int get best => Store.integer('streak.best');

  static String _key(DateTime d) => '${d.year}-${d.month}-${d.day}';

  /// Call once per app launch. Returns true if this is the first open of a
  /// day that extends a streak (so the UI can celebrate).
  static bool touch([DateTime? now]) {
    final n = now ?? DateTime.now();
    final today = _key(n);
    final last = Store.str('streak.day');
    if (last == today) return false;
    final yesterday = _key(DateTime(n.year, n.month, n.day - 1));
    final count = last == yesterday ? days + 1 : 1;
    Store.setStr('streak.day', today);
    Store.setInt('streak.n', count);
    if (count > best) Store.setInt('streak.best', count);
    return count > 1;
  }
}
