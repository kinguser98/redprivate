import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/series_model.dart';
import '../services/api_service.dart';
import '../services/streamtape_service.dart';
import '../services/embed_resolver.dart';
import 'video_player_screen.dart';
import 'video_launcher.dart';

class WebSeriesScreen extends StatefulWidget {
  final String initialSearch;
  final String title;

  const WebSeriesScreen({
    Key? key,
    this.initialSearch = '',
    this.title = 'Web Series',
  }) : super(key: key);

  @override
  State<WebSeriesScreen> createState() => _WebSeriesScreenState();
}

class _WebSeriesScreenState extends State<WebSeriesScreen> {
  final _searchController = TextEditingController();
  bool _isLoading = false;
  List<SeriesItemModel> _items = [];
  final Set<int> _expandedSeriesIds = {};
  final Map<int, List<SeriesSeasonModel>> _loadedSeasons = {};

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialSearch;
    _fetchSeries();
  }

  Future<void> _fetchSeries() async {
    setState(() => _isLoading = true);
    try {
      final list = await ApiService.fetchSeriesContent(
        search: _searchController.text.trim(),
      );
      if (list.isNotEmpty) {
        setState(() {
          _items = list;
          _isLoading = false;
        });
        return;
      }
    } catch (_) {}

    final basicList = await ApiService.fetchContent(
      type: 'series',
      search: _searchController.text.trim(),
    );
    setState(() {
      _items = basicList
          .map((m) => SeriesItemModel.fromBasicJson({
                'id': m.id.toString(),
                'name': m.name,
                'poster': m.poster,
                'banner': m.banner,
                'release_date': m.releaseDate,
              }))
          .toList();
      _isLoading = false;
    });
  }

  Future<List<SeriesSeasonModel>> _loadDetails(int seriesId) async {
    try {
      final url = "${ApiConfig.detailsUrl}?id=$seriesId&type=series";
      final res =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['status'] == 'success' && data['data'] != null) {
          final seasonsData = data['data']['seasons'] as List? ?? [];
          return seasonsData.map((s) => SeriesSeasonModel.fromJson(s)).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  void _onSeriesExpanded(int index, bool expanded) async {
    final series = _items[index];
    if (expanded && !_loadedSeasons.containsKey(series.id)) {
      final seasons = await _loadDetails(series.id);
      if (!mounted) return;
      setState(() {
        series.seasons = seasons;
        _loadedSeasons[series.id] = seasons;
        _expandedSeriesIds.add(series.id);
      });
    } else if (!expanded) {
      setState(() => _expandedSeriesIds.remove(series.id));
    }
  }

  Future<void> _playEpisode(dynamic rawUrl, String title, int seriesId) async {
    await playVideo(context, rawUrl?.toString() ?? '', title, contentId: seriesId, contentType: 2);
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
            child: TextField(
              controller: _searchController,
              onSubmitted: (_) => _fetchSeries(),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Search web series...",
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Color(0xFFE50914)),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    _fetchSeries();
                  },
                ),
                filled: true,
                fillColor: const Color(0xFF1E1E28),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFE50914)))
                : _items.isEmpty
                    ? const Center(
                        child: Text("No web series found",
                            style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _items.length,
                        itemBuilder: (context, index) =>
                            _buildSeriesCard(index),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeriesCard(int index) {
    final series = _items[index];
    final bool isExpanded = _expandedSeriesIds.contains(series.id);
    final bool hasDetails = _loadedSeasons.containsKey(series.id);
    final int totalEpisodes = hasDetails
        ? series.seasons.fold(0, (sum, s) => sum + s.episodes.length)
        : 0;

    return Card(
      color: const Color(0xFF1E1E28),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => _onSeriesExpanded(index, !isExpanded),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: series.poster,
                      width: 60,
                      height: 80,
                      fit: BoxFit.cover,
                      errorWidget: (c, u, e) => Container(
                        width: 60,
                        height: 80,
                        color: const Color(0xFF2D2D3C),
                        child: const Icon(Icons.movie, color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(series.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                        const SizedBox(height: 4),
                        Text(
                          hasDetails
                              ? "$totalEpisodes Episode${totalEpisodes != 1 ? 's' : ''}"
                              : "",
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white54,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(color: Colors.white12, height: 1),
            if (!hasDetails)
              const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: Color(0xFFE50914)),
              )
            else
              ...series.seasons.map((season) => _buildSeasonSection(series.id, season)),
          ],
        ],
      ),
    );
  }

  Widget _buildSeasonSection(int seriesId, SeriesSeasonModel season) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding: EdgeInsets.zero,
        collapsedShape: const RoundedRectangleBorder(),
        shape: const RoundedRectangleBorder(),
        title: Text(
          season.name.isNotEmpty ? season.name : "Season ${season.order + 1}",
          style: const TextStyle(
              color: Color(0xFFE50914),
              fontWeight: FontWeight.w600,
              fontSize: 13),
        ),
        children: season.episodes.map((ep) => _buildEpisodeTile(seriesId, ep)).toList(),
      ),
    );
  }

  Widget _buildEpisodeTile(int seriesId, SeriesEpisodeModel ep) {
    final hasLink = ep.playLink != null && ep.playLink!.url.isNotEmpty;
    return InkWell(
      onTap: hasLink ? () => _playEpisode(ep.playLink!.url, ep.name, seriesId) : null,
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 8, top: 6, bottom: 6),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: ep.image,
                    width: 90,
                    height: 60,
                    fit: BoxFit.cover,
                    errorWidget: (c, u, e) => Container(
                      width: 90,
                      height: 60,
                      color: const Color(0xFF2D2D3C),
                      child: const Icon(Icons.play_circle_outline,
                          color: Colors.grey, size: 28),
                    ),
                  ),
                  if (hasLink)
                    Container(
                      width: 90,
                      height: 60,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.black54, Colors.transparent],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                      child: const Center(
                        child: Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: 28),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ep.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (ep.playLink != null) ...[
                    const SizedBox(height: 2),
                    Text("${ep.playLink!.quality} | ${ep.playLink!.type}",
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11)),
                  ],
                ],
              ),
            ),
            if (hasLink)
              const Icon(Icons.play_circle_fill_rounded,
                  color: Color(0xFFE50914), size: 28),
          ],
        ),
      ),
    );
  }
}
