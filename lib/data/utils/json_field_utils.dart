class JsonFieldUtils {
  const JsonFieldUtils._();

  static String string(
    Map<String, dynamic> json,
    String key, {
    String defaultValue = '',
  }) {
    final value = json[key];
    if (value == null) return defaultValue;
    if (value is String) return value;
    return value.toString();
  }

  static int intValue(
    Map<String, dynamic> json,
    String key, {
    int defaultValue = 0,
  }) {
    final value = json[key];
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? defaultValue;
  }

  static double doubleValue(
    Map<String, dynamic> json,
    String key, {
    double defaultValue = 0,
  }) {
    final value = json[key];
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? defaultValue;
  }

  static bool boolValue(
    Map<String, dynamic> json,
    String key, {
    bool defaultValue = false,
  }) {
    final value = json[key];
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final lower = value.toString().toLowerCase();
    if (lower == 'true') return true;
    if (lower == 'false') return false;
    final parsed = int.tryParse(lower);
    return parsed != null ? parsed != 0 : defaultValue;
  }

  static DateTime dateTime(
    Map<String, dynamic> json,
    String key, {
    DateTime? defaultValue,
  }) {
    final value = json[key];
    if (value == null) return defaultValue ?? DateTime.fromMillisecondsSinceEpoch(0);
    if (value is DateTime) return value;
    final parsed = DateTime.tryParse(value.toString());
    return parsed ?? defaultValue ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  static List<T> list<T>(
    Map<String, dynamic> json,
    String key,
    T Function(dynamic) mapper,
  ) {
    final value = json[key];
    if (value is List) {
      return value.map(mapper).toList();
    }
    return <T>[];
  }

  static Map<String, dynamic> map(
    Map<String, dynamic> json,
    String key,
  ) {
    final value = json[key];
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map(
        (k, v) => MapEntry(k.toString(), v),
      );
    }
    return <String, dynamic>{};
  }
}
