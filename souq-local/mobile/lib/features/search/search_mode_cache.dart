/// Per-tab pagination/cache metadata for marketplace search.
class SearchModeCache {
  final Set<String> loadedModes = {};
  final Map<String, int> offsets = {};
  final Map<String, bool> hasMore = {};

  void invalidateAll() {
    loadedModes.clear();
    offsets.clear();
    hasMore.clear();
  }

  bool isLoaded(String mode) => loadedModes.contains(mode);

  int offsetFor(String mode) => offsets[mode] ?? 0;

  bool hasMoreFor(String mode) => hasMore[mode] ?? false;

  void recordPage({
    required String mode,
    required int itemCount,
    required bool pageHasMore,
    required bool append,
  }) {
    loadedModes.add(mode);
    offsets[mode] = (append ? offsetFor(mode) : 0) + itemCount;
    hasMore[mode] = pageHasMore;
  }
}
