import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import 'download_manager.dart';

class DownloadItem {
  final String id;
  final String name;
  final String url;
  final int totalBytes;
  final int downloadedBytes;
  final DownloadStatus status;
  final DateTime startTime;
  final String? errorMessage;
  final String? savePath;
  final String? referer;
  final String? postId;
  final String? creatorName;
  final String? service;

  DownloadItem({
    required this.id,
    required this.name,
    required this.url,
    required this.totalBytes,
    this.downloadedBytes = 0,
    this.status = DownloadStatus.pending,
    required this.startTime,
    this.errorMessage,
    this.savePath,
    this.referer,
    this.postId,
    this.creatorName,
    this.service,
  });

  DownloadItem copyWith({
    String? name,
    int? totalBytes,
    int? downloadedBytes,
    DownloadStatus? status,
    DateTime? startTime,
    String? errorMessage,
    String? savePath,
    String? referer,
    String? postId,
    String? creatorName,
    String? service,
  }) {
    return DownloadItem(
      id: id,
      name: name ?? this.name,
      url: url,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      status: status ?? this.status,
      startTime: startTime ?? this.startTime,
      errorMessage: errorMessage ?? this.errorMessage,
      savePath: savePath ?? this.savePath,
      referer: referer ?? this.referer,
      postId: postId ?? this.postId,
      creatorName: creatorName ?? this.creatorName,
      service: service ?? this.service,
    );
  }

  double get progress => totalBytes > 0 ? downloadedBytes / totalBytes : 0.0;

  DownloadedFile toDownloadedFile({double? fileSizeOverride}) {
    final size = fileSizeOverride ?? downloadedBytes.toDouble();
    return DownloadedFile(
      id: id,
      name: name,
      postId: postId ?? id,
      creatorName: creatorName ?? '',
      service: service ?? '',
      filePath: savePath ?? '',
      downloadDate: startTime.millisecondsSinceEpoch,
      fileSize: size,
    );
  }
}

enum DownloadStatus { pending, downloading, completed, failed, cancelled }

class DownloadProvider extends ChangeNotifier {
  // Kemono is used as the default because it is the more common source; callers
  // should always pass an explicit referer when downloading Coomer content.
  static const String _defaultReferer = 'https://kemono.cr/';

  static int _idCounter = 0;

  final List<DownloadItem> _downloads = [];
  final Map<String, CancelToken> _cancelTokens = {};
  bool _disposed = false;
  final DownloadManager _downloadManager;

  DownloadProvider({required DownloadManager downloadManager})
      : _downloadManager = downloadManager;

  List<DownloadItem> get downloads => List.unmodifiable(_downloads);

  List<DownloadItem> get activeDownloads => _downloads
      .where(
        (d) =>
            d.status == DownloadStatus.downloading ||
            d.status == DownloadStatus.pending,
      )
      .toList();

  List<DownloadItem> get completedDownloads =>
      _downloads.where((d) => d.status == DownloadStatus.completed).toList();

  /// Add new download to queue
  String addDownload({
    required String name,
    required String url,
    required String savePath,
    int totalBytes = 0,
    String? referer,
    String? postId,
    String? creatorName,
    String? service,
  }) {
    final id = '${DateTime.now().millisecondsSinceEpoch}_${++_idCounter}';
    final download = DownloadItem(
      id: id,
      name: name,
      url: url,
      totalBytes: totalBytes,
      startTime: DateTime.now(),
      savePath: savePath,
      referer: referer,
      postId: postId,
      creatorName: creatorName,
      service: service,
    );

    _downloads.add(download);
    if (!_disposed) notifyListeners();

    // Start download
    _startDownload(download);

    return id;
  }

  /// Start download with progress tracking
  Future<void> _startDownload(DownloadItem download) async {
    final cancelToken = CancelToken();
    _cancelTokens[download.id] = cancelToken;

    // Update status to downloading
    _updateDownloadStatus(download.id, DownloadStatus.downloading);

    try {
      final dio = Dio();

      // Browser-like headers; use the referer provided at queue time so that
      // both Kemono (kemono.cr) and Coomer (coomer.st) CDN anti-hotlink checks
      // pass correctly.
      final effectiveReferer =
          download.referer ?? _defaultReferer;
      final browserHeaders = {
        "User-Agent":
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Referer": effectiveReferer,
        "Origin": Uri.parse(effectiveReferer).origin,
        "Accept": "*/*",
        "Connection": "keep-alive",
        "Accept-Encoding": "gzip, deflate, br",
        "Accept-Language": "en-US,en;q=0.9",
        "Cache-Control": "no-cache",
        "Pragma": "no-cache",
      };

      await dio.download(
        download.url,
        download.savePath!,
        cancelToken: cancelToken,
        options: Options(
          headers: browserHeaders,
          receiveTimeout: const Duration(minutes: 5),
        ),
        onReceiveProgress: (received, total) {
          // Update progress
          _updateDownloadProgress(download.id, received, total);
        },
      );

      final fileSize = download.savePath != null
          ? await File(download.savePath!).length().catchError((_) => download.totalBytes)
          : download.totalBytes;
      _updateDownloadProgress(download.id, fileSize, fileSize);
      _updateDownloadStatus(download.id, DownloadStatus.completed);
      await _persistDownload(download, fileSize);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        _updateDownloadStatus(download.id, DownloadStatus.cancelled);
      } else {
        _updateDownloadError(download.id, e.message ?? 'Download failed');
      }
    } catch (e) {
      _updateDownloadError(download.id, e.toString());
    } finally {
      _cancelTokens.remove(download.id);
    }
  }

  Future<void> _persistDownload(DownloadItem download, int? finalBytes) async {
    if (download.savePath == null) return;
    final record = download.toDownloadedFile(
      fileSizeOverride: (finalBytes ?? download.totalBytes).toDouble(),
    );
    await _downloadManager.addToDownloads(record);
  }

  /// Cancel download
  void cancelDownload(String downloadId) {
    final cancelToken = _cancelTokens[downloadId];
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel();
    }
  }

  /// Retry a failed or cancelled download
  void retryDownload(String downloadId) {
    final index = _downloads.indexWhere((d) => d.id == downloadId);
    if (index == -1) return;

    final download = _downloads[index];
    if (download.status != DownloadStatus.failed &&
        download.status != DownloadStatus.cancelled) {
      return;
    }

    final retried = DownloadItem(
      id: download.id,
      name: download.name,
      url: download.url,
      totalBytes: download.totalBytes,
      downloadedBytes: 0,
      status: DownloadStatus.pending,
      startTime: DateTime.now(),
      savePath: download.savePath,
      referer: download.referer,
      postId: download.postId,
      creatorName: download.creatorName,
      service: download.service,
    );
    _downloads[index] = retried;
    if (!_disposed) notifyListeners();

    _startDownload(retried);
  }

  /// Remove download from list
  void removeDownload(String downloadId) {
    _downloads.removeWhere((d) => d.id == downloadId);
    if (!_disposed) notifyListeners();
  }

  /// Clear completed downloads
  void clearCompleted() {
    _downloads.removeWhere((d) => d.status == DownloadStatus.completed);
    if (!_disposed) notifyListeners();
  }

  /// Update download status
  void _updateDownloadStatus(String downloadId, DownloadStatus status) {
    final index = _downloads.indexWhere((d) => d.id == downloadId);
    if (index != -1) {
      _downloads[index] = _downloads[index].copyWith(status: status);
      if (!_disposed) notifyListeners();
    }
  }

  /// Update download progress
  void _updateDownloadProgress(
    String downloadId,
    int downloadedBytes,
    int totalBytes,
  ) {
    final index = _downloads.indexWhere((d) => d.id == downloadId);
    if (index != -1) {
      _downloads[index] = _downloads[index].copyWith(
        downloadedBytes: downloadedBytes,
        totalBytes: totalBytes,
      );
      if (!_disposed) notifyListeners();
    }
  }

  /// Update download error
  void _updateDownloadError(String downloadId, String errorMessage) {
    final index = _downloads.indexWhere((d) => d.id == downloadId);
    if (index != -1) {
      _downloads[index] = _downloads[index].copyWith(
        status: DownloadStatus.failed,
        errorMessage: errorMessage,
      );
      if (!_disposed) notifyListeners();
    }
  }

  /// Get download by ID
  DownloadItem? getDownloadById(String downloadId) {
    try {
      return _downloads.firstWhere((d) => d.id == downloadId);
    } catch (e) {
      return null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    // Cancel all active downloads
    for (final cancelToken in _cancelTokens.values) {
      if (!cancelToken.isCancelled) {
        cancelToken.cancel();
      }
    }
    _cancelTokens.clear();
    super.dispose();
  }
}
