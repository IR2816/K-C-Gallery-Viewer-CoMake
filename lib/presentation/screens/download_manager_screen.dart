import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/download_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_state_widgets.dart';

const _kDownloadFolderPath = '/storage/emulated/0/Download/KC Download';
const _kPrefSortKey = 'dm_sort_order';
// Delay after cancelling a download before rescanning the file-system, so
// that any partial file written to disk is included/removed correctly.
const _kDownloadRefreshDelay = Duration(milliseconds: 800);

// ─── Sort options ─────────────────────────────────────────────────────────────

enum _SortOrder { dateNewest, dateOldest, sizeDesc, creatorAZ }

const _kSortLabels = {
  _SortOrder.dateNewest: 'Date ↓',
  _SortOrder.dateOldest: 'Date ↑',
  _SortOrder.sizeDesc: 'Size ↓',
  _SortOrder.creatorAZ: 'Creator A-Z',
};

// ─── File type filter ─────────────────────────────────────────────────────────

enum _TypeFilter { all, images, videos, audio, documents }

const _kTypeLabels = {
  _TypeFilter.all: 'All',
  _TypeFilter.images: 'Images',
  _TypeFilter.videos: 'Videos',
  _TypeFilter.audio: 'Audio',
  _TypeFilter.documents: 'Documents',
};

// ─── Per-file metadata ────────────────────────────────────────────────────────

class _FileInfo {
  final File file;
  final String fileName;
  final String creator; // empty string if flat layout
  final String? postFolder;

  const _FileInfo({
    required this.file,
    required this.fileName,
    required this.creator,
    this.postFolder,
  });

  int get sizeBytes {
    try {
      return file.lengthSync();
    } catch (_) {
      return 0;
    }
  }

  DateTime get lastModified {
    try {
      return file.lastModifiedSync();
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class DownloadManagerScreen extends StatefulWidget {
  const DownloadManagerScreen({super.key});

  @override
  State<DownloadManagerScreen> createState() => _DownloadManagerScreenState();
}

class _DownloadManagerScreenState extends State<DownloadManagerScreen> {
  List<_FileInfo> _allFiles = [];
  bool _isLoading = true;

  // Filters / search / sort
  _SortOrder _sortOrder = _SortOrder.dateNewest;
  _TypeFilter _typeFilter = _TypeFilter.all;
  String? _creatorFilter; // null = show all
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // Select mode
  bool _isSelectMode = false;
  final Set<String> _selectedPaths = {};

  @override
  void initState() {
    super.initState();
    _loadPrefs().then((_) => _loadDownloadedFiles());
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ─── Prefs ────────────────────────────────────────────────────────────────

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPrefSortKey) ?? 'dateNewest';
    setState(() {
      _sortOrder = _SortOrder.values.firstWhere(
        (e) => e.name == raw,
        orElse: () => _SortOrder.dateNewest,
      );
    });
  }

  Future<void> _saveSortPref(_SortOrder order) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefSortKey, order.name);
  }

  // ─── File loading ─────────────────────────────────────────────────────────

  Future<void> _loadDownloadedFiles() async {
    setState(() => _isLoading = true);
    try {
      Directory? dir;
      if (Platform.isAndroid) {
        dir = Directory(_kDownloadFolderPath);
      } else {
        final base = await getDownloadsDirectory();
        if (base != null) dir = Directory('${base.path}/KC Download');
      }

      if (dir == null || !await dir.exists()) {
        setState(() {
          _allFiles = [];
          _isLoading = false;
        });
        return;
      }

      final infos = <_FileInfo>[];

      // Recursive scan to capture organized subdirectory files too
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) {
          final relativePath = entity.path
              .replaceFirst('${dir.path}/', '')
              .replaceFirst('${dir.path}\\', '');
          final parts = relativePath.split(Platform.pathSeparator);
          // Also handle forward-slash separator on all platforms
          final parts2 = relativePath.contains('/')
              ? relativePath.split('/')
              : parts;
          final segments = parts2.length > parts.length ? parts2 : parts;

          String creator = '';
          String? postFolder;
          String fileName = entity.path.split(Platform.pathSeparator).last;
          if (fileName.contains('/')) {
            fileName = fileName.split('/').last;
          }

          if (segments.length >= 3) {
            creator = segments[0];
            postFolder = segments[1];
          } else if (segments.length == 2) {
            postFolder = segments[0];
          }

          infos.add(
            _FileInfo(
              file: entity,
              fileName: fileName,
              creator: creator,
              postFolder: postFolder,
            ),
          );
        }
      }

      setState(() {
        _allFiles = infos;
        _isLoading = false;
        // Reset creator filter if it's no longer valid
        if (_creatorFilter != null &&
            !infos.any((f) => f.creator == _creatorFilter)) {
          _creatorFilter = null;
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading downloads: $e')));
      }
    }
  }

  // ─── Filtering / sorting ──────────────────────────────────────────────────

  List<_FileInfo> get _filteredFiles {
    var list = _allFiles.where((f) {
      // Type filter
      final ext = f.fileName.toLowerCase().split('.').last;
      if (_typeFilter == _TypeFilter.images &&
          ![
            'jpg',
            'jpeg',
            'png',
            'gif',
            'webp',
            'bmp',
            'tiff',
            'svg',
          ].contains(ext)) {
        return false;
      }
      if (_typeFilter == _TypeFilter.videos &&
          !['mp4', 'avi', 'mov', 'mkv', 'webm', 'flv', 'wmv'].contains(ext)) {
        return false;
      }
      if (_typeFilter == _TypeFilter.audio &&
          !['mp3', 'wav', 'ogg', 'flac', 'aac', 'm4a'].contains(ext)) {
        return false;
      }
      if (_typeFilter == _TypeFilter.documents &&
          ![
            'pdf',
            'doc',
            'docx',
            'txt',
            'zip',
            'rar',
            '7z',
            'epub',
          ].contains(ext)) {
        return false;
      }

      // Creator filter
      if (_creatorFilter != null && f.creator != _creatorFilter) return false;

      // Search
      if (_searchQuery.isNotEmpty &&
          !f.fileName.toLowerCase().contains(_searchQuery)) {
        return false;
      }

      return true;
    }).toList();

    // Sort
    switch (_sortOrder) {
      case _SortOrder.dateNewest:
        list.sort((a, b) => b.lastModified.compareTo(a.lastModified));
      case _SortOrder.dateOldest:
        list.sort((a, b) => a.lastModified.compareTo(b.lastModified));
      case _SortOrder.sizeDesc:
        list.sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));
      case _SortOrder.creatorAZ:
        list.sort((a, b) => a.creator.compareTo(b.creator));
    }

    return list;
  }

  List<String> get _allCreators {
    final creators =
        _allFiles
            .map((f) => f.creator)
            .where((c) => c.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return creators;
  }

  // ─── Statistics ───────────────────────────────────────────────────────────

  Map<String, int> _creatorFileCounts() {
    final map = <String, int>{};
    for (final f in _allFiles) {
      final key = f.creator.isEmpty ? '(uncategorized)' : f.creator;
      map[key] = (map[key] ?? 0) + 1;
    }
    return map;
  }

  int get _totalSize => _allFiles.fold(0, (sum, f) => sum + f.sizeBytes);

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: _buildAppBar(),
      floatingActionButton: _isSelectMode && _selectedPaths.isNotEmpty
          ? FloatingActionButton.extended(
              backgroundColor: Colors.red,
              onPressed: _bulkDelete,
              icon: const Icon(Icons.delete, color: Colors.white),
              label: Text(
                'Delete (${_selectedPaths.length})',
                style: const TextStyle(color: Colors.white),
              ),
            )
          : null,
      body: Consumer<DownloadProvider>(
        builder: (context, downloadProvider, child) {
          final activeDownloads = downloadProvider.activeDownloads;

          if (_isLoading) {
            return Column(
              children: [
                if (activeDownloads.isNotEmpty)
                  _buildActiveDownloadsSection(
                    activeDownloads,
                    downloadProvider,
                  ),
                const Expanded(child: AppSkeletonList()),
              ],
            );
          }

          return Column(
            children: [
              if (activeDownloads.isNotEmpty)
                _buildActiveDownloadsSection(activeDownloads, downloadProvider),
              if (_allFiles.isNotEmpty) ...[
                _buildStatsCard(),
                _buildSearchBar(),
                _buildSortAndFilterRow(),
              ],
              Expanded(
                child: _allFiles.isEmpty
                    ? _buildEmptyState()
                    : _buildFileList(),
              ),
            ],
          );
        },
      ),
    );
  }

  AppBar _buildAppBar() {
    if (_isSelectMode) {
      return AppBar(
        backgroundColor: Colors.green.withValues(alpha: 0.9),
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => setState(() {
            _isSelectMode = false;
            _selectedPaths.clear();
          }),
        ),
        title: Text(
          _selectedPaths.isEmpty
              ? 'Select files'
              : '${_selectedPaths.length} selected',
        ),
        actions: [
          TextButton(
            onPressed: _selectAll,
            child: const Text(
              'Select All',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      );
    }

    return AppBar(
      title: const Text('Download Manager'),
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.green.withValues(alpha: 0.8),
              Colors.green.withValues(alpha: 0.6),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      iconTheme: const IconThemeData(color: Colors.white),
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      actions: [
        IconButton(
          onPressed: _loadDownloadedFiles,
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
        ),
        if (_allFiles.isNotEmpty)
          IconButton(
            onPressed: () => setState(() {
              _isSelectMode = true;
              _selectedPaths.clear();
            }),
            icon: const Icon(Icons.checklist_rounded),
            tooltip: 'Select',
          ),
        if (_allFiles.isNotEmpty)
          IconButton(
            onPressed: _confirmClearAll,
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Clear all',
          ),
      ],
    );
  }

  // ─── Stats card ───────────────────────────────────────────────────────────

  Widget _buildStatsCard() {
    final counts = _creatorFileCounts();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          _statChip(
            Icons.insert_drive_file_rounded,
            '${_allFiles.length} files',
            Colors.green,
          ),
          const SizedBox(width: 12),
          _statChip(
            Icons.storage_rounded,
            _formatFileSize(_totalSize),
            Colors.blue,
          ),
          const SizedBox(width: 12),
          _statChip(
            Icons.person_rounded,
            '${counts.length} creator${counts.length == 1 ? '' : 's'}',
            Colors.purple,
          ),
          const Spacer(),
          // Per-creator details button
          if (counts.isNotEmpty)
            GestureDetector(
              onTap: () => _showCreatorStats(counts),
              child: Icon(
                Icons.info_outline_rounded,
                color: Colors.green,
                size: 18,
              ),
            ),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTheme.captionStyle.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  void _showCreatorStats(Map<String, int> counts) {
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Per-Creator Stats'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: sorted
                .map(
                  (e) => ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.person_rounded,
                      color: Colors.green,
                    ),
                    title: Text(e.key),
                    trailing: Text(
                      '${e.value} file${e.value == 1 ? '' : 's'}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ─── Search bar ───────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: TextField(
        controller: _searchCtrl,
        decoration: InputDecoration(
          hintText: 'Search files…',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => _searchCtrl.clear(),
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.4)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
          ),
          filled: true,
          fillColor: AppTheme.getSurfaceColor(context),
        ),
        style: AppTheme.bodyStyle,
      ),
    );
  }

  // ─── Sort + filter row ────────────────────────────────────────────────────

  Widget _buildSortAndFilterRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sort + Creator row
          Row(
            children: [
              // Sort dropdown
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.4),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<_SortOrder>(
                  value: _sortOrder,
                  underline: const SizedBox(),
                  isDense: true,
                  style: AppTheme.captionStyle.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  icon: const Icon(Icons.sort, size: 16),
                  items: _SortOrder.values
                      .map(
                        (o) => DropdownMenuItem(
                          value: o,
                          child: Text(_kSortLabels[o]!),
                        ),
                      )
                      .toList(),
                  onChanged: (o) {
                    if (o == null) return;
                    setState(() => _sortOrder = o);
                    _saveSortPref(o);
                  },
                ),
              ),
              const SizedBox(width: 10),
              // Creator filter dropdown (only visible when there are creators)
              if (_allCreators.isNotEmpty)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.purple.withValues(alpha: 0.4),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String?>(
                      value: _creatorFilter,
                      underline: const SizedBox(),
                      isDense: true,
                      isExpanded: true,
                      style: AppTheme.captionStyle.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      icon: const Icon(Icons.person, size: 16),
                      hint: const Text('All creators'),
                      items: [
                        const DropdownMenuItem<String?>(
                          child: Text('All creators'),
                        ),
                        ..._allCreators.map(
                          (c) => DropdownMenuItem<String?>(
                            value: c,
                            child: Text(c, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ],
                      onChanged: (c) => setState(() => _creatorFilter = c),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          // Type filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _TypeFilter.values
                  .map(
                    (t) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(
                          _kTypeLabels[t]!,
                          style: TextStyle(
                            fontSize: 12,
                            color: _typeFilter == t
                                ? Colors.white
                                : AppTheme.getOnSurfaceColor(context),
                          ),
                        ),
                        selected: _typeFilter == t,
                        selectedColor: Colors.green,
                        checkmarkColor: Colors.white,
                        onSelected: (_) => setState(() => _typeFilter = t),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Active downloads ─────────────────────────────────────────────────────

  Widget _buildActiveDownloadsSection(
    List<DownloadItem> activeDownloads,
    DownloadProvider downloadProvider,
  ) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.download_for_offline,
                color: Colors.green,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Active Downloads (${activeDownloads.length})',
                style: AppTheme.titleStyle.copyWith(
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () async {
                  for (final download in activeDownloads) {
                    downloadProvider.cancelDownload(download.id);
                  }
                  // Reload file list after a short delay so any partial files
                  // written to disk are included / cleaned up.
                  await Future.delayed(_kDownloadRefreshDelay);
                  if (mounted) _loadDownloadedFiles();
                },
                child: const Text(
                  'Cancel All',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...activeDownloads.map(
            (d) => _buildActiveDownloadItem(d, downloadProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveDownloadItem(
    DownloadItem download,
    DownloadProvider downloadProvider,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getStatusIcon(download.status),
                color: _getStatusColor(download.status),
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  download.name,
                  style: AppTheme.bodyStyle.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (download.status == DownloadStatus.downloading)
                Text(
                  '${(download.progress * 100).toInt()}%',
                  style: AppTheme.captionStyle.copyWith(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (download.status == DownloadStatus.pending)
                IconButton(
                  onPressed: () async {
                    downloadProvider.cancelDownload(download.id);
                    await Future.delayed(_kDownloadRefreshDelay);
                    if (mounted) _loadDownloadedFiles();
                  },
                  icon: const Icon(Icons.cancel, color: Colors.red, size: 16),
                  tooltip: 'Cancel',
                ),
              if (download.status == DownloadStatus.failed ||
                  download.status == DownloadStatus.cancelled)
                IconButton(
                  onPressed: () => downloadProvider.retryDownload(download.id),
                  icon: const Icon(
                    Icons.refresh,
                    color: Colors.orange,
                    size: 16,
                  ),
                  tooltip: 'Retry',
                ),
            ],
          ),
          if (download.status == DownloadStatus.downloading) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: download.progress,
              backgroundColor: Colors.grey.withValues(alpha: 0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatFileSize(download.downloadedBytes),
                  style: AppTheme.captionStyle.copyWith(
                    color: AppTheme.getOnSurfaceColor(
                      context,
                    ).withValues(alpha: 0.6),
                  ),
                ),
                Text(
                  download.totalBytes > 0
                      ? _formatFileSize(download.totalBytes)
                      : 'Unknown size',
                  style: AppTheme.captionStyle.copyWith(
                    color: AppTheme.getOnSurfaceColor(
                      context,
                    ).withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ],
          if (download.status == DownloadStatus.failed &&
              download.errorMessage != null) ...[
            const SizedBox(height: 4),
            Text(
              download.errorMessage!,
              style: AppTheme.captionStyle.copyWith(color: Colors.red),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Completed file list ──────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return AppEmptyState(
      icon: Icons.download_outlined,
      title: 'No downloaded files yet',
      message: 'Download files from posts to see them here',
      actionLabel: 'Back to Posts',
      onAction: () => Navigator.pop(context),
      accentColor: Colors.green,
    );
  }

  Widget _buildFileList() {
    final filtered = _filteredFiles;
    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: Colors.grey.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'No files match the current filter',
              style: AppTheme.bodyStyle.copyWith(
                color: AppTheme.getOnSurfaceColor(
                  context,
                ).withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    // Group by creator when showing all creators
    if (_creatorFilter == null && _sortOrder == _SortOrder.creatorAZ) {
      return _buildGroupedList(filtered);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      itemCount: filtered.length,
      itemBuilder: (context, i) => _buildFileCard(filtered[i]),
    );
  }

  Widget _buildGroupedList(List<_FileInfo> files) {
    // Build a flat list of items: either a String creator header or a _FileInfo.
    // We use a distinct sentinel because creator may be any user-supplied string.
    const sentinelNone = '\x00__no_prev_creator__';
    final items = <dynamic>[];
    String lastCreator = sentinelNone;

    for (final f in files) {
      final key = f.creator.isEmpty ? '(uncategorized)' : f.creator;
      if (key != lastCreator) {
        items.add(key); // header
        lastCreator = key;
      }
      items.add(f);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        if (item is String) return _buildCreatorHeader(item);
        return _buildFileCard(item as _FileInfo);
      },
    );
  }

  Widget _buildCreatorHeader(String creator) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 4),
      child: Row(
        children: [
          const Icon(Icons.person_rounded, size: 16, color: Colors.purple),
          const SizedBox(width: 6),
          Text(
            creator,
            style: AppTheme.titleStyle.copyWith(
              color: Colors.purple,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Divider(
              color: Colors.purple.withValues(alpha: 0.3),
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileCard(_FileInfo info) {
    final isSelected = _selectedPaths.contains(info.file.path);
    final typeColor = _fileTypeColor(info.fileName);
    final typeIcon = _fileTypeIcon(info.fileName);

    return GestureDetector(
      onLongPress: () {
        if (!_isSelectMode) {
          setState(() {
            _isSelectMode = true;
            _selectedPaths.add(info.file.path);
          });
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.green.withValues(alpha: 0.12)
              : AppTheme.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Colors.green.withValues(alpha: 0.5)
                : Colors.grey.withValues(alpha: 0.2),
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(12),
          leading: _isSelectMode
              ? Checkbox(
                  value: isSelected,
                  activeColor: Colors.green,
                  onChanged: (_) => _toggleSelect(info.file.path),
                )
              : Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(typeIcon, color: typeColor, size: 24),
                ),
          title: Text(
            info.fileName,
            style: AppTheme.bodyStyle.copyWith(fontWeight: FontWeight.w500),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(
                    Icons.storage,
                    size: 12,
                    color: AppTheme.getOnSurfaceColor(
                      context,
                    ).withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatFileSize(info.sizeBytes),
                    style: AppTheme.captionStyle.copyWith(
                      color: AppTheme.getOnSurfaceColor(
                        context,
                      ).withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    Icons.schedule,
                    size: 12,
                    color: AppTheme.getOnSurfaceColor(
                      context,
                    ).withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(info.lastModified),
                    style: AppTheme.captionStyle.copyWith(
                      color: AppTheme.getOnSurfaceColor(
                        context,
                      ).withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              if (info.creator.isNotEmpty) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.person_rounded,
                      size: 12,
                      color: Colors.purple.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        info.creator,
                        style: AppTheme.captionStyle.copyWith(
                          color: Colors.purple.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          onTap: _isSelectMode ? () => _toggleSelect(info.file.path) : null,
          trailing: _isSelectMode
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () => _openFile(info.file),
                      icon: const Icon(
                        Icons.open_in_new,
                        color: Colors.green,
                        size: 20,
                      ),
                      tooltip: 'Open',
                    ),
                    IconButton(
                      onPressed: () => _deleteFile(info),
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.red,
                        size: 20,
                      ),
                      tooltip: 'Delete',
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // ─── File type helpers ────────────────────────────────────────────────────

  IconData _fileTypeIcon(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    if ([
      'jpg',
      'jpeg',
      'png',
      'gif',
      'webp',
      'bmp',
      'tiff',
      'svg',
    ].contains(ext)) {
      return Icons.image_rounded;
    }
    if (['mp4', 'avi', 'mov', 'mkv', 'webm', 'flv', 'wmv'].contains(ext)) {
      return Icons.videocam_rounded;
    }
    if (['mp3', 'wav', 'ogg', 'flac', 'aac', 'm4a'].contains(ext)) {
      return Icons.audiotrack_rounded;
    }
    if (['pdf', 'doc', 'docx', 'txt', 'epub'].contains(ext)) {
      return Icons.description_rounded;
    }
    if (['zip', 'rar', '7z', 'tar', 'gz'].contains(ext)) {
      return Icons.folder_zip_rounded;
    }
    return Icons.insert_drive_file_rounded;
  }

  Color _fileTypeColor(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    if ([
      'jpg',
      'jpeg',
      'png',
      'gif',
      'webp',
      'bmp',
      'tiff',
      'svg',
    ].contains(ext)) {
      return Colors.blue;
    }
    if (['mp4', 'avi', 'mov', 'mkv', 'webm', 'flv', 'wmv'].contains(ext)) {
      return Colors.red;
    }
    if (['mp3', 'wav', 'ogg', 'flac', 'aac', 'm4a'].contains(ext)) {
      return Colors.purple;
    }
    if (['pdf', 'doc', 'docx', 'txt', 'epub'].contains(ext)) {
      return Colors.orange;
    }
    if (['zip', 'rar', '7z', 'tar', 'gz'].contains(ext)) return Colors.teal;
    return Colors.grey;
  }

  // ─── Selection ────────────────────────────────────────────────────────────

  void _toggleSelect(String path) {
    setState(() {
      if (_selectedPaths.contains(path)) {
        _selectedPaths.remove(path);
      } else {
        _selectedPaths.add(path);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedPaths
        ..clear()
        ..addAll(_filteredFiles.map((f) => f.file.path));
    });
  }

  Future<void> _bulkDelete() async {
    final count = _selectedPaths.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Files'),
        content: Text('Delete $count selected file${count == 1 ? '' : 's'}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    int deleted = 0;
    for (final path in List.of(_selectedPaths)) {
      try {
        await File(path).delete();
        deleted++;
      } catch (_) {}
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted $deleted file${deleted == 1 ? '' : 's'}'),
          backgroundColor: Colors.green,
        ),
      );
    }

    setState(() {
      _isSelectMode = false;
      _selectedPaths.clear();
    });
    await _loadDownloadedFiles();
  }

  Future<void> _confirmClearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Downloads'),
        content: Text(
          'This will permanently delete all ${_allFiles.length} '
          'file${_allFiles.length == 1 ? '' : 's'} in the KC Download folder.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    int deleted = 0;
    for (final info in List.of(_allFiles)) {
      try {
        await info.file.delete();
        deleted++;
      } catch (_) {}
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cleared $deleted file${deleted == 1 ? '' : 's'}'),
          backgroundColor: Colors.green,
        ),
      );
    }
    await _loadDownloadedFiles();
  }

  // ─── Formatters ───────────────────────────────────────────────────────────

  IconData _getStatusIcon(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.pending:
        return Icons.schedule;
      case DownloadStatus.downloading:
        return Icons.downloading;
      case DownloadStatus.completed:
        return Icons.check_circle;
      case DownloadStatus.failed:
        return Icons.error;
      case DownloadStatus.cancelled:
        return Icons.cancel;
    }
  }

  Color _getStatusColor(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.pending:
        return Colors.orange;
      case DownloadStatus.downloading:
        return Colors.green;
      case DownloadStatus.completed:
        return Colors.green;
      case DownloadStatus.failed:
        return Colors.red;
      case DownloadStatus.cancelled:
        return Colors.grey;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    int unitIndex = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    return '${size.toStringAsFixed(unitIndex == 0 ? 0 : 1)} ${units[unitIndex]}';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  // ─── File actions ─────────────────────────────────────────────────────────

  Future<void> _openFile(File file) async {
    try {
      final uri = Uri.file(file.path);
      bool launched = false;
      try {
        if (await canLaunchUrl(uri)) {
          launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } catch (_) {}

      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File saved at: ${file.path}'),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(label: 'Copy Path', onPressed: () {}),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteFile(_FileInfo info) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete File'),
        content: Text('Delete "${info.fileName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await info.file.delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File deleted'),
            backgroundColor: Colors.green,
          ),
        );
      }
      await _loadDownloadedFiles();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting file: $e')));
      }
    }
  }
}
