class PaginatedState<T> {
  PaginatedState({
    List<T>? items,
    this.offset = 0,
    this.hasMore = true,
    this.isLoading = false,
    this.error,
  }) : items = List<T>.from(items ?? const []);

  final List<T> items;
  int offset;
  bool hasMore;
  bool isLoading;
  String? error;

  void reset() {
    items.clear();
    offset = 0;
    hasMore = true;
    isLoading = false;
    error = null;
  }

  void setLoading(bool value) {
    isLoading = value;
  }

  void setError(String? value) {
    error = value;
  }

  void appendPage(List<T> page, int limit) {
    items.addAll(page);
    offset += page.length;
    hasMore = page.length >= limit;
  }
}
