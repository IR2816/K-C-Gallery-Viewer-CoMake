import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DownloadManager with ChangeNotifier {
  static const String _downloadsKey = 'downloaded_files';
  SharedPreferences? _prefs;
  List<DownloadedFile> _downloads = [];

  List<DownloadedFile> get downloads => _downloads;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadDownloads();
  }

  Future<void> _loadDownloads() async {
    final downloadsJson = _prefs?.getStringList(_downloadsKey) ?? [];
    _downloads = downloadsJson
        .map((json) {
          try {
            return DownloadedFile.fromJson(json as Map<String, dynamic>);
          } catch (e) {
            debugPrint('Error parsing download: $e');
            return null;
          }
        })
        .whereType<DownloadedFile>()
        .toList();
    notifyListeners();
  }

  Future<void> _saveDownloads() async {
    final downloadsJson = _downloads
        .map((download) => download.toJson())
        .toList();
    await _prefs?.setString(_downloadsKey, jsonEncode(downloadsJson));
  }

  Future<bool> addToDownloads(DownloadedFile download) async {
    // Check if already exists
    if (_downloads.any((d) => d.id == download.id)) {
      return false;
    }

    _downloads.insert(0, download);
    await _saveDownloads();
    notifyListeners();
    return true;
  }

  Future<bool> removeFromDownloads(String fileId) async {
    final initialLength = _downloads.length;
    _downloads.removeWhere((download) => download.id == fileId);

    if (_downloads.length < initialLength) {
      await _saveDownloads();
      notifyListeners();
      return true;
    }
    return false;
  }

  bool isDownloaded(String fileId) {
    return _downloads.any((download) => download.id == fileId);
  }

  DownloadedFile? getDownload(String fileId) {
    try {
      return _downloads.firstWhere((download) => download.id == fileId);
    } catch (e) {
      return null;
    }
  }

  Future<void> clearAllDownloads() async {
    _downloads.clear();
    await _saveDownloads();
    notifyListeners();
  }

  int get totalDownloads => _downloads.length;

  double getTotalDownloadSize() {
    return _downloads.fold<double>(
      0.0,
      (sum, download) => sum + download.fileSize,
    );
  }

  String getFormattedTotalSize() {
    final bytes = getTotalDownloadSize();
    if (bytes < 1024) {
      return '${bytes.toStringAsFixed(1)} B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }
}

class DownloadedFile {
  final String id;
  final String name;
  final String postId;
  final String creatorName;
  final String service;
  final String filePath;
  final int downloadDate;
  final double fileSize;

  DownloadedFile({
    required this.id,
    required this.name,
    required this.postId,
    required this.creatorName,
    required this.service,
    required this.filePath,
    required this.downloadDate,
    required this.fileSize,
  });

  factory DownloadedFile.fromJson(Map<String, dynamic> json) {
    return DownloadedFile(
      id: json['id'] as String,
      name: json['name'] as String,
      postId: json['postId'] as String,
      creatorName: json['creatorName'] as String,
      service: json['service'] as String,
      filePath: json['filePath'] as String,
      downloadDate: json['downloadDate'] as int,
      fileSize: (json['fileSize'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'postId': postId,
      'creatorName': creatorName,
      'service': service,
      'filePath': filePath,
      'downloadDate': downloadDate,
      'fileSize': fileSize,
    };
  }
}
