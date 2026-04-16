import 'dart:io';
void main() {
  final file = File('lib/presentation/screens/latest_posts_screen.dart');
  var content = file.readAsStringSync();
  
  final oldBuild = '''
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final ctrl = context.watch<LatestPostsController>();

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: _FeedAppBar(
        isLoading: ctrl.isLoading,
        hasBlockedTags: ctrl.blockedTags.isNotEmpty,
        onRefresh: ctrl.loadInitial,
        onDownloadManager: _showDownloadManager,
        onFilter: _showFilterBottomSheet,
      ),
      body: Stack(
        children: [
          const _FeedBackground(),
          RefreshWrapper(
            onRefresh: ctrl.loadInitial,
            child: Column(
              children: [
                _FilterInfoBar(
                  selectedService: ctrl.selectedService,
                  blockedTagCount: ctrl.blockedTags.length,
                ),
                _RecentCreatorsCarousel(
                  isExpanded: _isRecentlyViewedExpanded,
                  onToggle: () => setState(
                    () =>
                        _isRecentlyViewedExpanded = !_isRecentlyViewedExpanded,
                  ),
                  onCreatorTap: _navigateToCreatorDetail,
                ),
                Expanded(
                  child: ctrl.isSwitchingSource
                      ? _SwitchingSourceIndicator(
                          apiSourceName: ctrl.currentApiSource.name,
                        )
                      : _FeedContent(
                          controller: ctrl,
                          scrollController: _scrollController,
                          onPostTap: _navigateToPostDetail,
                          onCreatorTap: (post) => _navigateToCreatorDetail(
                            creatorStubFromPost(post),
                          ),
                          onFilterTap: _showFilterBottomSheet,
                        ),
                ),
                if ((ctrl.filteredPosts.isNotEmpty || ctrl.isInSearchMode) &&
                    !ctrl.isSwitchingSource)
                  const _PaginationBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }''';

  final newBuild = '''
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final ctrl = context.watch<LatestPostsController>();

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      body: Stack(
        children: [
          const _FeedBackground(),
          RefreshWrapper(
            onRefresh: ctrl.loadInitial,
            child: CustomScrollView(
              controller: _scrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverAppBar(
                  floating: true,
                  snap: true,
                  pinned: false,
                  elevation: 0,
                  backgroundColor: AppTheme.getBackgroundColor(context).withOpacity(0.85),
                  surfaceTintColor: Colors.transparent,
                  flexibleSpace: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                  title: const Text('Latest Posts', style: TextStyle(fontWeight: FontWeight.bold)),
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(60),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: _SearchBar(controller: ctrl),
                    ),
                  ),
                  actions: [
                    _ActionButton(
                      icon: Icons.download_rounded,
                      onTap: _showDownloadManager,
                      accentColor: AppTheme.secondaryAccent,
                    ),
                    _ActionButton(
                      icon: Icons.refresh_rounded,
                      onTap: ctrl.loadInitial,
                      accentColor: ctrl.isLoading ? AppTheme.primaryColor : null,
                      child: ctrl.isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.primaryColor,
                              ),
                            )
                          : null,
                    ),
                    _ActionButton(
                      icon: Icons.tune_rounded,
                      onTap: _showFilterBottomSheet,
                      accentColor: ctrl.blockedTags.isNotEmpty ? AppTheme.primaryColor : null,
                      margin: const EdgeInsets.only(right: 16),
                    ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      _FilterInfoBar(
                        selectedService: ctrl.selectedService,
                        blockedTagCount: ctrl.blockedTags.length,
                      ),
                      _RecentCreatorsCarousel(
                        isExpanded: _isRecentlyViewedExpanded,
                        onToggle: () => setState(
                          () => _isRecentlyViewedExpanded = !_isRecentlyViewedExpanded,
                        ),
                        onCreatorTap: _navigateToCreatorDetail,
                      ),
                    ],
                  ),
                ),
                if (ctrl.isSwitchingSource)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _SwitchingSourceIndicator(apiSourceName: ctrl.currentApiSource.name),
                  )
                else
                  _FeedContent(
                    controller: ctrl,
                    scrollController: _scrollController,
                    onPostTap: _navigateToPostDetail,
                    onCreatorTap: (post) => _navigateToCreatorDetail(
                      creatorStubFromPost(post),
                    ),
                    onFilterTap: _showFilterBottomSheet,
                  ),
                if ((ctrl.filteredPosts.isNotEmpty || ctrl.isInSearchMode) &&
                    !ctrl.isSwitchingSource)
                  const SliverToBoxAdapter(
                    child: _PaginationBar(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }''';

  content = content.replaceAll(oldBuild, newBuild);
  file.writeAsStringSync(content);
}
