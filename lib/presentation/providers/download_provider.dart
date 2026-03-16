import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

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
  });

  DownloadItem copyWith({
    String? name,
    int? totalBytes,
    int? downloadedBytes,
    DownloadStatus? status,
    DateTime? startTime,
    String? errorMessage,
    String? savePath,
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
    );
  }

  double get progress => totalBytes > 0 ? downloadedBytes / totalBytes : 0.0;
}

enum DownloadStatus { pending, downloading, completed, failed, cancelled }

class DownloadProvider extends ChangeNotifier {
  final List<DownloadItem> _downloads = [];
  final Map<String, CancelToken> _cancelTokens = {};

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
  }) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final download = DownloadItem(
      id: id,
      name: name,
      url: url,
      totalBytes: totalBytes,
      startTime: DateTime.now(),
      savePath: savePath,
    );

    _downloads.add(download);
    notifyListeners();

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

      // Browser-like headers
      final browserHeaders = {
        "User-Agent":
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Referer": "https://coomer.st/",
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

      // Download completed
      _updateDownloadStatus(download.id, DownloadStatus.completed);
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

  /// Cancel download
  void cancelDownload(String downloadId) {
    final cancelToken = _cancelTokens[downloadId];
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel();
    }
  }

  /// Remove download from list
  void removeDownload(String downloadId) {
    _downloads.removeWhere((d) => d.id == downloadId);
    notifyListeners();
  }

  /// Clear completed downloads
  void clearCompleted() {
    _downloads.removeWhere((d) => d.status == DownloadStatus.completed);
    notifyListeners();
  }

  /// Update download status
  void _updateDownloadStatus(String downloadId, DownloadStatus status) {
    final index = _downloads.indexWhere((d) => d.id == downloadId);
    if (index != -1) {
      _downloads[index] = _downloads[index].copyWith(status: status);
      notifyListeners();
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
      notifyListeners();
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
      notifyListeners();
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
