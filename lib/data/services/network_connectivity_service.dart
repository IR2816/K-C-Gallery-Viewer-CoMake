import 'dart:async';
import 'dart:collection';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../../utils/logger.dart';

class NetworkConnectivityService {
  NetworkConnectivityService._();
  static const int _maxQueuedRequests = 100;

  static final NetworkConnectivityService instance = NetworkConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  final Queue<Future<void> Function()> _offlineQueue = Queue<Future<void> Function()>();

  StreamSubscription<dynamic>? _subscription;
  bool _initialized = false;
  bool _isOnline = true;

  bool get isOnline => _isOnline;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _isOnline = await hasNetworkConnection();

    _subscription = _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> value) async {
      final online = _parseConnectivityValue(value);
      _isOnline = online;
      AppLogger.debug('Connectivity changed: online=$online', tag: 'Network');
      if (online) {
        await _flushQueue();
      }
    });
  }

  Future<bool> hasNetworkConnection() async {
    final result = await _connectivity.checkConnectivity();
    final online = _parseConnectivityValue(result);
    _isOnline = online;
    return online;
  }

  void enqueueForReconnect(Future<void> Function() request) {
    if (_offlineQueue.length >= _maxQueuedRequests) {
      _offlineQueue.removeFirst();
      AppLogger.warning(
        'Offline queue full; dropping oldest queued request.',
        tag: 'Network',
      );
    }
    _offlineQueue.add(request);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _initialized = false;
    _offlineQueue.clear();
  }

  bool _parseConnectivityValue(dynamic value) {
    if (value is List<ConnectivityResult>) {
      return value.any((entry) => entry != ConnectivityResult.none);
    }
    if (value is ConnectivityResult) {
      return value != ConnectivityResult.none;
    }
    return true;
  }

  Future<void> _flushQueue() async {
    while (_offlineQueue.isNotEmpty) {
      final callback = _offlineQueue.removeFirst();
      try {
        await callback();
      } catch (e) {
        AppLogger.warning('Queued offline request failed after reconnect', tag: 'Network', error: e);
      }
    }
  }
}
