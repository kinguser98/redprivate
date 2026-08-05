import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie_model.dart';
import '../services/api_service.dart';
import 'details_screen.dart';
import 'navigation_helper.dart';

class AllMoviesSeriesScreen extends StatefulWidget {
  final String initialSearch;
  final int initialNetworkId;
  final String initialGenre;
  final String initialType;
  final String title;

  const AllMoviesSeriesScreen({
    Key? key,
    this.initialSearch = '',
    this.initialNetworkId = 0,
    this.initialGenre = '',
    this.initialType = 'all',
    this.title = 'Catalog',
  }) : super(key: key);

  @override
  State<AllMoviesSeriesScreen> createState() => _AllMoviesSeriesScreenState();
}

class _AllMoviesSeriesScreenState extends State<AllMoviesSeriesScreen> {
  final _searchController = TextEditingController();
  String _selectedType = 'all'; // all, movie, series
  String _selectedSort = 'latest'; // latest, name
  int _selectedNetworkId = 0;
  String _selectedGenre = '';
  List<dynamic> _ottList = [];
  bool _isLoading = false;
  List<MovieModel> _items = [];

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialSearch;
    _selectedNetworkId = widget.initialNetworkId;
    _selectedGenre = widget.initialGenre;
    _selectedType = widget.initialType;
    ApiService.loadParkedIdsFromCache();
    unawaited(ApiService.refreshParkedIds());
    _fetchCatalog();
    _loadOttList();
  }

  Future<void> _loadOttList() async {
    final list = await ApiService.fetchOttGenres();
    if (!mounted) return;
    setState(() => _ottList = list);
  }

  int _selectedOttId() {
    int id = 0;
    if (_selectedNetworkId > 0) {
      id = _selectedNetworkId;
    } else {
      final match = _ottList.firstWhere(
        (o) => (o['name'] ?? '').toString().toLowerCase() ==
            _selectedGenre.toLowerCase(),
        orElse: () => const {},
      );
      id = int.tryParse('${match['id']}') ?? 0;
    }
    if (id > 0 && !_ottList.any((o) => int.tryParse('${o['id']}') == id)) {
      return 0;
    }
    return id;
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

  Future<void> _fetchCatalog() async {
    setState(() => _isLoading = true);

    // 1. Direct fetch using official Dooo REST API endpoints
    // (If Network ID > 0, calls getAllContentsOfNetwork/{id})
    // (If Genre name is set, calls getContentsReletedToGenre/{genre})
    final int netId = (_selectedGenre.isEmpty && _selectedNetworkId > 0) ? _selectedNetworkId : 0;
    final directResults = await ApiService.fetchContent(
      type: _selectedType,
      search: _searchController.text.trim(),
      genre: _selectedGenre,
      networkId: netId,
      sort: _selectedSort,
    );

    if (directResults.isNotEmpty) {
      setState(() {
        _items = directResults;
        _isLoading = false;
      });
      return;
    }

    // 2. Fallback to general catalog search
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

    final String genreTarget = _selectedGenre.trim().toLowerCase();
    final String searchTarget = _searchController.text.trim().toLowerCase();

    List<MovieModel> matchingItems = rawList;

    if (genreTarget.isNotEmpty || searchTarget.isNotEmpty) {
      final String filterTarget =
          genreTarget.isNotEmpty ? genreTarget : searchTarget;

      matchingItems = rawList.where((m) {
        final matchesTitle = m.name.toLowerCase().contains(filterTarget);
        final matchesDesc = m.description.toLowerCase().contains(filterTarget);
        final matchesOtt =
            m.ottName?.toLowerCase().contains(filterTarget) ?? false;
        final matchesTag = m.customTag.toLowerCase().contains(filterTarget);
        final matchesGenre =
            m.genres.any((g) => g.toLowerCase().contains(filterTarget));
        final matchesCast = m.castMembers
            .any((c) => c.name.toLowerCase().contains(filterTarget));
        return matchesTitle ||
            matchesDesc ||
            matchesOtt ||
            matchesTag ||
            matchesGenre ||
            matchesCast;
      }).toList();
    }

    setState(() {
      _items = matchingItems;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF14141C),
        title: Text(widget.title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF14141C),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onSubmitted: (_) => _fetchCatalog(),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Search movies, web series, cast...",
                    hintStyle: const TextStyle(color: Colors.grey),
                    prefixIcon:
                        const Icon(Icons.search, color: Color(0xFFE50914)),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        _searchController.clear();
                        _fetchCatalog();
                      },
                    ),
                    filled: true,
                    fillColor: const Color(0xFF1E1E28),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E28),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedType,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF1E1E28),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
                            icon: const Icon(Icons.arrow_drop_down,
                                color: Color(0xFFE50914)),
                            items: const [
                              DropdownMenuItem(
                                  value: 'all', child: Text("All Content")),
                              DropdownMenuItem(
                                  value: 'movie', child: Text("Movies Only")),
                              DropdownMenuItem(
                                  value: 'series',
                                  child: Text("Web Series Only")),
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
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E28),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedSort,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF1E1E28),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
                            icon: const Icon(Icons.arrow_drop_down,
                                color: Color(0xFFE50914)),
                            items: const [
                              DropdownMenuItem(
                                  value: 'latest', child: Text("Latest")),
                              DropdownMenuItem(
                                  value: 'name', child: Text("Name")),
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
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E28),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _selectedOttId(),
                            isExpanded: true,
                            dropdownColor: const Color(0xFF1E1E28),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
                            icon: const Icon(Icons.arrow_drop_down,
                                color: Color(0xFF8E2DE2)),
                            items: [
                              const DropdownMenuItem<int>(
                                value: 0,
                                child: Text("OTT: All",
                                    overflow: TextOverflow.ellipsis),
                              ),
                              ..._ottList.map<DropdownMenuItem<int>>((o) {
                                final id = int.tryParse('${o['id']}') ?? 0;
                                final name = (o['name'] ?? '').toString();
                                return DropdownMenuItem<int>(
                                  value: id,
                                  child: Text(name,
                                      overflow: TextOverflow.ellipsis),
                                );
                              }),
                            ],
                            onChanged: (val) {
                              if (val == null) return;
                              setState(() {
                                _selectedNetworkId = val;
                                _selectedGenre = val == 0
                                    ? ''
                                    : ((_ottList.firstWhere(
                                                (o) =>
                                                    int.tryParse('${o['id']}') ==
                                                    val,
                                                orElse: () => const {})['name'] ??
                                            '')
                                        .toString());
                              });
                              _fetchCatalog();
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFE50914)))
                : _items.isEmpty
                    ? const Center(
                        child: Text("No content found",
                            style: TextStyle(color: Colors.grey)))
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.62,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return GestureDetector(
                            onTap: () => navigateToContent(
                                context, item.id, item.itemType),
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
                                          placeholder: (c, u) => Container(
                                              color: const Color(0xFF1E1E28)),
                                          errorWidget: (c, u, e) => Container(
                                              color: const Color(0xFF1E1E28),
                                              child: const Icon(Icons.movie,
                                                  color: Colors.grey)),
                                        ),
                                        Positioned(
                                          top: 6,
                                          left: 6,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: _tagBgColor(item),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              item.customTag,
                                              style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color: _tagTextColor(item)),
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
                                      color: Colors.white),
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
