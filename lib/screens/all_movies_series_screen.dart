import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie_model.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/app_image_cache.dart';
import '../widgets/ott_filter_modal.dart';
import '../widgets/quick_preview_modal.dart';
import 'navigation_helper.dart';

class AllMoviesSeriesScreen extends StatefulWidget {
  final String initialSearch;
  final int initialNetworkId;
  final String initialGenre;
  final String initialType;
  final String title;
  final UserModel? user;

  const AllMoviesSeriesScreen({
    Key? key,
    this.initialSearch = '',
    this.initialNetworkId = 0,
    this.initialGenre = '',
    this.initialType = 'all',
    this.title = 'Catalog',
    this.user,
  }) : super(key: key);

  @override
  State<AllMoviesSeriesScreen> createState() => _AllMoviesSeriesScreenState();
}

class _AllMoviesSeriesScreenState extends State<AllMoviesSeriesScreen> {
  final _searchController = TextEditingController();
  String _selectedType = 'all'; // all, movie, series
  String _selectedSort = 'latest'; // latest, name
  Set<int> _selectedOttIds = {};
  List<String> _selectedOttNames = [];
  List<dynamic> _ottList = [];
  bool _isLoading = false;
  bool _isLiveSearching = false;
  List<MovieModel> _items = [];
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialSearch;
    if (widget.initialNetworkId > 0) {
      _selectedOttIds.add(widget.initialNetworkId);
    }
    if (widget.initialGenre.isNotEmpty) {
      _selectedOttNames.add(widget.initialGenre);
    }
    _selectedType = widget.initialType;
    ApiService.loadParkedIdsFromCache();
    unawaited(ApiService.refreshParkedIds());
    _fetchCatalog();
    _loadOttList();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOttList() async {
    final list = await ApiService.fetchOttGenres();
    if (!mounted) return;
    setState(() {
      _ottList = list;
      // Sync names if initial ID was provided
      if (_selectedOttIds.isNotEmpty && _selectedOttNames.isEmpty) {
        for (final id in _selectedOttIds) {
          final match = _ottList.firstWhere(
            (o) => int.tryParse('${o['id']}') == id,
            orElse: () => const {},
          );
          if (match.isNotEmpty && match['name'] != null) {
            _selectedOttNames.add(match['name'].toString());
          }
        }
        if (_selectedOttNames.isNotEmpty) {
          _fetchCatalog();
        }
      }
    });
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      // Instantly refresh when query is cleared
      _debounceTimer = Timer(const Duration(milliseconds: 150), () {
        _fetchCatalog();
      });
    } else if (trimmed.length >= 3) {
      // Live search triggered only after 3 characters without blocking the app
      setState(() => _isLiveSearching = true);
      _debounceTimer = Timer(const Duration(milliseconds: 380), () {
        _fetchCatalog(isLiveSearch: true);
      });
    }
  }

  Color _tagBgColor(MovieModel item) {
    final bg = item.customTagBg.trim();
    if (bg.isNotEmpty) {
      final c = _hexColor(bg);
      if (c != null) return c;
    }
    return const Color(0xFFE50914);
  }

  Color _tagTextColor(MovieModel item) {
    final tc = item.customTagColor.trim();
    if (tc.isNotEmpty) {
      final c = _hexColor(tc);
      if (c != null) return c;
    }
    return Colors.white;
  }

  Color? _hexColor(String hex) {
    var h = hex.replaceAll('#', '').trim();
    if (h.length == 6) h = 'FF$h';
    if (h.length != 8) return null;
    final v = int.tryParse(h, radix: 16);
    if (v == null) return null;
    return Color(v);
  }

  Future<void> _fetchCatalog({bool isLiveSearch = false}) async {
    if (!isLiveSearch) {
      setState(() => _isLoading = true);
    }

    final query = _searchController.text.trim();
    final singleNetId = _selectedOttIds.length == 1 ? _selectedOttIds.first : 0;
    final genreParam = _selectedOttNames.join(',');

    // 1. Direct fetch using backend content API
    final directResults = await ApiService.fetchContent(
      type: _selectedType,
      search: query,
      genre: genreParam,
      networkId: singleNetId,
      sort: _selectedSort,
    );

    if (directResults.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        _items = directResults;
        _isLoading = false;
        _isLiveSearching = false;
      });
      return;
    }

    // 2. Fallback to general catalog search with local multi-OTT filtering
    List<MovieModel> rawList = [];
    if (_selectedType == 'all') {
      final results = await Future.wait([
        ApiService.fetchContent(type: 'movie', sort: _selectedSort),
        ApiService.fetchContent(type: 'series', sort: _selectedSort),
      ]);
      rawList = [...results[0], ...results[1]];
      // Interleave movies and series by release date (newest first)
      if (_selectedSort != 'name') {
        rawList.sort((a, b) => b.releaseDate.compareTo(a.releaseDate));
      }
    } else {
      rawList = await ApiService.fetchContent(
        type: _selectedType,
        sort: _selectedSort,
      );
    }

    final String searchTarget = query.toLowerCase();
    List<MovieModel> matchingItems = rawList;

    // Multi-OTT Filter match
    if (_selectedOttNames.isNotEmpty) {
      final lowerOttNames = _selectedOttNames.map((n) => n.toLowerCase().trim()).toSet();
      matchingItems = matchingItems.where((m) {
        final ott = (m.ottName ?? '').toLowerCase().trim();
        final net = m.networkName.toLowerCase().trim();
        final tag = m.customTag.toLowerCase().trim();
        if (lowerOttNames.any((n) => (ott.isNotEmpty && (ott.contains(n) || n.contains(ott))) ||
                                      (net.isNotEmpty && (net.contains(n) || n.contains(net))) ||
                                      (tag.isNotEmpty && tag.contains(n)))) {
          return true;
        }
        for (final g in m.genres) {
          final gl = g.toLowerCase().trim();
          if (lowerOttNames.any((n) => gl.contains(n) || n.contains(gl))) return true;
        }
        return false;
      }).toList();
    }

    // Search query match (if any)
    if (searchTarget.isNotEmpty) {
      matchingItems = matchingItems.where((m) {
        final matchesTitle = m.name.toLowerCase().contains(searchTarget);
        final matchesDesc = m.description.toLowerCase().contains(searchTarget);
        final matchesOtt = m.ottName?.toLowerCase().contains(searchTarget) ?? false;
        final matchesNet = m.networkName.toLowerCase().contains(searchTarget);
        final matchesTag = m.customTag.toLowerCase().contains(searchTarget);
        final matchesGenre = m.genres.any((g) => g.toLowerCase().contains(searchTarget));
        final matchesCast = m.castMembers.any((c) => c.name.toLowerCase().contains(searchTarget));
        return matchesTitle || matchesDesc || matchesOtt || matchesNet || matchesTag || matchesGenre || matchesCast;
      }).toList();
    }

    if (!mounted) return;
    setState(() {
      _items = matchingItems;
      _isLoading = false;
      _isLiveSearching = false;
    });
  }

  void _openOttFilterModal() {
    OttFilterModal.show(
      context,
      ottList: _ottList,
      selectedOttIds: _selectedOttIds,
      onApply: (ids, names) {
        setState(() {
          _selectedOttIds = ids;
          _selectedOttNames = names;
        });
        _fetchCatalog();
      },
    );
  }

  String _getOttButtonLabel() {
    if (_selectedOttIds.isEmpty) return "OTT: All";
    if (_selectedOttIds.length == 1) {
      if (_selectedOttNames.isNotEmpty) return _selectedOttNames.first;
      return "OTT (1)";
    }
    return "OTT (${_selectedOttIds.length})";
  }

  @override
  Widget build(BuildContext context) {
    final effectiveUser = widget.user ?? AppSession.user;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF14141C),
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: Color(0xFF14141C),
              border: Border(bottom: BorderSide(color: Colors.white10)),
            ),
            child: Column(
              children: [
                // Live Search Box (Starts searching after 3 letters with zero lag)
                TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  onSubmitted: (_) => _fetchCatalog(),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: "Live search (type 3+ chars)...",
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                    prefixIcon: _isLiveSearching
                        ? Container(
                            width: 18,
                            height: 18,
                            padding: const EdgeInsets.all(12),
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFE50914),
                            ),
                          )
                        : const Icon(Icons.search_rounded, color: Color(0xFFE50914)),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, color: Colors.white60, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFF1E1E28),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Filter Buttons Row
                Row(
                  children: [
                    // 1. Type Selector Dropdown (Equal Size 1/3)
                    Expanded(
                      child: Container(
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E28),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedType,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF1A1D27),
                            style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
                            icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFE50914), size: 20),
                            items: const [
                              DropdownMenuItem(value: 'all', child: Text("All Type", overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'movie', child: Text("Movies", overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'series', child: Text("Series", overflow: TextOverflow.ellipsis)),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedType = val);
                                _fetchCatalog();
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // 2. Sort Selector Dropdown (Equal Size 1/3)
                    Expanded(
                      child: Container(
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E28),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedSort,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF1A1D27),
                            style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
                            icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFE50914), size: 20),
                            items: const [
                              DropdownMenuItem(value: 'latest', child: Text("Latest", overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'name', child: Text("Name", overflow: TextOverflow.ellipsis)),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedSort = val);
                                _fetchCatalog();
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // 3. Modern OTT Multi-Select Filter Button (Equal Size 1/3)
                    Expanded(
                      child: InkWell(
                        onTap: _openOttFilterModal,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          height: 42,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            gradient: _selectedOttIds.isNotEmpty
                                ? const LinearGradient(
                                    colors: [Color(0xFF8E2DE2), Color(0xFFE50914)],
                                  )
                                : null,
                            color: _selectedOttIds.isEmpty ? const Color(0xFF1E1E28) : null,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _selectedOttIds.isNotEmpty
                                  ? const Color(0xFFE50914)
                                  : Colors.white12,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.tune_rounded,
                                color: _selectedOttIds.isNotEmpty ? Colors.white : const Color(0xFFE50914),
                                size: 15,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  _getOttButtonLabel(),
                                  style: TextStyle(
                                    color: _selectedOttIds.isNotEmpty ? Colors.white : Colors.white70,
                                    fontSize: 11.5,
                                    fontWeight: _selectedOttIds.isNotEmpty ? FontWeight.w900 : FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Content Grid
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFE50914)),
                  )
                : _items.isEmpty
                    ? const Center(
                        child: Text(
                          "No content found",
                          style: TextStyle(color: Colors.white54, fontSize: 14),
                        ),
                      )
                    : GridView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.all(14),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.60,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return GestureDetector(
                            onTap: () => navigateToContent(context, item.id, item.itemType),
                            onLongPress: () => QuickPreviewModal.show(
                              context,
                              movie: item,
                              user: effectiveUser,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        CachedNetworkImage(
                                          imageUrl: item.poster,
                                          fit: BoxFit.cover,
                                          cacheManager: AppImageCache.posters,
                                          memCacheWidth: AppImageCache.posterMaxWidth,
                                          memCacheHeight: AppImageCache.posterMaxHeight,
                                          placeholder: (c, u) => Container(color: const Color(0xFF1E1E28)),
                                          errorWidget: (c, u, e) => Container(
                                            color: const Color(0xFF1E1E28),
                                            child: const Icon(Icons.movie_rounded, color: Colors.white24),
                                          ),
                                        ),
                                        Positioned(
                                          top: 6,
                                          left: 6,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: _tagBgColor(item),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              item.customTag,
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: _tagTextColor(item),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  item.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
