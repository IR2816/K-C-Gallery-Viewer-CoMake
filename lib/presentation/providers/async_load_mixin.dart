import 'package:flutter/foundation.dart';

/// Mixin to wrap the common "set loading → try/catch → finally → notify" pattern.
mixin AsyncLoadMixin on ChangeNotifier {
  Future<T> runAsync<T>(
    Future<T> Function() fn, {
    required void Function(bool isLoading) setLoading,
    void Function(Object error, StackTrace stackTrace)? onError,
    bool notifyOnStart = true,
    bool notifyOnComplete = true,
  }) async {
    setLoading(true);
    if (notifyOnStart) notifyListeners();

    try {
      return await fn();
    } catch (e, st) {
      onError?.call(e, st);
      rethrow;
    } finally {
      setLoading(false);
      if (notifyOnComplete) notifyListeners();
    }
  }
}
