import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/movie_model.dart';
import '../services/api_service.dart';
import '../widgets/app_error_widget.dart';
import '../widgets/details_loading.dart';
import '../details/details_data.dart';
import '../details/series/layout1.dart';
import 'details_screen.dart';
import 'video_launcher.dart';

class WebSeriesDetailScreen extends StatefulWidget {
  final int contentId;

  const WebSeriesDetailScreen({
    Key? key,
    required this.contentId,
  }) : super(key: key);

  @override
  State<WebSeriesDetailScreen> createState() => _WebSeriesDetailScreenState();
}

class _WebSeriesDetailScreenState extends State<WebSeriesDetailScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  MovieModel? _series;
  List<SeasonModel> _seasons = [];
  List<MovieModel> _related = [];
  List<CastMember> _castMembers = [];
  List<String> _genres = [];
  String? _ottName;
  String? _ottLogo;
  int? _ottId;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final url = "${ApiConfig.detailsUrl}?id=${widget.contentId}&type=series";
      final res =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['status'] == 'success' && data['data'] != null) {
          final detailsData = data['data'];
          final content = detailsData['content'] ?? {};
          final seasonsList = (detailsData['seasons'] as List? ?? [])
              .map((s) => SeasonModel.fromJson(s))
              .toList();
          final relatedList = (detailsData['related'] as List? ?? [])
              .map((e) => MovieModel.fromJson(e))
              .toList();

          List<CastMember> castMembers = [];
          if (detailsData['cast_members'] != null) {
            castMembers = (detailsData['cast_members'] as List)
                .map((e) => CastMember.fromJson(e))
                .toList();
          }

          List<String> genres = [];
          if (detailsData['genres'] != null) {
            genres = (detailsData['genres'] as List)
                .map((e) => e.toString())
                .toList();
          } else if (_series?.genres.isNotEmpty ?? false) {
            genres = _series!.genres;
          }

          String? ottName = detailsData['ott_name']?.toString();
          String? ottLogo = detailsData['ott_logo']?.toString();
          int? ottId = detailsData['ott_id'] != null
              ? int.tryParse(detailsData['ott_id'].toString())
              : null;

          final contentMap = Map<String, dynamic>.from(content);
          contentMap['item_type'] = 'series';

          setState(() {
            _series = MovieModel.fromJson(contentMap);
            _seasons = seasonsList;
            _related = relatedList;
            _castMembers = castMembers;
            _genres = genres;
            _ottName = ottName ?? _series?.ottName;
            _ottLogo = ottLogo ?? _series?.ottLogo;
            _ottId = ottId ?? _series?.ottId;
            _errorMessage = null;
          });
        } else {
          _errorMessage = data['message'] ?? 'Failed to load';
        }
      } else {
        _errorMessage = 'HTTP ${res.statusCode}';
      }
    } catch (e) {
      _errorMessage = 'Error: $e';
    }
    setState(() => _isLoading = false);
  }

  bool get _isPremium {
    final tag = (_series?.customTag ?? '').toUpperCase();
    return tag.contains('VIP') ||
        tag.contains('PREMIUM') ||
        tag.contains('EXCLUSIVE');
  }

  Future<void> _playEpisode(String rawUrl, String title, {int episodeIndex = 0}) async {
    ApiService.logView(widget.contentId, 'series');

    List<Map<String, dynamic>>? playlist;
    if (_seasons.isNotEmpty) {
      final allEps = _seasons.expand((s) => s.episodes).toList();
      playlist = allEps.map((e) => {
        'id': e.id,
        'title': e.name,
        'image': e.image,
        'url': e.playLinks.isNotEmpty ? e.playLinks.first.url : '',
        'play_links': e.playLinks.map((l) => {'name': l.name, 'url': l.url, 'quality': l.quality}).toList(),
      }).toList();
    }

    await playVideo(
      context, 
      rawUrl, 
      title, 
      premium: _isPremium,
      contentId: widget.contentId,
      contentType: 2,
      playlist: playlist,
      initialEpisodeIndex: episodeIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF09090D),
        body: _buildLoading(),
      );
    }

    if (_errorMessage != null || _series == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF09090D),
        body: _buildError(),
      );
    }

    final data = DetailsData(
      movie: _series!,
      playLinks: [],
      seasons: _seasons,
      related: _related,
      castMembers: _castMembers,
      genres: _genres,
      ottName: _ottName,
      ottLogo: _ottLogo,
      ottId: _ottId,
      seriesOverride: true,  // Always treat as series for download picker
    );

    final playCallback = () {
      if (_seasons.isNotEmpty && _seasons.first.episodes.isNotEmpty) {
        final firstEp = _seasons.first.episodes.first;
        final url =
            firstEp.playLinks.isNotEmpty ? firstEp.playLinks.first.url : '';
        if (url.isNotEmpty) _playEpisode(url, firstEp.name);
      }
    };

    final watchlistCallback = () async {
      final id = widget.contentId;
      final type = 'series';
      final favs = await ApiService.getFavorites();
      final exists = favs.any((f) =>
          int.tryParse('${f['content_id']}') == id &&
          int.tryParse('${f['content_type']}') == 2);
      final res = exists
          ? await ApiService.removeFavorite(id, type)
          : await ApiService.addFavorite(id, type,
              name: _series?.name ?? '',
              poster: _series?.poster ?? '');
      if (!mounted) return;
      final success = res['status'] == 'success';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? (exists
                  ? "${_series?.name ?? ''} removed from Favorites"
                  : "${_series?.name ?? ''} added to Favorites")
              : "Couldn't update favorites. Try again."),
          duration: const Duration(seconds: 2),
          backgroundColor: success ? (exists ? Colors.red : Colors.green) : Colors.grey.shade700,
        ),
      );
    };

    final shareCallback = () {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Share ${_series?.name ?? 'Series'} link..."),
          duration: const Duration(seconds: 1),
        ),
      );
    };

    final playEpisodeCallback = (String url, String title) {
      int epIdx = 0;
      if (_seasons.isNotEmpty) {
        final allEps = _seasons.expand((s) => s.episodes).toList();
        final found = allEps.indexWhere((e) => (e.playLinks.isNotEmpty && e.playLinks.first.url == url) || e.name == title);
        if (found >= 0) epIdx = found;
      }
      _playEpisode(url, title, episodeIndex: epIdx);
    };

    return AuroraGlassSeriesLayout(
      data: data,
      onPlay: playCallback,
      onWatchlist: watchlistCallback,
      onShare: shareCallback,
      onPlayEpisode: playEpisodeCallback,
      onNavigateToContent: (id, type) {
        final isSeries = type == 'series' || type == '2';
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => isSeries
                ? WebSeriesDetailScreen(contentId: id)
                : DetailsScreen(contentId: id, itemType: type),
          ),
        );
      },
    );
  }

  Widget _buildLoading() {
    return const DetailsLoadingView();
  }

  Widget _buildError() {
    return AppErrorView(
      message: friendlyError(_errorMessage, 'Failed to load series details.'),
      onRetry: _loadDetails,
    );
  }
}
