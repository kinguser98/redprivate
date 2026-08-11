import 'package:flutter/material.dart';
import '../models/movie_model.dart';
import '../services/api_service.dart';
import '../widgets/app_error_widget.dart';
import '../widgets/details_loading.dart';
import '../details/details_data.dart';
import '../details/movie/layout1.dart';
import '../details/series/layout1.dart';
import 'web_series_detail_screen.dart';
import 'video_launcher.dart';

class DetailsScreen extends StatefulWidget {
  final int contentId;
  final String itemType;

  const DetailsScreen({
    Key? key,
    required this.contentId,
    required this.itemType,
  }) : super(key: key);

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  MovieModel? _movieDetails;
  List<PlayLinkModel> _playLinks = [];
  List<SeasonModel> _seasons = [];
  List<MovieModel> _related = [];
  List<CastMember> _castMembers = [];
  List<String> _genres = [];
  String? _ottName;
  String? _ottLogo;
  int? _ottId;

  bool get _isMovie =>
      widget.itemType == 'movie' ||
      widget.itemType == '1' ||
      _movieDetails?.itemType == 'movie' ||
      _movieDetails?.itemType == '1';

  bool get _isPremium {
    final tag = (_movieDetails?.customTag ?? '').toUpperCase();
    return tag.contains('VIP') ||
        tag.contains('PREMIUM') ||
        tag.contains('EXCLUSIVE');
  }

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

    final res =
        await ApiService.fetchDetails(widget.contentId, widget.itemType);
    if (res['status'] == 'success' && res['data'] != null) {
      final data = res['data'];
      final detailsJson = data['content'] ?? data['details'] ?? {};
      final details = MovieModel.fromJson(detailsJson);

      List<PlayLinkModel> links = [];
      if (data['play_links'] != null) {
        links = (data['play_links'] as List)
            .map((e) => PlayLinkModel.fromJson(e))
            .toList();
      }

      List<SeasonModel> seasonList = [];
      if (data['seasons'] != null) {
        seasonList = (data['seasons'] as List)
            .map((e) => SeasonModel.fromJson(e))
            .toList();
      }

      List<MovieModel> relatedList = [];
      if (data['related'] != null) {
        relatedList = (data['related'] as List)
            .map((e) => MovieModel.fromJson(e))
            .toList();
      }

      List<CastMember> castMembers = [];
      if (data['cast_members'] != null) {
        castMembers = (data['cast_members'] as List)
            .map((e) => CastMember.fromJson(e))
            .toList();
      }

      List<String> genres = [];
      if (data['genres'] != null) {
        genres = (data['genres'] as List)
            .map((e) => e.toString())
            .toList();
      } else if (details.genres.isNotEmpty) {
        genres = details.genres;
      }

      String? ottName = data['ott_name']?.toString();
      String? ottLogo = data['ott_logo']?.toString();
      int? ottId = data['ott_id'] != null
          ? int.tryParse(data['ott_id'].toString())
          : null;

      if (ottName == null || ottName.isEmpty) {
        ottName = details.ottName;
      }
      if (ottLogo == null || ottLogo.isEmpty) {
        ottLogo = details.ottLogo;
      }
      if (ottId == null) {
        ottId = details.ottId;
      }

      setState(() {
        _movieDetails = details;
        _playLinks = links;
        _seasons = seasonList;
        _related = relatedList;
        _castMembers = castMembers;
        _genres = genres;
        _ottName = ottName;
        _ottLogo = ottLogo;
        _ottId = ottId;
        _errorMessage = null;
      });
    } else {
      setState(() {
        _errorMessage = res['message'] ?? 'Failed to load details from server';
      });
    }

    setState(() => _isLoading = false);
  }

  Future<void> _playVideo(String rawUrl, String title) async {
    ApiService.logView(widget.contentId, widget.itemType);
    final isMovie = widget.itemType == 'movie' || widget.itemType == '1';
    await playVideo(
      context, 
      rawUrl, 
      title, 
      premium: _isPremium,
      contentId: widget.contentId,
      contentType: isMovie ? 1 : 2,
    );
  }

  void _navigateToRelated(int contentId, String itemType) {
    final isSeries = itemType == 'series' || itemType == '2';
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => isSeries
            ? WebSeriesDetailScreen(contentId: contentId)
            : DetailsScreen(contentId: contentId, itemType: itemType),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0D12),
        body: _buildShimmerLoading(),
      );
    }

    if (_errorMessage != null || _movieDetails == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0D12),
        body: _buildErrorView(),
      );
    }

    final data = DetailsData(
      movie: _movieDetails!,
      playLinks: _playLinks,
      seasons: _seasons,
      related: _related,
      castMembers: _castMembers,
      genres: _genres,
      ottName: _ottName,
      ottLogo: _ottLogo,
      ottId: _ottId,
    );

    final playCallback = () {
      if (_isMovie) {
        if (_playLinks.isNotEmpty) {
          playVideoWithServerSelection(
            context,
            _playLinks.map((l) => {'name': l.name, 'url': l.url, 'quality': l.quality}).toList(),
            _movieDetails?.name ?? 'Movie',
            premium: _isPremium,
            contentId: widget.contentId,
            contentType: 1,
            defaultFallbackUrl: _playLinks.first.url,
          );
        } else {
          _playVideo(_movieDetails?.poster ?? '', _movieDetails?.name ?? 'Movie');
        }
      } else {
        if (_seasons.isNotEmpty && _seasons.first.episodes.isNotEmpty) {
          final firstEp = _seasons.first.episodes.first;
          final epLinks = firstEp.playLinks.map((l) => {'name': l.name, 'url': l.url, 'quality': l.quality}).toList();
          playVideoWithServerSelection(
            context,
            epLinks,
            firstEp.name,
            premium: _isPremium,
            contentId: widget.contentId,
            contentType: 2,
            defaultFallbackUrl: firstEp.playLinks.isNotEmpty ? firstEp.playLinks.first.url : '',
          );
        }
      }
    };

    final watchlistCallback = () async {
      final id = widget.contentId;
      final type = widget.itemType;
      final isMovie = type == 'movie' || type == '1';
      final typeNum = isMovie ? 1 : 2;
      final favs = await ApiService.getFavorites();
      final exists = favs.any((f) =>
          int.tryParse('${f['content_id']}') == id &&
          int.tryParse('${f['content_type']}') == typeNum);
      final res = exists
          ? await ApiService.removeFavorite(id, type)
          : await ApiService.addFavorite(id, type,
              name: _movieDetails?.name ?? '',
              poster: _movieDetails?.poster ?? '');
      if (!mounted) return;
      final success = res['status'] == 'success';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? (exists
                  ? "${_movieDetails?.name ?? ''} removed from Favorites"
                  : "${_movieDetails?.name ?? ''} added to Favorites")
              : "Couldn't update favorites. Try again."),
          duration: const Duration(seconds: 2),
          backgroundColor: success ? (exists ? Colors.red : Colors.green) : Colors.grey.shade700,
        ),
      );
    };

    final shareCallback = () {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Share ${_movieDetails?.name ?? 'Movie'} link..."),
          duration: const Duration(seconds: 1),
        ),
      );
    };

    final playEpisodeCallback = (String url, String title) {
      _playVideo(url, title);
    };

    final navigateCallback = (int id, String type) {
      _navigateToRelated(id, type);
    };

    if (_isMovie) {
      return AuroraGlassLayout(
        data: data,
        onPlay: playCallback,
        onWatchlist: watchlistCallback,
        onShare: shareCallback,
        onPlayEpisode: playEpisodeCallback,
        onNavigateToContent: navigateCallback,
      );
    } else {
      return AuroraGlassSeriesLayout(
        data: data,
        onPlay: playCallback,
        onWatchlist: watchlistCallback,
        onShare: shareCallback,
        onPlayEpisode: playEpisodeCallback,
        onNavigateToContent: navigateCallback,
      );
    }
  }

  Widget _buildErrorView() {
    return AppErrorView(
      message: friendlyError(_errorMessage, 'Failed to load content details.'),
      onRetry: _loadDetails,
    );
  }

  Widget _buildShimmerLoading() {
    return const DetailsLoadingView();
  }
}
