import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/post_bookmark.dart';
import '../providers/bookmark_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_state_widgets.dart';
import 'post_detail_screen.dart';
import '../../domain/entities/api_source.dart';
import '../../domain/entities/post.dart';
import '../../domain/entities/post_file.dart';

/// Full bookmarks management screen.
class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  BookmarkSortOrder _sortOrder = BookmarkSortOrder.dateBookmarkedDesc;
  String? _creatorFilter; // null = show all
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  static const _kSortLabels = {
    BookmarkSortOrder.dateBookmarkedDesc: 'Newest bookmarked',
    BookmarkSortOrder.dateBookmarkedAsc: 'Oldest bookmarked',
    BookmarkSortOrder.creatorAZ: 'Creator A-Z',
    BookmarkSortOrder.ratingDesc: 'Highest rated',
  };

  @override
  void initState() {
    super.initState();
    // Ensure provider is initialised
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookmarkProvider>().initialize();
    });
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Filtering ──────────────────────────────────────────────────────────────

  List<PostBookmark> _filtered(List<PostBookmark> sorted) {
    var list = sorted;
    if (_creatorFilter != null) {
      list = list.where((b) => b.creatorName == _creatorFilter).toList();
    }
    if (_searchQuery.isNotEmpty) {
      list = list.where((b) {
        return b.title.toLowerCase().contains(_searchQuery) ||
            b.creatorName.toLowerCase().contains(_searchQuery) ||
            b.personalNotes.toLowerCase().contains(_searchQuery) ||
            b.tags.any((t) => t.toLowerCase().contains(_searchQuery));
      }).toList();
    }
    return list;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Consumer<BookmarkProvider>(
      builder: (context, provider, _) {
        final sorted = provider.sorted(_sortOrder);
        final filtered = _filtered(sorted);
        final creators = provider.allCreators;

        return Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search bookmarks…',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: _searchCtrl.clear,
                        )
                      : null,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: AppTheme.getSurfaceColor(context),
                ),
              ),
            ),
            // Sort + creator row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  // Sort dropdown
                  _buildSortDropdown(),
                  const SizedBox(width: 8),
                  // Creator filter (only when creators exist)
                  if (creators.isNotEmpty) Expanded(child: _buildCreatorDropdown(creators)),
                ],
              ),
            ),
            // List
            Expanded(
              child: filtered.isEmpty
                  ? provider.count == 0
                      ? const AppEmptyState(
                          icon: Icons.bookmarks_outlined,
                          title: 'No bookmarks yet',
                          message:
                              'Tap the bookmark icon on a post to save it here',
                        )
                      : const AppEmptyState(
                          icon: Icons.search_off_rounded,
                          title: 'No bookmarks match',
                          message: 'Try adjusting your search or filter',
                        )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) =>
                          _buildBookmarkCard(filtered[i], provider),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSortDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(
          color: const Color(0xFFFFB300).withValues(alpha: 0.5),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<BookmarkSortOrder>(
        value: _sortOrder,
        underline: const SizedBox(),
        isDense: true,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTheme.getPrimaryTextColor(context),
        ),
        icon: const Icon(Icons.sort, size: 16),
        items: BookmarkSortOrder.values
            .map(
              (o) => DropdownMenuItem(
                value: o,
                child: Text(_kSortLabels[o]!),
              ),
            )
            .toList(),
        onChanged: (o) {
          if (o != null) setState(() => _sortOrder = o);
        },
      ),
    );
  }

  Widget _buildCreatorDropdown(List<String> creators) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
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
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTheme.getPrimaryTextColor(context),
        ),
        icon: const Icon(Icons.person, size: 16),
        hint: const Text('All creators'),
        items: [
          const DropdownMenuItem<String?>(child: Text('All creators')),
          ...creators.map(
            (c) => DropdownMenuItem<String?>(
              value: c,
              child: Text(c, overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
        onChanged: (c) => setState(() => _creatorFilter = c),
      ),
    );
  }

  // ── Bookmark card ──────────────────────────────────────────────────────────

  Widget _buildBookmarkCard(PostBookmark bm, BookmarkProvider provider) {
    return Dismissible(
      key: ValueKey(bm.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.red, size: 26),
      ),
      onDismissed: (_) async {
        await provider.removeBookmark(bm.postId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Bookmark removed'),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () => provider.restoreBookmark(bm),
              ),
            ),
          );
        }
      },
      child: GestureDetector(
        onLongPress: () => _showEditDialog(context, bm, provider),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: AppTheme.getCardColor(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.getBorderColor(context, opacity: 0.35),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha:
                      Theme.of(context).brightness == Brightness.dark
                          ? 0.2
                          : 0.06,
                ),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _openPost(context, bm),
              child: Row(
                children: [
                  // Thumbnail
                  _buildThumbnail(bm),
                  // Info
                  Expanded(child: _buildInfo(bm)),
                  // Actions column
                  _buildActionsColumn(context, bm, provider),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(PostBookmark bm) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(16),
        bottomLeft: Radius.circular(16),
      ),
      child: SizedBox(
        width: 88,
        height: 88,
        child: bm.thumbnailUrl != null
            ? CachedNetworkImage(
                imageUrl: bm.thumbnailUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => _placeholderIcon(),
                errorWidget: (_, __, ___) => _placeholderIcon(),
              )
            : _placeholderIcon(),
      ),
    );
  }

  Widget _placeholderIcon() {
    return Container(
      color: AppTheme.getElevatedSurfaceColor(context),
      child: Icon(
        Icons.image_not_supported_rounded,
        color: AppTheme.getSecondaryTextColor(context, opacity: 0.4),
        size: 28,
      ),
    );
  }

  Widget _buildInfo(PostBookmark bm) {
    final dateStr = DateFormat('MMM d, yyyy').format(bm.bookmarkedDate);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            bm.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: AppTheme.getPrimaryTextColor(context),
            ),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Icon(
                Icons.person_rounded,
                size: 11,
                color: Colors.purple.withValues(alpha: 0.75),
              ),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  bm.creatorName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.purple.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Icon(
                Icons.bookmark_added_rounded,
                size: 11,
                color: AppTheme.getSecondaryTextColor(context, opacity: 0.6),
              ),
              const SizedBox(width: 3),
              Text(
                dateStr,
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.getSecondaryTextColor(context, opacity: 0.6),
                ),
              ),
              if (bm.mediaCount > 0) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.perm_media_rounded,
                  size: 11,
                  color: AppTheme.getSecondaryTextColor(
                    context,
                    opacity: 0.5,
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  '${bm.mediaCount}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.getSecondaryTextColor(
                      context,
                      opacity: 0.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
          // Rating
          if (bm.rating != null) ...[
            const SizedBox(height: 4),
            _buildStarRow(bm.rating!, 11),
          ],
          // Tags
          if (bm.tags.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              runSpacing: 2,
              children: bm.tags
                  .take(3)
                  .map(
                    (t) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB300).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: const Color(0xFFFFB300).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        t,
                        style: const TextStyle(
                          fontSize: 9,
                          color: Color(0xFFFFB300),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionsColumn(
    BuildContext context,
    PostBookmark bm,
    BookmarkProvider provider,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          iconSize: 18,
          onPressed: () => _showEditDialog(context, bm, provider),
          icon: const Icon(Icons.edit_outlined),
          tooltip: 'Edit notes / tags / rating',
          color: AppTheme.getSecondaryTextColor(context, opacity: 0.6),
        ),
        IconButton(
          iconSize: 18,
          onPressed: () => _confirmDelete(context, bm, provider),
          icon: const Icon(Icons.delete_outline),
          color: Colors.red.withValues(alpha: 0.75),
          tooltip: 'Remove bookmark',
        ),
      ],
    );
  }

  Widget _buildStarRow(int rating, double size) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Icon(
          i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
          size: size,
          color: i < rating
              ? const Color(0xFFFFB300)
              : AppTheme.getSecondaryTextColor(context, opacity: 0.35),
        );
      }),
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  void _openPost(BuildContext context, PostBookmark bm) {
    final settings = context.read<SettingsProvider>();
    // Reconstruct a minimal Post object from bookmark data
    final post = Post(
      id: bm.postId,
      user: bm.creatorName,
      service: bm.service,
      title: bm.title,
      content: bm.content,
      sharedFile: '',
      added: bm.bookmarkedDate,
      published: bm.published,
      edited: bm.bookmarkedDate,
      attachments: [],
      file: bm.thumbnailUrl != null
          ? [
              PostFile(
                id: '',
                name: 'thumbnail',
                path: bm.thumbnailUrl!,
              ),
            ]
          : [],
      tags: [],
      saved: false,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostDetailScreen(
          post: post,
          apiSource: settings.defaultApiSource,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    PostBookmark bm,
    BookmarkProvider provider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Bookmark'),
        content: Text('Remove "${bm.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) await provider.removeBookmark(bm.postId);
  }

  // ── Edit dialog ────────────────────────────────────────────────────────────

  Future<void> _showEditDialog(
    BuildContext context,
    PostBookmark bm,
    BookmarkProvider provider,
  ) async {
    final notesCtrl = TextEditingController(text: bm.personalNotes);
    final tagCtrl = TextEditingController();
    int? rating = bm.rating;
    final tags = List<String>.from(bm.tags);

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(
            bm.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Notes
                TextField(
                  controller: notesCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Personal notes',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),

                // Rating
                const Text(
                  'Rating',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Row(
                  children: List.generate(5, (i) {
                    final starVal = i + 1;
                    return GestureDetector(
                      onTap: () => setD(
                        () => rating = rating == starVal ? null : starVal,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(
                          (rating != null && i < rating!)
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: (rating != null && i < rating!)
                              ? const Color(0xFFFFB300)
                              : Colors.grey,
                          size: 28,
                        ),
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 14),

                // Tags
                const Text(
                  'Tags (max 5)',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                if (tags.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: tags
                        .map(
                          (t) => Chip(
                            label: Text(t, style: const TextStyle(fontSize: 11)),
                            deleteIcon: const Icon(Icons.close, size: 14),
                            onDeleted: () => setD(() => tags.remove(t)),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          ),
                        )
                        .toList(),
                  ),
                if (tags.length < 5) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: tagCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Add tag',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (v) {
                            final tag = v.trim();
                            if (tag.isNotEmpty && !tags.contains(tag)) {
                              setD(() {
                                tags.add(tag);
                                tagCtrl.clear();
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () {
                          final tag = tagCtrl.text.trim();
                          if (tag.isNotEmpty && !tags.contains(tag)) {
                            setD(() {
                              tags.add(tag);
                              tagCtrl.clear();
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final updated = bm.copyWith(
                  personalNotes: notesCtrl.text.trim(),
                  rating: rating,
                  clearRating: rating == null,
                  tags: tags,
                );
                await provider.updateBookmark(updated);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    notesCtrl.dispose();
    tagCtrl.dispose();
  }
}
