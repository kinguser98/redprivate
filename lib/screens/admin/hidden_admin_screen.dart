import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../config/api_config.dart';
import '../streamtape_domains_screen.dart';
import 'fly_mode_manager_screen.dart';

class HiddenAdminScreen extends StatefulWidget {
  const HiddenAdminScreen({Key? key}) : super(key: key);

  @override
  State<HiddenAdminScreen> createState() => _HiddenAdminScreenState();
}

class _HiddenAdminScreenState extends State<HiddenAdminScreen> {
  int _selectedIndex = 0;
  String _deadFilter = 'all';

  final List<String> _navLabels = [
    'Studio Overview',
    'Views & Ranking Manager',
    'Add Movie / Web Series',
    'Movies Catalog',
    'Web Series Catalog',
    'Upcoming Schedule',
    'OTT Platforms & Genres',
    'Cast & Networks',
    'Users & VIP Subscriptions',
    'Coupon Codes',
    'Dead Link Diagnostic Engine',
    'Link Updater (Domain Replace)',
    'App Settings',
    'Push Campaigns & Announcements',
    'User Reports Manager',
    'Streamtape Domains Manager',
    'Live Telemetry & Analytics',
    'SkyMoviesHD Auto Importer',
    'HDMove99 Auto Importer',
    'Aagmaal Auto Importer',
    'Fly Mode Manager',
  ];

  final List<IconData> _navIcons = [
    Icons.dashboard_rounded,
    Icons.trending_up_rounded,
    Icons.add_to_photos_rounded,
    Icons.movie_filter_rounded,
    Icons.video_collection_rounded,
    Icons.calendar_today_rounded,
    Icons.live_tv_rounded,
    Icons.recent_actors_rounded,
    Icons.admin_panel_settings_rounded,
    Icons.confirmation_number_rounded,
    Icons.health_and_safety_rounded,
    Icons.swap_horiz_rounded,
    Icons.settings_suggest_rounded,
    Icons.send_rounded,
    Icons.report_rounded,
    Icons.dns_rounded,
    Icons.analytics_rounded,
    Icons.cloud_download_rounded,
    Icons.video_library_rounded,
    Icons.local_fire_department_rounded,
    Icons.flight_takeoff_rounded,
  ];

  // Data lists
  List<dynamic> _movies = [];
  List<dynamic> _series = [];
  List<dynamic> _upcoming = [];
  List<dynamic> _cast = [];
  List<dynamic> _genres = [];
  List<dynamic> _users = [];
  Set<int> _selectedUserIds = {};
  bool _usersSelectMode = false;
  List<dynamic> _parkedMovies = [];
  List<dynamic> _parkedSeries = [];
  List<String> _dbCustomTags = ['HD', '4K', 'VIP', 'PREMIUM', 'TRENDING', 'EXCLUSIVE', 'POPULAR'];

  bool _isLoading = false;
  String _movieCatalogQuery = '';
  String _seriesCatalogQuery = '';
  String _movieCatalogOttFilter = '';
  String _seriesCatalogOttFilter = '';
  String _selectedOttFilter = 'All';
  bool _ottGridView = false;
  String _ottQuery = '';
  String _castQuery = '';
  String _usersQuery = '';
  List<dynamic> _coupons = [];
  bool _couponsLoaded = false;
  bool _parkedLoading = false;
  String _deadQuery = '';
  String _deadOttFilter = '';
  bool _deadSelectMode = false;
  final Set<String> _deadSelected = {};
  // Dead Scanner State

  bool _scanning = false;
  bool _scanDone = false;
  int _movieChecked = 0, _movieTotal = 0, _movieDead = 0;
  int _epChecked = 0, _epTotal = 0, _epDead = 0;


  // HDMove99 Auto Importer State
  List<dynamic> _hdmove99Catalog = [];
  bool _hdmove99Loading = false;
  int _hdmove99Page = 1;
  final _hdmove99SearchCtrl = TextEditingController();

  // Aagmaal Auto Importer State
  List<dynamic> _aagmaalCatalog = [];
  bool _aagmaalLoading = false;
  int _aagmaalPage = 1;
  final _aagmaalSearchCtrl = TextEditingController();

  // Form Controllers
  final _addTitleCtrl = TextEditingController();
  final _addDescCtrl = TextEditingController();
  final _addReleaseDateCtrl = TextEditingController(text: DateTime.now().toString().split(' ')[0]);
  final _addRuntimeCtrl = TextEditingController(text: '120 min');
  final _addTrailerCtrl = TextEditingController();
  final _addThumbUrlCtrl = TextEditingController();
  final _addPosterUrlCtrl = TextEditingController();
  final _addStreamUrlCtrl = TextEditingController();
  final _tmdbIdCtrl = TextEditingController();
  final TextEditingController _skymoviesDomainCtrl = TextEditingController(text: 'https://skymovieshd.ceo');
  final TextEditingController _hdmaalDomainCtrl = TextEditingController(text: 'https://hdmaal.gg');
  final TextEditingController _uncutmastiDomainCtrl = TextEditingController(text: 'https://uncutmasti.com');
  final TextEditingController _hdmove99DomainCtrl = TextEditingController(text: 'https://hdmove99.com');
  final TextEditingController _aagmaalDomainCtrl = TextEditingController(text: 'https://aagmaal.mba');
  final TextEditingController _uffmaalDomainCtrl = TextEditingController(text: 'https://uffmaal.com');
  List<dynamic> _skymoviesCatalog = [];
  bool _skymoviesLoading = false;
  String _skymoviesCat = 'Hot-Short-Film';
  int _skymoviesPage = 1;


  String _addType = 'movie';
  String _addCustomTag = 'HD';
  String _addTier = 'Free';
  String _streamType = 'MP4/MKV Direct Link';
  bool _enableDownload = true;

  // Taxonomy data for OTT genres & cast networks
  List<dynamic> _ottGenres = [];
  List<dynamic> _castNetworks = [];
  Set<int> _selectedOttGenreIds = {};
  Set<int> _selectedCastNetworkIds = {};

  // Editing state
  Map<String, dynamic>? _editingItem;

  // Push Campaigns & Announcements state
  int _pushSubTab = 0;
  final _pushTitleCtrl = TextEditingController(text: 'Newly Uploaded Today!');
  int _pushHoursValid = 24;
  final Set<String> _selectedPushItemKeys = {};
  String _pushCatalogSearch = '';
  List<dynamic> _pushCampaignsList = [];

  final _annTitleCtrl = TextEditingController(text: 'Important Update');
  final _annMessageCtrl = TextEditingController();
  final _annImageUrlCtrl = TextEditingController();
  int _annHoursValid = 72;
  List<dynamic> _announcementsList = [];
  List<Map<String, dynamic>> _extraMovieServers = [];

  @override
  void initState() {
    super.initState();
    _addPosterUrlCtrl.addListener(() => setState(() {}));
    _addThumbUrlCtrl.addListener(() => setState(() {}));
    _loadDashboardData();
    _fetchTaxonomy();
    _loadPushCampaigns();
    _loadAnnouncements();
  }

  @override
  void dispose() {
    _addTitleCtrl.dispose();
    _addDescCtrl.dispose();
    _addReleaseDateCtrl.dispose();
    _addRuntimeCtrl.dispose();
    _addTrailerCtrl.dispose();
    _addThumbUrlCtrl.dispose();
    _addPosterUrlCtrl.dispose();
    _addStreamUrlCtrl.dispose();
    _tmdbIdCtrl.dispose();
    _pushTitleCtrl.dispose();
    _annTitleCtrl.dispose();
    _annMessageCtrl.dispose();
    _annImageUrlCtrl.dispose();
    super.dispose();
  }

  // REST API Client (Dooo) - REMOVED: all data now comes from our custom admin_api.php

  // Admin PHP API Client
  Future<Map<String, dynamic>> _adminPhpApi(String action, Map<String, dynamic> body, {int timeout = 45}) async {
    try {
      final res = await http.post(
        Uri.parse(ApiConfig.adminUrl),
        body: json.encode({...body, 'action': action}),
        headers: {'Content-Type': 'application/json'},
      ).timeout(Duration(seconds: timeout));

      final String raw = res.body.trim();
      if (raw.startsWith('{') && raw.endsWith('}')) {
        return json.decode(raw);
      }
      if (raw.toLowerCase().contains('success') || raw.contains('1')) {
        return {'status': 'success', 'message': 'Operation completed successfully'};
      }
      return {'status': 'error', 'message': 'Server output: $raw'};
    } catch (e) {
      return {'status': 'error', 'message': '$e'};
    }
  }

  // Analytics & Views Ranking State
  Map<String, dynamic> _analyticsData = {};
  List<dynamic> _reportsList = [];
  bool _reportsLoading = false;
  bool _analyticsLoading = false;
  String _viewsQuery = '';
  String _reportsQuery = '';
  String _viewsTypeFilter = 'all';

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      // Run all independent loads in parallel for a fast refresh
      await Future.wait([
        _loadMovies(),
        _loadSeries(),
        _loadGenresNetworks(),
        _loadUpcoming(),
        _loadUsers(),
        _loadAnalytics(),
        _loadReports(),
      ]);
      // Parked content is loaded lazily when the Dead Scanner tab opens
    } catch (e) {
      print("Dashboard load error: $e");
    }
    setState(() => _isLoading = false);
  }

  Future<void> _loadAnalytics() async {
    _analyticsLoading = true;
    final res = await _adminPhpApi('get_analytics', {});
    if (res['status'] == 'success' && res['data'] != null) {
      setState(() {
        _analyticsData = res['data'];
      });
    }
    _analyticsLoading = false;
  }

  Future<void> _updateViews(String type, int id, int views, int weeklyViews) async {
    final res = await _adminPhpApi('update_views', {
      'type': type,
      'id': id,
      'views': views,
      'weekly_views': weeklyViews,
    });
    if (res['status'] == 'success') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("View count & ranking updated successfully!"), backgroundColor: Colors.green),
      );
      _loadDashboardData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${res['message']}"), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _resetAllViews() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161A26),
        title: const Text("Reset All View Counts?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text("This will reset all total views and weekly views to 0 for all movies and web series. New views will count live as users open content details.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Reset All to 0", style: TextStyle(color: Color(0xFFFF1744), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final res = await _adminPhpApi('reset_all_views', {});
      if (res['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("All view counts reset to 0!"), backgroundColor: Colors.green),
        );
        _loadDashboardData();
      }
    }
  }

  Future<void> _loadMovies() async {
    final mRes = await _adminPhpApi('list_movies', {});
    if (mRes['status'] == 'success' && mRes['data']?['movies'] != null) {
      setState(() => _movies = List<Map<String,dynamic>>.from(mRes['data']['movies']));
    }
  }

  Future<void> _loadSeries() async {
    final sRes = await _adminPhpApi('list_series', {});
    if (sRes['status'] == 'success' && sRes['data']?['series'] != null) {
      setState(() => _series = List<Map<String,dynamic>>.from(sRes['data']['series']));
    }
  }

  Future<void> _loadGenresNetworks() async {
    final gRes = await _adminPhpApi('list_genres', {});
    if (gRes['status'] == 'success' && gRes['data']?['genres'] != null) {
      _genres = List<Map<String,dynamic>>.from(gRes['data']['genres']);
    }
    final nRes = await _adminPhpApi('get_taxonomy', {});
    if (nRes['status'] == 'success' && nRes['data']?['cast_networks'] != null) {
      _cast = List<Map<String,dynamic>>.from(nRes['data']['cast_networks']);
    }
  }

  Future<void> _loadUpcoming() async {
    final upRes = await _adminPhpApi('list_upcoming', {});
    if (upRes['status'] == 'success' && upRes['data']?['upcoming'] != null) {
      setState(() => _upcoming = List<Map<String,dynamic>>.from(upRes['data']['upcoming']));
    }
  }

  Future<void> _loadUsers() async {
    final uRes = await _adminPhpApi('list_users', {});
    if (uRes['status'] == 'success' && uRes['data']?['users'] != null) {
      _users = uRes['data']['users'];
    }
  }

  Future<void> _loadParked() async {
    if (_parkedLoading) return;
    _parkedLoading = true;
    final d = await _adminPhpApi('get_parked', {});
    _parkedLoading = false;
    if (d['status'] == 'success' && d['data'] != null) {
      setState(() {
        _parkedMovies = d['data']['movies'] ?? [];
        _parkedSeries = d['data']['series'] ?? [];
      });
    }
  }

  // Fetch TMDb Data
  Future<void> _fetchTmdbData() async {
    final tmdbId = _tmdbIdCtrl.text.trim();
    if (tmdbId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Enter a valid TMDb ID")));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Fetching TMDb Data...")));
    try {
      final url = "https://api.themoviedb.org/3/movie/$tmdbId?api_key=15d22307d15a19b26b3de92343b09970";
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          _addTitleCtrl.text = data['title'] ?? data['name'] ?? '';
          _addDescCtrl.text = data['overview'] ?? '';
          _addReleaseDateCtrl.text = data['release_date'] ?? data['first_air_date'] ?? '';
          _addRuntimeCtrl.text = "${data['runtime'] ?? 120} min";
          final movieTitle = _addTitleCtrl.text.trim();
          if (data['poster_path'] != null) {
            final rawTmdbPoster = "https://image.tmdb.org/t/p/w500${data['poster_path']}";
            _uploadImageUrlToServer(rawTmdbPoster, customTitle: movieTitle).then((serverUrl) {
              if (serverUrl != null && mounted) {
                setState(() => _addPosterUrlCtrl.text = serverUrl);
              }
            });
          }
          if (data['backdrop_path'] != null) {
            final rawTmdbBackdrop = "https://image.tmdb.org/t/p/w780${data['backdrop_path']}";
            _uploadImageUrlToServer(rawTmdbBackdrop, customTitle: '${movieTitle}_banner').then((serverUrl) {
              if (serverUrl != null && mounted) {
                setState(() => _addThumbUrlCtrl.text = serverUrl);
              }
            });
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("TMDb Data Auto-Filled!"), backgroundColor: Colors.green));
      }
    } catch (e) {
      print("TMDb fetch error: $e");
    }
  }

  // Fetch OTT Genres, Cast Networks & custom tags from DB
  Future<void> _fetchTaxonomy() async {
    final res = await _adminPhpApi('get_taxonomy', {});
    if (res['status'] == 'success' && res['data'] != null) {
      setState(() {
        _ottGenres = res['data']['ott_platforms'] ?? [];
        _castNetworks = res['data']['cast_networks'] ?? [];
        final dbTags = (res['data']['custom_tags'] as List? ?? [])
            .map((t) => (t is Map ? (t['name'] ?? '') : t).toString())
            .where((n) => n.isNotEmpty)
            .toList();
        if (dbTags.isNotEmpty) _dbCustomTags = dbTags;
      });
    }
  }

  // Start editing an item — prefills the form and switches to studio tab
  void _startEdit(Map<String, dynamic> item, String type) {
    final links = (item['play_links'] as List<dynamic>? ?? []);
    final firstLink = links.isNotEmpty ? (links[0] as Map? ?? const {}) : const {};
    final existingUrl = (firstLink['url'] ?? item['stream_url'] ?? '').toString();
    final existingType = (firstLink['type'] ?? '').toString().toLowerCase();
    String guessedStreamType = _streamType;
    if (existingType.contains('xhamster') ||
        existingUrl.contains('xhamster') ||
        existingUrl.contains('xhvid') ||
        existingUrl.contains('xh.video')) {
      guessedStreamType = 'xHamster Stream';
    } else if (existingType.contains('luluvdo') ||
        existingUrl.contains('luluvdo') ||
        existingUrl.contains('lulustream') ||
        existingUrl.contains('lulucdn')) {
      guessedStreamType = 'Luluvdo Stream';
    } else if (existingType.contains('hls') ||
        existingType.contains('m3u8') ||
        existingUrl.contains('.m3u8')) {
      guessedStreamType = 'HLS/M3U8 Stream';
    } else if (existingType.contains('streamtape') ||
        existingUrl.contains('streamtape') ||
        existingUrl.contains('tapepops') ||
        existingUrl.contains('advtpe') ||
        existingUrl.contains('tpead')) {
      guessedStreamType = 'Streamtape Stream';
    } else if (existingType.contains('embed') ||
        existingUrl.contains('iframe') ||
        existingUrl.contains('player')) {
      guessedStreamType = 'Embed Player';
    } else {
      guessedStreamType = 'MP4/MKV Direct Link';
    }
    setState(() {
      _editingItem = item;
      _addType = type;
      _addTitleCtrl.text = item['name'] ?? '';
      _addDescCtrl.text = item['description'] ?? '';
      _addPosterUrlCtrl.text = item['poster'] ?? '';
      _addThumbUrlCtrl.text = item['banner'] ?? '';
      _addReleaseDateCtrl.text = item['release_date'] ?? '';
      _addRuntimeCtrl.text = item['runtime'] ?? '';
      _addCustomTag = (item['custom_tag'] ?? 'HD').toString();
      if (!_dbCustomTags.contains(_addCustomTag)) {
        _dbCustomTags = [..._dbCustomTags, _addCustomTag];
      }
      _addStreamUrlCtrl.text = existingUrl;
      _streamType = guessedStreamType;
      _selectedOttGenreIds.clear();
      _selectedCastNetworkIds.clear();
      
      // Parse genres (contains IDs or names)
      final genresStr = (item['genres'] ?? '').toString();
      if (genresStr.isNotEmpty) {
        for (final g in _ottGenres) {
          final gIdStr = (g['id'] ?? '').toString().trim();
          final gNameStr = (g['name'] ?? '').toString().trim();
          if (genresStr.split(',').any((n) => n.trim() == gIdStr || n.trim() == gNameStr)) {
            _selectedOttGenreIds.add(g['id'] is int ? g['id'] : int.tryParse('${g['id']}') ?? 0);
          }
        }
      }

      // Parse cast networks (contains IDs)
      final netIdsStr = (item['network_ids'] ?? item['network'] ?? '').toString();
      if (netIdsStr.isNotEmpty) {
        for (final idStr in netIdsStr.split(',')) {
          final id = int.tryParse(idStr.trim());
          if (id != null) {
            _selectedCastNetworkIds.add(id);
          }
        }
      }
      _selectedIndex = 2; // Switch to Add Movie / Web Series tab
    });
    // For series: lazily load full episode play_links (not included in list for speed)
    if (type == 'series') {
      final seriesId = item['id'];
      _adminPhpApi('get_series_episodes', {'series_id': seriesId}).then((res) {
        if (!mounted) return;
        if (res['status'] == 'success' && res['data']?['seasons'] != null) {
          setState(() {
            // Merge loaded seasons (with play_links) back into _editingItem
            if (_editingItem != null && _editingItem!['id'] == seriesId) {
              _editingItem!['seasons'] = res['data']['seasons'];
              // Also update the item in _series list
              final idx = _series.indexWhere((s) => s['id'] == seriesId);
              if (idx >= 0) _series[idx]['seasons'] = res['data']['seasons'];
            }
          });
        }
      }).catchError((_) {}); // Silently ignore — series can still be viewed/edited
    }
  }

  // Upload any image URL to our server, saving it named after the movie/series
  Future<String?> _uploadImageUrlToServer(String rawUrl, {String? customTitle, bool showNotification = true}) async {
    final url = rawUrl.trim();
    if (url.isEmpty) return null;
    if (url.contains('goprivate.fun/api/uploads')) return url;

    final title = (customTitle != null && customTitle.isNotEmpty)
        ? customTitle
        : _addTitleCtrl.text.trim();

    try {
      if (showNotification && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                SizedBox(width: 12),
                Text("Uploading image to server..."),
              ],
            ),
            duration: Duration(seconds: 15),
            backgroundColor: Color(0xFF1E2436),
          ),
        );
      }

      final res = await _adminPhpApi('upload_image', {
        'image_url': url,
        'title': title,
      });

      if (mounted && showNotification) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }

      if (res['status'] == 'success' && res['data']?['url'] != null) {
        final serverUrl = res['data']['url'].toString();
        if (showNotification && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Image uploaded to server successfully!"), backgroundColor: Colors.green, duration: Duration(seconds: 2)),
          );
        }
        return serverUrl;
      } else {
        if (showNotification && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Upload error: ${res['message'] ?? 'Failed'}"), backgroundColor: Colors.red),
          );
        }
        return null;
      }
    } catch (e) {
      if (showNotification && mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Upload error: $e"), backgroundColor: Colors.red),
        );
      }
      return null;
    }
  }

  // Save Content Action (Adds/Updates DB + Instantly updates catalog UI)
  Future<void> _submitAddContent() async {
    final title = _addTitleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Title is required")));
      return;
    }

    // Auto-upload poster if external URL
    if (_addPosterUrlCtrl.text.trim().isNotEmpty && !_addPosterUrlCtrl.text.contains('goprivate.fun/api/uploads')) {
      final uploaded = await _uploadImageUrlToServer(_addPosterUrlCtrl.text.trim(), customTitle: title, showNotification: true);
      if (uploaded != null && uploaded.isNotEmpty) {
        _addPosterUrlCtrl.text = uploaded;
      }
    }
    // Auto-upload banner if external URL
    if (_addThumbUrlCtrl.text.trim().isNotEmpty && !_addThumbUrlCtrl.text.contains('goprivate.fun/api/uploads')) {
      final uploaded = await _uploadImageUrlToServer(_addThumbUrlCtrl.text.trim(), customTitle: '${title}_banner', showNotification: true);
      if (uploaded != null && uploaded.isNotEmpty) {
        _addThumbUrlCtrl.text = uploaded;
      }
    }

    final newContent = {
      'id': _editingItem?['id'] ?? DateTime.now().millisecondsSinceEpoch,
      'name': title,
      'description': _addDescCtrl.text.trim(),
      'poster': _addPosterUrlCtrl.text.trim(),
      'banner': _addThumbUrlCtrl.text.trim(),
      'release_date': _addReleaseDateCtrl.text.trim(),
      'runtime': _addRuntimeCtrl.text.trim(),
      'custom_tag': _addCustomTag,
      'rating': '8.5',
      'status': '1',
      'type': _addType == 'movie' ? '1' : '2',
      'stream_url': _addStreamUrlCtrl.text.trim(),
      'genres': _selectedOttGenreIds.join(','),
      'network': _selectedCastNetworkIds.join(','),
    };

    final isEdit = _editingItem != null;

    final List<Map<String, String>> moviePlayLinksPayload = [];
    if (_addStreamUrlCtrl.text.trim().isNotEmpty) {
      moviePlayLinksPayload.add({
        'name': 'Server 1',
        'type': _streamType,
        'quality': '720p',
        'url': _addStreamUrlCtrl.text.trim(),
      });
    }
    for (int i = 0; i < _extraMovieServers.length; i++) {
      final s = _extraMovieServers[i];
      final ctrl = s['ctrl'] as TextEditingController;
      final url = ctrl.text.trim();
      if (url.isNotEmpty) {
        moviePlayLinksPayload.add({
          'name': (s['name'] ?? 'Server ${i + 2}').toString(),
          'type': (s['type'] ?? 'MP4/MKV Direct Link').toString(),
          'quality': '720p',
          'url': url,
        });
      }
    }

    if (isEdit) {
      // Update existing content
      final action = _addType == 'movie' ? 'edit_movie' : 'edit_series';
      final res = await _adminPhpApi(action, {
        'id': _editingItem!['id'],
        'name': title,
        'description': _addDescCtrl.text.trim(),
        'poster': _addPosterUrlCtrl.text.trim(),
        'banner': _addThumbUrlCtrl.text.trim(),
        'release_date': _addReleaseDateCtrl.text.trim(),
        'custom_tag': _addCustomTag,
        'genres': _selectedOttGenreIds.join(','),
        'network': _selectedCastNetworkIds.join(','),
        'stream_url': _addStreamUrlCtrl.text.trim(),
        'stream_type': _streamType,
        'play_links': moviePlayLinksPayload,
      });
      if (res['status'] != 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Update failed: ${res['message'] ?? 'Unknown error'}"), backgroundColor: Colors.red),
        );
        return;
      }
      // Update local catalog
      setState(() {
        if (_addType == 'movie') {
          final idx = _movies.indexWhere((m) => m['id'] == _editingItem!['id']);
          if (idx >= 0) _movies[idx] = newContent;
        } else {
          final idx = _series.indexWhere((s) => s['id'] == _editingItem!['id']);
          if (idx >= 0) _series[idx] = newContent;
        }
        _editingItem = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${_addType.toUpperCase()} Updated!"), backgroundColor: Colors.green),
      );
    } else {
      // Send backend add request and wait for response
      final res = await _adminPhpApi('add_content', {
        'item_type': _addType,
        'name': title,
        'description': _addDescCtrl.text.trim(),
        'poster': _addPosterUrlCtrl.text.trim(),
        'banner': _addThumbUrlCtrl.text.trim(),
        'release_date': _addReleaseDateCtrl.text.trim(),
        'runtime': _addRuntimeCtrl.text.trim(),
        'youtube_trailer': _addTrailerCtrl.text.trim(),
        'custom_tag': _addCustomTag,
        'content_type': _addTier,
        'downloadable': _enableDownload ? 1 : 0,
        'stream_url': _addStreamUrlCtrl.text.trim(),
        'stream_type': _streamType,
        'play_links': moviePlayLinksPayload,
        'status': 1,
        'genres': _selectedOttGenreIds.join(','),
        'network': _selectedCastNetworkIds.join(','),
      });

      if (res['status'] != 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save to database: ${res['message'] ?? 'Unknown error'}"), backgroundColor: Colors.red),
        );
        return;
      }

      // Update newContent['id'] with the REAL auto-increment ID returned by server
      final realId = res['data']?['id'] ?? res['data']?['content_id'];
      if (realId != null) {
        final parsedId = int.tryParse(realId.toString());
        if (parsedId != null && parsedId > 0) {
          newContent['id'] = parsedId;
        }
      }

      // Instantly add to local catalog list and switch to catalog view!
      setState(() {
        if (_addType == 'movie') {
          _movies.insert(0, newContent);
          _selectedIndex = 3; // Jump to Movies Catalog
        } else {
          _series.insert(0, newContent);
          _selectedIndex = 4; // Jump to Web Series Catalog
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${_addType.toUpperCase()} Added & Displayed in Catalog!"), backgroundColor: Colors.green),
      );
    }

    _addTitleCtrl.clear();
    _addDescCtrl.clear();
    _addPosterUrlCtrl.clear();
    _addThumbUrlCtrl.clear();
    _addStreamUrlCtrl.clear();
    setState(() {
      _selectedOttGenreIds.clear();
      _selectedCastNetworkIds.clear();
      _editingItem = null;
    });
  }

  // Episode & Season Manager Modal — two-level flow:
  // Level 1: Seasons list (add / edit / delete season)
  // Level 2: Episodes of a season (add / edit / delete episode)
  void _openEpisodeManagerModal(dynamic seriesItem) {
    final String seriesTitle = seriesItem['name'] ?? 'Web Series';
    final int seriesId = int.tryParse(seriesItem['id']?.toString() ?? '') ?? 0;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.65),
      barrierDismissible: true,
      builder: (ctx) {
        List<dynamic> seasons = [];
        bool loading = true;
        bool loadStarted = false;
        bool inSeasonView = false;
        dynamic currentSeason;
        List<dynamic> currentEpisodes = [];

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            Future<void> refresh() async {
              final s = await _loadEpisodes(seriesId);
              setModalState(() {
                if (s != null) {
                  seasons = s;
                  if (currentSeason != null) {
                    final sid = currentSeason!['id'];
                    dynamic match;
                    for (final se in s) {
                      if (se['id'] == sid) { match = se; break; }
                    }
                    if (match != null) {
                      currentSeason = match;
                      currentEpisodes = (match['episodes'] as List<dynamic>?) ?? [];
                    }
                  }
                }
                loading = false;
              });
            }

            if (loading && !loadStarted) {
              loadStarted = true;
              refresh();
            }

            // ── Season add / edit dialog ──
            Future<void> showSeasonDialog({dynamic existing}) async {
              final isEdit = existing != null;
              final list = List.generate(10, (i) => "Season ${i + 1}");
              String selectedName = existing != null ? (existing['Session_Name'] ?? '').toString().trim() : 'Season 1';
              if (selectedName.isEmpty) selectedName = 'Season 1';
              if (!list.contains(selectedName)) {
                list.add(selectedName);
              }

              final orderCtrl = TextEditingController(
                  text: existing != null ? '${existing['season_order'] ?? seasons.length + 1}' : '${seasons.length + 1}');
              await showDialog(
                context: ctx,
                builder: (dctx) => StatefulBuilder(
                  builder: (context, dsetState) => Dialog(
                    backgroundColor: const Color(0xFF0F131D),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: Colors.white.withOpacity(0.1))),
                    insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.9,
                      constraints: const BoxConstraints(maxWidth: 420),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: Colors.cyanAccent.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                                child: const Icon(Icons.video_collection_rounded, color: Colors.cyanAccent, size: 20),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  isEdit ? "Edit Season" : "Add New Season",
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(dctx),
                                icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 18),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF141722),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedName,
                                dropdownColor: const Color(0xFF141722),
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                isExpanded: true,
                                items: list.map((s) => DropdownMenuItem<String>(
                                  value: s,
                                  child: Text(s, style: const TextStyle(color: Colors.white)),
                                )).toList(),
                                onChanged: (val) {
                                  if (val != null) dsetState(() => selectedName = val);
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF141722),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: TextField(
                              controller: orderCtrl,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              decoration: const InputDecoration(
                                labelText: "Season Order",
                                labelStyle: TextStyle(color: Colors.white60, fontSize: 12),
                                prefixIcon: Icon(Icons.format_list_numbered_rounded, color: Colors.cyanAccent, size: 18),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () => Navigator.pop(dctx),
                                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                                  child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    final name = selectedName.trim();
                                    if (name.isEmpty) return;
                                    Map<String, dynamic> res;
                                    if (seriesId <= 0) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text("Please publish or save the Web Series first before adding seasons."), backgroundColor: Colors.orangeAccent),
                                      );
                                      return;
                                    }
                                    if (isEdit) {
                                      res = await _adminPhpApi('edit_season', {
                                        'id': existing['id'],
                                        'name': name,
                                        'season_order': int.tryParse(orderCtrl.text.trim()) ?? existing['season_order'] ?? 0,
                                      });
                                    } else {
                                      res = await _adminPhpApi('add_season', {
                                        'series_id': seriesId,
                                        'name': name,
                                        'order': int.tryParse(orderCtrl.text.trim()) ?? (seasons.length + 1),
                                      });
                                    }
                                    if (dctx.mounted) Navigator.pop(dctx);
                                    if (res['status'] == 'success') {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(isEdit ? "Season updated!" : "Season added!"), backgroundColor: Colors.green),
                                      );
                                      await refresh();
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text("Failed: ${res['message'] ?? 'Unknown error'}"), backgroundColor: Colors.red),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.check_circle_rounded, size: 16),
                                  label: Text(isEdit ? "SAVE CHANGES" : "ADD SEASON", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.cyanAccent,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    elevation: 0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }

            // ── Season delete with confirm ──
            Future<void> confirmDeleteSeason(dynamic season) async {
              final ok = await showDialog<bool>(
                context: ctx,
                builder: (dctx) => AlertDialog(
                  backgroundColor: const Color(0xFF1A2132),
                  surfaceTintColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: Colors.white.withOpacity(0.08))),
                  title: const Text("Delete Season?", style: TextStyle(color: Colors.white)),
                  content: Text(
                    "Delete '${(season['Session_Name'] ?? '').toString().trim()}' and all its episodes?",
                    style: const TextStyle(color: Colors.white70),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(dctx, false), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
                    TextButton(onPressed: () => Navigator.pop(dctx, true), child: const Text("Delete", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
                  ],
                ),
              );
              if (ok == true) {
                final res = await _adminPhpApi('delete_season', {'id': season['id']});
                setModalState(() {
                  if (currentSeason != null && currentSeason!['id'] == season['id']) {
                    currentSeason = null;
                    currentEpisodes = [];
                    inSeasonView = false;
                  }
                });
                if (res['status'] == 'success') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Season deleted!"), backgroundColor: Colors.green),
                  );
                  await refresh();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Failed: ${res['message'] ?? 'Unknown error'}"), backgroundColor: Colors.red),
                  );
                }
              }
            }

            // ── Episode add / edit dialog ──
            Future<void> showEpisodeDialog({dynamic existing}) async {
              final links = existing != null ? (existing['play_links'] as List<dynamic>? ?? []) : [];
              final firstLink = links.isNotEmpty ? links[0] : null;
              final isEdit = existing != null;

              final epNamesList = <String>[];
              for (int i = 1; i <= 10; i++) {
                epNamesList.add("Episode $i");
                epNamesList.add("Part $i");
              }
              String selectedEpName = existing != null ? (existing['Episoade_Name'] ?? '').toString().trim() : 'Episode 1';
              if (selectedEpName.isEmpty) selectedEpName = 'Episode 1';
              if (!epNamesList.contains(selectedEpName)) {
                epNamesList.add(selectedEpName);
              }

              final qualitiesList = ['480p', '720p', '1080p'];
              String selectedQuality = existing != null ? (firstLink?['quality'] ?? '720p').toString().trim() : '720p';
              if (selectedQuality.isEmpty) selectedQuality = '720p';
              if (!qualitiesList.contains(selectedQuality)) {
                qualitiesList.add(selectedQuality);
              }

              final epImageCtrl = TextEditingController(
                  text: existing != null ? (existing['episoade_image'] ?? '').toString() : '');
              final epUrlCtrl = TextEditingController(
                  text: existing != null ? (firstLink?['url'] ?? '').toString() : '');
              final epOrderCtrl = TextEditingController(
                  text: existing != null ? '${existing['episoade_order'] ?? existing['order'] ?? 1}' : '${currentEpisodes.length + 1}');
              bool checkingEpLink = false;

              String epStreamType = existing != null
                  ? (firstLink?['type'] ?? 'MP4/MKV Direct Link').toString()
                  : 'MP4/MKV Direct Link';

              await showDialog(
                context: ctx,
                builder: (dctx) => StatefulBuilder(
                  builder: (dctx2, setDlgState) => Dialog(
                    backgroundColor: const Color(0xFF0F131D),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: Colors.white.withOpacity(0.1))),
                    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.95,
                      constraints: const BoxConstraints(maxWidth: 480),
                      padding: const EdgeInsets.all(20),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: Colors.purpleAccent.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                                  child: const Icon(Icons.tv_rounded, color: Colors.purpleAccent, size: 20),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isEdit ? "Edit Episode" : "Add New Episode",
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      Text(
                                        "Season: ${(currentSeason?['Session_Name'] ?? 'Season').toString().trim()}",
                                        style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => Navigator.pop(dctx),
                                  icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 18),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Episode Name & Order in Row
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF141722),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white12),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: selectedEpName,
                                        dropdownColor: const Color(0xFF141722),
                                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                        isExpanded: true,
                                        items: epNamesList.map((s) => DropdownMenuItem<String>(
                                          value: s,
                                          child: Text(s, style: const TextStyle(color: Colors.white)),
                                        )).toList(),
                                        onChanged: (val) {
                                          if (val != null) setDlgState(() => selectedEpName = val);
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF141722),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white12),
                                    ),
                                    child: TextField(
                                      controller: epOrderCtrl,
                                      keyboardType: TextInputType.number,
                                      style: const TextStyle(color: Colors.white, fontSize: 12),
                                      decoration: const InputDecoration(
                                        labelText: "Order",
                                        labelStyle: TextStyle(color: Colors.white60, fontSize: 11),
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Thumbnail Image Input & Live Preview
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF141722),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: TextField(
                                controller: epImageCtrl,
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                                onChanged: (_) => setDlgState(() {}),
                                decoration: const InputDecoration(
                                  hintText: "Episode Thumbnail URL (https://...)",
                                  hintStyle: TextStyle(color: Colors.white30, fontSize: 11),
                                  prefixIcon: Icon(Icons.image_outlined, color: Colors.purpleAccent, size: 18),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ),
                            if (epImageCtrl.text.trim().isNotEmpty) ...[
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: AspectRatio(
                                  aspectRatio: 16 / 9,
                                  child: CachedNetworkImage(
                                    imageUrl: epImageCtrl.text.trim(),
                                    fit: BoxFit.cover,
                                    errorWidget: (c, u, e) => Container(
                                      color: const Color(0xFF141722),
                                      child: const Center(child: Icon(Icons.broken_image_rounded, color: Colors.white24, size: 24)),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),

                            // Stream Source Type & Quality in Row
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF141722),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white12),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: ['MP4/MKV Direct Link', 'Streamtape Stream', 'Luluvdo Stream', 'xHamster Stream', 'HLS/M3U8 Stream', 'Embed Player'].contains(epStreamType) ? epStreamType : 'MP4/MKV Direct Link',
                                        dropdownColor: const Color(0xFF141722),
                                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                        isExpanded: true,
                                        items: ['MP4/MKV Direct Link', 'Streamtape Stream', 'Luluvdo Stream', 'xHamster Stream', 'HLS/M3U8 Stream', 'Embed Player'].map((st) {
                                          return DropdownMenuItem<String>(
                                            value: st,
                                            child: Text(st, style: const TextStyle(color: Colors.white, fontSize: 11)),
                                          );
                                        }).toList(),
                                        onChanged: (val) {
                                          if (val != null) setDlgState(() => epStreamType = val);
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF141722),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white12),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: selectedQuality,
                                        dropdownColor: const Color(0xFF141722),
                                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                        isExpanded: true,
                                        items: qualitiesList.map((s) => DropdownMenuItem<String>(
                                          value: s,
                                          child: Text(s, style: const TextStyle(color: Colors.white, fontSize: 11)),
                                        )).toList(),
                                        onChanged: (val) {
                                          if (val != null) setDlgState(() => selectedQuality = val);
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Stream URL with Check & Quick Extract
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF141722),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white12),
                                    ),
                                    child: TextField(
                                      controller: epUrlCtrl,
                                      style: const TextStyle(color: Colors.white, fontSize: 12),
                                      decoration: const InputDecoration(
                                        hintText: "Stream URL (Server 1)...",
                                        hintStyle: TextStyle(color: Colors.white30, fontSize: 11),
                                        prefixIcon: Icon(Icons.link_rounded, color: Colors.cyanAccent, size: 18),
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                OutlinedButton(
                                  onPressed: checkingEpLink ? null : () async {
                                    final url = epUrlCtrl.text.trim();
                                    if (url.isEmpty) return;
                                    setDlgState(() => checkingEpLink = true);
                                    final res = await _adminPhpApi('check_link', {'url': url});
                                    setDlgState(() => checkingEpLink = false);
                                    if (res['status'] == 'success') {
                                      final ok = res['data']?['ok'] == true;
                                      final code = res['data']?['code'] ?? 0;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(ok ? "Link is LIVE (HTTP $code)" : "Link is DEAD / Failed (HTTP $code)"),
                                          backgroundColor: ok ? Colors.green : Colors.red,
                                        ),
                                      );
                                    }
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.cyanAccent,
                                    side: const BorderSide(color: Colors.cyanAccent, width: 0.8),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  child: checkingEpLink
                                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyanAccent))
                                      : const Text("CHECK", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 4),
                                ElevatedButton.icon(
                                  onPressed: () => _showQuickLinkExtractorDialog((extractedUrl, {posterUrl}) {
                                    setDlgState(() {
                                      epUrlCtrl.text = extractedUrl;
                                      if (posterUrl != null && posterUrl.isNotEmpty) {
                                        epImageCtrl.text = posterUrl;
                                      }
                                    });
                                  }, defaultSearchText: (seriesTitle.isNotEmpty ? seriesTitle : (_editingItem?['name'] ?? _addTitleCtrl.text)).trim()),
                                  icon: const Icon(Icons.bolt_rounded, size: 14),
                                  label: const Text("EXTRACT", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.amberAccent,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    elevation: 0,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Actions
                            Row(
                              children: [
                                Expanded(
                                  child: TextButton(
                                    onPressed: () => Navigator.pop(dctx),
                                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                                    child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 2,
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      if (selectedEpName.isEmpty || epUrlCtrl.text.trim().isEmpty) {
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Episode name and stream URL required")));
                                        return;
                                      }
                                      final epOrder = int.tryParse(epOrderCtrl.text.trim()) ?? (currentEpisodes.length + 1);

                                      final List<Map<String, String>> epPlayLinksPayload = [
                                        {
                                          'name': 'Server 1',
                                          'type': epStreamType,
                                          'quality': selectedQuality,
                                          'url': epUrlCtrl.text.trim(),
                                        }
                                      ];

                                      Map<String, dynamic> res;
                                      if (isEdit) {
                                        res = await _adminPhpApi('update_episode', {
                                          'id': existing['id'],
                                          'Episoade_Name': selectedEpName.trim(),
                                          'episoade_image': epImageCtrl.text.trim(),
                                          'url': epUrlCtrl.text.trim(),
                                          'stream_type': epStreamType,
                                          'quality': selectedQuality,
                                          'order': epOrder,
                                          'play_links': epPlayLinksPayload,
                                        });
                                      } else {
                                        res = await _adminPhpApi('add_episode_link', {
                                          'series_id': seriesId,
                                          'season_name': (currentSeason?['Session_Name'] ?? 'Season').toString().trim(),
                                          'name': selectedEpName.trim(),
                                          'url': epUrlCtrl.text.trim(),
                                          'stream_type': epStreamType,
                                          'episode_image': epImageCtrl.text.trim(),
                                          'quality': selectedQuality,
                                          'order': epOrder,
                                          'play_links': epPlayLinksPayload,
                                        });
                                      }
                                      if (dctx.mounted) Navigator.pop(dctx);
                                      if (res['status'] == 'success') {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text(isEdit ? "Episode updated!" : "Episode added!"), backgroundColor: Colors.green),
                                        );
                                        await refresh();
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text("Failed: ${res['message'] ?? 'Unknown error'}"), backgroundColor: Colors.red),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.check_circle_rounded, size: 16),
                                    label: Text(isEdit ? "SAVE EPISODE" : "ADD EPISODE", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.greenAccent,
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      elevation: 0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }

            // ── Episode delete with confirm ──
            Future<void> confirmDeleteEpisode(dynamic ep) async {
              final ok = await showDialog<bool>(
                context: ctx,
                builder: (dctx) => AlertDialog(
                  backgroundColor: const Color(0xFF1A2132),
                  surfaceTintColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: Colors.white.withOpacity(0.08))),
                  title: const Text("Delete Episode?", style: TextStyle(color: Colors.white)),
                  content: Text(
                    "Delete '${(ep['Episoade_Name'] ?? '').toString().trim()}'?",
                    style: const TextStyle(color: Colors.white70),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(dctx, false), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
                    TextButton(onPressed: () => Navigator.pop(dctx, true), child: const Text("Delete", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
                  ],
                ),
              );
              if (ok == true) {
                final res = await _adminPhpApi('delete_episode', {'id': ep['id']});
                if (res['status'] == 'success') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Episode deleted!"), backgroundColor: Colors.green),
                  );
                  await refresh();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Failed: ${res['message'] ?? 'Unknown error'}"), backgroundColor: Colors.red),
                  );
                }
              }
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 26, sigmaY: 26),
                  child: Container(
                    width: double.maxFinite,
                    constraints: BoxConstraints(
                      maxWidth: 430,
                      maxHeight: MediaQuery.of(ctx).size.height * 0.8,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1E2436), Color(0xFF0D0F16)],
                      ),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.55), blurRadius: 40, offset: const Offset(0, 18)),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.fromLTRB(18, 12, 8, 12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                const Color(0xFF8E2DE2).withOpacity(0.30),
                                const Color(0xFFE50914).withOpacity(0.16),
                                Colors.transparent,
                              ],
                            ),
                            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
                          ),
                          child: Row(
                            children: [
                              if (inSeasonView)
                                IconButton(
                                  onPressed: () => setModalState(() {
                                    inSeasonView = false;
                                    currentSeason = null;
                                    currentEpisodes = [];
                                  }),
                                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70),
                                ),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [Color(0xFF8E2DE2), Color(0xFFE50914)]),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(color: const Color(0xFF8E2DE2).withOpacity(0.4), blurRadius: 14, offset: const Offset(0, 4)),
                                  ],
                                ),
                                child: Icon(
                                  inSeasonView ? Icons.video_library_rounded : Icons.video_collection_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      inSeasonView ? 'EPISODES' : 'SEASONS',
                                      style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.4),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      inSeasonView ? (currentSeason?['Session_Name'] ?? 'Season').toString().trim() : seriesTitle,
                                      style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white60), onPressed: () => Navigator.pop(ctx)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Body
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (loading)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 48),
                                    child: Center(child: CircularProgressIndicator(color: Color(0xFF8E2DE2))),
                                  )
                                else if (!inSeasonView) ...[
                                  // ── Level 1: Seasons list ──
                                  _glassButton(
                                    icon: Icons.add_rounded,
                                    label: 'ADD NEW SEASON',
                                    gradient: const LinearGradient(colors: [Color(0xFF8E2DE2), Color(0xFFE50914)]),
                                    onTap: () => showSeasonDialog(),
                                  ),
                                  const SizedBox(height: 14),
                                  if (seasons.isEmpty)
                                    _emptyBox('No seasons yet. Add your first season to start organizing episodes.')
                                  else
                                    ...seasons.map((season) {
                                      final sName = (season['Session_Name'] ?? 'Season').toString().trim();
                                      final eps = season['episodes'] as List<dynamic>? ?? [];
                                      return _glassTile(
                                        icon: Icons.video_library_rounded,
                                        iconColor: const Color(0xFF8E2DE2),
                                        title: sName,
                                        subtitle: '${eps.length} episodes',
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            _iconAction(Icons.edit_rounded, Colors.orangeAccent, () => showSeasonDialog(existing: season)),
                                            _iconAction(Icons.delete_outline_rounded, Colors.redAccent, () => confirmDeleteSeason(season)),
                                          ],
                                        ),
                                        onTap: () => setModalState(() {
                                          currentSeason = season;
                                          currentEpisodes = eps;
                                          inSeasonView = true;
                                        }),
                                      );
                                    }),
                                ] else ...[
                                  // ── Level 2: Episodes of the selected season ──
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _glassButton(
                                          icon: Icons.playlist_add_rounded,
                                          label: 'ADD SINGLE EPISODE',
                                          gradient: const LinearGradient(colors: [Color(0xFF8E2DE2), Color(0xFFE50914)]),
                                          onTap: () => showEpisodeDialog(),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _glassButton(
                                          icon: Icons.bolt_rounded,
                                          label: '⚡ BATCH IMPORT',
                                          gradient: const LinearGradient(colors: [Color(0xFFFF8008), Color(0xFFFFC837)]),
                                          onTap: () => _showBatchEpisodeImportDialog(
                                            seriesId: seriesId,
                                            seriesTitle: seriesTitle,
                                            currentSeason: currentSeason,
                                            currentEpisodes: currentEpisodes,
                                            refresh: refresh,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  if (currentEpisodes.isEmpty)
                                    _emptyBox('No episodes in this season yet. Tap above to add the first one.')
                                  else
                                    ...currentEpisodes.map((ep) {
                                      final epName = (ep['Episoade_Name'] ?? '').toString().trim();
                                      final epImage = (ep['episoade_image'] ?? '').toString();
                                      final links = ep['play_links'] as List<dynamic>? ?? [];
                                      final firstLink = links.isNotEmpty ? links[0] : null;
                                      final linkUrl = firstLink?['url'] ?? '';
                                      final quality = firstLink?['quality'] ?? 'HD';
                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 10),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [const Color(0xFF232A3C).withOpacity(0.9), const Color(0xFF161B28).withOpacity(0.9)],
                                          ),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: Colors.white.withOpacity(0.07)),
                                        ),
                                        child: Row(
                                          children: [
                                            if (epImage.isNotEmpty)
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(10),
                                                child: CachedNetworkImage(
                                                  imageUrl: epImage, width: 46, height: 46, fit: BoxFit.cover,
                                                  errorWidget: (c, u, e) => Container(
                                                    width: 46, height: 46,
                                                    color: const Color(0xFF2A3145),
                                                    child: const Icon(Icons.movie, color: Colors.white24),
                                                  ),
                                                ),
                                              )
                                            else
                                              Container(
                                                width: 46, height: 46,
                                                decoration: BoxDecoration(color: const Color(0xFF2A3145), borderRadius: BorderRadius.circular(10)),
                                                child: const Icon(Icons.movie, color: Colors.white24),
                                              ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(epName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                                  const SizedBox(height: 4),
                                                  Wrap(
                                                    spacing: 6,
                                                    children: [
                                                      _epTag("Quality: $quality", Colors.orangeAccent),
                                                      if (linkUrl.isNotEmpty) _epTag("Link OK", Colors.greenAccent),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            _iconAction(Icons.edit_rounded, Colors.orangeAccent, () => showEpisodeDialog(existing: ep)),
                                            _iconAction(Icons.delete_outline_rounded, Colors.redAccent, () => confirmDeleteEpisode(ep)),
                                          ],
                                        ),
                                      );
                                    }),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<List<dynamic>?> _loadEpisodes(int seriesId) async {
    // Try the dedicated endpoint first (returns seasons with full episodes)
    final res = await _adminPhpApi('get_episodes', {'id': seriesId});
    if (res['status'] == 'success' && res['data']?['seasons'] != null) {
      return res['data']['seasons'];
    }
    // Fall back to a fresh list_series call (works even on older server builds)
    final sRes = await _adminPhpApi('list_series', {});
    if (sRes['status'] == 'success' && sRes['data']?['series'] != null) {
      for (final s in sRes['data']['series']) {
        if (s['id'] == seriesId && s['seasons'] != null && (s['seasons'] as List).isNotEmpty) {
          return s['seasons'] as List<dynamic>;
        }
      }
    }
    // Last resort: cached catalog data
    for (final s in _series) {
      if (s['id'] == seriesId && s['seasons'] != null && (s['seasons'] as List).isNotEmpty) {
        return s['seasons'] as List<dynamic>;
      }
    }
    return null;
  }

  Widget _epTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _glassButton({required IconData icon, required String label, required LinearGradient gradient, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: gradient.colors.last.withOpacity(0.35), blurRadius: 18, offset: const Offset(0, 6))],
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.4)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyBox(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          const Icon(Icons.inbox_rounded, color: Colors.white24, size: 32),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white38, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _glassTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget trailing,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF232A3C).withOpacity(0.9), const Color(0xFF161B28).withOpacity(0.9)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: iconColor.withOpacity(0.15), borderRadius: BorderRadius.circular(11)),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              trailing,
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconAction(IconData icon, Color color, VoidCallback onTap, {double size = 20}) {
    return IconButton(
      icon: Icon(icon, color: color, size: size),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
      onPressed: onTap,
    );
  }

  // Dead Scanner Logic
  Future<void> _startScan({String? ottFilter}) async {
    final ott = ottFilter ?? _deadOttFilter;
    setState(() {
      _scanning = true;
      _scanDone = false;
      _movieChecked = 0;
      _movieTotal = 0;
      _movieDead = 0;
      _epChecked = 0;
      _epTotal = 0;
      _epDead = 0;
    });

    // Reset server-side scan state so totals are stable across batches
    await _adminPhpApi('reset_scan', {'ott': ott}, timeout: 30);
    final init = await _adminPhpApi('get_scan_progress', {'ott': ott}, timeout: 30);
    if (init['status'] == 'success' && init['data']?['movie'] != null) {
      setState(() {
        _movieTotal = int.tryParse('${init['data']['movie']['total']}') ?? 0;
        _epTotal = int.tryParse('${init['data']['episode']['total']}') ?? 0;
      });
    }

    const batchSize = 50;
    bool movieDone = false;

    while (!movieDone && _scanning) {
      final d = await _adminPhpApi('scan_movie_links', {'offset': 0, 'limit': batchSize, 'ott': ott}, timeout: 120);
      if (d['status'] == 'success') {
        final parked = (d['data']['parked_movies'] as List? ?? []);
        setState(() {
          _movieChecked = int.tryParse('${d['data']['checked']}') ?? _movieChecked;
          if ((d['data']['total'] ?? 0) > 0) {
            _movieTotal = int.tryParse('${d['data']['total']}') ?? _movieTotal;
          }
          _movieDead += int.tryParse('${d['data']['found_dead']}') ?? 0;
          movieDone = (d['data']['done'] ?? false) == true;
          _mergeParkedMoviesLive(parked);
        });
      } else {
        // If a batch fails (network), pause briefly then retry once
        if (!_scanning) break;
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    bool epDone = false;
    while (!epDone && _scanning) {
      final d = await _adminPhpApi('scan_episode_links', {'offset': 0, 'limit': batchSize, 'ott': ott}, timeout: 120);
      if (d['status'] == 'success') {
        final parked = (d['data']['parked_series'] as List? ?? []);
        setState(() {
          _epChecked = int.tryParse('${d['data']['checked']}') ?? _epChecked;
          if ((d['data']['total'] ?? 0) > 0) {
            _epTotal = int.tryParse('${d['data']['total']}') ?? _epTotal;
          }
          _epDead += int.tryParse('${d['data']['found_dead']}') ?? 0;
          epDone = (d['data']['done'] ?? false) == true;
          _mergeParkedSeriesLive(parked);
        });
      } else {
        if (!_scanning) break;
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    if (_scanning) {
      await _adminPhpApi('park_dead_content', {'ott': ott}, timeout: 120);
      setState(() {
        _scanning = false;
        _scanDone = true;
      });
      _loadParked();
    } else {
      setState(() => _scanning = false);
    }
  }

  // Merge newly-parked movies from a scan batch into the parked list (live)
  void _mergeParkedMoviesLive(List<dynamic> parked) {
    for (final p in parked) {
      if (p is! Map) continue;
      final id = int.tryParse('${p['id']}') ?? 0;
      if (id <= 0) continue;
      final existingIndex =
          _parkedMovies.indexWhere((m) => int.tryParse('${m['id']}') == id);
      if (existingIndex >= 0) {
        _parkedMovies[existingIndex] = p;
      } else {
        _parkedMovies.insert(0, p);
      }
    }
  }

  // Merge newly-parked series from a scan batch into the parked list (live)
  void _mergeParkedSeriesLive(List<dynamic> parked) {
    for (final p in parked) {
      if (p is! Map) continue;
      final id = int.tryParse('${p['id']}') ?? 0;
      if (id <= 0) continue;
      final existingIndex =
          _parkedSeries.indexWhere((s) => int.tryParse('${s['id']}') == id);
      if (existingIndex >= 0) {
        _parkedSeries[existingIndex] = p;
      } else {
        _parkedSeries.insert(0, p);
      }
    }
  }

  void _cancelScan() => setState(() => _scanning = false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF10121A),
        elevation: 0,
        title: Text(
          _navLabels[_selectedIndex],
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 0.5),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.cyanAccent),
            onPressed: _loadDashboardData,
          ),
        ],
      ),
      drawer: _buildStudioDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE50914)))
          : _buildCurrentView(),
    );
  }

  Widget _buildStudioDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF10121A),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white10)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFE50914), Color(0xFF8E2DE2)]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.movie_creation_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text("RED CHILLIES STUDIO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1.2)),
                      Text("Admin Studio Pro Engine", style: TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _navLabels.length,
                itemBuilder: (context, index) {
                  final isSelected = index == _selectedIndex;
                  return ListTile(
                    leading: Icon(_navIcons[index], color: isSelected ? Colors.cyanAccent : Colors.white60, size: 22),
                    title: Text(
                      _navLabels[index],
                      style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 14),
                    ),
                    tileColor: isSelected ? const Color(0xFF1E2230) : Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    onTap: () {
                      setState(() => _selectedIndex = index);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentView() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboardView();
      case 1:
        return _buildViewsRankingView();
      case 2:
        return _buildAddContentStudioView();
      case 3:
        return _buildMoviesView();
      case 4:
        return _buildWebSeriesView();
      case 5:
        return _buildUpcomingView();
      case 6:
        return _buildOttView();
      case 7:
        return _buildCastView();
      case 8:
        return _buildUsersView();
      case 9:
        return _buildCouponsView();
      case 10:
        return _buildDeadScannerView();
      case 11:
        return _buildLinkUpdaterView();
      case 12:
        return _buildAppSettingsView();
      case 13:
        return _buildPushCampaignsView();
      case 14:
        return _buildReportsManagerView();
      case 15:
        return const StreamtapeDomainsScreen();
      case 16:
        return _buildLiveTelemetryView();
      case 17:
        return _buildSkymoviesImporterView();
      case 18:
        return _buildHdmove99ImporterView();
      case 19:
        return _buildAagmaalImporterView();
      case 20:
        return const FlyModeManagerScreen();
      default:
        return _buildDashboardView();
    }
  }

  // 0. Studio Overview (Dashboard)
  Widget _buildDashboardView() {
    final moviesData = _analyticsData['movies'] ?? {};
    final seriesData = _analyticsData['series'] ?? {};
    final episodesData = _analyticsData['episodes'] ?? {};
    final movieLinksData = _analyticsData['movie_links'] ?? {};
    final epLinksData = _analyticsData['episode_links'] ?? {};
    final usersData = _analyticsData['users'] ?? {};

    final topMovies = (_analyticsData['top_15_movies'] as List? ?? []);
    final topSeries = (_analyticsData['top_15_series'] as List? ?? []);
    final weeklyTrending = (_analyticsData['weekly_trending'] as List? ?? []);
    final liveData = _analyticsData['live'] ?? {};
    final int onlineUsers = liveData['online_users'] ?? 0;
    final int streamingUsers = liveData['streaming_users'] ?? 0;
    final int todayStreams = liveData['today_streams'] ?? 0;
    final List<dynamic> topDownloads = liveData['top_downloads'] as List? ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Live Telemetry Board
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFE50914).withOpacity(0.12),
                  const Color(0xFF1E1E28).withOpacity(0.9),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE50914).withOpacity(0.2), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.greenAccent, blurRadius: 6, spreadRadius: 1),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text("REAL-TIME TELEMETRY",
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("$onlineUsers",
                              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                          const Text("Online Now",
                              style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("$streamingUsers",
                              style: const TextStyle(color: Colors.cyanAccent, fontSize: 28, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                          const Text("Streaming",
                              style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("$todayStreams",
                              style: const TextStyle(color: Colors.amberAccent, fontSize: 28, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                          const Text("Plays Today",
                              style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ],
                ),
                if (topDownloads.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white12, height: 1),
                  const SizedBox(height: 12),
                  const Text("Top Downloaded Content",
                      style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  ...topDownloads.map((dl) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            dl['name'] ?? '',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          "${dl['count']} download(s)",
                          style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  )),
                ],
              ],
            ),
          ),
          // Header Analytics Ratio Cards
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.25,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildRatioStatCard(
                title: "Movies Ratio",
                active: moviesData['active'] ?? _movies.length,
                parked: moviesData['parked'] ?? 0,
                total: moviesData['total'] ?? _movies.length,
                icon: Icons.movie_rounded,
                color: const Color(0xFFFF1744),
              ),
              _buildRatioStatCard(
                title: "Web Series Ratio",
                active: seriesData['active'] ?? _series.length,
                parked: seriesData['parked'] ?? 0,
                total: seriesData['total'] ?? _series.length,
                icon: Icons.tv_rounded,
                color: const Color(0xFF8E2DE2),
              ),
              _buildRatioStatCard(
                title: "Episodes Ratio",
                active: episodesData['active'] ?? 0,
                parked: 0,
                total: episodesData['total'] ?? 0,
                icon: Icons.video_library_rounded,
                color: const Color(0xFF00C6FF),
              ),
              _buildRatioStatCard(
                title: "Movie Links Health",
                active: movieLinksData['active'] ?? 0,
                parked: movieLinksData['dead'] ?? 0,
                total: movieLinksData['total'] ?? 0,
                icon: Icons.link_rounded,
                color: const Color(0xFFFFB703),
                parkedLabel: "Dead",
              ),
              _buildRatioStatCard(
                title: "Episode Links Health",
                active: epLinksData['active'] ?? 0,
                parked: epLinksData['dead'] ?? 0,
                total: epLinksData['total'] ?? 0,
                icon: Icons.health_and_safety_rounded,
                color: const Color(0xFF00E676),
                parkedLabel: "Dead",
              ),
              _buildRatioStatCard(
                title: "Users & VIPs",
                active: usersData['vip'] ?? 0,
                parked: usersData['free'] ?? 0,
                total: usersData['total'] ?? _users.length,
                icon: Icons.people_alt_rounded,
                color: const Color(0xFFFFD700),
                activeLabel: "VIP",
                parkedLabel: "Free",
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Action Shortcuts & Reset Views
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => setState(() => _selectedIndex = 1), // Views & Ranking
                  icon: const Icon(Icons.trending_up_rounded),
                  label: const Text("Views Manager"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF1744),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => setState(() => _selectedIndex = 10), // Dead Scanner
                  icon: const Icon(Icons.health_and_safety_rounded),
                  label: const Text("Dead Scanner"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8E2DE2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _resetAllViews,
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                label: const Text("Reset 0"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF262C3A),
                  foregroundColor: Colors.amberAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // TOP 5 MOST VIEWED MOVIES
          _buildRankingHeader("Top 5 Most Viewed Movies", Icons.local_fire_department_rounded, const Color(0xFFFF1744)),
          const SizedBox(height: 12),
          if (topMovies.isEmpty)
            _buildEmptyAnalyticsPlaceholder("No movie views recorded yet.")
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: min(5, topMovies.length),
              itemBuilder: (ctx, index) {
                final item = topMovies[index];
                return _buildRankedItemCard(
                  rank: index + 1,
                  type: 'movie',
                  id: int.tryParse('${item['id']}') ?? 0,
                  name: (item['name'] ?? '').toString(),
                  poster: (item['poster'] ?? '').toString(),
                  views: int.tryParse('${item['views']}') ?? 0,
                  weeklyViews: int.tryParse('${item['weekly_views']}') ?? 0,
                  releaseDate: (item['release_date'] ?? '').toString(),
                );
              },
            ),
          const SizedBox(height: 28),

          // TOP 5 MOST VIEWED WEB SERIES
          _buildRankingHeader("Top 5 Most Viewed Web Series", Icons.tv_rounded, const Color(0xFF8E2DE2)),
          const SizedBox(height: 12),
          if (topSeries.isEmpty)
            _buildEmptyAnalyticsPlaceholder("No series views recorded yet.")
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: min(5, topSeries.length),
              itemBuilder: (ctx, index) {
                final item = topSeries[index];
                return _buildRankedItemCard(
                  rank: index + 1,
                  type: 'series',
                  id: int.tryParse('${item['id']}') ?? 0,
                  name: (item['name'] ?? '').toString(),
                  poster: (item['poster'] ?? '').toString(),
                  views: int.tryParse('${item['views']}') ?? 0,
                  weeklyViews: int.tryParse('${item['weekly_views']}') ?? 0,
                  releaseDate: (item['release_date'] ?? '').toString(),
                );
              },
            ),
          const SizedBox(height: 28),

          // TOP 5 WEEKLY TRENDING
          _buildRankingHeader("Top 5 Weekly Trending", Icons.auto_awesome_rounded, const Color(0xFFFFB703)),
          const SizedBox(height: 12),
          if (weeklyTrending.isEmpty)
            _buildEmptyAnalyticsPlaceholder("No weekly views recorded yet.")
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: min(5, weeklyTrending.length),
              itemBuilder: (ctx, index) {
                final item = weeklyTrending[index];
                return _buildRankedItemCard(
                  rank: index + 1,
                  type: item['type'] ?? 'movie',
                  id: int.tryParse('${item['id']}') ?? 0,
                  name: (item['name'] ?? '').toString(),
                  poster: (item['poster'] ?? '').toString(),
                  views: int.tryParse('${item['views']}') ?? 0,
                  weeklyViews: int.tryParse('${item['weekly_views']}') ?? 0,
                  releaseDate: (item['release_date'] ?? '').toString(),
                );
              },
            ),
        ],
      ),
    );
  }

  // 1. Views & Ranking Manager Tab
  Widget _buildViewsRankingView() {
    final allContent = <Map<String, dynamic>>[];
    final srcMovies = _movies.isNotEmpty ? _movies : (_analyticsData['top_15_movies'] as List? ?? []);
    final srcSeries = _series.isNotEmpty ? _series : (_analyticsData['top_15_series'] as List? ?? []);

    for (final m in srcMovies) {
      if (m is Map<String, dynamic>) {
        allContent.add({...m, 'content_type': 'movie'});
      } else if (m is Map) {
        allContent.add({...Map<String, dynamic>.from(m), 'content_type': 'movie'});
      }
    }
    for (final s in srcSeries) {
      if (s is Map<String, dynamic>) {
        allContent.add({...s, 'content_type': 'series'});
      } else if (s is Map) {
        allContent.add({...Map<String, dynamic>.from(s), 'content_type': 'series'});
      }
    }

    final filtered = allContent.where((item) {
      final name = (item['name'] ?? '').toString().toLowerCase();
      final type = item['content_type'] ?? 'movie';
      final matchesQuery = _viewsQuery.isEmpty || name.contains(_viewsQuery.toLowerCase());
      final matchesType = _viewsTypeFilter == 'all' || type == _viewsTypeFilter;
      return matchesQuery && matchesType;
    }).toList();

    filtered.sort((a, b) {
      final va = int.tryParse('${a['views'] ?? 0}') ?? 0;
      final vb = int.tryParse('${b['views'] ?? 0}') ?? 0;
      return vb - va;
    });

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          color: const Color(0xFF10121A),
          child: Column(
            children: [
              TextField(
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Search movie or web series to edit views & ranking...",
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.cyanAccent),
                  filled: true,
                  fillColor: const Color(0xFF181C2A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: (val) => setState(() => _viewsQuery = val),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _filterTabChip("All Content", 'all'),
                  const SizedBox(width: 8),
                  _filterTabChip("Movies Only", 'movie'),
                  const SizedBox(width: 8),
                  _filterTabChip("Series Only", 'series'),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? _buildEmptyAnalyticsPlaceholder("No movies or web series match your search filter.")
              : ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, index) {
                    final item = filtered[index];
                    final type = (item['content_type'] ?? 'movie').toString();
                    final id = int.tryParse('${item['id']}') ?? 0;
                    final name = (item['name'] ?? '').toString();
                    final poster = (item['poster'] ?? '').toString();
                    final views = int.tryParse('${item['views']}') ?? 0;
                    final weeklyViews = int.tryParse('${item['weekly_views']}') ?? 0;
                    final releaseDate = (item['release_date'] ?? '').toString();

                    return _buildRankedItemCard(
                      rank: index + 1,
                      type: type,
                      id: id,
                      name: name,
                      poster: poster,
                      views: views,
                      weeklyViews: weeklyViews,
                      releaseDate: releaseDate,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _filterTabChip(String label, String value) {
    final isSelected = _viewsTypeFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _viewsTypeFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF1744) : const Color(0xFF1E2230),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? const Color(0xFFFF1744) : Colors.white12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildRatioStatCard({
    required String title,
    required int active,
    required int parked,
    required int total,
    required IconData icon,
    required Color color,
    String activeLabel = "Active",
    String parkedLabel = "Parked",
  }) {
    final double pct = total > 0 ? (active / total).clamp(0.0, 1.0) : 0.0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF141722),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                "$active / $total",
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
              ),
              Text(
                "${(pct * 100).toStringAsFixed(0)}%",
                style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 5,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          Text(
            "$activeLabel: $active  •  $parkedLabel: $parked",
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildRankingHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
      ],
    );
  }

  Widget _buildEmptyAnalyticsPlaceholder(String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF141722),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Center(
        child: Text(
          msg,
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildRankedItemCard({
    required int rank,
    required String type,
    required int id,
    required String name,
    required String poster,
    required int views,
    required int weeklyViews,
    required String releaseDate,
  }) {
    final isTop3 = rank <= 3;
    final rankColor = rank == 1
        ? const Color(0xFFFFD700)
        : rank == 2
            ? const Color(0xFFC0C0C0)
            : rank == 3
                ? const Color(0xFFCD7F32)
                : const Color(0xFF00C6FF);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF141722),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isTop3 ? rankColor.withOpacity(0.5) : Colors.white.withOpacity(0.06),
          width: isTop3 ? 1.2 : 0.8,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isTop3 ? rankColor.withOpacity(0.2) : Colors.white10,
              shape: BoxShape.circle,
            ),
            child: Text(
              "#$rank",
              style: TextStyle(
                color: isTop3 ? rankColor : Colors.white70,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 38,
              height: 52,
              child: poster.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: poster,
                      fit: BoxFit.cover,
                      errorWidget: (c, u, e) => Container(color: Colors.white10),
                    )
                  : Container(color: Colors.white10),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: type == 'movie' ? const Color(0xFFFF1744) : const Color(0xFF8E2DE2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        type.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.remove_red_eye_rounded, color: Colors.cyanAccent, size: 13),
                    const SizedBox(width: 4),
                    Text("$views total", style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 10),
                    const Icon(Icons.date_range_rounded, color: Colors.amberAccent, size: 13),
                    const SizedBox(width: 4),
                    Text("$weeklyViews weekly", style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: Colors.white70, size: 20),
            tooltip: 'Edit Views',
            onPressed: () => _showEditViewsDialog(
              type: type,
              id: id,
              name: name,
              currentViews: views,
              currentWeeklyViews: weeklyViews,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditViewsDialog({
    required String type,
    required int id,
    required String name,
    required int currentViews,
    required int currentWeeklyViews,
  }) async {
    final viewsCtrl = TextEditingController(text: '$currentViews');
    final weeklyCtrl = TextEditingController(text: '$currentWeeklyViews');

    await showDialog(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: const Color(0xFF161A26),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Color(0x33FF1744)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF1744).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.trending_up_rounded, color: Color(0xFFFF1744), size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Edit View Count", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Total Views (Determines Top 10 Order)", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: viewsCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF0D0F17),
                prefixIcon: const Icon(Icons.remove_red_eye_rounded, color: Colors.cyanAccent, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            const Text("Weekly Views (Determines Weekly Trending Order)", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: weeklyCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF0D0F17),
                prefixIcon: const Icon(Icons.date_range_rounded, color: Colors.amberAccent, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            const Text("Quick Action Presets:", style: TextStyle(color: Colors.white60, fontSize: 12)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _presetChip("+1,000 Views", () {
                  final v = (int.tryParse(viewsCtrl.text) ?? 0) + 1000;
                  final w = (int.tryParse(weeklyCtrl.text) ?? 0) + 500;
                  viewsCtrl.text = '$v';
                  weeklyCtrl.text = '$w';
                }),
                _presetChip("+5,000 Views", () {
                  final v = (int.tryParse(viewsCtrl.text) ?? 0) + 5000;
                  final w = (int.tryParse(weeklyCtrl.text) ?? 0) + 2500;
                  viewsCtrl.text = '$v';
                  weeklyCtrl.text = '$w';
                }),
                _presetChip("Make #1 Top 10 (100K)", () {
                  viewsCtrl.text = '100000';
                  weeklyCtrl.text = '50000';
                }),
                _presetChip("Make #1 Weekly (50K)", () {
                  weeklyCtrl.text = '50000';
                }),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF1744),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final newV = int.tryParse(viewsCtrl.text.trim()) ?? 0;
              final newW = int.tryParse(weeklyCtrl.text.trim()) ?? 0;
              Navigator.pop(dctx);
              await _updateViews(type, id, newV, newW);
            },
            child: const Text("Save & Rank", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _presetChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF22283A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: Text(label, style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildStatCard(String label, String count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141722),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(count, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        ],
      ),
    );
  }

  // 1. ADD MOVIE / WEB SERIES PAGE WITH LIVE IMAGE PREVIEWERS & STREAMTAPE/MP4 TYPES
  Widget _buildAddContentStudioView() {
    final posterUrl = _addPosterUrlCtrl.text.trim();
    final thumbUrl = _addThumbUrlCtrl.text.trim();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Edit Mode Banner
          if (_editingItem != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF2E1A22), Color(0xFF1E2230)]),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orangeAccent.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.edit_rounded, color: Colors.orangeAccent, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text("EDITING: ${_editingItem!['name'] ?? ''}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _editingItem = null;
                        _addTitleCtrl.clear();
                        _addDescCtrl.clear();
                        _addPosterUrlCtrl.clear();
                        _addThumbUrlCtrl.clear();
                        _addReleaseDateCtrl.clear();
                        _addRuntimeCtrl.clear();
                        _selectedOttGenreIds.clear();
                        _selectedCastNetworkIds.clear();
                      });
                    },
                    child: const Text("CANCEL", style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // TMDb Auto Import Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1E2230), Color(0xFF141722)]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.cloud_download_rounded, color: Colors.cyanAccent, size: 24),
                    SizedBox(width: 10),
                    Text("TMDb Auto Import Scraper", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _tmdbIdCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Enter TMDb ID (e.g. 550, 603)",
                          hintStyle: const TextStyle(color: Colors.grey),
                          filled: true,
                          fillColor: const Color(0xFF090A0F),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _fetchTmdbData,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
                      child: const Text("FETCH", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Main Form Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF141722),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Content Type Selector
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text("Movie"),
                      selected: _addType == 'movie',
                      selectedColor: const Color(0xFFE50914),
                      onSelected: (s) => setState(() => _addType = 'movie'),
                    ),
                    const SizedBox(width: 10),
                    ChoiceChip(
                      label: const Text("Web Series"),
                      selected: _addType == 'series',
                      selectedColor: const Color(0xFF8E2DE2),
                      onSelected: (s) => setState(() => _addType = 'series'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                _buildInputField("Title", _addTitleCtrl, hint: "Enter Content Title"),
                _buildInputField("Description", _addDescCtrl, maxLines: 3, hint: "Enter Overview / Description"),
                _buildInputField("Release Date", _addReleaseDateCtrl, hint: "YYYY-MM-DD"),
                _buildInputField("Runtime", _addRuntimeCtrl, hint: "120 min"),
                _buildInputField("Trailer URL (YouTube)", _addTrailerCtrl, hint: "https://www.youtube.com/watch?v=..."),

                _buildInputField("Poster URL (500x750)", _addPosterUrlCtrl, hint: "https://..."),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _pickAndUploadImage,
                          icon: _isUploadingPoster
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.cloud_upload_rounded, size: 16),
                          label: Text(_isUploadingPoster ? "UPLOADING..." : "UPLOAD POSTER", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE50914),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _showImageSearchDialog,
                          icon: const Icon(Icons.image_search_rounded, size: 16),
                          label: const Text("WEB SEARCH IMAGE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E2230),
                            foregroundColor: Colors.cyanAccent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            side: const BorderSide(color: Colors.cyanAccent, width: 0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (posterUrl.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  const Text("Live Poster Preview:", style: TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Container(
                    height: 160,
                    width: 110,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.cyanAccent.withOpacity(0.5)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: CachedNetworkImage(
                      imageUrl: posterUrl,
                      fit: BoxFit.cover,
                      errorWidget: (c, u, e) => const Center(child: Icon(Icons.broken_image, color: Colors.redAccent)),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Thumbnail URL Field + LIVE THUMBNAIL PREVIEW
                _buildInputField("Thumbnail / Banner URL (2048x1152)", _addThumbUrlCtrl, hint: "https://..."),
                if (thumbUrl.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  const Text("Live Banner Preview:", style: TextStyle(color: Colors.purpleAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.purpleAccent.withOpacity(0.5)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: CachedNetworkImage(
                      imageUrl: thumbUrl,
                      fit: BoxFit.cover,
                      errorWidget: (c, u, e) => const Center(child: Icon(Icons.broken_image, color: Colors.redAccent)),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Stream Source Selector & Input
                if (_addType == 'movie') ...[
                  DropdownButtonFormField<String>(
                    value: ['MP4/MKV Direct Link', 'Streamtape Stream', 'Luluvdo Stream', 'xHamster Stream', 'HLS/M3U8 Stream', 'Embed Player'].contains(_streamType) ? _streamType : 'MP4/MKV Direct Link',
                    dropdownColor: const Color(0xFF161A26),
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      labelText: "Stream Source Format",
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: const Color(0xFF0F121C),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: ['MP4/MKV Direct Link', 'Streamtape Stream', 'Luluvdo Stream', 'xHamster Stream', 'HLS/M3U8 Stream', 'Embed Player'].map((st) {
                      return DropdownMenuItem<String>(
                        value: st,
                        child: Text(st, style: const TextStyle(color: Colors.white)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _streamType = val);
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInputField("Primary Stream URL (Server 1)", _addStreamUrlCtrl, hint: "https://..."),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 20.0, right: 12.0),
                        child: ElevatedButton.icon(
                          onPressed: () => _showQuickLinkExtractorDialog((extractedUrl, {posterUrl}) {
                            setState(() {
                              _addStreamUrlCtrl.text = extractedUrl;
                              if (posterUrl != null && posterUrl.isNotEmpty) {
                                _addPosterUrlCtrl.text = posterUrl;
                                _addThumbUrlCtrl.text = posterUrl;
                              }
                            });
                          }),
                          icon: const Icon(Icons.bolt_rounded, size: 16, color: Colors.amberAccent),
                          label: const Text("EXTRACT", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amberAccent)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF231F10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Colors.amberAccent, width: 0.8)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Dynamic Extra Movie Servers List
                  ..._extraMovieServers.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final server = entry.value;
                    final ctrl = server['ctrl'] as TextEditingController;
                    final sType = (server['type'] ?? 'MP4/MKV Direct Link').toString();
                    final sNum = idx + 2;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F131E),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Server $sNum Link", style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                onPressed: () {
                                  setState(() {
                                    ctrl.dispose();
                                    _extraMovieServers.removeAt(idx);
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: ['MP4/MKV Direct Link', 'Streamtape Stream', 'Luluvdo Stream', 'xHamster Stream', 'HLS/M3U8 Stream', 'Embed Player'].contains(sType) ? sType : 'MP4/MKV Direct Link',
                            dropdownColor: const Color(0xFF161A26),
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            decoration: InputDecoration(
                              labelText: "Server $sNum Stream Type",
                              labelStyle: const TextStyle(color: Colors.white70, fontSize: 12),
                              filled: true,
                              fillColor: const Color(0xFF090A0F),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            items: ['MP4/MKV Direct Link', 'Streamtape Stream', 'Luluvdo Stream', 'xHamster Stream', 'HLS/M3U8 Stream', 'Embed Player'].map((st) {
                              return DropdownMenuItem<String>(value: st, child: Text(st, style: const TextStyle(color: Colors.white)));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => server['type'] = val);
                            },
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: ctrl,
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                  decoration: InputDecoration(
                                    labelText: "Server $sNum URL",
                                    labelStyle: const TextStyle(color: Colors.white70, fontSize: 12),
                                    filled: true,
                                    fillColor: const Color(0xFF090A0F),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              ElevatedButton(
                                onPressed: () => _showQuickLinkExtractorDialog((extractedUrl, {posterUrl}) {
                                  setState(() => ctrl.text = extractedUrl);
                                }),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber.withOpacity(0.15),
                                  foregroundColor: Colors.amberAccent,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Colors.amberAccent, width: 0.8)),
                                ),
                                child: const Text("EXTRACT", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),

                  // Button: Add Extra Server Link
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _extraMovieServers.add({
                          'name': 'Server ${_extraMovieServers.length + 2}',
                          'type': 'MP4/MKV Direct Link',
                          'ctrl': TextEditingController(),
                        });
                      });
                    },
                    icon: const Icon(Icons.add_circle_outline, color: Colors.cyanAccent, size: 18),
                    label: const Text("+ Add Extra Server / Link", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.cyanAccent, width: 1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    ),
                  ),
                ],

                const SizedBox(height: 18),
                _buildMultiSelectDropdown(
                  label: "OTT Genres",
                  items: _ottGenres,
                  selectedIds: _selectedOttGenreIds,
                  accentColor: Colors.cyanAccent,
                  onToggle: (id) => setState(() {
                    if (_selectedOttGenreIds.contains(id)) { _selectedOttGenreIds.remove(id); } else { _selectedOttGenreIds.add(id); }
                  }),
                ),
                const SizedBox(height: 14),
                _buildMultiSelectDropdown(
                  label: "Cast Networks",
                  items: _castNetworks,
                  selectedIds: _selectedCastNetworkIds,
                  accentColor: Colors.purpleAccent,
                  onToggle: (id) => setState(() {
                    if (_selectedCastNetworkIds.contains(id)) { _selectedCastNetworkIds.remove(id); } else { _selectedCastNetworkIds.add(id); }
                  }),
                ),
                const SizedBox(height: 14),

                // Custom Tag linked to DB tags
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Access Tier", style: TextStyle(color: Colors.white70, fontSize: 13)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: _addTier,
                            dropdownColor: const Color(0xFF10121A),
                            style: const TextStyle(color: Colors.white),
                            items: ['Free', 'Premium'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                            onChanged: (v) => setState(() => _addTier = v!),
                            decoration: InputDecoration(filled: true, fillColor: const Color(0xFF090A0F), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Custom Tag (DB Linked)", style: TextStyle(color: Colors.white70, fontSize: 13)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: _dbCustomTags.contains(_addCustomTag)
                                ? _addCustomTag
                                : null,
                            dropdownColor: const Color(0xFF10121A),
                            style: const TextStyle(color: Colors.white),
                            items: _dbCustomTags.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                            onChanged: (v) => setState(() => _addCustomTag = v!),
                            decoration: InputDecoration(filled: true, fillColor: const Color(0xFF090A0F), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text("Enable Download Link", style: TextStyle(color: Colors.white)),
                  value: _enableDownload,
                  activeColor: Colors.greenAccent,
                  onChanged: (v) => setState(() => _enableDownload = v),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _submitAddContent,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE50914), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: Text("${_editingItem != null ? 'UPDATE' : 'CREATE'} ${_addType.toUpperCase()}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController ctrl, {int maxLines = 1, String hint = ''}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl,
            maxLines: maxLines,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.grey),
              filled: true,
              fillColor: const Color(0xFF090A0F),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultiSelectDropdown({
    required String label,
    required List<dynamic> items,
    required Set<int> selectedIds,
    required Color accentColor,
    required void Function(int id) onToggle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        InkWell(
          onTap: () {
            showModalBottomSheet(
              context: context,
              backgroundColor: const Color(0xFF141722),
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
              builder: (ctx) {
                // Local copy of selectedIds for the bottom sheet
                final localSelected = Set<int>.from(selectedIds);
                return StatefulBuilder(
                  builder: (ctx, setSheetState) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("Select $label", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        if (items.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text("Loading...", style: TextStyle(color: Colors.grey)),
                          )
                        else
                          Flexible(
                            child: ListView(
                              shrinkWrap: true,
                              children: items.map((item) {
                                final id = item['id'] is int ? item['id'] : int.tryParse('${item['id']}') ?? 0;
                                final name = item['name'] ?? '';
                                final checked = localSelected.contains(id);
                                return CheckboxListTile(
                                  dense: true,
                                  title: Text(name, style: const TextStyle(color: Colors.white, fontSize: 14)),
                                  value: checked,
                                  activeColor: accentColor,
                                  checkColor: Colors.black,
                                  onChanged: (_) {
                                    setSheetState(() {
                                      if (localSelected.contains(id)) {
                                        localSelected.remove(id);
                                      } else {
                                        localSelected.add(id);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              for (final id in localSelected) {
                                if (!selectedIds.contains(id)) onToggle(id);
                              }
                              for (final id in Set<int>.from(selectedIds)) {
                                if (!localSelected.contains(id)) onToggle(id);
                              }
                              Navigator.pop(ctx);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentColor,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text("Apply", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF090A0F),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selectedIds.isEmpty
                        ? "Tap to select..."
                        : "${selectedIds.length} selected",
                    style: TextStyle(
                      color: selectedIds.isEmpty ? Colors.grey : Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
                Icon(Icons.arrow_drop_down, color: accentColor.withOpacity(0.7)),
              ],
            ),
          ),
        ),
        if (selectedIds.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: items.where((item) {
              final id = item['id'] is int ? item['id'] : int.tryParse('${item['id']}') ?? 0;
              return selectedIds.contains(id);
            }).map((item) {
              return Chip(
                label: Text(item['name'] ?? '', style: const TextStyle(color: Colors.black, fontSize: 11)),
                backgroundColor: accentColor.withOpacity(0.8),
                deleteIcon: const Icon(Icons.close, size: 14, color: Colors.black54),
                onDeleted: () => onToggle(item['id'] is int ? item['id'] : int.tryParse('${item['id']}') ?? 0),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  // 2. Movies Catalog View with Search Filter
  Widget _buildMoviesView() {
    final filtered = _movies.where((m) {
      final name = (m['name'] ?? '').toString().toLowerCase();
      final genres = (m['genres'] ?? '').toString().toLowerCase();
      final matchesQuery = _movieCatalogQuery.isEmpty || name.contains(_movieCatalogQuery.toLowerCase());
      final matchesOtt = _movieCatalogOttFilter.isEmpty || genres.contains(_movieCatalogOttFilter.toLowerCase());
      return matchesQuery && matchesOtt;
    }).toList();

    // Build OTT options from loaded genres list
    final ottOptions = <String>[''];
    for (final g in _genres) {
      final name = (g['name'] ?? '').toString();
      if (name.isNotEmpty) ottOptions.add(name);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: TextField(
            onChanged: (v) => setState(() => _movieCatalogQuery = v),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Search Movies Catalog...",
              hintStyle: const TextStyle(color: Colors.grey),
              prefixIcon: const Icon(Icons.search, color: Colors.cyanAccent),
              filled: true,
              fillColor: const Color(0xFF141722),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ),
        // OTT Filter Dropdown
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF141722),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.cyanAccent.withOpacity(0.2)),
            ),
            child: DropdownButton<String>(
              isExpanded: true,
              value: _movieCatalogOttFilter,
              dropdownColor: const Color(0xFF1A1F2E),
              underline: const SizedBox(),
              icon: const Icon(Icons.filter_list_rounded, color: Colors.cyanAccent, size: 18),
              hint: const Text('Filter by OTT Platform', style: TextStyle(color: Colors.grey, fontSize: 13)),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              items: ottOptions.map((o) => DropdownMenuItem<String>(
                value: o,
                child: Text(o.isEmpty ? 'All OTT Platforms' : o,
                    style: TextStyle(color: o.isEmpty ? Colors.grey : Colors.white)),
              )).toList(),
              onChanged: (v) => setState(() => _movieCatalogOttFilter = v ?? ''),
            ),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text("No movies found", style: TextStyle(color: Colors.grey)))
              : GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.5,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    final poster = item['poster'] ?? '';
                    final name = item['name'] ?? '';
                    return GestureDetector(
                      onTap: () => _startEdit(item, 'movie'),
                      onLongPress: () => _showItemActions(context, item, 'movie'),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                          color: const Color(0xFF141722),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CachedNetworkImage(
                              imageUrl: poster,
                              fit: BoxFit.cover,
                              errorWidget: (c, u, e) => const Center(child: Icon(Icons.movie, color: Colors.grey, size: 48)),
                            ),
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [Colors.black87, Colors.transparent],
                                  ),
                                ),
                                child: Text(
                                  name,
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showItemActions(BuildContext context, Map<String, dynamic> item, String type) {
    final isMovie = type == 'movie';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141722),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(item['name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _actionButton(ctx, "View Details", Icons.info_outline, Colors.cyanAccent, () {
              Navigator.pop(ctx);
              _showDetailsDialog(item, type);
            }),
            const SizedBox(height: 8),
            _actionButton(ctx, "Edit", Icons.edit_rounded, Colors.orangeAccent, () {
              Navigator.pop(ctx);
              _startEdit(item, type);
            }),
            const SizedBox(height: 8),
            _actionButton(ctx, "Delete", Icons.delete_outline, Colors.redAccent, () async {
              Navigator.pop(ctx);
              final confirm = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  backgroundColor: const Color(0xFF141722),
                  title: const Text("Confirm Delete", style: TextStyle(color: Colors.white)),
                  content: Text("Delete '${item['name']}'?", style: const TextStyle(color: Colors.white70)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
                    TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("Delete", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
                  ],
                ),
              );
              if (confirm == true) {
                final action = isMovie ? 'delete_movie' : 'delete_series';
                await _adminPhpApi(action, {'id': item['id']});
                setState(() {
                  if (isMovie) { _movies.removeWhere((m) => m['id'] == item['id']); }
                  else { _series.removeWhere((s) => s['id'] == item['id']); }
                });
              }
            }),
            if (!isMovie) ...[
              const SizedBox(height: 8),
              _actionButton(ctx, "Manage Episodes", Icons.playlist_add_rounded, const Color(0xFF8E2DE2), () {
                Navigator.pop(ctx);
                _openEpisodeManagerModal(item);
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _actionButton(BuildContext ctx, String label, IconData icon, Color color, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.15),
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  void _showDetailsDialog(Map<String, dynamic> item, String type) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141722),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(item['name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((item['poster'] ?? '').isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CachedNetworkImage(imageUrl: item['poster'], height: 200, width: double.infinity, fit: BoxFit.cover, errorWidget: (c, u, e) => const SizedBox()),
                ),
              const SizedBox(height: 12),
              _detailRow("ID", "${item['id']}"),
              _detailRow("Description", item['description'] ?? 'N/A'),
              _detailRow("Genres", item['genres'] ?? 'N/A'),
              _detailRow("Release Date", item['release_date'] ?? 'N/A'),
              _detailRow("Status", item['status'] == '1' || item['status'] == 1 ? 'Published' : 'Unpublished'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close", style: TextStyle(color: Colors.cyanAccent))),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text("$label:", style: const TextStyle(color: Colors.white54, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 13))),
        ],
      ),
    );
  }

  // 3. Web Series Catalog View with Search Filter & EPISODES Button
  Widget _buildWebSeriesView() {
    final filtered = _series.where((s) {
      final name = (s['name'] ?? '').toString().toLowerCase();
      final genres = (s['genres'] ?? '').toString().toLowerCase();
      final matchesQuery = _seriesCatalogQuery.isEmpty || name.contains(_seriesCatalogQuery.toLowerCase());
      final matchesOtt = _seriesCatalogOttFilter.isEmpty || genres.contains(_seriesCatalogOttFilter.toLowerCase());
      return matchesQuery && matchesOtt;
    }).toList();

    // Build OTT options from loaded genres list
    final ottOptions = <String>[''];
    for (final g in _genres) {
      final name = (g['name'] ?? '').toString();
      if (name.isNotEmpty) ottOptions.add(name);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: TextField(
            onChanged: (v) => setState(() => _seriesCatalogQuery = v),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Search Web Series Catalog...",
              hintStyle: const TextStyle(color: Colors.grey),
              prefixIcon: const Icon(Icons.search, color: Colors.purpleAccent),
              filled: true,
              fillColor: const Color(0xFF141722),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ),
        // OTT Filter Dropdown
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF141722),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.purpleAccent.withOpacity(0.2)),
            ),
            child: DropdownButton<String>(
              isExpanded: true,
              value: _seriesCatalogOttFilter,
              dropdownColor: const Color(0xFF1A1F2E),
              underline: const SizedBox(),
              icon: const Icon(Icons.filter_list_rounded, color: Colors.purpleAccent, size: 18),
              hint: const Text('Filter by OTT Platform', style: TextStyle(color: Colors.grey, fontSize: 13)),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              items: ottOptions.map((o) => DropdownMenuItem<String>(
                value: o,
                child: Text(o.isEmpty ? 'All OTT Platforms' : o,
                    style: TextStyle(color: o.isEmpty ? Colors.grey : Colors.white)),
              )).toList(),
              onChanged: (v) => setState(() => _seriesCatalogOttFilter = v ?? ''),
            ),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text("No series found", style: TextStyle(color: Colors.grey)))
              : GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.5,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    final poster = item['poster'] ?? '';
                    final name = item['name'] ?? '';
                    return GestureDetector(
                      onTap: () => _startEdit(item, 'series'),
                      onLongPress: () => _showItemActions(context, item, 'series'),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                          color: const Color(0xFF141722),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CachedNetworkImage(
                              imageUrl: poster,
                              fit: BoxFit.cover,
                              errorWidget: (c, u, e) => const Center(child: Icon(Icons.tv, color: Colors.grey, size: 48)),
                            ),
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [Colors.black87, Colors.transparent],
                                  ),
                                ),
                                child: Text(
                                  name,
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // 4. Upcoming View
  Widget _buildUpcomingView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showAddUpcomingDialog(),
              icon: const Icon(Icons.add_circle, color: Colors.white),
              label: const Text("ADD UPCOMING CONTENT", style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE50914), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ),
        ),
        Expanded(
          child: _upcoming.isEmpty
              ? const Center(child: Text("No upcoming content", style: TextStyle(color: Colors.grey)))
              : GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.5,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: _upcoming.length,
                  itemBuilder: (context, index) {
                    final item = _upcoming[index];
                    final poster = item['poster'] ?? '';
                    final name = item['name'] ?? '';
                    return GestureDetector(
                      onLongPress: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: const Color(0xFF141722),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _actionButton(ctx, "View Details", Icons.info_outline, Colors.cyanAccent, () { Navigator.pop(ctx); _showUpcomingDetails(item); }),
                                const SizedBox(height: 8),
                                _actionButton(ctx, "Edit", Icons.edit_rounded, Colors.orangeAccent, () { Navigator.pop(ctx); _showEditUpcomingDialog(item, index); }),
                                const SizedBox(height: 8),
                                _actionButton(ctx, "Delete", Icons.delete_outline, Colors.redAccent, () async {
                                  Navigator.pop(ctx);
                                  await _adminPhpApi('delete_upcoming', {'id': item['id']});
                                  setState(() => _upcoming.removeAt(index));
                                }),
                              ],
                            ),
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                          color: const Color(0xFF141722),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CachedNetworkImage(
                              imageUrl: poster,
                              fit: BoxFit.cover,
                              errorWidget: (c, u, e) => const Center(child: Icon(Icons.event, color: Colors.grey, size: 48)),
                            ),
                            Positioned(
                              bottom: 0, left: 0, right: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black87, Colors.transparent]),
                                ),
                                child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showUpcomingDetails(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141722),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(item['name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            if ((item['poster'] ?? '').isNotEmpty)
              ClipRRect(borderRadius: BorderRadius.circular(10), child: CachedNetworkImage(imageUrl: item['poster'], height: 200, width: double.infinity, fit: BoxFit.cover, errorWidget: (c, u, e) => const SizedBox())),
            const SizedBox(height: 12),
            _detailRow("Description", item['description'] ?? 'N/A'),
            _detailRow("Release Date", item['release_date'] ?? 'N/A'),
          ]),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close", style: TextStyle(color: Colors.cyanAccent)))],
      ),
    );
  }

  void _showAddUpcomingDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final posterCtrl = TextEditingController();
    final dateCtrl = TextEditingController(text: DateTime.now().toString().split(' ')[0]);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141722),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Add Upcoming Content", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "Title", labelStyle: const TextStyle(color: Colors.white70), filled: true, fillColor: const Color(0xFF090A0F), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 10),
            TextField(controller: descCtrl, style: const TextStyle(color: Colors.white), maxLines: 3, decoration: InputDecoration(labelText: "Description", labelStyle: const TextStyle(color: Colors.white70), filled: true, fillColor: const Color(0xFF090A0F), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 10),
            TextField(controller: posterCtrl, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "Poster URL", labelStyle: const TextStyle(color: Colors.white70), filled: true, fillColor: const Color(0xFF090A0F), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 10),
            TextField(controller: dateCtrl, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "Release Date", labelStyle: const TextStyle(color: Colors.white70), filled: true, fillColor: const Color(0xFF090A0F), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () async {
            if (nameCtrl.text.trim().isEmpty) return;
            final res = await _adminPhpApi('add_upcoming', {
              'name': nameCtrl.text.trim(),
              'description': descCtrl.text.trim(),
              'poster': posterCtrl.text.trim(),
              'release_date': dateCtrl.text.trim(),
            });
            if (res['status'] == 'success') {
              setState(() => _upcoming.insert(0, {
                'id': DateTime.now().millisecondsSinceEpoch,
                'name': nameCtrl.text.trim(),
                'description': descCtrl.text.trim(),
                'poster': posterCtrl.text.trim(),
                'release_date': dateCtrl.text.trim(),
              }));
            }
            if (ctx.mounted) Navigator.pop(ctx);
          }, child: const Text("Add", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  void _showEditUpcomingDialog(Map<String, dynamic> item, int index) {
    final nameCtrl = TextEditingController(text: item['name'] ?? '');
    final descCtrl = TextEditingController(text: item['description'] ?? '');
    final posterCtrl = TextEditingController(text: item['poster'] ?? '');
    final dateCtrl = TextEditingController(text: item['release_date'] ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141722),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Edit Upcoming Content", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "Title", labelStyle: const TextStyle(color: Colors.white70), filled: true, fillColor: const Color(0xFF090A0F), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 10),
            TextField(controller: descCtrl, style: const TextStyle(color: Colors.white), maxLines: 3, decoration: InputDecoration(labelText: "Description", labelStyle: const TextStyle(color: Colors.white70), filled: true, fillColor: const Color(0xFF090A0F), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 10),
            TextField(controller: posterCtrl, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "Poster URL", labelStyle: const TextStyle(color: Colors.white70), filled: true, fillColor: const Color(0xFF090A0F), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 10),
            TextField(controller: dateCtrl, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "Release Date", labelStyle: const TextStyle(color: Colors.white70), filled: true, fillColor: const Color(0xFF090A0F), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () async {
            if (nameCtrl.text.trim().isEmpty) return;
            final res = await _adminPhpApi('edit_upcoming', {
              'id': item['id'],
              'name': nameCtrl.text.trim(),
              'description': descCtrl.text.trim(),
              'poster': posterCtrl.text.trim(),
              'release_date': dateCtrl.text.trim(),
            });
            if (res['status'] == 'success') {
              setState(() {
                _upcoming[index]['name'] = nameCtrl.text.trim();
                _upcoming[index]['description'] = descCtrl.text.trim();
                _upcoming[index]['poster'] = posterCtrl.text.trim();
                _upcoming[index]['release_date'] = dateCtrl.text.trim();
              });
            }
            if (ctx.mounted) Navigator.pop(ctx);
          }, child: const Text("Save", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  // 5. OTT Platforms & Genres View
  Widget _buildOttView() {
    final query = _ottQuery.trim().toLowerCase();
    final filtered = query.isEmpty
        ? List<dynamic>.from(_genres)
        : _genres
            .where((g) =>
                (g['name'] ?? '').toString().toLowerCase().contains(query))
            .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showAddGenreDialog(),
                  icon: const Icon(Icons.add_circle, color: Colors.white),
                  label: const Text("ADD GENRE", style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent.withOpacity(0.3), foregroundColor: Colors.cyanAccent, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                decoration: BoxDecoration(color: const Color(0xFF141722), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
                child: Row(
                  children: [
                    _ottViewModeButton(Icons.view_list_rounded, !_ottGridView, () => setState(() => _ottGridView = false)),
                    _ottViewModeButton(Icons.grid_view_rounded, _ottGridView, () => setState(() => _ottGridView = true)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
          child: TextField(
            onChanged: (v) => setState(() => _ottQuery = v),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Search genres...",
              hintStyle: const TextStyle(color: Colors.grey),
              prefixIcon: const Icon(Icons.search, color: Colors.cyanAccent),
              suffixIcon: _ottQuery.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.close, color: Colors.white38), onPressed: () => setState(() => _ottQuery = ''))
                  : null,
              filled: true,
              fillColor: const Color(0xFF141722),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Text(
            query.isNotEmpty
                ? "${filtered.length} result(s)"
                : (_ottGridView ? "Tap a card to edit • visibility icon toggles home visibility" : "Press & hold a genre to drag-reorder it"),
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ),
        Expanded(
          child: _genres.isEmpty
              ? const Center(child: Text("No genres found", style: TextStyle(color: Colors.grey)))
              : filtered.isEmpty
                  ? const Center(child: Text("No matching genres", style: TextStyle(color: Colors.grey)))
                  : _ottGridView
                      ? _buildOttGridView(filtered)
                      : query.isNotEmpty
                          ? _buildOttSearchResults(filtered)
                          : _buildOttReorderableList(),
        ),
      ],
    );
  }

  Widget _ottViewModeButton(IconData icon, bool selected, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: selected ? const Color(0xFF8E2DE2) : Colors.transparent, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: selected ? Colors.white : Colors.white38, size: 18),
      ),
    );
  }

  Widget _buildOttReorderableList() {
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      buildDefaultDragHandles: false,
      itemCount: _genres.length,
      onReorder: (oldIndex, newIndex) async {
        setState(() {
          if (newIndex > oldIndex) newIndex--;
          final item = _genres.removeAt(oldIndex);
          _genres.insert(newIndex, item);
        });
        final ids = _genres.map((g) => g['id']).join(',');
        await _adminPhpApi('reorder_genres', {'order': ids});
      },
      itemBuilder: (context, index) {
        final item = _genres[index];
        return ReorderableDelayedDragStartListener(
          key: ValueKey('genre-${item['id']}'),
          index: index,
          child: _ottListTile(item, index, showDragHandle: true),
        );
      },
    );
  }

  Widget _buildOttSearchResults(List<dynamic> filtered) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      itemCount: filtered.length,
      itemBuilder: (context, index) => _ottListTile(filtered[index], index),
    );
  }

  Widget _ottListTile(dynamic item, int index, {bool showDragHandle = false}) {
    final realIndex = _genres.indexWhere((g) => g['id'] == item['id']);
    final name = item['name'] ?? '';
    final iconUrl = (item['icon'] ?? '').toString();
    final status = (item['status'] ?? 1) == 1;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF232A3C).withOpacity(0.9), const Color(0xFF161B28).withOpacity(0.9)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: status ? Colors.white.withOpacity(0.07) : Colors.redAccent.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Colors.cyanAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(9)),
              child: Text("${realIndex + 1}", style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            const SizedBox(width: 12),
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: const Color(0xFF2A3145), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.06))),
              clipBehavior: Clip.antiAlias,
              child: iconUrl.isNotEmpty
                  ? CachedNetworkImage(imageUrl: iconUrl, fit: BoxFit.cover, errorWidget: (c, u, e) => const Icon(Icons.category_rounded, color: Colors.white38))
                  : const Icon(Icons.category_rounded, color: Colors.white38),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(status ? 'Visible' : 'Hidden', style: TextStyle(color: status ? Colors.greenAccent : Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Switch(
              value: status,
              activeTrackColor: Colors.greenAccent,
              onChanged: (v) async {
                setState(() => item['status'] = v ? 1 : 0);
                final res = await _adminPhpApi('edit_genre', {'id': item['id'], 'status': v ? 1 : 0});
                if (res['status'] != 'success') {
                  setState(() => item['status'] = v ? 0 : 1);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to update visibility"), backgroundColor: Colors.red));
                }
              },
            ),
            _iconAction(Icons.edit_rounded, Colors.orangeAccent, () => _showEditGenreDialog(item, realIndex)),
            _iconAction(Icons.delete_outline_rounded, Colors.redAccent, () => _confirmDeleteGenre(item, realIndex)),
            if (showDragHandle)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.drag_handle_rounded, color: Colors.white24),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOttGridView(List<dynamic> filtered) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.78,
      ),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final item = filtered[index];
        final realIndex = _genres.indexWhere((g) => g['id'] == item['id']);
        final name = item['name'] ?? '';
        final iconUrl = (item['icon'] ?? '').toString();
        final status = (item['status'] ?? 1) == 1;
        return GestureDetector(
          onTap: () => _showEditGenreDialog(item, realIndex),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF232A3C).withOpacity(0.9), const Color(0xFF161B28).withOpacity(0.9)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: status ? Colors.white.withOpacity(0.07) : Colors.redAccent.withOpacity(0.3)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(color: const Color(0xFF2A3145), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(0.06))),
                      clipBehavior: Clip.antiAlias,
                      child: iconUrl.isNotEmpty
                          ? CachedNetworkImage(imageUrl: iconUrl, fit: BoxFit.cover, errorWidget: (c, u, e) => const Icon(Icons.category_rounded, color: Colors.white38))
                          : const Icon(Icons.category_rounded, color: Colors.white38),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: status ? Colors.greenAccent : Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text("#${realIndex + 1}", style: const TextStyle(color: Colors.white38, fontSize: 10)),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _iconAction(Icons.visibility_rounded, status ? Colors.greenAccent : Colors.white30, () async {
                      setState(() => item['status'] = status ? 0 : 1);
                      await _adminPhpApi('edit_genre', {'id': item['id'], 'status': status ? 0 : 1});
                    }, size: 16),
                    _iconAction(Icons.edit_rounded, Colors.orangeAccent, () => _showEditGenreDialog(item, realIndex), size: 16),
                    _iconAction(Icons.delete_outline_rounded, Colors.redAccent, () => _confirmDeleteGenre(item, realIndex), size: 16),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteGenre(Map<String, dynamic> item, int index) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2132),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: Colors.white.withOpacity(0.08))),
        title: const Text("Delete Genre?", style: TextStyle(color: Colors.white)),
        content: Text("Delete '${item['name'] ?? ''}'?", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (ok == true) {
      final res = await _adminPhpApi('delete_genre', {'id': item['id']});
      if (res['status'] == 'success') {
        setState(() => _genres.removeAt(index));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed: ${res['message'] ?? 'Unknown error'}"), backgroundColor: Colors.red));
      }
    }
  }

  void _showAddGenreDialog() {
    final nameCtrl = TextEditingController();
    final iconCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2132),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: Colors.white.withOpacity(0.08))),
        title: const Text("Add Genre", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "Genre Name", labelStyle: const TextStyle(color: Colors.white70), filled: true, fillColor: const Color(0xFF090A0F), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
          const SizedBox(height: 10),
          TextField(controller: iconCtrl, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "Icon URL (optional)", labelStyle: const TextStyle(color: Colors.white70), filled: true, fillColor: const Color(0xFF090A0F), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final res = await _adminPhpApi('add_genre', {'name': nameCtrl.text.trim(), 'icon': iconCtrl.text.trim()});
              if (res['status'] == 'success') {
                final gRes = await _adminPhpApi('list_genres', {});
                if (gRes['status'] == 'success') setState(() => _genres = gRes['data']['genres']);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Genre added!"), backgroundColor: Colors.green));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed: ${res['message'] ?? 'Unknown error'}"), backgroundColor: Colors.red));
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text("Add", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showEditGenreDialog(Map<String, dynamic> item, int index) {
    final nameCtrl = TextEditingController(text: item['name'] ?? '');
    final iconCtrl = TextEditingController(text: item['icon'] ?? '');
    bool status = (item['status'] ?? 1) == 1;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF1A2132),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: Colors.white.withOpacity(0.08))),
          title: Text("Edit Genre — #${index + 1}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "Genre Name", labelStyle: const TextStyle(color: Colors.white70), filled: true, fillColor: const Color(0xFF090A0F), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 10),
            TextField(controller: iconCtrl, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "Icon URL (shown on home screen)", labelStyle: const TextStyle(color: Colors.white70), filled: true, fillColor: const Color(0xFF090A0F), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text("Visible on Home Screen", style: TextStyle(color: Colors.white, fontSize: 14)),
              value: status,
              activeTrackColor: Colors.greenAccent,
              onChanged: (v) => setDlgState(() => status = v),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
            TextButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                final res = await _adminPhpApi('edit_genre', {'id': item['id'], 'name': nameCtrl.text.trim(), 'icon': iconCtrl.text.trim(), 'status': status ? 1 : 0});
                if (res['status'] == 'success') {
                  setState(() {
                    _genres[index]['name'] = nameCtrl.text.trim();
                    _genres[index]['icon'] = iconCtrl.text.trim();
                    _genres[index]['status'] = status ? 1 : 0;
                  });
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed: ${res['message'] ?? 'Unknown error'}"), backgroundColor: Colors.red));
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text("Save", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // 6. Cast Networks View
  Widget _buildCastView() {
    final query = _castQuery.trim().toLowerCase();
    final filtered = query.isEmpty
        ? List<dynamic>.from(_cast)
        : _cast
            .where((c) =>
                (c['name'] ?? '').toString().toLowerCase().contains(query))
            .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showAddNetworkDialog(),
              icon: const Icon(Icons.add_circle, color: Colors.white),
              label: const Text("ADD NETWORK", style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent.withOpacity(0.3), foregroundColor: Colors.purpleAccent, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
          child: TextField(
            onChanged: (v) => setState(() => _castQuery = v),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Search cast / networks...",
              hintStyle: const TextStyle(color: Colors.grey),
              prefixIcon: const Icon(Icons.search, color: Colors.purpleAccent),
              suffixIcon: _castQuery.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.close, color: Colors.white38), onPressed: () => setState(() => _castQuery = ''))
                  : null,
              filled: true,
              fillColor: const Color(0xFF141722),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ),
        Expanded(
          child: _cast.isEmpty
              ? const Center(child: Text("No networks found", style: TextStyle(color: Colors.grey)))
              : filtered.isEmpty
                  ? const Center(child: Text("No matching cast / networks", style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        final realIndex = _cast.indexWhere((c) => c['id'] == item['id']);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [const Color(0xFF232A3C).withOpacity(0.9), const Color(0xFF161B28).withOpacity(0.9)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.07)),
                          ),
                          child: ListTile(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            leading: CircleAvatar(
                              backgroundImage: item['logo'] != null && item['logo'].toString().isNotEmpty ? CachedNetworkImageProvider(item['logo']) : null,
                              radius: 20,
                              child: (item['logo'] ?? '').isEmpty ? const Icon(Icons.person, color: Colors.purpleAccent) : null,
                            ),
                            title: Text(item['name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            subtitle: Text("Order: ${item['networks_order'] ?? 0} • ${(item['status'] ?? 0) == 1 ? 'Active' : 'Inactive'}", style: const TextStyle(color: Colors.white60, fontSize: 12)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Switch(
                                  value: (item['status'] ?? 1) == 1,
                                  activeColor: Colors.purpleAccent,
                                  onChanged: (val) async {
                                    final newStatus = val ? 1 : 0;
                                    final res = await _adminPhpApi('toggle_network_status', {
                                      'id': item['id'],
                                      'status': newStatus,
                                    });
                                    if (res['status'] == 'success') {
                                      setState(() {
                                        _cast[realIndex]['status'] = newStatus;
                                      });
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text("Failed to update status: ${res['message'] ?? 'Error'}"),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  },
                                ),
                                _iconAction(Icons.edit_rounded, Colors.orangeAccent, () => _showEditNetworkDialog(item, realIndex)),
                                _iconAction(Icons.delete_outline_rounded, Colors.redAccent, () async {
                                  final res = await _adminPhpApi('delete_network', {'id': item['id']});
                                  if (res['status'] == 'success') {
                                    setState(() => _cast.removeAt(realIndex));
                                  }
                                }),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  void _showAddNetworkDialog() {
    final nameCtrl = TextEditingController();
    final logCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141722),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Add Network", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "Network Name", labelStyle: const TextStyle(color: Colors.white70), filled: true, fillColor: const Color(0xFF090A0F), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
          const SizedBox(height: 10),
          TextField(controller: logCtrl, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "Logo URL (optional)", labelStyle: const TextStyle(color: Colors.white70), filled: true, fillColor: const Color(0xFF090A0F), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () async {
            if (nameCtrl.text.trim().isEmpty) return;
            final res = await _adminPhpApi('add_network', {'name': nameCtrl.text.trim(), 'logo': logCtrl.text.trim()});
            if (res['status'] == 'success') {
              final nRes = await _adminPhpApi('list_networks', {});
              if (nRes['status'] == 'success') setState(() => _cast = nRes['data']['networks']);
            }
            if (ctx.mounted) Navigator.pop(ctx);
          }, child: const Text("Add", style: TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  void _showEditNetworkDialog(Map<String, dynamic> item, int index) {
    final nameCtrl = TextEditingController(text: item['name'] ?? '');
    final logCtrl = TextEditingController(text: item['logo'] ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141722),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Edit Network", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "Network Name", labelStyle: const TextStyle(color: Colors.white70), filled: true, fillColor: const Color(0xFF090A0F), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
          const SizedBox(height: 10),
          TextField(controller: logCtrl, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "Logo URL", labelStyle: const TextStyle(color: Colors.white70), filled: true, fillColor: const Color(0xFF090A0F), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () async {
            if (nameCtrl.text.trim().isEmpty) return;
            await _adminPhpApi('edit_network', {'id': item['id'], 'name': nameCtrl.text.trim(), 'logo': logCtrl.text.trim()});
            setState(() { _cast[index]['name'] = nameCtrl.text.trim(); _cast[index]['logo'] = logCtrl.text.trim(); });
            if (ctx.mounted) Navigator.pop(ctx);
          }, child: const Text("Save", style: TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  // 7. Users View
  Widget _buildUsersView() {
    final query = _usersQuery.trim().toLowerCase();
    final filtered = query.isEmpty
        ? List<dynamic>.from(_users)
        : _users
            .where((u) =>
                (u['name'] ?? '').toString().toLowerCase().contains(query) ||
                (u['email'] ?? '').toString().toLowerCase().contains(query))
            .toList();

    // All filtered IDs for select-all logic
    final filteredIds = filtered.map((u) => int.tryParse(u['id'].toString()) ?? 0).toSet();
    final allSelected = filteredIds.isNotEmpty && filteredIds.every((id) => _selectedUserIds.contains(id));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            onChanged: (v) => setState(() => _usersQuery = v),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Search users by name or email...",
              hintStyle: const TextStyle(color: Colors.grey),
              prefixIcon: const Icon(Icons.search, color: Colors.cyanAccent),
              suffixIcon: _usersQuery.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.close, color: Colors.white38), onPressed: () => setState(() => _usersQuery = ''))
                  : null,
              filled: true,
              fillColor: const Color(0xFF141722),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ),
        // Toolbar: count + select-mode toggle + bulk delete + bulk expiry
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 2, 14, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _usersSelectMode && _selectedUserIds.isNotEmpty
                      ? "${_selectedUserIds.length} selected"
                      : "${filtered.length} user(s) — tap for details",
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ),
              if (_usersSelectMode && _selectedUserIds.isNotEmpty)
                GestureDetector(
                  onTap: () => _bulkDeleteUsers(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 14),
                        const SizedBox(width: 4),
                        Text('Delete ${_selectedUserIds.length}', style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              if (_usersSelectMode)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      if (allSelected) {
                        _selectedUserIds.removeAll(filteredIds);
                      } else {
                        _selectedUserIds.addAll(filteredIds);
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(allSelected ? 'Deselect All' : 'Select All', style: const TextStyle(color: Colors.white60, fontSize: 11)),
                  ),
                ),
              // Bulk expiry button (always visible)
              GestureDetector(
                onTap: _showBulkExpiryDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: Colors.amberAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amberAccent.withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_month_rounded, color: Colors.amberAccent, size: 13),
                      SizedBox(width: 3),
                      Text('Expiry', style: TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() {
                  _usersSelectMode = !_usersSelectMode;
                  if (!_usersSelectMode) _selectedUserIds.clear();
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _usersSelectMode ? Colors.orangeAccent.withOpacity(0.15) : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _usersSelectMode ? Colors.orangeAccent.withOpacity(0.4) : Colors.transparent),
                  ),
                  child: Text(_usersSelectMode ? 'Cancel' : 'Select', style: TextStyle(color: _usersSelectMode ? Colors.orangeAccent : Colors.white60, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _users.isEmpty
              ? const Center(child: Text("No users found", style: TextStyle(color: Colors.grey)))
              : filtered.isEmpty
                  ? const Center(child: Text("No matching users", style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final u = filtered[index];
                        final uid = int.tryParse(u['id'].toString()) ?? 0;
                        final isVip = _isUserVip(u);
                        final isChecked = _selectedUserIds.contains(uid);
                        final profilePic = (u['profile_pic'] ?? '').toString();
                        return GestureDetector(
                          onLongPress: () {
                            // Long press enters select mode
                            setState(() {
                              _usersSelectMode = true;
                              _selectedUserIds.add(uid);
                            });
                          },
                          onTap: () {
                            if (_usersSelectMode) {
                              setState(() {
                                if (isChecked) {
                                  _selectedUserIds.remove(uid);
                                } else {
                                  _selectedUserIds.add(uid);
                                }
                              });
                            } else {
                              _showUserDetailDialog(u);
                            }
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isChecked
                                    ? [const Color(0xFF3A1515).withOpacity(0.9), const Color(0xFF2A1010).withOpacity(0.9)]
                                    : [const Color(0xFF232A3C).withOpacity(0.9), const Color(0xFF161B28).withOpacity(0.9)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isChecked
                                    ? Colors.redAccent.withOpacity(0.5)
                                    : isVip
                                        ? Colors.greenAccent.withOpacity(0.3)
                                        : Colors.white.withOpacity(0.07),
                              ),
                            ),
                            child: ListTile(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              leading: _usersSelectMode
                                  ? Checkbox(
                                      value: isChecked,
                                      onChanged: (_) {
                                        setState(() {
                                          if (isChecked) {
                                            _selectedUserIds.remove(uid);
                                          } else {
                                            _selectedUserIds.add(uid);
                                          }
                                        });
                                      },
                                      activeColor: Colors.redAccent,
                                      checkColor: Colors.white,
                                      side: const BorderSide(color: Colors.white38),
                                    )
                                  : CircleAvatar(
                                      radius: 22,
                                      backgroundColor: isVip
                                          ? Colors.greenAccent.withOpacity(0.15)
                                          : Colors.cyanAccent.withOpacity(0.15),
                                      backgroundImage: profilePic.isNotEmpty
                                          ? NetworkImage(profilePic)
                                          : null,
                                      child: profilePic.isEmpty
                                          ? Icon(Icons.person, color: isVip ? Colors.greenAccent : Colors.cyanAccent)
                                          : null,
                                    ),
                              title: Text(u['name'] ?? 'User', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(u['email'] ?? '', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                                  const SizedBox(height: 2),
                                  Text("App Version: ${u['app_version'] ?? '1.0.0'}", style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 10, fontWeight: FontWeight.w500)),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(color: isVip ? Colors.green : Colors.grey[800], borderRadius: BorderRadius.circular(12)),
                                    child: Text(isVip ? "VIP" : "FREE", style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                  if (!_usersSelectMode) const SizedBox(width: 4),
                                  if (!_usersSelectMode) const Icon(Icons.chevron_right, color: Colors.white24),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Future<void> _bulkDeleteUsers() async {
    if (_selectedUserIds.isEmpty) return;
    final count = _selectedUserIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2132),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
            const SizedBox(width: 10),
            Text('Delete $count User${count > 1 ? 's' : ''}?', style: const TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          'This will permanently delete $count selected user${count > 1 ? 's' : ''} and all their data (reports, favorites, watch history, subscriptions).\n\nThis cannot be undone.',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton.icon(
            icon: const Icon(Icons.delete_forever_rounded, size: 16, color: Colors.white),
            label: const Text('Delete All', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    int deleted = 0;
    int failed = 0;
    for (final uid in List<int>.from(_selectedUserIds)) {
      try {
        final res = await _adminPhpApi('delete_user', {'user_id': uid});
        if (res['status'] == 'success') {
          deleted++;
          setState(() {
            _users.removeWhere((u) => int.tryParse(u['id'].toString()) == uid);
          });
        } else {
          failed++;
        }
      } catch (_) {
        failed++;
      }
    }
    setState(() {
      _selectedUserIds.clear();
      _usersSelectMode = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(failed == 0
              ? '$deleted user${deleted > 1 ? 's' : ''} deleted successfully'
              : '$deleted deleted, $failed failed'),
          backgroundColor: failed == 0 ? Colors.green : Colors.orange,
        ),
      );
    }
  }

  bool _isUserVip(Map<String, dynamic> u) {
    final sub = (u['active_subscription'] ?? '').toString().trim();
    final low = sub.toLowerCase();
    if (sub.isEmpty ||
        low == '0' ||
        low == 'free' ||
        low == 'none' ||
        low == 'null' ||
        low == 'false' ||
        low == '1') {
      return false;
    }
    final exp = (u['subscription_exp'] ?? '').toString().trim();
    if (exp.isNotEmpty &&
        exp != '0000-00-00' &&
        exp != '0000-00-00 00:00:00') {
      final dt = DateTime.tryParse(exp);
      if (dt != null && dt.isBefore(DateTime.now())) return false;
    }
    return true;
  }

  void _showUserDetailDialog(Map<String, dynamic> u) {
    final isVip = _isUserVip(u);
    
    // Telemetry state variables
    bool loadingTelemetry = true;
    Map<String, dynamic>? telemetryData;
    String? telemetryError;
    bool telemetryTriggered = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, dialogSetState) {
            if (!telemetryTriggered) {
              telemetryTriggered = true;
              _adminPhpApi('get_user_telemetry', {'user_id': u['id']}).then((res) {
                if (dialogContext.mounted) {
                  dialogSetState(() {
                    if (res['status'] == 'success' && res['data'] != null) {
                      telemetryData = res['data'];
                    } else {
                      telemetryError = res['message'] ?? 'Failed to load telemetry';
                    }
                    loadingTelemetry = false;
                  });
                }
              }).catchError((err) {
                if (dialogContext.mounted) {
                  dialogSetState(() {
                    telemetryError = err.toString();
                    loadingTelemetry = false;
                  });
                }
              });
            }

            // Calculations for active session & playtime
            Widget activeSessionWidget;
            if (loadingTelemetry) {
              activeSessionWidget = const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orangeAccent)),
                    SizedBox(width: 8),
                    Text("Loading live status...", style: TextStyle(color: Colors.white60, fontSize: 12)),
                  ],
                ),
              );
            } else if (telemetryError != null) {
              activeSessionWidget = Text("Telemetry Error: $telemetryError", style: const TextStyle(color: Colors.redAccent, fontSize: 12));
            } else {
              final active = telemetryData?['active_session'];
              if (active != null) {
                final lastPingStr = active['last_ping']?.toString();
                bool isOnline = false;
                if (lastPingStr != null) {
                  final lp = DateTime.tryParse(lastPingStr);
                  if (lp != null) {
                    isOnline = DateTime.now().difference(lp).inMinutes.abs() < 3;
                  }
                }
                
                final String viewName = active['current_view']?.toString() ?? 'Browsing';
                final String? contentName = active['content_name']?.toString();

                activeSessionWidget = Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isOnline ? Colors.greenAccent : Colors.grey,
                        shape: BoxShape.circle,
                        boxShadow: isOnline ? [BoxShadow(color: Colors.greenAccent.withOpacity(0.5), blurRadius: 6, spreadRadius: 1)] : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isOnline
                            ? "Online • ${contentName != null ? 'Watching: $contentName' : 'View: $viewName'}"
                            : "Offline (Last active: ${lastPingStr ?? 'N/A'})",
                        style: TextStyle(
                          color: isOnline ? Colors.greenAccent : Colors.white60,
                          fontSize: 12.5,
                          fontWeight: isOnline ? FontWeight.bold : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                );
              } else {
                activeSessionWidget = Row(
                  children: [
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    const Text("Offline (No active pings)", style: TextStyle(color: Colors.white60, fontSize: 12.5)),
                  ],
                );
              }
            }

            // Watch history helper
            List<Widget> historyItems = [];
            String totalPlaytimeFormatted = "0 mins";
            if (!loadingTelemetry && telemetryData != null) {
              final history = telemetryData!['play_history'] as List?;
              final totalSec = int.tryParse(telemetryData!['total_playtime_seconds']?.toString() ?? '0') ?? 0;
              
              if (totalSec > 0) {
                final hrs = totalSec ~/ 3600;
                final mins = (totalSec % 3600) ~/ 60;
                totalPlaytimeFormatted = hrs > 0 ? "$hrs hrs $mins mins" : "$mins mins";
              }

              if (history == null || history.isEmpty) {
                historyItems.add(const Text("No play events recorded yet.", style: TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic)));
              } else {
                for (var h in history.take(5)) {
                  final name = h['content_name']?.toString() ?? 'Unknown Content';
                  final typeLabel = h['content_type']?.toString() == '1' ? 'Movie' : 'Series';
                  final duration = int.tryParse(h['duration_seconds']?.toString() ?? '0') ?? 0;
                  final durMins = duration ~/ 60;
                  final completed = h['completed']?.toString() == '1';

                  historyItems.add(
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6.0),
                      child: Row(
                        children: [
                          Icon(typeLabel == 'Movie' ? Icons.movie_outlined : Icons.live_tv_outlined, size: 14, color: Colors.orangeAccent),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            "$durMins m",
                            style: const TextStyle(color: Colors.white54, fontSize: 11, fontFamily: 'monospace'),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: completed ? Colors.green.withOpacity(0.2) : Colors.blue.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              completed ? "COMP" : "PLAY",
                              style: TextStyle(color: completed ? Colors.greenAccent : Colors.blueAccent, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
              }
            }

            // Downloads helper
            List<Widget> downloadItems = [];
            if (!loadingTelemetry && telemetryData != null) {
              final downloads = telemetryData!['downloads'] as List?;
              if (downloads == null || downloads.isEmpty) {
                downloadItems.add(const Text("No downloads triggered yet.", style: TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic)));
              } else {
                for (var d in downloads.take(5)) {
                  final name = d['content_name']?.toString() ?? 'Unknown Content';
                  final typeLabel = d['content_type']?.toString() == '1' ? 'Movie' : 'Series';
                  final status = d['status']?.toString() ?? 'started';
                  final isDone = status == 'completed';

                  downloadItems.add(
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6.0),
                      child: Row(
                        children: [
                          const Icon(Icons.download_rounded, size: 14, color: Colors.cyanAccent),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: isDone ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: TextStyle(color: isDone ? Colors.greenAccent : Colors.orangeAccent, fontSize: 8, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
              }
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF1A2132),
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: Colors.white.withOpacity(0.08))),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF8E2DE2), Color(0xFFE50914)]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.person_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(u['name'] ?? 'User', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _userDetailRow("ID", "${u['id'] ?? 'N/A'}"),
                      _userDetailRow("Email", u['email'] ?? 'N/A'),
                      _userDetailRow("App Version", u['app_version'] ?? '1.0.0'),
                      _userDetailRow("Role", '${u['role'] ?? 0}'),
                      _userDetailRow("Subscription", u['active_subscription'] ?? 'Free'),
                      _userDetailRow("Expires", '${u['subscription_exp'] ?? 'N/A'}'),
                      _userDetailRow("Device ID", u['device_id'] ?? 'N/A'),
                      const SizedBox(height: 8),
                      
                      // VIP Badge Banner
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isVip ? Colors.green.withOpacity(0.12) : Colors.grey.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isVip ? "✔ VIP ACTIVE" : "NO VIP SUBSCRIPTION",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isVip ? Colors.greenAccent : Colors.white54,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      
                      // ── Telemetry View Section ──
                      const SizedBox(height: 16),
                      const Row(
                        children: [
                          Icon(Icons.query_stats_rounded, color: Colors.orangeAccent, size: 18),
                          SizedBox(width: 6),
                          Text("LIVE USER METRICS & TELEMETRY", style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 11.5, letterSpacing: 0.5)),
                        ],
                      ),
                      const Divider(color: Colors.white10, height: 12),
                      
                      // Active Session Status
                      const Text("Current Live Status:", style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      activeSessionWidget,
                      
                      // Total Watch Playtime
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Total Watch Time:", style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                          Text(
                            totalPlaytimeFormatted,
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Recent Watch History List
                      const Text("Recent Play History (Last 5):", style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      if (loadingTelemetry)
                        const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orangeAccent))
                      else
                        ...historyItems,
                        
                      // Recent Downloads List
                      const SizedBox(height: 12),
                      const Text("Recent Downloads (Last 5):", style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      if (loadingTelemetry)
                        const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyanAccent))
                      else
                        ...downloadItems,
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _confirmDeleteUser(u);
                  },
                  child: const Text("Delete User", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                ),
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close", style: TextStyle(color: Colors.grey))),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showEditUserDialog(u);
                  },
                  child: const Text("Edit User", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                ),
                if (isVip)
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _confirmRevokeVip(u);
                    },
                    child: const Text("Revoke VIP", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  )
                else
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showGrantVipDialog(u);
                    },
                    child: const Text("Grant VIP", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _userDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text("$label:", style: const TextStyle(color: Colors.white54, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 13))),
        ],
      ),
    );
  }

  void _showGrantVipDialog(Map<String, dynamic> u) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _GrantVipDialog(
        user: u,
        apiCall: _adminPhpApi,
        onGranted: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("VIP granted to ${u['name']}!"), backgroundColor: Colors.green),
          );
          _loadDashboardData();
        },
      ),
    );
  }

  // ── EDIT USER BOTTOM SHEET ──
  void _showEditUserDialog(Map<String, dynamic> u) {
    final nameCtrl = TextEditingController(text: u['name'] ?? '');
    final emailCtrl = TextEditingController(text: u['email'] ?? '');
    final pwCtrl = TextEditingController();
    DateTime? expiryDate = DateTime.tryParse((u['subscription_exp'] ?? '').toString().split(' ').first);
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D1117),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: Colors.white12),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ssCtx, ssSetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 16,
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 32,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.edit_rounded, color: Colors.cyanAccent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Edit User — ${u['name'] ?? ''}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Name field
                _buildSheetField('Name', nameCtrl, hint: 'Display name'),
                const SizedBox(height: 10),
                // Email field
                _buildSheetField('Email', emailCtrl, hint: 'Email address', keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 10),
                // Password field
                _buildSheetField('New Password', pwCtrl, hint: 'Leave empty to keep unchanged', obscure: true),
                const SizedBox(height: 10),
                // Expiry date picker
                GestureDetector(
                  onTap: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: expiryDate ?? DateTime(now.year, now.month + 1, 0),
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2030),
                      builder: (ctx, child) => Theme(data: ThemeData.dark(), child: child!),
                    );
                    if (picked != null) ssSetState(() => expiryDate = picked);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141722),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, color: Colors.cyanAccent, size: 16),
                        const SizedBox(width: 10),
                        Text(
                          expiryDate != null
                              ? 'Expiry: ${expiryDate!.year}-${expiryDate!.month.toString().padLeft(2, '0')}-${expiryDate!.day.toString().padLeft(2, '0')}'
                              : 'Tap to set expiry date',
                          style: TextStyle(color: expiryDate != null ? Colors.white : Colors.white38, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: saving ? null : () async {
                      ssSetState(() => saving = true);
                      final body = <String, dynamic>{'user_id': u['id']};
                      if (nameCtrl.text.trim().isNotEmpty) body['name'] = nameCtrl.text.trim();
                      if (emailCtrl.text.trim().isNotEmpty) body['email'] = emailCtrl.text.trim();
                      if (pwCtrl.text.trim().isNotEmpty) body['password'] = pwCtrl.text.trim();
                      if (expiryDate != null) {
                        body['subscription_exp'] = '${expiryDate!.year}-${expiryDate!.month.toString().padLeft(2, '0')}-${expiryDate!.day.toString().padLeft(2, '0')} 23:59:59';
                      }
                      final res = await _adminPhpApi('edit_user', body);
                      ssSetState(() => saving = false);
                      if (!mounted) return;
                      if (res['status'] == 'success') {
                        Navigator.pop(sheetCtx);
                        // Update local user data
                        setState(() {
                          if (nameCtrl.text.trim().isNotEmpty) u['name'] = nameCtrl.text.trim();
                          if (emailCtrl.text.trim().isNotEmpty) u['email'] = emailCtrl.text.trim();
                          if (expiryDate != null) {
                            u['subscription_exp'] = '${expiryDate!.year}-${expiryDate!.month.toString().padLeft(2, '0')}-${expiryDate!.day.toString().padLeft(2, '0')}';
                          }
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('User updated successfully!'), backgroundColor: Colors.green),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: ${res['message'] ?? 'Unknown error'}'), backgroundColor: Colors.red),
                        );
                      }
                    },
                    icon: saving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : const Icon(Icons.save_rounded, size: 18),
                    label: Text(saving ? 'Saving...' : 'Save Changes', style: const TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyanAccent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSheetField(String label, TextEditingController ctrl, {
    String hint = '',
    bool obscure = false,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          obscureText: obscure,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
            filled: true,
            fillColor: const Color(0xFF141722),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }

  // ── BULK EXPIRY DIALOG ──
  void _showBulkExpiryDialog() {
    DateTime selectedDate = DateTime(DateTime.now().year, DateTime.now().month + 1, 0);
    bool running = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ssCtx, ssSetState) => AlertDialog(
          backgroundColor: const Color(0xFF1A2132),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: Colors.white.withOpacity(0.08))),
          title: const Row(
            children: [
              Icon(Icons.calendar_month_rounded, color: Colors.amberAccent),
              SizedBox(width: 10),
              Text('Bulk Set VIP Expiry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Set the subscription expiry date for ALL active VIP users.',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: now,
                    lastDate: DateTime(2030),
                    builder: (ctx, child) => Theme(data: ThemeData.dark(), child: child!),
                  );
                  if (picked != null) ssSetState(() => selectedDate = picked);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141722),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amberAccent.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, color: Colors.amberAccent, size: 16),
                      const SizedBox(width: 10),
                      Text(
                        '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: running ? null : () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
            ElevatedButton.icon(
              onPressed: running ? null : () async {
                ssSetState(() => running = true);
                final dateStr = '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
                final payload = <String, dynamic>{'expiry': dateStr};
                if (_selectedUserIds.isNotEmpty) {
                  payload['user_ids'] = _selectedUserIds.toList();
                }
                final res = await _adminPhpApi('bulk_set_expiry', payload);
                ssSetState(() => running = false);
                if (!mounted) return;
                Navigator.pop(ctx);
                final updated = res['data']?['updated'] ?? 0;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res['status'] == 'success'
                        ? 'Updated $updated user(s) expiry to $dateStr'
                        : 'Error: ${res['message'] ?? 'Failed'}'),
                    backgroundColor: res['status'] == 'success' ? Colors.green : Colors.red,
                  ),
                );
                if (res['status'] == 'success') {
                  setState(() {
                    for (var u in _users) {
                      final uid = int.tryParse(u['id'].toString()) ?? 0;
                      if (_selectedUserIds.isEmpty || _selectedUserIds.contains(uid)) {
                        u['subscription_exp'] = dateStr;
                      }
                    }
                  });
                  _loadUsers();
                  _loadDashboardData();
                }
              },
              icon: running
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.check_rounded, size: 16),
              label: Text(
                running
                    ? 'Updating...'
                    : _selectedUserIds.isNotEmpty
                        ? 'Apply to Selected (${_selectedUserIds.length})'
                        : 'Apply to All Users',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amberAccent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRevokeVip(Map<String, dynamic> u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2132),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: Colors.white.withOpacity(0.08))),
        title: const Text("Revoke VIP?", style: TextStyle(color: Colors.white)),
        content: Text("Remove VIP from '${u['name'] ?? 'User'}'?", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Revoke", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (ok == true) {
      final res = await _adminPhpApi('revoke_vip', {'user_id': u['id']});
      if (res['status'] == 'success') {
        setState(() {
          u['active_subscription'] = 'Free';
          u['subscription_type'] = 0;
          u['time'] = 0;
          u['amount'] = 0;
          u['subscription_exp'] = '0000-00-00';
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("VIP revoked from ${u['name']}"), backgroundColor: Colors.green));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed: ${res['message'] ?? 'Unknown error'}"), backgroundColor: Colors.red));
      }
    }
  }

  // 8. Coupons View
  Widget _buildCouponsView() {
    if (!_couponsLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_couponsLoaded) _loadCoupons();
      });
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showCreateCouponDialog,
              icon: const Icon(Icons.confirmation_number_rounded, color: Colors.white),
              label: const Text("GENERATE COUPON", style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8E2DE2), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Text("Coupons are linked to subscription plans and are redeemable in the app", style: const TextStyle(color: Colors.white38, fontSize: 11)),
        ),
        Expanded(
          child: _coupons.isEmpty
              ? (_couponsLoaded
                  ? const Center(child: Text("No coupons yet. Generate one above.", style: TextStyle(color: Colors.grey)))
                  : const Center(child: CircularProgressIndicator(color: Color(0xFF8E2DE2))))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  itemCount: _coupons.length,
                  itemBuilder: (context, index) => _couponCard(_coupons[index]),
                ),
        ),
      ],
    );
  }

  Future<void> _loadCoupons() async {
    final res = await _adminPhpApi('list_coupons', {});
    if (!mounted) return;
    if (res['status'] == 'success' && res['data']?['coupons'] != null) {
      setState(() {
        _coupons = res['data']['coupons'];
        _couponsLoaded = true;
      });
    } else {
      setState(() => _couponsLoaded = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load coupons: ${res['message'] ?? 'Unknown'}"), backgroundColor: Colors.red),
      );
    }
  }

  Widget _couponCard(dynamic c) {
    final code = (c['coupon_code'] ?? '').toString();
    final name = (c['name'] ?? '').toString();
    final used = int.tryParse('${c['used'] ?? 0}') ?? 0;
    final maxUse = int.tryParse('${c['max_use'] ?? 1}') ?? 1;
    final status = int.tryParse('${c['status'] ?? 1}') ?? 1;
    final days = int.tryParse('${c['time'] ?? 0}') ?? 0;
    final amount = int.tryParse('${c['amount'] ?? 0}') ?? 0;
    final exp = (c['expire_date'] ?? '').toString();
    final usedUsers = c['used_users'] as List? ?? [];
    final active = status == 1;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF232A3C).withOpacity(0.9), const Color(0xFF161B28).withOpacity(0.9)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: active ? Colors.greenAccent.withOpacity(0.25) : Colors.redAccent.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: (active ? Colors.greenAccent : Colors.redAccent).withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.confirmation_number_rounded, color: active ? Colors.greenAccent : Colors.redAccent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(code, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
                    Text(name, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: active ? Colors.green : Colors.grey[800], borderRadius: BorderRadius.circular(12)),
                child: Text(active ? "ACTIVE" : "EXPIRED", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _epTag("$days Days • ₹$amount", Colors.cyanAccent),
              _epTag("$used / $maxUse used", used >= maxUse ? Colors.redAccent : Colors.orangeAccent),
              _epTag("Expires: ${exp.isEmpty ? 'Never' : exp}", Colors.white54),
            ],
          ),
          if (usedUsers.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text("Used by:", style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            ...usedUsers.map((uu) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text("• ${uu['name'] ?? 'User'} (id: ${uu['id']})", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                )),
          ],
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _iconAction(Icons.toggle_on_rounded, active ? Colors.greenAccent : Colors.redAccent, () async {
                final res = await _adminPhpApi('toggle_coupon', {'id': c['id']});
                if (res['status'] == 'success') {
                  setState(() => c['status'] = active ? 0 : 1);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed: ${res['message'] ?? 'Unknown error'}"), backgroundColor: Colors.red));
                }
              }),
              _iconAction(Icons.delete_outline_rounded, Colors.redAccent, () => _confirmDeleteCoupon(c)),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteCoupon(dynamic c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2132),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: Colors.white.withOpacity(0.08))),
        title: const Text("Delete Coupon?", style: TextStyle(color: Colors.white)),
        content: Text("Delete coupon '${c['coupon_code'] ?? ''}'?", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (ok == true) {
      final res = await _adminPhpApi('delete_coupon', {'id': c['id']});
      if (res['status'] == 'success') {
        setState(() => _coupons.removeWhere((x) => x['id'] == c['id']));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed: ${res['message'] ?? 'Unknown error'}"), backgroundColor: Colors.red));
      }
    }
  }

  void _showCreateCouponDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CreateCouponDialog(
        apiCall: _adminPhpApi,
        onCreated: () {
          _loadCoupons();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Coupon created!"), backgroundColor: Colors.green),
          );
        },
      ),
    );
  }

  String _randomCouponCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random();
    return 'RED' + List.generate(8, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  // 9. DEAD LINKS SCANNER VIEW
  Widget _buildDeadScannerView() {
    if (_parkedMovies.isEmpty && _parkedSeries.isEmpty && !_parkedLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _parkedMovies.isEmpty && _parkedSeries.isEmpty && !_parkedLoading) _loadParked();
      });
    }

    final query = _deadQuery.trim().toLowerCase();
    final ott = _deadOttFilter;

    final movies = _parkedMovies.where((m) {
      if (_deadFilter == 'series') return false;
      if (query.isNotEmpty && !(m['name'] ?? '').toString().toLowerCase().contains(query)) return false;
      if (ott.isNotEmpty && !((m['genres'] ?? '').toString().contains(ott))) return false;
      return true;
    }).toList();

    final series = _parkedSeries.where((s) {
      if (_deadFilter == 'movie') return false;
      if (query.isNotEmpty && !(s['name'] ?? '').toString().toLowerCase().contains(query)) return false;
      if (ott.isNotEmpty && !((s['genres'] ?? '').toString().contains(ott))) return false;
      return true;
    }).toList();

    final otts = _genres.map((g) => (g['name'] ?? '').toString()).where((n) => n.isNotEmpty).toList();
    final totalDead = _parkedMovies.length + _parkedSeries.length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1E2230), Color(0xFF141722)]),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE50914).withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.health_and_safety_rounded, color: Color(0xFFE50914), size: 24),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text("Dead Link Diagnostic Engine",
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text("$totalDead parked item(s) — tap a card to repair",
                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      if (!_scanning) ...[
                        ElevatedButton.icon(
                          onPressed: () => _startScan(),
                          icon: const Icon(Icons.play_arrow_rounded, size: 16),
                          label: const Text("FULL SCAN", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE50914), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9)),
                        ),
                        if (_deadOttFilter.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () => _startScan(ottFilter: _deadOttFilter),
                            icon: const Icon(Icons.filter_alt_rounded, size: 16),
                            label: Text("SCAN '$_deadOttFilter'", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9)),
                          ),
                        ],
                      ] else ...[
                        ElevatedButton.icon(
                          onPressed: _cancelScan,
                          icon: const Icon(Icons.stop_rounded, size: 16),
                          label: const Text("STOP", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[800], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9)),
                        ),
                      ],
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => setState(() {
                          _deadSelectMode = !_deadSelectMode;
                          if (!_deadSelectMode) _deadSelected.clear();
                        }),
                        icon: Icon(_deadSelectMode ? Icons.close_rounded : Icons.checklist_rounded, size: 16),
                        label: Text(_deadSelectMode ? "DONE" : "SELECT", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(backgroundColor: _deadSelectMode ? Colors.cyanAccent : const Color(0xFF2A3145), foregroundColor: _deadSelectMode ? Colors.black : Colors.white, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _confirmRestoreAll,
                        icon: const Icon(Icons.cloud_upload_rounded, size: 16),
                        label: const Text("REMOVE ALL", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9)),
                      ),
                    ],
                  ),
                ),
                if (_scanning) ...[
                  const SizedBox(height: 10),
                  _scanProgress("Movies", _movieChecked, _movieTotal, _movieDead),
                  const SizedBox(height: 4),
                  _scanProgress("Episodes", _epChecked, _epTotal, _epDead),
                  const SizedBox(height: 6),
                  const Text("Dead movies/series appear below in the parked list as they are found.",
                      style: TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
          child: TextField(
            onChanged: (v) => setState(() => _deadQuery = v),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Live search dead content...",
              hintStyle: const TextStyle(color: Colors.grey),
              prefixIcon: const Icon(Icons.search, color: Colors.redAccent),
              suffixIcon: _deadQuery.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.close, color: Colors.white38), onPressed: () => setState(() => _deadQuery = ''))
                  : null,
              filled: true,
              fillColor: const Color(0xFF141722),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
          child: Row(
            children: [
              Expanded(
                child: _deadDropdown<String>(
                  value: _deadFilter,
                  items: const {
                    'all': 'All Content',
                    'movie': 'Movies Only',
                    'series': 'Web Series Only',
                  },
                  onChanged: (v) => setState(() => _deadFilter = v ?? 'all'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _deadDropdown<String>(
                  value: _deadOttFilter,
                  items: {'': 'All OTTs', for (final o in otts) o: o},
                  onChanged: (v) => setState(() => _deadOttFilter = v ?? ''),
                ),
              ),
            ],
          ),
        ),
        if (_deadSelectMode)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.cyanAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.cyanAccent.withOpacity(0.35)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text("${_deadSelected.length} selected",
                        style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  TextButton.icon(
                    onPressed: _deadSelected.isEmpty ? null : _removeSelectedDead,
                    icon: const Icon(Icons.restore_rounded, size: 18),
                    label: const Text("REMOVE", style: TextStyle(fontWeight: FontWeight.bold)),
                    style: TextButton.styleFrom(foregroundColor: Colors.greenAccent),
                  ),
                  TextButton.icon(
                    onPressed: _deadSelected.isEmpty ? null : _deleteSelectedDead,
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text("DELETE", style: TextStyle(fontWeight: FontWeight.bold)),
                    style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child: (_parkedMovies.isEmpty && _parkedSeries.isEmpty)
              ? Center(
                  child: _parkedLoading
                      ? const CircularProgressIndicator(color: Color(0xFFE50914))
                      : const Text("No parked content. Run a scan to find dead links.",
                          style: TextStyle(color: Colors.white54)),
                )
              : (movies.isEmpty && series.isEmpty)
                  ? const Center(child: Text("No matching dead content", style: TextStyle(color: Colors.white54)))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                      itemCount: movies.length + series.length,
                      itemBuilder: (context, index) {
                        if (index < movies.length) return _deadMovieTile(movies[index]);
                        return _deadSeriesTile(series[index - movies.length]);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _scanProgress(String label, int checked, int total, int dead) {
    return Row(
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total > 0 ? (checked / total).clamp(0.0, 1.0) : 0,
              minHeight: 5,
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE50914)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text("$checked/$total • $dead dead", style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }

  Widget _deadDropdown<T>({required T value, required Map<T, String> items, required ValueChanged<T?> onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: const Color(0xFF141722), borderRadius: BorderRadius.circular(12)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          dropdownColor: const Color(0xFF141722),
          isExpanded: true,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
          items: items.entries
              .map((e) => DropdownMenuItem<T>(
                    value: e.key,
                    child: Text(e.value,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _deadMovieTile(dynamic m) {
    final deadCount = (m['dead_links'] as List? ?? []).length;
    final key = 'm${m['id']}';
    return _deadContentCard(
      poster: m['poster'] ?? '',
      title: m['name'] ?? '',
      subtitle: '$deadCount dead link(s)',
      icon: Icons.movie_rounded,
      accent: Colors.redAccent,
      selectKey: key,
      onTap: () {
        if (_deadSelectMode) {
          _toggleDeadSelect(key);
        } else {
          _showMovieRepairDialog(m);
        }
      },
      onRemove: () => _removeOneDead('movie', m['id'], m['name'] ?? ''),
    );
  }

  Widget _deadSeriesTile(dynamic s) {
    final deadCount = (s['dead_episodes'] as List? ?? []).length;
    final key = 's${s['id']}';
    return _deadContentCard(
      poster: s['poster'] ?? '',
      title: s['name'] ?? '',
      subtitle: '$deadCount dead episode(s)',
      icon: Icons.tv_rounded,
      accent: Colors.purpleAccent,
      selectKey: key,
      onTap: () {
        if (_deadSelectMode) {
          _toggleDeadSelect(key);
        } else {
          _showSeriesRepairDialog(s);
        }
      },
      onRemove: () => _removeOneDead('series', s['id'], s['name'] ?? ''),
    );
  }

  void _toggleDeadSelect(String key) {
    setState(() {
      if (_deadSelected.contains(key)) {
        _deadSelected.remove(key);
      } else {
        _deadSelected.add(key);
      }
    });
  }

  Future<void> _removeOneDead(String type, dynamic id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2132),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: Colors.white.withOpacity(0.08))),
        title: const Text("Remove from Dead Area?", style: TextStyle(color: Colors.white)),
        content: Text("Restore '$name' back to the app immediately?", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Remove", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (ok == true) {
      final res = await _adminPhpApi('remove_from_dead', {'type': type, 'id': id});
      if (res['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Restored to the app"), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed: ${res['message'] ?? 'Unknown error'}"), backgroundColor: Colors.red),
        );
      }
      await _loadParked();
    }
  }

  Future<void> _removeSelectedDead() async {
    if (_deadSelected.isEmpty) return;
    for (final key in _deadSelected.toList()) {
      final type = key.startsWith('m') ? 'movie' : 'series';
      final id = int.tryParse(key.substring(1)) ?? 0;
      await _adminPhpApi('remove_from_dead', {'type': type, 'id': id});
    }
    setState(() => _deadSelected.clear());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Selected items restored to the app"), backgroundColor: Colors.green),
    );
    await _loadParked();
  }

  Future<void> _deleteSelectedDead() async {
    if (_deadSelected.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2132),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: Colors.white.withOpacity(0.08))),
        title: const Text("Delete Selected?", style: TextStyle(color: Colors.white)),
        content: Text("Permanently delete ${_deadSelected.length} selected item(s) with all their links?", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (ok == true) {
      for (final key in _deadSelected.toList()) {
        final type = key.startsWith('m') ? 'movie' : 'series';
        final id = int.tryParse(key.substring(1)) ?? 0;
        await _adminPhpApi('delete_content', {'type': type, 'id': id});
      }
      setState(() => _deadSelected.clear());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Selected items deleted"), backgroundColor: Colors.green),
      );
      await _loadParked();
    }
  }

  Widget _deadContentCard({
    required String poster,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accent,
    required String selectKey,
    required VoidCallback onTap,
    required VoidCallback onRemove,
  }) {
    final selected = _deadSelected.contains(selectKey);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFF232A3C).withOpacity(0.9), const Color(0xFF161B28).withOpacity(0.9)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? Colors.cyanAccent
                : accent.withOpacity(0.3),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: poster.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: poster, width: 46, height: 60, fit: BoxFit.cover,
                      errorWidget: (c, u, e) => Container(width: 46, height: 60, color: const Color(0xFF2A3145), child: Icon(icon, color: Colors.white24)))
                  : Container(width: 46, height: 60, color: const Color(0xFF2A3145), child: Icon(icon, color: Colors.white24)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(subtitle, style: TextStyle(color: accent, fontSize: 12)),
                ],
              ),
            ),
            if (_deadSelectMode)
              Icon(
                selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                color: selected ? Colors.cyanAccent : Colors.white30,
                size: 22,
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.restore_rounded, color: Colors.greenAccent, size: 20),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Remove from dead area',
                    onPressed: onRemove,
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white24),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _showMovieRepairDialog(dynamic m) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _MovieRepairDialog(
        item: m,
        apiCall: _adminPhpApi,
        onDone: () {
          _loadParked();
          setState(() {});
        },
        showExtractor: _showQuickLinkExtractorDialog,
        onEdit: (item, type) {
          _startEdit(item, type);
          setState(() => _selectedIndex = 2);
        },
      ),
    );
  }

  void _showSeriesRepairDialog(dynamic s) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _SeriesRepairDialog(
        item: s,
        apiCall: _adminPhpApi,
        onDone: () {
          _loadParked();
          setState(() {});
        },
        showExtractor: _showQuickLinkExtractorDialog,
        onEdit: (item, type) {
          _startEdit(item, type);
          setState(() => _selectedIndex = 2);
        },
      ),
    );
  }

  Future<void> _confirmRestoreAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2132),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: Colors.white.withOpacity(0.08))),
        title: const Text("Remove all from Dead Area?", style: TextStyle(color: Colors.white)),
        content: const Text("This restores ALL parked content back to the app immediately, even if their links are still broken.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Restore All", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (ok == true) {
      final res = await _adminPhpApi('restore_all', {});
      if (res['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("All dead content restored to the app"), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed: ${res['message'] ?? 'Unknown error'}"), backgroundColor: Colors.red),
        );
      }
      await _loadParked();
    }
  }

  // 9b. Link Updater (Domain Replace) View
  final _oldDomainCtrl = TextEditingController();
  final _newDomainCtrl = TextEditingController();
  bool _domainReplacing = false;
  String? _domainResult;

  Widget _buildLinkUpdaterView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1E2230), Color(0xFF141722)]),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF8E2DE2).withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.swap_horiz_rounded, color: Color(0xFF8E2DE2), size: 24),
                SizedBox(width: 8),
                Expanded(
                  child: Text("Link Updater — Replace Domain Everywhere",
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF232A3C).withOpacity(0.9), const Color(0xFF161B28).withOpacity(0.9)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.07)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                    "Streamtape & other hosts change domains frequently. Replace an old host with a new one across ALL play + download links (movies & series) in one click.",
                    style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4)),
                const SizedBox(height: 14),
                TextField(
                  controller: _oldDomainCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: "Old Domain (e.g. tapepops.com)",
                    labelStyle: const TextStyle(color: Colors.white70),
                    hintText: "tapepops.com",
                    hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                    prefixIcon: const Icon(Icons.link_off_rounded, color: Color(0xFFE50914)),
                    filled: true,
                    fillColor: const Color(0xFF090A0F),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _newDomainCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: "New Domain (e.g. tpead.net)",
                    labelStyle: const TextStyle(color: Colors.white70),
                    hintText: "tpead.net",
                    hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                    prefixIcon: const Icon(Icons.link_rounded, color: Color(0xFF4CAF50)),
                    filled: true,
                    fillColor: const Color(0xFF090A0F),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _domainReplacing ? null : _previewDomainReplace,
                        icon: const Icon(Icons.search_rounded, color: Colors.white),
                        label: const Text("PREVIEW", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2A3145),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _domainReplacing ? null : _confirmDomainReplace,
                        icon: const Icon(Icons.swap_horiz_rounded, color: Colors.white),
                        label: const Text("REPLACE ALL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8E2DE2),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_domainResult != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8E2DE2).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF8E2DE2).withOpacity(0.4)),
                    ),
                    child: Text(_domainResult!,
                        style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _previewDomainReplace() async {
    final oldD = _oldDomainCtrl.text.trim();
    final newD = _newDomainCtrl.text.trim();
    if (oldD.isEmpty || newD.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter both old and new domain")),
      );
      return;
    }
    setState(() {
      _domainReplacing = true;
      _domainResult = null;
    });
    final res = await _adminPhpApi('replace_domain',
        {'old_domain': oldD, 'new_domain': newD, 'dry_run': true}, timeout: 120);
    if (!mounted) return;
    setState(() {
      _domainReplacing = false;
      _domainResult = res['status'] == 'success'
          ? "Preview: ${res['data']?['updated'] ?? 0} link(s) would be updated."
          : "Failed: ${res['message'] ?? 'Unknown error'}";
    });
  }

  Future<void> _confirmDomainReplace() async {
    final oldD = _oldDomainCtrl.text.trim();
    final newD = _newDomainCtrl.text.trim();
    if (oldD.isEmpty || newD.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter both old and new domain")),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2132),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: Colors.white.withOpacity(0.08))),
        title: const Text("Replace domain everywhere?", style: TextStyle(color: Colors.white)),
        content: Text(
          "Replace '$oldD' with '$newD' in ALL play links and download links for both movies and web series?\n\nThis cannot be undone.",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Replace All", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _domainReplacing = true;
      _domainResult = null;
    });
    final res = await _adminPhpApi('replace_domain',
        {'old_domain': oldD, 'new_domain': newD}, timeout: 180);
    if (!mounted) return;
    setState(() {
      _domainReplacing = false;
      _domainResult = res['status'] == 'success'
          ? "Done: ${res['data']?['updated'] ?? 0} link(s) updated across movies, series, play & download."
          : "Failed: ${res['message'] ?? 'Unknown error'}";
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res['status'] == 'success'
            ? "${res['data']?['updated'] ?? 0} link(s) updated"
            : "Failed: ${res['message'] ?? 'Unknown error'}"),
        backgroundColor: res['status'] == 'success' ? Colors.green : Colors.red,
      ),
    );
  }

  // 10. App Settings View
  bool _loginMandatory = false;
  bool _settingsLoaded = false;
  final _telegramLinkCtrl = TextEditingController();
  final _adminPinCtrl = TextEditingController();
  
  bool _updateSkippable = false;
  final _latestVersionCtrl = TextEditingController();
  final _v7aApkCtrl = TextEditingController();
  final _v8aApkCtrl = TextEditingController();
  final _universalApkCtrl = TextEditingController();

  bool _telemetryDashboardLoading = false;
  Map<String, dynamic>? _telemetryDashboardData;
  String? _telemetryDashboardError;
  bool _isUploadingPoster = false;

  Widget _buildAppSettingsView() {
    if (!_settingsLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_settingsLoaded) _loadAppSettings();
      });
    }
    return SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF1E2230), Color(0xFF141722)]),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.cyanAccent.withOpacity(0.25)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.settings_suggest_rounded, color: Colors.cyanAccent, size: 24),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text("App Settings",
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF232A3C).withOpacity(0.9), const Color(0xFF161B28).withOpacity(0.9)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.07)),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    value: _loginMandatory,
                    activeTrackColor: Colors.cyanAccent,
                    onChanged: (v) => setState(() => _loginMandatory = v),
                    title: const Text("Login Mandatory",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    subtitle: const Text(
                        "If ON, users must log in to open the app. If OFF, guests can browse without login.",
                        style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                    child: TextField(
                      controller: _telegramLinkCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "Telegram Link",
                        labelStyle: const TextStyle(color: Colors.white70),
                        hintText: "https://t.me/+xxxxxxxxx",
                        hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                        prefixIcon: const Icon(Icons.send_rounded, color: Color(0xFF229ED9)),
                        filled: true,
                        fillColor: const Color(0xFF090A0F),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                    child: TextField(
                      controller: _adminPinCtrl,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 6,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "Admin Panel PIN (4-6 digits)",
                        labelStyle: const TextStyle(color: Colors.white70),
                        hintText: "Leave blank to keep current",
                        hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                        prefixIcon: const Icon(Icons.password_rounded, color: Color(0xFF8E2DE2)),
                        filled: true,
                        fillColor: const Color(0xFF090A0F),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        counterText: "",
                      ),
                    ),
                  ),
                  
                  // App Update Manager Settings Divider & Title
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    child: Row(
                      children: [
                        Icon(Icons.cloud_upload_rounded, color: Colors.orangeAccent, size: 20),
                        SizedBox(width: 8),
                        Text(
                          "APP UPDATE MANAGER",
                          style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  
                  SwitchListTile(
                    value: _updateSkippable,
                    activeTrackColor: Colors.orangeAccent,
                    onChanged: (v) => setState(() => _updateSkippable = v),
                    title: const Text("Update Skippable",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text(
                        "If ON, user is presented with a 'Skip Update' button. If OFF, the update is mandatory.",
                        style: TextStyle(color: Colors.white54, fontSize: 11)),
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                    child: TextField(
                      controller: _latestVersionCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "Latest App Version",
                        labelStyle: const TextStyle(color: Colors.white70),
                        hintText: "e.g. 1.0.1",
                        hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                        prefixIcon: const Icon(Icons.new_releases_rounded, color: Colors.orangeAccent),
                        filled: true,
                        fillColor: const Color(0xFF090A0F),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                    child: TextField(
                      controller: _v7aApkCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "v7a APK URL (Normal Phones)",
                        labelStyle: const TextStyle(color: Colors.white70),
                        hintText: "https://domain.com/app-v7a.apk",
                        hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                        prefixIcon: const Icon(Icons.download_rounded, color: Colors.orangeAccent),
                        filled: true,
                        fillColor: const Color(0xFF090A0F),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                    child: TextField(
                      controller: _v8aApkCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "v8a APK URL (Newer Phones)",
                        labelStyle: const TextStyle(color: Colors.white70),
                        hintText: "https://domain.com/app-v8a.apk",
                        hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                        prefixIcon: const Icon(Icons.download_rounded, color: Colors.orangeAccent),
                        filled: true,
                        fillColor: const Color(0xFF090A0F),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(14, 16, 14, 6),
                    child: Text("AUTOMATION DOMAINS", style: TextStyle(color: Colors.cyanAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                    child: TextField(
                      controller: _hdmaalDomainCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "HDMaal Domain",
                        labelStyle: const TextStyle(color: Colors.white70),
                        hintText: "https://hdmaal.gg",
                        prefixIcon: const Icon(Icons.language_rounded, color: Colors.purpleAccent),
                        filled: true,
                        fillColor: const Color(0xFF090A0F),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                    child: TextField(
                      controller: _uncutmastiDomainCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "UncutMasti Domain",
                        labelStyle: const TextStyle(color: Colors.white70),
                        hintText: "https://uncutmasti.com",
                        prefixIcon: const Icon(Icons.language_rounded, color: Colors.redAccent),
                        filled: true,
                        fillColor: const Color(0xFF090A0F),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                    child: TextField(
                      controller: _hdmove99DomainCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "HDMove99 Domain",
                        labelStyle: const TextStyle(color: Colors.white70),
                        hintText: "https://hdmove99.com",
                        prefixIcon: const Icon(Icons.language_rounded, color: Colors.amberAccent),
                        filled: true,
                        fillColor: const Color(0xFF090A0F),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                    child: TextField(
                      controller: _aagmaalDomainCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "Aagmaal Domain",
                        labelStyle: const TextStyle(color: Colors.white70),
                        hintText: "https://aagmaal.mba",
                        prefixIcon: const Icon(Icons.language_rounded, color: Colors.pinkAccent),
                        filled: true,
                        fillColor: const Color(0xFF090A0F),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                    child: TextField(
                      controller: _uffmaalDomainCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "UFFMaal Domain",
                        labelStyle: const TextStyle(color: Colors.white70),
                        hintText: "https://uffmaal.com",
                        prefixIcon: const Icon(Icons.language_rounded, color: Colors.amberAccent),
                        filled: true,
                        fillColor: const Color(0xFF090A0F),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                    child: TextField(
                      controller: _skymoviesDomainCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "SkyMoviesHD Domain",
                        labelStyle: const TextStyle(color: Colors.white70),
                        hintText: "https://skymovieshd.ceo",
                        prefixIcon: const Icon(Icons.language_rounded, color: Colors.cyanAccent),
                        filled: true,
                        fillColor: const Color(0xFF090A0F),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                    child: TextField(
                      controller: _universalApkCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "Universal APK URL (High Size)",
                        labelStyle: const TextStyle(color: Colors.white70),
                        hintText: "https://domain.com/app-universal.apk",
                        hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                        prefixIcon: const Icon(Icons.download_rounded, color: Colors.orangeAccent),
                        filled: true,
                        fillColor: const Color(0xFF090A0F),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saveAppSettings,
                        icon: const Icon(Icons.save_rounded, color: Colors.white),
                        label: const Text("SAVE SETTINGS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8E2DE2), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Future<void> _loadAppSettings() async {
    final res = await _adminPhpApi('get_app_settings', {});
    if (!mounted) return;
    if (res['status'] == 'success' && res['data']?['settings'] != null) {
      final settings = res['data']['settings'];
      setState(() {
        _loginMandatory = settings['login_mandatory']?.toString() == '1';
        _telegramLinkCtrl.text = settings['telegram_link']?.toString() ?? '';
        _adminPinCtrl.text = settings['admin_pin']?.toString() ?? '';
        _latestVersionCtrl.text = settings['latest_version']?.toString() ?? '1.0.0';
        _updateSkippable = settings['update_skippable']?.toString() == '1';
        _v7aApkCtrl.text = settings['download_url_v7a']?.toString() ?? '';
        _v8aApkCtrl.text = settings['download_url_v8a']?.toString() ?? '';
        _universalApkCtrl.text = settings['download_url_universal']?.toString() ?? '';
        _skymoviesDomainCtrl.text = settings['skymovies_domain']?.toString() ?? 'https://skymovieshd.ceo';
        _hdmaalDomainCtrl.text = settings['hdmaal_domain']?.toString() ?? 'https://hdmaal.gg';
        _uncutmastiDomainCtrl.text = settings['uncutmasti_domain']?.toString() ?? 'https://uncutmasti.com';
        _hdmove99DomainCtrl.text = settings['hdmove99_domain']?.toString() ?? 'https://hdmove99.com';
        _aagmaalDomainCtrl.text = settings['aagmaal_domain']?.toString() ?? 'https://aagmaal.mba';
        _uffmaalDomainCtrl.text = settings['uffmaal_domain']?.toString() ?? 'https://uffmaal.com';

        _settingsLoaded = true;
      });
    } else {
      setState(() => _settingsLoaded = true);
    }
  }

  Future<void> _saveAppSettings() async {
    final pin = _adminPinCtrl.text.trim();
    if (pin.isNotEmpty && !RegExp(r'^\d{4,6}$').hasMatch(pin)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Admin PIN must be 4-6 digits (or leave blank to keep current)"),
            backgroundColor: Colors.orange),
      );
      return;
    }
    final res = await _adminPhpApi('save_app_settings', {
      'settings': {
        'login_mandatory': _loginMandatory ? '1' : '0',
        'telegram_link': _telegramLinkCtrl.text.trim(),
        if (pin.isNotEmpty) 'admin_pin': pin,
        'latest_version': _latestVersionCtrl.text.trim(),
        'update_skippable': _updateSkippable ? '1' : '0',
        'download_url_v7a': _v7aApkCtrl.text.trim(),
        'download_url_v8a': _v8aApkCtrl.text.trim(),
        'download_url_universal': _universalApkCtrl.text.trim(),
        'skymovies_domain': _skymoviesDomainCtrl.text.trim(),
        'hdmaal_domain': _hdmaalDomainCtrl.text.trim(),
        'uncutmasti_domain': _uncutmastiDomainCtrl.text.trim(),
        'hdmove99_domain': _hdmove99DomainCtrl.text.trim(),
        'aagmaal_domain': _aagmaalDomainCtrl.text.trim(),
        'uffmaal_domain': _uffmaalDomainCtrl.text.trim(),
      },
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res['status'] == 'success' ? "App settings saved" : "Failed: ${res['message'] ?? 'Unknown error'}"),
        backgroundColor: res['status'] == 'success' ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _pickAndUploadImage() async {
    if (_isUploadingPoster) return;
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty || result.files.single.path == null) {
        return;
      }

      setState(() => _isUploadingPoster = true);

      final filePath = result.files.single.path!;
      final request = http.MultipartRequest("POST", Uri.parse(ApiConfig.adminUrl));
      request.fields['action'] = 'upload_image';
      request.files.add(await http.MultipartFile.fromPath('image', filePath));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 45));
      final res = await http.Response.fromStream(streamedResponse);
      
      setState(() => _isUploadingPoster = false);

      final raw = res.body.trim();
      if (raw.startsWith('{') && raw.endsWith('}')) {
        final decoded = json.decode(raw);
        if (decoded['status'] == 'success' && decoded['data']?['url'] != null) {
          final imageUrl = decoded['data']['url'];
          setState(() {
            _addPosterUrlCtrl.text = imageUrl;
            _addThumbUrlCtrl.text = imageUrl;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Poster and Banner uploaded successfully!"), backgroundColor: Colors.green),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Upload failed: ${decoded['message'] ?? 'Unknown error'}"), backgroundColor: Colors.red),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Upload error: $raw"), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      setState(() => _isUploadingPoster = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  void _showImageSearchDialog({Function(String)? onSelected, String defaultTitle = ''}) {
    final initialQuery = defaultTitle.trim().isNotEmpty ? defaultTitle.trim() : _addTitleCtrl.text.trim();
    final searchCtrl = TextEditingController(text: initialQuery);
    List<String> foundImages = [];
    List<String> hdmove99Images = [];
    List<String> skymoviesImages = [];
    bool isSearchingServer = false;
    bool isSearchingHdmove99 = false;
    bool isSearchingSkymovies = false; // kept for state compat; tab removed
    String? serverError;
    String? hdmove99Error;
    String? skymoviesError;
    List<String> googleImages = [];
    bool isSearchingGoogle = false;
    String? googleError;
    int activeTab = 0; // 0 = Google Images, 1 = Bing + DDG, 2 = HDMove99
    // (Sky Movies tab removed — not returning results)

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, dialogSetState) {

            Future<void> runGoogleSearch() async {
              // Google tab uses WebView — no async fetch needed,
              // but we trigger a dialogSetState so the WebView rebuilds with the new query.
              dialogSetState(() {
                isSearchingGoogle = false;
                googleError = null;
                googleImages = []; // unused for WebView tab
              });
            }

            Future<void> runServerSearch() async {
              if (isSearchingServer) return;
              dialogSetState(() {
                isSearchingServer = true;
                serverError = null;
                foundImages = [];
              });
              try {
                final q = searchCtrl.text.trim();
                final res = await _adminPhpApi('search_images', {'query': '$q poster'});
                if (dialogContext.mounted) {
                  dialogSetState(() {
                    isSearchingServer = false;
                    if (res['status'] == 'success' && res['data']?['images'] != null) {
                      foundImages = List<String>.from(res['data']['images']);
                      if (foundImages.isEmpty) serverError = 'No images found. Try a different query.';
                    } else {
                      serverError = res['message'] ?? 'No images found';
                    }
                  });
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  dialogSetState(() {
                    isSearchingServer = false;
                    serverError = 'Server search failed: ${e.toString().split('\n').first}';
                  });
                }
              }
            }

            Future<void> runHdmove99Search() async {
              if (isSearchingHdmove99) return;
              dialogSetState(() {
                isSearchingHdmove99 = true;
                hdmove99Error = null;
                hdmove99Images = [];
              });
              try {
                final q = searchCtrl.text.trim();
                final res = await _adminPhpApi('search_hdmove99_catalog', {'query': q});
                if (dialogContext.mounted) {
                  dialogSetState(() {
                    isSearchingHdmove99 = false;
                    if (res['status'] == 'success' && res['data']?['items'] != null) {
                      final items = res['data']['items'] as List;
                      hdmove99Images = items
                          .map((e) => (e['poster'] ?? '').toString())
                          .where((p) => p.isNotEmpty)
                          .toList();
                      if (hdmove99Images.isEmpty) hdmove99Error = 'No posters found on HDMove99.';
                    } else {
                      hdmove99Error = res['message'] ?? 'No posters found';
                    }
                  });
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  dialogSetState(() {
                    isSearchingHdmove99 = false;
                    hdmove99Error = 'HDMove99 search failed: ${e.toString().split('\n').first}';
                  });
                }
              }
            }

            Future<void> runSkymoviesSearch() async {
              if (isSearchingSkymovies) return;
              dialogSetState(() {
                isSearchingSkymovies = true;
                skymoviesError = null;
                skymoviesImages = [];
              });
              try {
                final q = searchCtrl.text.trim();
                final res = await _adminPhpApi('search_skymovies_catalog', {'query': q});
                if (dialogContext.mounted) {
                  dialogSetState(() {
                    isSearchingSkymovies = false;
                    if (res['status'] == 'success' && res['data']?['items'] != null) {
                      final items = res['data']['items'] as List;
                      skymoviesImages = items
                          .map((e) => (e['poster'] ?? '').toString())
                          .where((p) => p.isNotEmpty)
                          .toList();
                      if (skymoviesImages.isEmpty) skymoviesError = 'No posters found on SKY.';
                    } else {
                      skymoviesError = res['message'] ?? 'No posters found';
                    }
                  });
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  dialogSetState(() {
                    isSearchingSkymovies = false;
                    skymoviesError = 'SKY search failed: ${e.toString().split('\n').first}';
                  });
                }
              }
            }

            void runSearch() {
              if (activeTab == 0) runGoogleSearch();
              else if (activeTab == 1) runServerSearch();
              else runHdmove99Search(); // tab 2 = HDMove99 (SKY removed)
            }

            // Auto-trigger search on open if title is filled
            if (googleImages.isEmpty && foundImages.isEmpty && hdmove99Images.isEmpty &&
                !isSearchingGoogle && !isSearchingServer && !isSearchingHdmove99 &&
                googleError == null && serverError == null && hdmove99Error == null &&
                searchCtrl.text.trim().isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) => runSearch());
            }

            final currentImages = activeTab == 0 ? googleImages : (activeTab == 1 ? foundImages : hdmove99Images);
            final isSearching = activeTab == 0 ? isSearchingGoogle : (activeTab == 1 ? isSearchingServer : isSearchingHdmove99);
            final searchError = activeTab == 0 ? googleError : (activeTab == 1 ? serverError : hdmove99Error);


            return Dialog(
              backgroundColor: const Color(0xFF0D1117),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Colors.white12),
              ),
              child: Container(
                width: MediaQuery.of(dialogContext).size.width * 0.95,
                height: MediaQuery.of(dialogContext).size.height * 0.88,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ──
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.cyanAccent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.image_search_rounded, color: Colors.cyanAccent, size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text('Poster Image Search',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white60, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ── Search Bar ──
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFF161B22),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: TextField(
                              controller: searchCtrl,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              decoration: const InputDecoration(
                                hintText: 'Movie/series title...',
                                hintStyle: TextStyle(color: Colors.white38, fontSize: 12),
                                prefixIcon: Icon(Icons.search_rounded, color: Colors.white38, size: 18),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(vertical: 12),
                              ),
                              onSubmitted: (_) => runSearch(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: runSearch,
                          icon: const Icon(Icons.search_rounded, size: 16),
                          label: const Text('Search'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.cyanAccent,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // ── Source Tabs (Google Images, Bing+DDG, HDMove99) ──
                    Container(
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF161B22),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          // Google Images tab
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                dialogSetState(() => activeTab = 0);
                                if (googleImages.isEmpty && !isSearchingGoogle && searchCtrl.text.isNotEmpty) runGoogleSearch();
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: activeTab == 0 ? Colors.redAccent.withOpacity(0.18) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('G', style: TextStyle(color: activeTab == 0 ? const Color(0xFF4285F4) : Colors.white38, fontSize: 11, fontWeight: FontWeight.bold)),
                                    Text('o', style: TextStyle(color: activeTab == 0 ? const Color(0xFFEA4335) : Colors.white38, fontSize: 11, fontWeight: FontWeight.bold)),
                                    Text('o', style: TextStyle(color: activeTab == 0 ? const Color(0xFFFBBC05) : Colors.white38, fontSize: 11, fontWeight: FontWeight.bold)),
                                    Text('g', style: TextStyle(color: activeTab == 0 ? const Color(0xFF4285F4) : Colors.white38, fontSize: 11, fontWeight: FontWeight.bold)),
                                    Text('le', style: TextStyle(color: activeTab == 0 ? const Color(0xFF34A853) : Colors.white38, fontSize: 11, fontWeight: FontWeight.bold)),
                                    if (googleImages.isNotEmpty)
                                      Text(' (${googleImages.length})', style: TextStyle(color: activeTab == 0 ? Colors.white70 : Colors.white38, fontSize: 10)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Bing+DDG tab
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                dialogSetState(() => activeTab = 1);
                                if (foundImages.isEmpty && !isSearchingServer && searchCtrl.text.isNotEmpty) runServerSearch();
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: activeTab == 1 ? Colors.cyanAccent.withOpacity(0.18) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Bing+DDG${foundImages.isNotEmpty ? " (${foundImages.length})" : ""}',
                                  style: TextStyle(
                                    color: activeTab == 1 ? Colors.cyanAccent : Colors.white54,
                                    fontSize: 11, fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // HDMove99 tab
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                dialogSetState(() => activeTab = 2);
                                if (hdmove99Images.isEmpty && !isSearchingHdmove99 && searchCtrl.text.isNotEmpty) runHdmove99Search();
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: activeTab == 2 ? Colors.greenAccent.withOpacity(0.18) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'HD${hdmove99Images.isNotEmpty ? " (${hdmove99Images.length})" : ""}',
                                  style: TextStyle(
                                    color: activeTab == 2 ? Colors.greenAccent : Colors.white54,
                                    fontSize: 11, fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ── Results ──
                    Expanded(
                      child: activeTab == 0
                          // ── Google Images WebView ──
                          ? _GoogleImagesWebView(
                              query: searchCtrl.text.trim(),
                              ottHint: _selectedOttGenreIds.isNotEmpty && _ottGenres.isNotEmpty
                                  ? (_ottGenres.firstWhere(
                                      (g) => _selectedOttGenreIds.contains(g['id'] is int ? g['id'] : int.tryParse('${g['id']}') ?? 0),
                                      orElse: () => {'name': ''},
                                    )['name'] ?? '').toString()
                                  : '',
                              onImageSelected: (imgUrl) {
                                if (onSelected != null) {
                                  onSelected(imgUrl);
                                } else {
                                  setState(() {
                                    _addPosterUrlCtrl.text = imgUrl;
                                    _addThumbUrlCtrl.text = imgUrl;
                                  });
                                }
                                Navigator.pop(ctx);
                              },
                            )
                          : isSearching
                          ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
                          : searchError != null
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 32),
                                      const SizedBox(height: 8),
                                      Text(searchError!, textAlign: TextAlign.center,
                                          style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                                      const SizedBox(height: 12),
                                      TextButton.icon(
                                        onPressed: runSearch,
                                        icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.cyanAccent),
                                        label: const Text('Retry Search', style: TextStyle(color: Colors.cyanAccent, fontSize: 12)),
                                      ),
                                    ],
                                  ),
                                )
                              : currentImages.isEmpty
                                  ? const Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.image_not_supported_rounded, color: Colors.white24, size: 40),
                                          SizedBox(height: 8),
                                          Text('Enter a title and tap Search to find posters.',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(color: Colors.white38, fontSize: 12)),
                                        ],
                                      ),
                                    )
                                  : GridView.builder(
                                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 3,
                                        childAspectRatio: 0.67,
                                        crossAxisSpacing: 8,
                                        mainAxisSpacing: 8,
                                      ),
                                      itemCount: currentImages.length,
                                      itemBuilder: (context, idx) {
                                        final imgUrl = currentImages[idx];
                                        return GestureDetector(
                                          onTap: () {
                                            if (onSelected != null) {
                                              onSelected(imgUrl);
                                            } else {
                                              setState(() {
                                                _addPosterUrlCtrl.text = imgUrl;
                                                _addThumbUrlCtrl.text = imgUrl;
                                              });
                                            }
                                            Navigator.pop(ctx);
                                          },
                                          child: Container(
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: Colors.white10),
                                            ),
                                            clipBehavior: Clip.antiAlias,
                                            child: Stack(
                                              fit: StackFit.expand,
                                              children: [
                                                CachedNetworkImage(
                                                  imageUrl: imgUrl,
                                                  fit: BoxFit.cover,
                                                  placeholder: (context, url) => Container(
                                                    color: Colors.white.withOpacity(0.04),
                                                    child: const Center(
                                                      child: CircularProgressIndicator(
                                                          strokeWidth: 1.5, color: Colors.white24)),
                                                  ),
                                                  errorWidget: (context, url, error) => Container(
                                                    color: Colors.white.withOpacity(0.04),
                                                    child: const Center(
                                                      child: Icon(Icons.broken_image_rounded,
                                                          color: Colors.white24, size: 20)),
                                                  ),
                                                ),
                                                Positioned(
                                                  bottom: 0, left: 0, right: 0,
                                                  child: Container(
                                                    height: 30,
                                                    decoration: BoxDecoration(
                                                      gradient: LinearGradient(
                                                        begin: Alignment.bottomCenter,
                                                        end: Alignment.topCenter,
                                                        colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                                                      ),
                                                    ),
                                                    alignment: Alignment.center,
                                                    child: const Icon(Icons.add_circle_rounded,
                                                        color: Colors.white70, size: 18),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Direct client-side image search using DuckDuckGo API (no server needed).

  // ── 18. SkyMoviesHD Auto Importer View ──
  Widget _buildSkymoviesImporterView() {
    if (_skymoviesCatalog.isEmpty && !_skymoviesLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadSkymoviesCatalog());
    }

    return Column(
      children: [
        // Category & Domain Header
        Container(
          padding: const EdgeInsets.all(12),
          color: const Color(0xFF141722),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.cloud_download_rounded, color: Colors.cyanAccent, size: 22),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text("SkyMoviesHD Auto Importer Engine", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Colors.cyanAccent),
                    onPressed: _loadSkymoviesCatalog,
                    tooltip: "Refresh Catalog",
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          'Hot-Short-Film',
                          'All-Web-Series',
                          'Bollywood-Movies',
                          'South-Indian-Hindi-Dubbed-Movies',
                          'Hollywood-Hindi-Dubbed-Movies'
                        ].map((cat) {
                          final isSelected = _skymoviesCat == cat;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6.0),
                            child: ChoiceChip(
                              label: Text(cat.replaceAll('-', ' '), style: TextStyle(fontSize: 11, color: isSelected ? Colors.black : Colors.white70, fontWeight: FontWeight.bold)),
                              selected: isSelected,
                              selectedColor: Colors.cyanAccent,
                              backgroundColor: const Color(0xFF1E2230),
                              onSelected: (s) {
                                if (s) {
                                  setState(() {
                                    _skymoviesCat = cat;
                                    _skymoviesPage = 1;
                                    _skymoviesCatalog = [];
                                  });
                                  _loadSkymoviesCatalog();
                                }
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Fast List Content (Clean text list)
        Expanded(
          child: _skymoviesLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
              : _skymoviesCatalog.isEmpty
                  ? const Center(child: Text("No items found in this category.", style: TextStyle(color: Colors.white54)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _skymoviesCatalog.length,
                      itemBuilder: (context, idx) {
                        final item = _skymoviesCatalog[idx];
                        return Card(
                          color: const Color(0xFF141722),
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Colors.white10),
                          ),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.cyanAccent.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.movie_rounded, color: Colors.cyanAccent, size: 20),
                            ),
                            title: Text(
                              item['title'] ?? 'Title',
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              item['page_url'] ?? '',
                              style: const TextStyle(color: Colors.white38, fontSize: 10),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: ElevatedButton.icon(
                              onPressed: () => _autoImportSkymoviesItem(item),
                              icon: const Icon(Icons.download_rounded, size: 14),
                              label: const Text("AUTO-IMPORT", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.cyanAccent,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),

        // Pagination Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: const Color(0xFF141722),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white70, size: 18),
                onPressed: _skymoviesPage > 1
                    ? () {
                        setState(() => _skymoviesPage--);
                        _loadSkymoviesCatalog();
                      }
                    : null,
              ),
              Text("Page $_skymoviesPage", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 18),
                onPressed: () {
                  setState(() => _skymoviesPage++);
                  _loadSkymoviesCatalog();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _loadSkymoviesCatalog({bool forceRefresh = false}) async {
    setState(() => _skymoviesLoading = true);
    final res = await _adminPhpApi('fetch_skymovies_catalog', {
      'category': _skymoviesCat,
      'page': _skymoviesPage,
      'refresh': forceRefresh ? 1 : 0,
    });
    if (!mounted) return;
    setState(() {
      _skymoviesLoading = false;
      if (res['status'] == 'success' && res['data']?['items'] != null) {
        _skymoviesCatalog = res['data']['items'];
      } else {
        _skymoviesCatalog = [];
      }
    });
  }

  Future<void> _autoImportSkymoviesItem(dynamic item) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        backgroundColor: Color(0xFF141722),
        content: Row(
          children: [
            CircularProgressIndicator(color: Colors.cyanAccent),
            SizedBox(width: 16),
            Expanded(child: Text("Extracting details & downloading poster to your server...", style: TextStyle(color: Colors.white, fontSize: 12))),
          ],
        ),
      ),
    );

    final pageUrl = item['page_url'] ?? '';
    final res = await _adminPhpApi('extract_skymovies_details', {'page_url': pageUrl});

    if (!mounted) return;
    Navigator.pop(context); // Close loading dialog

    if (res['status'] == 'success' && res['data'] != null) {
      final data = res['data'];
      final title = data['title'] ?? item['title'] ?? '';
      final poster = data['poster'] ?? item['poster'] ?? '';
      final streamUrl = data['stream_url'] ?? '';

      // Auto-switch to Add Content tab and fill fields
      setState(() {
        _addType = 'movie';
        _addTitleCtrl.text = title;
        _addDescCtrl.text = "Watch $title in full HD quality online.";
        _addPosterUrlCtrl.text = poster;
        _addThumbUrlCtrl.text = poster;
        _addStreamUrlCtrl.text = streamUrl;
        _streamType = 'Streamtape Stream';
        _selectedIndex = 2; // Jump to Add Content form
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Details extracted & poster saved to your server! Review & tap PUBLISH MOVIE."),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to extract: ${res['message'] ?? 'Unknown error'}"), backgroundColor: Colors.red),
      );
    }
  }


  // 18. HDMove99 Auto Importer View (Grid View with Poster Cards & Instant Caching)
  Widget _buildHdmove99ImporterView() {
    if (_hdmove99Catalog.isEmpty && !_hdmove99Loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _hdmove99Catalog.isEmpty && !_hdmove99Loading) _loadHdmove99Catalog();
      });
    }

    final isWide = MediaQuery.of(context).size.width > 600;
    final crossCount = isWide ? (MediaQuery.of(context).size.width > 1000 ? 5 : 4) : 2;

    return Column(
      children: [
        // Header Banner
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1E2230), Color(0xFF141722)]),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.amberAccent.withOpacity(0.35)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.amberAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.video_library_rounded, color: Colors.amberAccent, size: 22),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("HDMove99 Auto Importer", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                      Text("Grid View • Poster Gallery • Auto-Import Details & Links", style: TextStyle(color: Colors.white54, fontSize: 11)),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _loadHdmove99Catalog(forceRefresh: true),
                  icon: const Icon(Icons.refresh_rounded, size: 14),
                  label: const Text("REFRESH LATEST", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amberAccent.withOpacity(0.2),
                    foregroundColor: Colors.amberAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Colors.amberAccent, width: 0.8)),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Search Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _hdmove99SearchCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Search HDMove99 catalog...",
                    hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                    prefixIcon: const Icon(Icons.search, color: Colors.amberAccent),
                    suffixIcon: _hdmove99SearchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, color: Colors.white38),
                            onPressed: () {
                              _hdmove99SearchCtrl.clear();
                              _hdmove99Page = 1;
                              _loadHdmove99Catalog();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFF141722),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  onSubmitted: (_) {
                    _hdmove99Page = 1;
                    _loadHdmove99Catalog();
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  _hdmove99Page = 1;
                  _loadHdmove99Catalog();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amberAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("SEARCH", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
        ),

        // Poster Grid View
        Expanded(
          child: _hdmove99Loading
              ? const Center(child: CircularProgressIndicator(color: Colors.amberAccent))
              : _hdmove99Catalog.isEmpty
                  ? const Center(child: Text("No items found in HDMove99 catalog", style: TextStyle(color: Colors.white54)))
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossCount,
                        childAspectRatio: 0.65,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: _hdmove99Catalog.length,
                      itemBuilder: (context, index) {
                        final item = _hdmove99Catalog[index];
                        final poster = (item['poster'] ?? '').toString();
                        final title = (item['title'] ?? 'Untitled').toString();
                        final date = (item['date'] ?? '').toString();

                        return Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1F2636), Color(0xFF141722)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.08)),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 6, offset: const Offset(0, 3)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Poster Image
                              Expanded(
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                      child: poster.isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl: poster,
                                              width: double.infinity,
                                              height: double.infinity,
                                              fit: BoxFit.cover,
                                              errorWidget: (c, u, e) => Container(color: const Color(0xFF2A3145), child: const Icon(Icons.movie, color: Colors.white24, size: 36)),
                                            )
                                          : Container(color: const Color(0xFF2A3145), child: const Icon(Icons.movie, color: Colors.white24, size: 36)),
                                    ),
                                    if (date.isNotEmpty)
                                      Positioned(
                                        top: 6,
                                        right: 6,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(color: Colors.black.withOpacity(0.75), borderRadius: BorderRadius.circular(6)),
                                          child: Text(date, style: const TextStyle(color: Colors.amberAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              // Title & Auto-Import Button
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: () => _autoImportHdmove99Item(item),
                                        icon: const Icon(Icons.download_rounded, size: 13),
                                        label: const Text("AUTO-IMPORT", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.amberAccent,
                                          foregroundColor: Colors.black,
                                          padding: const EdgeInsets.symmetric(vertical: 6),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),

        // Pagination Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: const Color(0xFF141722),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white70, size: 18),
                onPressed: _hdmove99Page > 1
                    ? () {
                        setState(() => _hdmove99Page--);
                        _loadHdmove99Catalog();
                      }
                    : null,
              ),
              Text("Page $_hdmove99Page", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 18),
                onPressed: () {
                  setState(() => _hdmove99Page++);
                  _loadHdmove99Catalog();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _loadHdmove99Catalog({bool forceRefresh = false}) async {
    setState(() => _hdmove99Loading = true);
    final q = _hdmove99SearchCtrl.text.trim();
    final res = await _adminPhpApi('fetch_hdmove99_catalog', {
      'query': q,
      'page': _hdmove99Page,
      'refresh': forceRefresh ? 1 : 0,
    });
    if (!mounted) return;
    setState(() {
      _hdmove99Loading = false;
      if (res['status'] == 'success' && res['data']?['items'] != null) {
        _hdmove99Catalog = res['data']['items'];
      } else {
        _hdmove99Catalog = [];
      }
    });
  }

  Future<void> _autoImportHdmove99Item(dynamic item) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        backgroundColor: Color(0xFF141722),
        content: Row(
          children: [
            CircularProgressIndicator(color: Colors.amberAccent),
            SizedBox(width: 16),
            Expanded(child: Text("Extracting HDMove99 details & downloading poster to server...", style: TextStyle(color: Colors.white, fontSize: 12))),
          ],
        ),
      ),
    );

    final res = await _adminPhpApi('extract_hdmove99_details', {'page_url': item['page_url']});

    if (mounted) Navigator.pop(context);

    if (res['status'] == 'success' && res['data'] != null) {
      final d = res['data'];
      final playLinks = (d['play_links'] as List<dynamic>? ?? []);
      final primaryUrl = (d['stream_url'] ?? '').toString().trim();

      setState(() {
        _addType = 'movie';
        _addTitleCtrl.text = d['title'] ?? item['title'] ?? '';
        _addDescCtrl.text = d['description'] ?? "Watch ${d['title'] ?? item['title']} online in HD.";
        _addPosterUrlCtrl.text = d['poster'] ?? d['raw_poster'] ?? item['poster'] ?? '';
        _addThumbUrlCtrl.text = d['poster'] ?? d['raw_poster'] ?? item['poster'] ?? '';
        if (d['release_date'] != null && (d['release_date'] as String).isNotEmpty) {
          _addReleaseDateCtrl.text = d['release_date'];
        } else if (item['date'] != null) {
          _addReleaseDateCtrl.text = item['date'];
        }
        final mainUrl = (playLinks.isNotEmpty && playLinks.first['url'] != null && playLinks.first['url'].toString().isNotEmpty)
            ? playLinks.first['url'].toString().trim()
            : primaryUrl;

        if (mainUrl.isNotEmpty) {
          _addStreamUrlCtrl.text = mainUrl;
          // Auto-guess stream type
          if (mainUrl.contains('lulu') || primaryUrl.contains('tnmr.org')) {
            _streamType = 'Luluvdo Stream';
          } else if (mainUrl.contains('streamtape') || mainUrl.contains('tpead')) {
            _streamType = 'Streamtape Stream';
          } else if (mainUrl.endsWith('.mp4') || mainUrl.endsWith('.mkv')) {
            _streamType = 'MP4/MKV Direct Link';
          } else {
            _streamType = 'Luluvdo Stream';
          }
        } else {
          _addStreamUrlCtrl.clear();
        }

        _extraMovieServers.clear();
        for (int i = 1; i < playLinks.length; i++) {
          final pl = playLinks[i];
          _extraMovieServers.add({
            'name': pl['name'] ?? 'Server ${i + 1}',
            'type': pl['type'] ?? 'Luluvdo Stream',
            'ctrl': TextEditingController(text: pl['url'] ?? ''),
          });
        }
        _selectedIndex = 2; // Switch to Add Content studio tab
      });

      final serverCount = playLinks.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(serverCount > 0
              ? "HDMove99: Extracted $serverCount server link(s)! ${serverCount > 1 ? 'Multiple servers found. Review & Publish.' : 'Review & tap Publish.'}"
              : "HDMove99 details extracted (No stream links found on page)."),
          backgroundColor: serverCount > 0 ? Colors.green : Colors.orange,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Extraction failed: ${res['message'] ?? 'Unknown error'}"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  //
  // ── AAGMAAL AUTO IMPORTER VIEW ──
  //
  Widget _buildAagmaalImporterView() {
    if (_aagmaalCatalog.isEmpty && !_aagmaalLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _aagmaalCatalog.isEmpty && !_aagmaalLoading) {
          _loadAagmaalCatalog();
        }
      });
    }

    final width = MediaQuery.of(context).size.width;
    int crossCount = 3;
    if (width > 1200) {
      crossCount = 6;
    } else if (width > 900) {
      crossCount = 5;
    } else if (width > 600) {
      crossCount = 4;
    }

    return Column(
      children: [
        // Header Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF38121E), Color(0xFF1E1422)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.pinkAccent.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.local_fire_department_rounded, color: Colors.pinkAccent, size: 24),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Aagmaal Auto Importer", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                      Text("Grid View • Poster Gallery • Direct MP4 & Download Stream Extract", style: TextStyle(color: Colors.white54, fontSize: 11)),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _loadAagmaalCatalog(forceRefresh: true),
                  icon: const Icon(Icons.refresh_rounded, size: 14),
                  label: const Text("REFRESH LATEST", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pinkAccent.withOpacity(0.2),
                    foregroundColor: Colors.pinkAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Colors.pinkAccent, width: 0.8)),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Search Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _aagmaalSearchCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Search Aagmaal catalog...",
                    hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                    prefixIcon: const Icon(Icons.search, color: Colors.pinkAccent),
                    suffixIcon: _aagmaalSearchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, color: Colors.white38),
                            onPressed: () {
                              _aagmaalSearchCtrl.clear();
                              _aagmaalPage = 1;
                              _loadAagmaalCatalog();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFF141722),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  onSubmitted: (_) {
                    _aagmaalPage = 1;
                    _loadAagmaalCatalog();
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  _aagmaalPage = 1;
                  _loadAagmaalCatalog();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pinkAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("SEARCH", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
        ),

        // Landscape Card Grid / List View
        Expanded(
          child: _aagmaalLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.pinkAccent))
              : _aagmaalCatalog.isEmpty
                  ? const Center(child: Text("No items found in Aagmaal catalog", style: TextStyle(color: Colors.white54)))
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final crossCount = width > 750 ? 3 : (width > 480 ? 2 : 1);
                        return GridView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossCount,
                            childAspectRatio: 1.35,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: _aagmaalCatalog.length,
                          itemBuilder: (context, index) {
                            final item = _aagmaalCatalog[index];
                            final poster = (item['poster'] ?? '').toString();
                            final title = (item['title'] ?? 'Untitled').toString();
                            final date = (item['date'] ?? '').toString();

                            return Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF24142B), Color(0xFF131520)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.pinkAccent.withOpacity(0.2)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.45),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // 16:9 Landscape Poster Banner
                                    Expanded(
                                      flex: 5,
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          poster.isNotEmpty
                                              ? CachedNetworkImage(
                                                  imageUrl: poster,
                                                  fit: BoxFit.cover,
                                                  errorWidget: (c, u, e) => Container(
                                                    color: const Color(0xFF202636),
                                                    child: const Center(child: Icon(Icons.movie_outlined, color: Colors.pinkAccent, size: 36)),
                                                  ),
                                                )
                                              : Container(
                                                  color: const Color(0xFF202636),
                                                  child: const Center(child: Icon(Icons.movie_outlined, color: Colors.pinkAccent, size: 36)),
                                                ),
                                          Container(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [Colors.transparent, Colors.black.withOpacity(0.75)],
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                              ),
                                            ),
                                          ),
                                          if (date.isNotEmpty)
                                            Positioned(
                                              top: 8,
                                              right: 8,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: Colors.black.withOpacity(0.85),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: Colors.pinkAccent.withOpacity(0.4)),
                                                ),
                                                child: Text(
                                                  date,
                                                  style: const TextStyle(color: Colors.pinkAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ),
                                          Positioned(
                                            top: 8,
                                            left: 8,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.pinkAccent.withOpacity(0.85),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Text("AAGMAAL", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Title & Auto-Import Action Bar
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              title,
                                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          ElevatedButton.icon(
                                            onPressed: () => _autoImportAagmaalItem(item),
                                            icon: const Icon(Icons.download_rounded, size: 13),
                                            label: const Text("IMPORT", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.pinkAccent,
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              visualDensity: VisualDensity.compact,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
        ),

        // Pagination Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: const Color(0xFF141722),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white70, size: 18),
                onPressed: _aagmaalPage > 1
                    ? () {
                        setState(() => _aagmaalPage--);
                        _loadAagmaalCatalog();
                      }
                    : null,
              ),
              Text("Page $_aagmaalPage", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 18),
                onPressed: () {
                  setState(() => _aagmaalPage++);
                  _loadAagmaalCatalog();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Client-side Scrapers for HDMaal & Aagmaal (Instant Fallback) ──

  Future<List<Map<String, dynamic>>> _scrapeHdmaalSearch(String query) async {
    try {
      final uri = Uri.parse("https://hdmaal.gg/?s=${Uri.encodeComponent(query)}");
      final res = await http.get(uri, headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        'Referer': 'https://hdmaal.gg/',
      }).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return [];
      final html = res.body;
      final results = <Map<String, dynamic>>[];

      final reg = RegExp(r'<a[^>]+class="[^"]*video[^"]*"[^>]*href="([^"]+)"[^>]*title="([^"]*)"[^>]*style="([^"]*)"|<a[^>]+class="[^"]*video[^"]*"[^>]*style="([^"]*)"[^>]*title="([^"]*)"[^>]*href="([^"]+)"', caseSensitive: false);
      for (final match in reg.allMatches(html)) {
        final url = (match.group(1) ?? match.group(6) ?? '').trim();
        final title = (match.group(2) ?? match.group(5) ?? '').trim();
        final style = match.group(3) ?? match.group(4) ?? '';
        var poster = '';
        final bgMatch = RegExp(r'''background-image:\s*url\(['"]?([^'")]+)['"]?\)''').firstMatch(style);
        if (bgMatch != null) {
          poster = bgMatch.group(1) ?? '';
        }
        if (url.isNotEmpty && title.isNotEmpty) {
          results.add({
            'title': title,
            'page_url': url,
            'poster': poster,
          });
        }
      }
      return results;
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> _scrapeHdmaalDetails(String pageUrl) async {
    try {
      final res = await http.get(Uri.parse(pageUrl), headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Referer': 'https://hdmaal.gg/',
      }).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      final html = res.body;

      var title = '';
      final titleMatch = RegExp(r'<h1[^>]*class="[^"]*entry-title[^"]*"[^>]*>([^<]+)</h1>', caseSensitive: false).firstMatch(html);
      if (titleMatch != null) {
        title = titleMatch.group(1)!.trim();
      }

      var poster = '';
      final ogMatch = RegExp(r'<meta property="og:image" content="([^"]+)"', caseSensitive: false).firstMatch(html);
      if (ogMatch != null) {
        poster = ogMatch.group(1)!.trim();
      }

      var streamUrl = '';
      final iframeMatch = RegExp(r'<iframe[^>]+src="([^"]+)"', caseSensitive: false).firstMatch(html);
      if (iframeMatch != null) {
        streamUrl = iframeMatch.group(1)!.trim();
      }

      if (streamUrl.isEmpty) {
        final videoMatch = RegExp(r'''https?://[^\s<>"']+\.(?:mp4|m3u8)''', caseSensitive: false).firstMatch(html);
        if (videoMatch != null) {
          streamUrl = videoMatch.group(0)!;
        }
      }

      return {
        'title': title,
        'poster': poster,
        'stream_url': streamUrl,
      };
    } catch (_) {
      return null;
    }
  }

  // ── Client-side Scrapers for UFFMaal (Instant Fallback & Multi-Episode) ──

  Future<List<Map<String, dynamic>>> _scrapeUffmaalCatalog({String query = '', int page = 1}) async {
    try {
      final base = _uffmaalDomainCtrl.text.trim().isNotEmpty ? _uffmaalDomainCtrl.text.trim() : "https://uffmaal.com";
      final q = query.trim();
      final url = q.isNotEmpty
          ? (page > 1 ? "$base/page/$page/?s=${Uri.encodeComponent(q)}" : "$base/?s=${Uri.encodeComponent(q)}")
          : (page > 1 ? "$base/page/$page/" : "$base/");
      final res = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Referer': '$base/',
      }).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return [];
      final html = res.body;
      final results = <Map<String, dynamic>>[];
      final seenUrls = <String>{};

      // Match post-card articles
      final articleReg = RegExp(
        r'<article[^>]*class="[^"]*post-card[^"]*"[^>]*>[\s\S]*?<a[^>]+href="([^"]+)"[^>]*>[\s\S]*?<img[^>]+(?:src|data-src)="([^"]+)"[\s\S]*?<h2>([^<]+)</h2>',
        caseSensitive: false,
      );
      for (final m in articleReg.allMatches(html)) {
        final pageUrl = m.group(1)!.trim();
        final poster = m.group(2)!.trim();
        final title = m.group(3)!.trim();
        if (pageUrl.isNotEmpty && title.isNotEmpty && !seenUrls.contains(pageUrl)) {
          seenUrls.add(pageUrl);
          results.add({
            'title': title,
            'page_url': pageUrl,
            'poster': poster,
            'is_episode': pageUrl.contains('/episode/'),
          });
        }
      }

      return results;
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> _scrapeUffmaalDetails(String pageUrl) async {
    try {
      final base = _uffmaalDomainCtrl.text.trim().isNotEmpty ? _uffmaalDomainCtrl.text.trim() : "https://uffmaal.com";
      final res = await http.get(Uri.parse(pageUrl), headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Referer': '$base/',
      }).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return null;
      final html = res.body;

      var title = '';
      final tMatch = RegExp(r'<h1[^>]*class="[^"]*entry-title[^"]*"[^>]*>([^<]+)</h1>|<h1[^>]*>([^<]+)</h1>', caseSensitive: false).firstMatch(html);
      if (tMatch != null) {
        title = (tMatch.group(1) ?? tMatch.group(2) ?? '').trim();
      }

      var poster = '';
      final vPoster = RegExp(r'<video[^>]+poster="([^"]+)"', caseSensitive: false).firstMatch(html);
      if (vPoster != null) {
        poster = vPoster.group(1)!.trim();
      }
      if (poster.isEmpty) {
        final og = RegExp(r'<meta property="og:image" content="([^"]+)"', caseSensitive: false).firstMatch(html);
        if (og != null) poster = og.group(1)!.trim();
      }

      var streamUrl = '';
      final srcMatch = RegExp(r'<source[^>]+src="([^"]+)"', caseSensitive: false).firstMatch(html);
      if (srcMatch != null) {
        streamUrl = srcMatch.group(1)!.replaceAll('&#038;', '&').replaceAll('&amp;', '&').trim();
      }
      if (streamUrl.isEmpty) {
        final dlMatch = RegExp(r'<a[^>]+href="([^"]+\.mp4[^"]*)"[^>]*class="[^"]*mlink[^"]*"', caseSensitive: false).firstMatch(html);
        if (dlMatch != null) {
          streamUrl = dlMatch.group(1)!.replaceAll('&#038;', '&').replaceAll('&amp;', '&').trim();
        }
      }
      if (streamUrl.isEmpty) {
        final videoTag = RegExp(r'''<video[^>]+src="([^"]+)"''', caseSensitive: false).firstMatch(html);
        if (videoTag != null) {
          streamUrl = videoTag.group(1)!.replaceAll('&#038;', '&').replaceAll('&amp;', '&').trim();
        }
      }

      // Check if this is a series page with multiple episodes
      final episodes = <Map<String, dynamic>>[];
      final epMatches = RegExp(
        r'<div[^>]*class="[^"]*episode-card[^"]*"[^>]*>\s*<a[^>]+href="([^"]+)"[^>]*>[\s\S]*?<img[^>]+(?:src|data-src)="([^"]+)"[\s\S]*?<span[^>]*class="episode-number"[^>]*>([^<]+)</span>',
        caseSensitive: false,
      ).allMatches(html);

      for (final em in epMatches) {
        final epUrl = em.group(1)!.trim();
        final epPoster = em.group(2)!.trim();
        final epNum = em.group(3)!.trim();
        episodes.add({
          'episode_url': epUrl,
          'poster': epPoster,
          'episode_number': epNum,
          'title': title.isNotEmpty ? '$title Episode $epNum' : 'Episode $epNum',
        });
      }

      return {
        'title': title,
        'poster': poster,
        'stream_url': streamUrl,
        'episodes': episodes,
      };
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _scrapeAagmaalCatalog({String query = '', int page = 1}) async {
    try {
      final q = query.trim();
      final url = q.isNotEmpty
          ? (page > 1 ? "https://aagmaal.mba/page/$page/?s=${Uri.encodeComponent(q)}" : "https://aagmaal.mba/?s=${Uri.encodeComponent(q)}")
          : (page > 1 ? "https://aagmaal.mba/page/$page/" : "https://aagmaal.mba/");
      final res = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
        'Referer': 'https://aagmaal.mba/',
      }).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return [];
      final html = res.body;
      final results = <Map<String, dynamic>>[];
      final seenUrls = <String>{};

      // Match thumbnail block + following title on Homepage and Category pages
      final thumbBlockReg = RegExp(
        r'<div[^>]*class="[^"]*post-thumbnail[^"]*"[^>]*>\s*<a[^>]+href="([^"]+)"[^>]*>[\s\S]*?<img[^>]+(?:src|data-src|data-lazy-src)="([^"]+)"[\s\S]*?</div>[\s\S]*?<h[23][^>]*class="[^"]*post-box-title[^"]*"[^>]*>\s*<a[^>]+href="[^"]*"[^>]*>([^<]+)</a>',
        caseSensitive: false,
      );
      for (final tm in thumbBlockReg.allMatches(html)) {
        final pageUrl = tm.group(1)!.trim();
        final poster = tm.group(2)!.trim();
        final title = tm.group(3)!.trim();
        if (pageUrl.isNotEmpty && title.isNotEmpty && !seenUrls.contains(pageUrl)) {
          seenUrls.add(pageUrl);
          results.add({
            'title': title,
            'page_url': pageUrl,
            'poster': poster,
            'date': 'Latest',
          });
        }
      }

      // Match item-list articles on Search pages
      if (results.isEmpty) {
        final articleReg = RegExp(r'<article[^>]*class="[^"]*item-list[^"]*"[^>]*>([\s\S]*?)</article>', caseSensitive: false);
        for (final m in articleReg.allMatches(html)) {
          final block = m.group(1) ?? '';
          var title = '';
          var pageUrl = '';
          var poster = '';
          var date = 'Latest';

          final tMatch = RegExp(r'<h[23][^>]*class="[^"]*post-box-title[^"]*"[^>]*>\s*<a[^>]+href="([^"]+)"[^>]*>([^<]+)</a>', caseSensitive: false).firstMatch(block);
          if (tMatch != null) {
            pageUrl = tMatch.group(1)!.trim();
            title = tMatch.group(2)!.trim();
          }

          final imgMatch = RegExp(r'<img[^>]+(?:src|data-src|data-lazy-src)="([^"]+)"', caseSensitive: false).firstMatch(block);
          if (imgMatch != null) {
            poster = imgMatch.group(1)!.trim();
          }

          final dMatch = RegExp(r'<span class="tie-date"[^>]*>([^<]+)</span>', caseSensitive: false).firstMatch(block);
          if (dMatch != null) {
            date = dMatch.group(1)!.trim();
          }

          if (pageUrl.isNotEmpty && title.isNotEmpty && !seenUrls.contains(pageUrl)) {
            seenUrls.add(pageUrl);
            results.add({
              'title': title,
              'page_url': pageUrl,
              'poster': poster,
              'date': date,
            });
          }
        }
      }

      // Fallback: match standalone post-box-titles
      if (results.isEmpty) {
        final titleReg = RegExp(r'<h[23][^>]*class="[^"]*post-box-title[^"]*"[^>]*>\s*<a[^>]+href="([^"]+)"[^>]*>([^<]+)</a>', caseSensitive: false);
        for (final tm in titleReg.allMatches(html)) {
          final pageUrl = tm.group(1)!.trim();
          final title = tm.group(2)!.trim();
          if (pageUrl.isNotEmpty && title.isNotEmpty && !seenUrls.contains(pageUrl)) {
            seenUrls.add(pageUrl);
            results.add({
              'title': title,
              'page_url': pageUrl,
              'poster': '',
              'date': 'Latest',
            });
          }
        }
      }

      return results;
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> _scrapeAagmaalDetails(String pageUrl) async {
    try {
      final res = await http.get(Uri.parse(pageUrl), headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Referer': 'https://aagmaal.mba/',
      }).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return null;
      final html = res.body;

      var title = '';
      final tMatch = RegExp(r'<h1[^>]*class="[^"]*post-title[^"]*"[^>]*>[\s\S]*?<span[^>]*itemprop="name">([^<]+)</span>|<h1[^>]*>([^<]+)</h1>', caseSensitive: false).firstMatch(html);
      if (tMatch != null) {
        title = (tMatch.group(1) ?? tMatch.group(2) ?? '').trim();
      }

      var poster = '';
      final vPoster = RegExp(r'<video[^>]+poster="([^"]+)"', caseSensitive: false).firstMatch(html);
      if (vPoster != null) {
        poster = vPoster.group(1)!.trim();
      }
      if (poster.isEmpty) {
        final og = RegExp(r'<meta property="og:image" content="([^"]+)"', caseSensitive: false).firstMatch(html);
        if (og != null) poster = og.group(1)!.trim();
      }

      var streamUrl = '';
      final playLinks = <Map<String, dynamic>>[];

      final srcMatch = RegExp(r'<source[^>]+src="([^"]+)"', caseSensitive: false).firstMatch(html);
      if (srcMatch != null) {
        streamUrl = srcMatch.group(1)!.trim();
      }

      if (streamUrl.isEmpty) {
        final mp4Match = RegExp(r'''https?://[^\s<>"']+\.mp4(?:\?[^\s<>"']*)?''', caseSensitive: false).firstMatch(html);
        if (mp4Match != null) {
          streamUrl = mp4Match.group(0)!.trim();
        }
      }

      if (streamUrl.isNotEmpty) {
        playLinks.add({
          'name': 'Server 1 (Direct HD)',
          'type': 'MP4/MKV Direct Link',
          'url': streamUrl,
        });
      }

      final dlMatches = RegExp(r'<a[^>]+href="([^"]+)"[^>]*class="[^"]*shortc-button[^"]*"[^>]*>([^<]+)</a>|<a[^>]+class="[^"]*shortc-button[^"]*"[^>]*href="([^"]+)"[^>]*>([^<]+)</a>', caseSensitive: false).allMatches(html);
      int sIdx = 2;
      for (final dlm in dlMatches) {
        final dUrl = (dlm.group(1) ?? dlm.group(3) ?? '').trim();
        var label = (dlm.group(2) ?? dlm.group(4) ?? '').trim();
        label = label.replaceAll(RegExp(r'<[^>]*>'), '').trim();
        if (dUrl.isNotEmpty && dUrl != streamUrl && !dUrl.contains('javascript') && !dUrl.contains('telegram.me') && !dUrl.contains('t.me')) {
          var serverName = 'Server $sIdx ($label)';
          var streamType = 'MP4/MKV Direct Link';
          if (label.contains('720P') || label.contains('720p')) {
            serverName = 'Server $sIdx (720P HD Mirror)';
          } else if (label.contains('480P') || label.contains('480p')) {
            serverName = 'Server $sIdx (480P SD Mirror)';
          } else if (label.contains('1080P') || label.contains('1080p')) {
            serverName = 'Server $sIdx (1080P Full HD Mirror)';
          } else if (dUrl.contains('streamtape')) {
            serverName = 'Server $sIdx (Streamtape Mirror)';
            streamType = 'Streamtape Stream';
          } else if (dUrl.contains('lulu')) {
            serverName = 'Server $sIdx (Luluvdo Mirror)';
            streamType = 'Luluvdo Stream';
          }
          playLinks.add({
            'name': serverName,
            'type': streamType,
            'url': dUrl,
          });
          sIdx++;
        }
      }

      return {
        'title': title,
        'poster': poster,
        'stream_url': streamUrl,
        'page_url': pageUrl,
        'play_links': playLinks,
      };
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadAagmaalCatalog({bool forceRefresh = false}) async {
    setState(() => _aagmaalLoading = true);
    final q = _aagmaalSearchCtrl.text.trim();
    List<dynamic> items = [];

    // Client-side scraper first for instant loading with 100% posters
    items = await _scrapeAagmaalCatalog(query: q, page: _aagmaalPage);

    if (items.isEmpty) {
      final res = await _adminPhpApi('fetch_aagmaal_catalog', {
        'query': q,
        'page': _aagmaalPage,
        'refresh': forceRefresh ? 1 : 0,
      });
      if (res['status'] == 'success' && res['data']?['items'] != null) {
        items = res['data']['items'];
      }
    }

    if (!mounted) return;
    setState(() {
      _aagmaalLoading = false;
      _aagmaalCatalog = items;
    });
  }

  Future<void> _autoImportAagmaalItem(dynamic item) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        backgroundColor: Color(0xFF141722),
        content: Row(
          children: [
            CircularProgressIndicator(color: Colors.pinkAccent),
            SizedBox(width: 16),
            Expanded(child: Text("Extracting Aagmaal details & preparing movie draft...", style: TextStyle(color: Colors.white, fontSize: 12))),
          ],
        ),
      ),
    );

    final pageUrl = (item['page_url'] ?? '').toString();
    Map<String, dynamic>? data;

    // Instant client extraction first
    data = await _scrapeAagmaalDetails(pageUrl);

    if (data == null || (data['stream_url'] ?? '').toString().isEmpty) {
      final res = await _adminPhpApi('extract_aagmaal_details', {'page_url': pageUrl});
      if (res['status'] == 'success' && res['data'] != null) {
        data = Map<String, dynamic>.from(res['data']);
      }
    }

    if (mounted) Navigator.pop(context);

    if (data != null) {
      final playLinks = (data['play_links'] as List<dynamic>? ?? []);
      final primaryUrl = (data['stream_url'] ?? '').toString().trim();

      setState(() {
        _addType = 'movie';
        _addTitleCtrl.text = data?['title'] ?? item['title'] ?? '';
        _addDescCtrl.text = data?['description'] ?? "Watch ${data?['title'] ?? item['title']} online in HD.";
        _addPosterUrlCtrl.text = data?['poster'] ?? data?['raw_poster'] ?? item['poster'] ?? '';
        _addThumbUrlCtrl.text = data?['poster'] ?? data?['raw_poster'] ?? item['poster'] ?? '';
        if (data?['release_date'] != null && (data!['release_date'] as String).isNotEmpty) {
          _addReleaseDateCtrl.text = data['release_date'];
        } else if (item['date'] != null && item['date'] != 'Latest') {
          _addReleaseDateCtrl.text = item['date'];
        }
        final mainUrl = (playLinks.isNotEmpty && playLinks.first['url'] != null && playLinks.first['url'].toString().isNotEmpty)
            ? playLinks.first['url'].toString().trim()
            : primaryUrl;

        if (mainUrl.isNotEmpty) {
          _addStreamUrlCtrl.text = mainUrl;
          if (mainUrl.contains('lulu') || primaryUrl.contains('tnmr.org')) {
            _streamType = 'Luluvdo Stream';
          } else if (mainUrl.contains('streamtape') || mainUrl.contains('tpead')) {
            _streamType = 'Streamtape Stream';
          } else if (mainUrl.contains('.mp4') || mainUrl.contains('.mkv') || mainUrl.contains('uncutmaal') || mainUrl.contains('download-hot-web-series')) {
            _streamType = 'MP4/MKV Direct Link';
          } else {
            _streamType = 'MP4/MKV Direct Link';
          }
        } else {
          _addStreamUrlCtrl.clear();
        }

        _extraMovieServers.clear();
        for (int i = 1; i < playLinks.length; i++) {
          final pl = playLinks[i];
          _extraMovieServers.add({
            'name': pl['name'] ?? 'Server ${i + 1}',
            'type': pl['type'] ?? 'MP4/MKV Direct Link',
            'ctrl': TextEditingController(text: pl['url'] ?? ''),
          });
        }
        _selectedIndex = 2; // Switch to Add Content studio tab
      });

      final serverCount = playLinks.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(serverCount > 0
              ? "Aagmaal: Extracted $serverCount server link(s)! Review & Publish."
              : "Aagmaal details extracted (No stream links found on page)."),
          backgroundColor: serverCount > 0 ? Colors.green : Colors.orange,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Extraction failed. Please check your network or try another title."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }


  // ── Quick Link Extractor Popup (Search or Paste URL) ──
  void _showQuickLinkExtractorDialog(Function(String, {String? posterUrl}) onLinkSelected, {String defaultSearchText = ''}) {
    final initialQuery = defaultSearchText.trim().isNotEmpty ? defaultSearchText.trim() : _addTitleCtrl.text.trim();
    final queryCtrl = TextEditingController(text: initialQuery);
    int tab = 0; // 0 = HDMaal, 1 = Aagmaal, 2 = Uncut, 3 = HDMove99, 4 = SKY
    bool isSearching = false;
    bool isExtracting = false;
    List<dynamic> searchResults = [];
    String? errorText;
    bool hasAutoSearched = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, dialogSetState) {
            Future<void> runSearch() async {
              final q = queryCtrl.text.trim();
              if (q.isEmpty) return;

              // If user pasted a full HTTP URL, directly extract!
              if (q.startsWith('http://') || q.startsWith('https://')) {
                dialogSetState(() {
                  isExtracting = true;
                  errorText = null;
                });

                // Server-side resolver for Luluvdo / LuluStream URLs (auto-detected by URL)
                if (q.contains('luluvdo') || q.contains('lulustream') || q.contains('lulucdn')) {
                  final serverRes = await _adminPhpApi('resolve_server_stream', {'url': q});
                  if (!dialogCtx.mounted) return;
                  dialogSetState(() => isExtracting = false);
                  if (serverRes['status'] == 'success' && serverRes['data']?['stream_url'] != null) {
                    var streamUrl = serverRes['data']['stream_url'].toString().trim();
                    if (streamUrl.isNotEmpty) {
                      onLinkSelected(streamUrl);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Luluvdo stream resolved & extracted!"),
                          backgroundColor: Colors.green,
                        ),
                      );
                      return;
                    }
                  }
                  dialogSetState(() => errorText = "No playable stream found for Luluvdo URL");
                  return;
                }

                // Direct UFFMaal URL client fallback
                if (q.contains('uffmaal') || tab == 1) {
                  final clientData = await _scrapeUffmaalDetails(q);
                  if (clientData != null) {
                    final streamUrl = (clientData['stream_url'] ?? '').toString();
                    final poster = (clientData['poster'] ?? '').toString();
                    if (streamUrl.isNotEmpty) {
                      if (!dialogCtx.mounted) return;
                      dialogSetState(() => isExtracting = false);
                      onLinkSelected(streamUrl, posterUrl: poster.isNotEmpty ? poster : null);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(poster.isNotEmpty ? "Extracted UFFMaal stream link & poster!" : "Extracted UFFMaal stream link!"),
                          backgroundColor: Colors.green,
                        ),
                      );
                      return;
                    }
                  }
                }

                // Direct HDMaal URL client fallback
                if (q.contains('hdmaal') || tab == 0) {
                  final clientData = await _scrapeHdmaalDetails(q);
                  if (clientData != null && (clientData['stream_url'] ?? '').toString().isNotEmpty) {
                    if (!dialogCtx.mounted) return;
                    dialogSetState(() => isExtracting = false);
                    final streamUrl = clientData['stream_url'].toString();
                    final poster = (clientData['poster'] ?? '').toString();
                    onLinkSelected(streamUrl, posterUrl: poster.isNotEmpty ? poster : null);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(poster.isNotEmpty ? "Extracted HDMaal stream link & poster!" : "Extracted HDMaal stream link!"),
                        backgroundColor: Colors.green,
                      ),
                    );
                    return;
                  }
                }

                String extractAction = 'extract_hdmaal_details';
                if (tab == 1) extractAction = 'extract_uffmaal_details';
                if (tab == 2) extractAction = 'extract_uncutmasti_details';
                if (tab == 3) extractAction = 'extract_hdmove99_details';
                if (tab == 4) extractAction = 'extract_skymovies_details';

                final res = await _adminPhpApi(extractAction, {'page_url': q});
                if (!dialogCtx.mounted) return;
                dialogSetState(() => isExtracting = false);
                if (res['status'] == 'success' && res['data']?['stream_url'] != null) {
                  var streamUrl = res['data']['stream_url'].toString().trim();
                  if (streamUrl.contains(' ')) {
                    streamUrl = streamUrl.replaceAll(' ', '%20');
                  }
                  if (streamUrl.isNotEmpty) {
                    final extractedPoster = (res['data']['poster'] ?? res['data']['raw_poster'] ?? '').toString();
                    onLinkSelected(streamUrl, posterUrl: extractedPoster.isNotEmpty ? extractedPoster : null);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(extractedPoster.isNotEmpty ? "Extracted stream link & poster!" : "Extracted stream link!"),
                        backgroundColor: Colors.green,
                      ),
                    );
                    return;
                  }
                }
                dialogSetState(() => errorText = res['message'] ?? "No video stream link found");
                return;
              }

              // Otherwise perform catalog search by title
              dialogSetState(() {
                isSearching = true;
                errorText = null;
                searchResults = [];
              });

              List<dynamic> items = [];

              if (tab == 0) {
                // HDMaal search: instant client scraper first
                items = await _scrapeHdmaalSearch(q);
                if (items.isEmpty) {
                  final res = await _adminPhpApi('search_hdmaal_catalog', {'query': q});
                  if (res['status'] == 'success' && res['data']?['items'] != null) {
                    items = res['data']['items'];
                  }
                }
              } else if (tab == 1) {
                // UFFMaal search: instant client scraper
                items = await _scrapeUffmaalCatalog(query: q);
              } else {
                String searchAction = 'search_uncutmasti_catalog';
                if (tab == 3) searchAction = 'search_hdmove99_catalog';
                if (tab == 4) searchAction = 'search_skymovies_catalog';
                final res = await _adminPhpApi(searchAction, {'query': q});
                if (res['status'] == 'success' && res['data']?['items'] != null) {
                  items = res['data']['items'];
                }
              }

              if (!dialogCtx.mounted) return;
              dialogSetState(() {
                isSearching = false;
                searchResults = items;
                if (items.isEmpty) {
                  errorText = "No items matched your query.";
                }
              });
            }

            Future<void> extractFromPage(String pageUrl) async {
              dialogSetState(() {
                isExtracting = true;
                errorText = null;
              });

              String? streamUrl;
              String? extractedPoster;

              if (tab == 0) {
                // HDMaal: instant client extraction
                final clientData = await _scrapeHdmaalDetails(pageUrl);
                if (clientData != null && (clientData['stream_url'] ?? '').toString().isNotEmpty) {
                  streamUrl = clientData['stream_url'].toString();
                  extractedPoster = (clientData['poster'] ?? '').toString();
                } else {
                  final res = await _adminPhpApi('extract_hdmaal_details', {'page_url': pageUrl});
                  if (res['status'] == 'success' && res['data']?['stream_url'] != null) {
                    streamUrl = res['data']['stream_url'].toString().trim();
                    extractedPoster = (res['data']['poster'] ?? res['data']['raw_poster'] ?? '').toString();
                  }
                }
              } else if (tab == 1) {
                // UFFMaal: instant client extraction
                final clientData = await _scrapeUffmaalDetails(pageUrl);
                if (clientData != null) {
                  if ((clientData['stream_url'] ?? '').toString().isNotEmpty) {
                    streamUrl = clientData['stream_url'].toString();
                    extractedPoster = (clientData['poster'] ?? '').toString();
                  } else if ((clientData['episodes'] as List<dynamic>? ?? []).isNotEmpty) {
                    // It's a series page: extract the first episode stream
                    final firstEp = (clientData['episodes'] as List<dynamic>).first;
                    final epDetails = await _scrapeUffmaalDetails(firstEp['episode_url'] ?? '');
                    if (epDetails != null && (epDetails['stream_url'] ?? '').toString().isNotEmpty) {
                      streamUrl = epDetails['stream_url'].toString();
                      extractedPoster = (epDetails['poster'] ?? firstEp['poster'] ?? clientData['poster'] ?? '').toString();
                    }
                  }
                }
              } else {
                String extractAction = 'extract_uncutmasti_details';
                if (tab == 3) extractAction = 'extract_hdmove99_details';
                if (tab == 4) extractAction = 'extract_skymovies_details';
                final res = await _adminPhpApi(extractAction, {'page_url': pageUrl});
                if (res['status'] == 'success' && res['data']?['stream_url'] != null) {
                  streamUrl = res['data']['stream_url'].toString().trim();
                  extractedPoster = (res['data']['poster'] ?? res['data']['raw_poster'] ?? '').toString();
                }
              }

              if (!dialogCtx.mounted) return;
              dialogSetState(() => isExtracting = false);

              if (streamUrl != null && streamUrl.isNotEmpty) {
                if (streamUrl.contains(' ')) {
                  streamUrl = streamUrl.replaceAll(' ', '%20');
                }
                onLinkSelected(streamUrl, posterUrl: (extractedPoster != null && extractedPoster.isNotEmpty) ? extractedPoster : null);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text((extractedPoster != null && extractedPoster.isNotEmpty) ? "Extracted stream link & poster!" : "Extracted stream link!"),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                dialogSetState(() => errorText = "No video link found on selected page.");
              }
            }

            if (!hasAutoSearched && queryCtrl.text.trim().isNotEmpty && !isSearching && !isExtracting) {
              hasAutoSearched = true;
              WidgetsBinding.instance.addPostFrameCallback((_) => runSearch());
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF0D1117),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Colors.white12)),
              title: Row(
                children: [
                  const Icon(Icons.bolt_rounded, color: Colors.amberAccent, size: 22),
                  const SizedBox(width: 8),
                  const Expanded(child: Text("Quick Link Search & Extractor", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white54, size: 18), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Source Tabs (HDMaal, UFFMaal, Uncut, HDMove99, SKY)
                    Container(
                      height: 34,
                      decoration: BoxDecoration(color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                dialogSetState(() {
                                  tab = 0;
                                  searchResults = [];
                                  errorText = null;
                                });
                                runSearch();
                              },
                              child: Container(
                                decoration: BoxDecoration(color: tab == 0 ? Colors.purpleAccent.withOpacity(0.2) : Colors.transparent, borderRadius: BorderRadius.circular(8)),
                                alignment: Alignment.center,
                                child: Text("HDMaal", style: TextStyle(color: tab == 0 ? Colors.purpleAccent : Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                dialogSetState(() {
                                  tab = 1;
                                  searchResults = [];
                                  errorText = null;
                                });
                                runSearch();
                              },
                              child: Container(
                                decoration: BoxDecoration(color: tab == 1 ? Colors.amberAccent.withOpacity(0.2) : Colors.transparent, borderRadius: BorderRadius.circular(8)),
                                alignment: Alignment.center,
                                child: Text("UFFMaal", style: TextStyle(color: tab == 1 ? Colors.amberAccent : Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                dialogSetState(() {
                                  tab = 2;
                                  searchResults = [];
                                  errorText = null;
                                });
                                runSearch();
                              },
                              child: Container(
                                decoration: BoxDecoration(color: tab == 2 ? Colors.orangeAccent.withOpacity(0.2) : Colors.transparent, borderRadius: BorderRadius.circular(8)),
                                alignment: Alignment.center,
                                child: Text("Uncut", style: TextStyle(color: tab == 2 ? Colors.orangeAccent : Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                dialogSetState(() {
                                  tab = 3;
                                  searchResults = [];
                                  errorText = null;
                                });
                                runSearch();
                              },
                              child: Container(
                                decoration: BoxDecoration(color: tab == 3 ? Colors.greenAccent.withOpacity(0.2) : Colors.transparent, borderRadius: BorderRadius.circular(8)),
                                alignment: Alignment.center,
                                child: Text("HDMove99", style: TextStyle(color: tab == 3 ? Colors.greenAccent : Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                dialogSetState(() {
                                  tab = 4;
                                  searchResults = [];
                                  errorText = null;
                                });
                                runSearch();
                              },
                              child: Container(
                                decoration: BoxDecoration(color: tab == 4 ? Colors.cyanAccent.withOpacity(0.2) : Colors.transparent, borderRadius: BorderRadius.circular(8)),
                                alignment: Alignment.center,
                                child: Text("SKY", style: TextStyle(color: tab == 4 ? Colors.cyanAccent : Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Search Input
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: queryCtrl,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            decoration: InputDecoration(
                              hintText: "Enter movie title or paste full page URL...",
                              hintStyle: const TextStyle(color: Colors.white38, fontSize: 11),
                              prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 16),
                              filled: true,
                              fillColor: const Color(0xFF161B22),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onSubmitted: (_) => runSearch(),
                          ),
                        ),
                        const SizedBox(width: 6),
                        ElevatedButton(
                          onPressed: isSearching || isExtracting ? null : runSearch,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amberAccent,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text("Search", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Status & Results
                    if (isSearching || isExtracting) ...[
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(color: Colors.amberAccent),
                      ),
                    ] else if (errorText != null) ...[
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(errorText!, style: const TextStyle(color: Colors.redAccent, fontSize: 11), textAlign: TextAlign.center),
                      ),
                    ] else if (searchResults.isNotEmpty) ...[
                      SizedBox(
                        height: 220,
                        child: ListView.builder(
                          itemCount: searchResults.length,
                          itemBuilder: (context, idx) {
                            final item = searchResults[idx];
                            final fullTitle = item['title'] ?? 'Title';
                            return Card(
                              color: const Color(0xFF141722),
                              margin: const EdgeInsets.only(bottom: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Colors.white10)),
                              child: Tooltip(
                                message: fullTitle,
                                child: ListTile(
                                  dense: true,
                                  leading: (item['poster'] ?? '').toString().isNotEmpty
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(6),
                                          child: CachedNetworkImage(
                                            imageUrl: item['poster'].toString(),
                                            width: 32,
                                            height: 32,
                                            fit: BoxFit.cover,
                                            errorWidget: (c, u, e) => const Icon(Icons.movie, color: Colors.white24, size: 20),
                                          ),
                                        )
                                      : const Icon(Icons.movie_outlined, color: Colors.amberAccent, size: 20),
                                  title: Text(fullTitle, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                                  subtitle: const Text("Hold to view full title", style: TextStyle(color: Colors.white38, fontSize: 9)),
                                  trailing: const Icon(Icons.bolt_rounded, color: Colors.amberAccent, size: 18),
                                  onTap: () => extractFromPage(item['page_url'] ?? ''),
                                  onLongPress: () {
                                    final posterUrl = (item['poster'] ?? '').toString();
                                    showDialog(
                                      context: dialogCtx,
                                      builder: (c) => AlertDialog(
                                        backgroundColor: const Color(0xFF161B22),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        title: Text(
                                          fullTitle,
                                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        content: SingleChildScrollView(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (posterUrl.isNotEmpty) ...[
                                                ClipRRect(
                                                  borderRadius: BorderRadius.circular(10),
                                                  child: CachedNetworkImage(
                                                    imageUrl: posterUrl,
                                                    height: 200,
                                                    fit: BoxFit.cover,
                                                    errorWidget: (c, u, e) => const SizedBox.shrink(),
                                                  ),
                                                ),
                                                const SizedBox(height: 12),
                                              ],
                                              SelectableText(
                                                item['page_url'] ?? '',
                                                style: const TextStyle(color: Colors.cyanAccent, fontSize: 11),
                                              ),
                                            ],
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(c),
                                            child: const Text("CLOSE", style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── Multi-Episode Batch Importer Dialog (UFFMaal / HDMaal / Uncut) ──
  void _showBatchEpisodeImportDialog({
    required int seriesId,
    required String seriesTitle,
    required dynamic currentSeason,
    required List<dynamic> currentEpisodes,
    required Future<void> Function() refresh,
  }) {
    final searchCtrl = TextEditingController(text: seriesTitle.trim());
    int tab = 0; // 0 = UFFMaal, 1 = HDMaal, 2 = Uncut
    bool isSearching = false;
    bool isImporting = false;
    String importStatus = '';
    double importProgress = 0.0;
    List<Map<String, dynamic>> episodeItems = [];
    String namingMode = 'episode'; // 'episode' (Episode 1,2..), 'part' (Part 1,2..), 'original'
    String selectedQuality = '720p';
    int startOrder = currentEpisodes.length + 1;
    String? errorText;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, dialogSetState) {
            Future<void> performSearch() async {
              final q = searchCtrl.text.trim();
              if (q.isEmpty) return;
              dialogSetState(() {
                isSearching = true;
                errorText = null;
                episodeItems = [];
              });

              try {
                // If direct URL is pasted
                if (q.startsWith('http://') || q.startsWith('https://')) {
                  if (q.contains('uffmaal') || tab == 0) {
                    final details = await _scrapeUffmaalDetails(q);
                    if (details != null) {
                      final eps = (details['episodes'] as List<dynamic>? ?? []);
                      if (eps.isNotEmpty) {
                        episodeItems = eps.map((e) => {
                          'title': e['title'] ?? 'Episode ${e['episode_number']}',
                          'url': e['episode_url'] ?? '',
                          'poster': e['poster'] ?? details['poster'] ?? '',
                          'ep_num': e['episode_number'] ?? '',
                          'selected': true,
                        }).toList();
                      } else if ((details['stream_url'] ?? '').toString().isNotEmpty) {
                        episodeItems = [{
                          'title': details['title'] ?? 'Episode 1',
                          'url': q,
                          'stream_url': details['stream_url'],
                          'poster': details['poster'] ?? '',
                          'ep_num': '1',
                          'selected': true,
                        }];
                      }
                    }
                  }
                } else {
                  // Search query
                  if (tab == 0) {
                    // UFFMaal catalog search
                    final results = await _scrapeUffmaalCatalog(query: q);
                    if (results.isNotEmpty) {
                      // Find first series or list all results
                      final seriesItem = results.firstWhere((r) => r['is_episode'] != true, orElse: () => results.first);
                      final details = await _scrapeUffmaalDetails(seriesItem['page_url'] ?? '');
                      if (details != null && (details['episodes'] as List<dynamic>? ?? []).isNotEmpty) {
                        final eps = details['episodes'] as List<dynamic>;
                        episodeItems = eps.map((e) => {
                          'title': e['title'] ?? 'Episode ${e['episode_number']}',
                          'url': e['episode_url'] ?? '',
                          'poster': e['poster'] ?? details['poster'] ?? '',
                          'ep_num': e['episode_number'] ?? '',
                          'selected': true,
                        }).toList();
                      } else {
                        // All results as episodes
                        episodeItems = results.map((r) => {
                          'title': r['title'] ?? 'Episode',
                          'url': r['page_url'] ?? '',
                          'poster': r['poster'] ?? '',
                          'ep_num': '',
                          'selected': true,
                        }).toList();
                      }
                    }
                  } else if (tab == 1) {
                    // HDMaal
                    final results = await _scrapeHdmaalSearch(q);
                    episodeItems = results.map((r) => {
                      'title': r['title'] ?? 'Episode',
                      'url': r['page_url'] ?? '',
                      'poster': r['poster'] ?? '',
                      'ep_num': '',
                      'selected': true,
                    }).toList();
                  } else {
                    // Uncut
                    final res = await _adminPhpApi('search_uncutmasti_catalog', {'query': q});
                    if (res['status'] == 'success' && res['data']?['items'] != null) {
                      final items = res['data']['items'] as List<dynamic>;
                      episodeItems = items.map((r) => {
                        'title': r['title'] ?? 'Episode',
                        'url': r['page_url'] ?? '',
                        'poster': r['poster'] ?? '',
                        'ep_num': '',
                        'selected': true,
                      }).toList();
                    }
                  }
                }
                if (episodeItems.isEmpty) {
                  errorText = "No episodes found for '$q'. Try another title or paste series URL.";
                }
              } catch (e) {
                errorText = "Search error: $e";
              }

              if (!dialogCtx.mounted) return;
              dialogSetState(() => isSearching = false);
            }

            Future<void> runBatchImport() async {
              final selectedList = episodeItems.where((e) => e['selected'] == true).toList();
              if (selectedList.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please select at least 1 episode to import"), backgroundColor: Colors.orange),
                );
                return;
              }

              dialogSetState(() {
                isImporting = true;
                importProgress = 0.0;
                importStatus = "Starting batch extraction & import...";
              });

              final episodesPayload = <Map<String, dynamic>>[];
              int successCount = 0;

              for (int i = 0; i < selectedList.length; i++) {
                final item = selectedList[i];
                final epIndex = i + 1;
                final epOrder = startOrder + i;
                dialogSetState(() {
                  importStatus = "Resolving stream $epIndex of ${selectedList.length}...";
                  importProgress = (i) / selectedList.length;
                });

                String streamUrl = (item['stream_url'] ?? '').toString();
                String poster = (item['poster'] ?? '').toString();

                if (streamUrl.isEmpty) {
                  final pageUrl = (item['url'] ?? '').toString();
                  if (pageUrl.contains('uffmaal')) {
                    final d = await _scrapeUffmaalDetails(pageUrl);
                    if (d != null && (d['stream_url'] ?? '').toString().isNotEmpty) {
                      streamUrl = d['stream_url'].toString();
                      if (poster.isEmpty) poster = (d['poster'] ?? '').toString();
                    }
                  } else if (pageUrl.contains('hdmaal')) {
                    final d = await _scrapeHdmaalDetails(pageUrl);
                    if (d != null && (d['stream_url'] ?? '').toString().isNotEmpty) {
                      streamUrl = d['stream_url'].toString();
                      if (poster.isEmpty) poster = (d['poster'] ?? '').toString();
                    }
                  } else {
                    final res = await _adminPhpApi('extract_uncutmasti_details', {'page_url': pageUrl});
                    if (res['status'] == 'success' && res['data']?['stream_url'] != null) {
                      streamUrl = res['data']['stream_url'].toString();
                      if (poster.isEmpty) poster = (res['data']['poster'] ?? '').toString();
                    }
                  }
                }

                if (streamUrl.isNotEmpty) {
                  String epName = "Episode $epIndex";
                  if (namingMode == 'part') {
                    epName = "Part $epIndex";
                  } else if (namingMode == 'original') {
                    epName = (item['title'] ?? "Episode $epIndex").toString();
                  }

                  episodesPayload.add({
                    'name': epName,
                    'url': streamUrl,
                    'episode_image': poster,
                    'stream_type': 'MP4/MKV Direct Link',
                    'quality': selectedQuality,
                    'order': epOrder,
                    'play_links': [
                      {
                        'name': 'Server 1',
                        'type': 'MP4/MKV Direct Link',
                        'quality': selectedQuality,
                        'url': streamUrl,
                      }
                    ],
                  });
                }
              }

              if (episodesPayload.isEmpty) {
                dialogSetState(() {
                  isImporting = false;
                  errorText = "Could not extract playable streams for any selected episode.";
                });
                return;
              }

              dialogSetState(() {
                importStatus = "Saving ${episodesPayload.length} episodes to database...";
                importProgress = 0.9;
              });

              final seasonName = (currentSeason?['Session_Name'] ?? 'Season 1').toString().trim();
              final batchRes = await _adminPhpApi('batch_add_episodes', {
                'series_id': seriesId,
                'season_name': seasonName,
                'episodes': episodesPayload,
              });

              if (batchRes['status'] == 'success') {
                successCount = batchRes['data']?['inserted_count'] ?? episodesPayload.length;
              } else {
                for (final ep in episodesPayload) {
                  final sRes = await _adminPhpApi('add_episode_link', {
                    'series_id': seriesId,
                    'season_name': seasonName,
                    'name': ep['name'],
                    'url': ep['url'],
                    'stream_type': ep['stream_type'],
                    'episode_image': ep['episode_image'],
                    'quality': ep['quality'],
                    'order': ep['order'],
                    'play_links': ep['play_links'],
                  });
                  if (sRes['status'] == 'success') successCount++;
                }
              }

              if (!dialogCtx.mounted) return;
              Navigator.pop(ctx);
              await refresh();

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text("Successfully imported $successCount episode(s) into $seasonName!")),
                    ],
                  ),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }

            if (searchCtrl.text.trim().isNotEmpty && !isSearching && episodeItems.isEmpty && errorText == null && !isImporting) {
              WidgetsBinding.instance.addPostFrameCallback((_) => performSearch());
            }

            final selectedCount = episodeItems.where((e) => e['selected'] == true).length;

            return Dialog(
              backgroundColor: const Color(0xFF0F131D),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: Colors.white.withOpacity(0.1))),
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.95,
                constraints: const BoxConstraints(maxWidth: 540, maxHeight: 680),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFFFF8008), Color(0xFFFFC837)]),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.bolt_rounded, color: Colors.black, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "⚡ Batch Import Multi Episodes",
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                "Target Season: ${(currentSeason?['Session_Name'] ?? 'Season').toString().trim()}",
                                style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        if (!isImporting)
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Source Tabs
                    Container(
                      height: 32,
                      decoration: BoxDecoration(color: const Color(0xFF141722), borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: isImporting ? null : () {
                                dialogSetState(() {
                                  tab = 0;
                                  episodeItems = [];
                                  errorText = null;
                                });
                                performSearch();
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: tab == 0 ? Colors.amberAccent.withOpacity(0.2) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                alignment: Alignment.center,
                                child: Text("UFFMaal (Fast CDN)", style: TextStyle(color: tab == 0 ? Colors.amberAccent : Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: isImporting ? null : () {
                                dialogSetState(() {
                                  tab = 1;
                                  episodeItems = [];
                                  errorText = null;
                                });
                                performSearch();
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: tab == 1 ? Colors.purpleAccent.withOpacity(0.2) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                alignment: Alignment.center,
                                child: Text("HDMaal", style: TextStyle(color: tab == 1 ? Colors.purpleAccent : Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: isImporting ? null : () {
                                dialogSetState(() {
                                  tab = 2;
                                  episodeItems = [];
                                  errorText = null;
                                });
                                performSearch();
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: tab == 2 ? Colors.orangeAccent.withOpacity(0.2) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                alignment: Alignment.center,
                                child: Text("UncutMasti", style: TextStyle(color: tab == 2 ? Colors.orangeAccent : Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Search input
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF141722),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: TextField(
                              controller: searchCtrl,
                              enabled: !isImporting,
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                              decoration: const InputDecoration(
                                hintText: "Search series title or paste series URL...",
                                hintStyle: TextStyle(color: Colors.white30, fontSize: 11),
                                prefixIcon: Icon(Icons.search_rounded, color: Colors.amberAccent, size: 18),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              ),
                              onSubmitted: (_) => performSearch(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: isSearching || isImporting ? null : performSearch,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amberAccent,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text("Search", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Naming Format & Quality Controls
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141722),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Title Naming Format:", style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              _buildFormatChip("Episode 1, 2...", namingMode == 'episode', () {
                                dialogSetState(() => namingMode = 'episode');
                              }),
                              const SizedBox(width: 6),
                              _buildFormatChip("Part 1, 2...", namingMode == 'part', () {
                                dialogSetState(() => namingMode = 'part');
                              }),
                              const SizedBox(width: 6),
                              _buildFormatChip("Original Titles", namingMode == 'original', () {
                                dialogSetState(() => namingMode = 'original');
                              }),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Text("Quality:", style: TextStyle(color: Colors.white60, fontSize: 11)),
                              const SizedBox(width: 8),
                              DropdownButton<String>(
                                value: selectedQuality,
                                dropdownColor: const Color(0xFF141722),
                                underline: const SizedBox.shrink(),
                                style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                items: ['480p', '720p', '1080p'].map((q) => DropdownMenuItem(value: q, child: Text(q))).toList(),
                                onChanged: isImporting ? null : (val) {
                                  if (val != null) dialogSetState(() => selectedQuality = val);
                                },
                              ),
                              const Spacer(),
                              if (episodeItems.isNotEmpty)
                                TextButton(
                                  onPressed: isImporting ? null : () {
                                    final allSelected = episodeItems.every((e) => e['selected'] == true);
                                    dialogSetState(() {
                                      for (var e in episodeItems) {
                                        e['selected'] = !allSelected;
                                      }
                                    });
                                  },
                                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
                                  child: Text(
                                    episodeItems.every((e) => e['selected'] == true) ? "Deselect All" : "Select All",
                                    style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Episodes List / Loading Status
                    if (isImporting) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          children: [
                            LinearProgressIndicator(value: importProgress > 0 ? importProgress : null, backgroundColor: Colors.white12, color: Colors.amberAccent),
                            const SizedBox(height: 12),
                            Text(importStatus, style: const TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    ] else if (isSearching) ...[
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: CircularProgressIndicator(color: Colors.amberAccent),
                        ),
                      ),
                    ] else if (errorText != null) ...[
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Text(errorText!, style: const TextStyle(color: Colors.redAccent, fontSize: 11), textAlign: TextAlign.center),
                      ),
                    ] else if (episodeItems.isNotEmpty) ...[
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF141722),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.06)),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            padding: const EdgeInsets.all(8),
                            itemCount: episodeItems.length,
                            separatorBuilder: (c, i) => const Divider(color: Colors.white10, height: 1),
                            itemBuilder: (c, i) {
                              final ep = episodeItems[i];
                              final isChecked = ep['selected'] == true;
                              final poster = (ep['poster'] ?? '').toString();
                              String displayName = namingMode == 'part' ? "Part ${i + 1}" : (namingMode == 'episode' ? "Episode ${i + 1}" : ep['title']);

                              return CheckboxListTile(
                                value: isChecked,
                                activeColor: Colors.amberAccent,
                                checkColor: Colors.black,
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                                secondary: poster.isNotEmpty
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: CachedNetworkImage(
                                          imageUrl: poster,
                                          width: 48,
                                          height: 32,
                                          fit: BoxFit.cover,
                                          errorWidget: (cx, u, e) => const Icon(Icons.tv, color: Colors.white24, size: 20),
                                        ),
                                      )
                                    : const Icon(Icons.tv, color: Colors.white24, size: 20),
                                title: Text(displayName, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                subtitle: Text(ep['title'] ?? '', style: const TextStyle(color: Colors.white38, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
                                onChanged: (val) {
                                  dialogSetState(() => ep['selected'] = val == true);
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    ] else ...[
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Text("Search for a series title or paste a series URL to discover episodes.", style: TextStyle(color: Colors.white38, fontSize: 11), textAlign: TextAlign.center),
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),

                    // Actions
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: isImporting ? null : () => Navigator.pop(ctx),
                            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: isImporting || selectedCount == 0 ? null : runBatchImport,
                            icon: const Icon(Icons.bolt_rounded, size: 16),
                            label: Text(
                              selectedCount > 0 ? "⚡ IMPORT ($selectedCount) EPISODES" : "Select Episodes",
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amberAccent,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFormatChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.amberAccent.withOpacity(0.2) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? Colors.amberAccent : Colors.white12, width: isSelected ? 1 : 0.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.amberAccent : Colors.white70,
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Future<List<String>> _doClientSideImageSearch(String query) async {
    final List<String> results = [];
    try {
      // Step 1: Get vqd token from DDG HTML
      final htmlRes = await http.get(
        Uri.parse('https://html.duckduckgo.com/html/?q=${Uri.encodeQueryComponent(query)}'),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
          'Accept-Language': 'en-US,en;q=0.9',
        },
      ).timeout(const Duration(seconds: 12));
      final htmlBody = htmlRes.body;
      String? vqd;
      final m1 = RegExp(r'name="vqd"\s+value="([^"]+)"').firstMatch(htmlBody);
      if (m1 != null) {
        vqd = m1.group(1);
      } else {
        final m2 = RegExp(r'vqd=(\d[\d-]*)').firstMatch(htmlBody);
        if (m2 != null) vqd = m2.group(1);
      }
      if (vqd == null || vqd.isEmpty) return results;

      // Step 2: Get image results from DDG images API
      final params = {
        'l': 'us-en', 'o': 'json', 'q': query,
        'vqd': vqd, 'f': ',,,', 'p': '1',
      };
      final imgRes = await http.get(
        Uri.https('duckduckgo.com', '/i.js', params),
        headers: {
          'Referer': 'https://duckduckgo.com/',
          'Accept': 'application/json, */*',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      ).timeout(const Duration(seconds: 12));
      final data = json.decode(imgRes.body);
      if (data is Map && data['results'] != null) {
        for (final r in data['results'] as List) {
          final img = r['image']?.toString();
          if (img != null && img.startsWith('http')) {
            results.add(img);
          }
        }
      }
    } catch (e) {
      debugPrint('DDG client search error: $e');
    }
    return results;
  }

  Future<void> _loadLiveTelemetryData() async {
    if (_telemetryDashboardLoading) return;
    setState(() {
      _telemetryDashboardLoading = true;
      _telemetryDashboardError = null;
    });

    try {
      final res = await _adminPhpApi('get_dashboard_telemetry', {});
      if (mounted) {
        setState(() {
          _telemetryDashboardLoading = false;
          if (res['status'] == 'success') {
            _telemetryDashboardData = res['data'];
          } else {
            _telemetryDashboardError = res['message'] ?? 'Failed to load telemetry';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _telemetryDashboardLoading = false;
          _telemetryDashboardError = e.toString();
        });
      }
    }
  }

  Widget _buildLiveTelemetryView() {
    if (_telemetryDashboardData == null && !_telemetryDashboardLoading && _telemetryDashboardError == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadLiveTelemetryData();
      });
    }

    if (_telemetryDashboardLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.orangeAccent));
    }

    if (_telemetryDashboardError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
              const SizedBox(height: 16),
              Text(
                "Error: $_telemetryDashboardError",
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadLiveTelemetryData,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text("RETRY"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
              ),
            ],
          ),
        ),
      );
    }

    final liveUsers = (_telemetryDashboardData?['live_users'] as List? ?? []);
    final topUsers = (_telemetryDashboardData?['top_users'] as List? ?? []);
    final topDownloads = (_telemetryDashboardData?['top_downloads'] as List? ?? []);
    final topPlayed = (_telemetryDashboardData?['top_played'] as List? ?? []);

    return RefreshIndicator(
      onRefresh: _loadLiveTelemetryData,
      color: Colors.orangeAccent,
      backgroundColor: const Color(0xFF10121A),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header stats
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFE50914), Color(0xFF8B0000)]),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.people_alt_rounded, color: Colors.white, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Live Users (5m)", style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                              Text("${liveUsers.length} Active", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF1E2230), Color(0xFF141722)]),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.refresh_rounded, color: Colors.cyanAccent, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: _loadLiveTelemetryData,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text("Last Updated", style: TextStyle(color: Colors.white54, fontSize: 11)),
                                Text("Tap to Refresh", style: TextStyle(color: Colors.cyanAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 1. LIVE USERS DETAILS VIEW
            _buildSectionHeader(Icons.sensors_rounded, "LIVE USERS PLAYING DETAILS", Colors.greenAccent),
            const SizedBox(height: 8),
            if (liveUsers.isEmpty)
              _buildEmptyCard("No active users browsing or playing currently.")
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: liveUsers.length,
                itemBuilder: (context, index) {
                  final lu = liveUsers[index];
                  final name = lu['user_name'] ?? 'Guest';
                  final email = lu['user_email'] ?? 'guest@redapp.space';
                  final view = lu['current_view'] ?? 'Browsing';
                  final content = lu['content_name']?.toString();
                  final ver = lu['app_version'] ?? '1.0.0';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1F2E),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.greenAccent.withOpacity(0.15)),
                    ),
                    child: ListTile(
                      dense: true,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.08), shape: BoxShape.circle),
                        child: const Icon(Icons.play_circle_outline_rounded, color: Colors.greenAccent),
                      ),
                      title: Row(
                        children: [
                          Expanded(child: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
                          Text("Ver $ver", style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(email, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  content != null ? "Watching: $content" : "Viewing: $view",
                                  style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 16),

            // 2. TOP 10 PLAYTIME USERS
            _buildSectionHeader(Icons.military_tech_rounded, "TOP 10 USERS BY PLAYTIME", Colors.orangeAccent),
            const SizedBox(height: 8),
            if (topUsers.isEmpty)
              _buildEmptyCard("No play statistics collected yet.")
            else
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF161924),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: topUsers.length,
                  separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                  itemBuilder: (context, index) {
                    final tu = topUsers[index];
                    final name = tu['user_name'] ?? 'User';
                    final email = tu['user_email'] ?? 'N/A';
                    final ver = tu['app_version'] ?? '1.0.0';
                    final sec = int.tryParse(tu['total_playtime_seconds']?.toString() ?? '0') ?? 0;
                    
                    final hrs = sec ~/ 3600;
                    final mins = (sec % 3600) ~/ 60;
                    final timeStr = hrs > 0 ? "$hrs hrs $mins mins" : "$mins mins";

                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 12,
                        backgroundColor: index == 0
                            ? Colors.amber
                            : index == 1
                                ? Colors.grey[400]
                                : index == 2
                                    ? Colors.brown[400]
                                    : Colors.white12,
                        child: Text(
                          "${index + 1}",
                          style: TextStyle(color: index < 3 ? Colors.black : Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Text("$email (Ver: $ver)", style: const TextStyle(color: Colors.white38, fontSize: 11)),
                      trailing: Text(
                        timeStr,
                        style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),

            // 3. TOP 10 PLAYED CONTENT
            _buildSectionHeader(Icons.local_fire_department_rounded, "TOP 10 MOST WATCHED CONTENT", Colors.redAccent),
            const SizedBox(height: 8),
            if (topPlayed.isEmpty)
              _buildEmptyCard("No watch history statistics yet.")
            else
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF161924),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: topPlayed.length,
                  separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                  itemBuilder: (context, index) {
                    final tp = topPlayed[index];
                    final name = tp['content_name'] ?? 'Unknown Content';
                    final plays = tp['play_count'] ?? 0;
                    final type = tp['content_type']?.toString() == '1' ? 'Movie' : 'Series';
                    
                    final sec = int.tryParse(tp['total_playtime_seconds']?.toString() ?? '0') ?? 0;
                    final hrs = sec ~/ 3600;
                    final mins = (sec % 3600) ~/ 60;
                    final playtimeStr = hrs > 0 ? "$hrs hrs $mins mins" : "$mins mins";

                    return ListTile(
                      dense: true,
                      leading: Icon(type == 'Movie' ? Icons.movie_rounded : Icons.live_tv_rounded, size: 18, color: Colors.redAccent),
                      title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
                      subtitle: Text("$plays play sessions • Playtime: $playtimeStr", style: const TextStyle(color: Colors.white38, fontSize: 11)),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),

            // 4. TOP 10 DOWNLOADS
            _buildSectionHeader(Icons.download_for_offline_rounded, "TOP 10 MOST DOWNLOADED CONTENT", Colors.cyanAccent),
            const SizedBox(height: 8),
            if (topDownloads.isEmpty)
              _buildEmptyCard("No downloads registered yet.")
            else
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF161924),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: topDownloads.length,
                  separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                  itemBuilder: (context, index) {
                    final td = topDownloads[index];
                    final name = td['content_name'] ?? 'Unknown Content';
                    final count = td['download_count'] ?? 0;
                    final type = td['content_type']?.toString() == '1' ? 'Movie' : 'Series';

                    return ListTile(
                      dense: true,
                      leading: Icon(type == 'Movie' ? Icons.movie_outlined : Icons.live_tv_outlined, size: 18, color: Colors.cyanAccent),
                      title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
                      subtitle: Text("$count download requests recorded", style: const TextStyle(color: Colors.white38, fontSize: 11)),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),

            // 5. FLY MODE ANALYTICS
            ..._buildFlyModeAnalyticsWidgets(_telemetryDashboardData?['fly_mode'] as Map<String, dynamic>?),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFlyModeAnalyticsWidgets(Map<String, dynamic>? fly) {
    if (fly == null) return const [];
    final totalPlays = int.tryParse(fly['total_plays']?.toString() ?? '0') ?? 0;
    final totalDownloads = int.tryParse(fly['total_downloads']?.toString() ?? '0') ?? 0;
    final playsToday = int.tryParse(fly['plays_today']?.toString() ?? '0') ?? 0;
    final playsWeek = int.tryParse(fly['plays_week']?.toString() ?? '0') ?? 0;
    final uniqueUsers = int.tryParse(fly['unique_users']?.toString() ?? '0') ?? 0;
    final topSources = (fly['top_sources'] as List? ?? []);
    final topUsers = (fly['top_users'] as List? ?? []);
    final topVideos = (fly['top_videos'] as List? ?? []);
    final recent = (fly['recent'] as List? ?? []);
    final int maxSourcePlays = topSources.fold(0, (m, s) {
      final p = int.tryParse(s['plays']?.toString() ?? '0') ?? 0;
      return p > m ? p : m;
    });

    return [
      _buildSectionHeader(Icons.flight_takeoff_rounded, "FLY MODE ANALYTICS", Colors.deepPurpleAccent),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: _buildFlyStatCard("Total Plays", "$totalPlays", const Color(0xFFE50914), Icons.play_circle_fill_rounded),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildFlyStatCard("Downloads", "$totalDownloads", Colors.cyanAccent, Icons.download_done_rounded),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildFlyStatCard("Plays Today", "$playsToday", Colors.amberAccent, Icons.today_rounded),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: _buildFlyStatCard("Plays (7d)", "$playsWeek", Colors.blueAccent, Icons.date_range_rounded),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildFlyStatCard("Unique Users", "$uniqueUsers", Colors.deepPurpleAccent, Icons.person_pin_rounded),
          ),
        ],
      ),
      const SizedBox(height: 16),

      // Most visited sites
      _buildSectionHeader(Icons.language_rounded, "MOST VISITED SITES", Colors.deepPurpleAccent),
      const SizedBox(height: 8),
      if (topSources.isEmpty)
        _buildEmptyCard("No Fly Mode plays registered yet.")
      else
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF161924),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: topSources.length,
            separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
            itemBuilder: (context, index) {
              final s = topSources[index];
              final name = s['source_name'] ?? s['source_id'] ?? 'Unknown';
              final plays = int.tryParse(s['plays']?.toString() ?? '0') ?? 0;
              final downloads = int.tryParse(s['download_count']?.toString() ?? '0') ?? 0;
              final pct = maxSourcePlays > 0 ? plays / maxSourcePlays : 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
                        ),
                        Text("$plays plays • $downloads dl", style: const TextStyle(color: Colors.white54, fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 6,
                        backgroundColor: Colors.white10,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.deepPurpleAccent),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      const SizedBox(height: 16),

      // Most active users
      _buildSectionHeader(Icons.military_tech_rounded, "MOST ACTIVE FLY MODE USERS", Colors.orangeAccent),
      const SizedBox(height: 8),
      if (topUsers.isEmpty)
        _buildEmptyCard("No Fly Mode user activity yet.")
      else
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF161924),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: topUsers.length,
            separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
            itemBuilder: (context, index) {
              final u = topUsers[index];
              final name = u['user_name'] ?? 'User';
              final plays = int.tryParse(u['plays']?.toString() ?? '0') ?? 0;
              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 12,
                  backgroundColor: index == 0
                      ? Colors.amber
                      : index == 1
                          ? Colors.grey[400]
                          : index == 2
                              ? Colors.brown[400]
                              : Colors.white12,
                  child: Text(
                    "${index + 1}",
                    style: TextStyle(color: index < 3 ? Colors.black : Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                trailing: Text("$plays plays", style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold)),
              );
            },
          ),
        ),
      const SizedBox(height: 16),

      // Most watched videos
      _buildSectionHeader(Icons.local_fire_department_rounded, "MOST WATCHED FLY MODE VIDEOS", Colors.redAccent),
      const SizedBox(height: 8),
      if (topVideos.isEmpty)
        _buildEmptyCard("No Fly Mode video statistics yet.")
      else
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF161924),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: topVideos.length,
            separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
            itemBuilder: (context, index) {
              final v = topVideos[index];
              final title = v['video_title'] ?? 'Unknown Video';
              final source = v['source_name'] ?? 'Unknown';
              final plays = int.tryParse(v['plays']?.toString() ?? '0') ?? 0;
              return ListTile(
                dense: true,
                leading: const Icon(Icons.movie_rounded, size: 18, color: Colors.redAccent),
                title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
                subtitle: Text("$source • $plays plays", style: const TextStyle(color: Colors.white38, fontSize: 11)),
              );
            },
          ),
        ),
      const SizedBox(height: 16),

      // Recent activity
      _buildSectionHeader(Icons.sensors_rounded, "RECENT FLY MODE ACTIVITY", Colors.greenAccent),
      const SizedBox(height: 8),
      if (recent.isEmpty)
        _buildEmptyCard("No Fly Mode activity yet.")
      else
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF161924),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recent.length,
            separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
            itemBuilder: (context, index) {
              final r = recent[index];
              final name = r['user_name'] ?? 'Guest';
              final source = r['source_name'] ?? '';
              final title = r['video_title'] ?? '';
              final isPlay = (r['action'] ?? 'play') == 'play';
              final when = (r['created_at'] ?? '').toString();
              return ListTile(
                dense: true,
                leading: Icon(isPlay ? Icons.play_arrow_rounded : Icons.download_done_rounded, size: 18, color: isPlay ? Colors.greenAccent : Colors.cyanAccent),
                title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  "${isPlay ? "Played" : "Downloaded"}${source.isNotEmpty ? " on $source" : ""}${when.isNotEmpty ? " • $when" : ""}",
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: title.isNotEmpty
                    ? Icon(isPlay ? Icons.play_circle_fill : Icons.download_done, size: 18, color: isPlay ? Colors.greenAccent : Colors.cyanAccent)
                    : null,
              );
            },
          ),
        ),
    ];
  }

  Widget _buildFlyStatCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withOpacity(0.25), const Color(0xFF161924)]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 12,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyCard(String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF161924),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
      ),
      child: Text(
        msg,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white30, fontSize: 12.5),
      ),
    );
  }

  // 13. Push Campaigns & Announcements View
  Widget _buildPushCampaignsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text("🔥 Push Content Campaign (Modal)")),
                  selected: _pushSubTab == 0,
                  selectedColor: const Color(0xFFFF1744),
                  backgroundColor: const Color(0xFF161A26),
                  labelStyle: TextStyle(color: _pushSubTab == 0 ? Colors.white : Colors.white60, fontWeight: FontWeight.bold),
                  onSelected: (val) {
                    if (val) {
                      setState(() => _pushSubTab = 0);
                      _loadPushCampaigns();
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text("📢 Push Announcement")),
                  selected: _pushSubTab == 1,
                  selectedColor: const Color(0xFF8E2DE2),
                  backgroundColor: const Color(0xFF161A26),
                  labelStyle: TextStyle(color: _pushSubTab == 1 ? Colors.white : Colors.white60, fontWeight: FontWeight.bold),
                  onSelected: (val) {
                    if (val) {
                      setState(() => _pushSubTab = 1);
                      _loadAnnouncements();
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (_pushSubTab == 0) _buildPushCampaignSubTab() else _buildAnnouncementSubTab(),
        ],
      ),
    );
  }

  Widget _buildPushCampaignSubTab() {
    final allContent = <Map<String, dynamic>>[];
    for (final m in _movies) {
      if (m is Map<String, dynamic>) {
        allContent.add({...m, 'content_type': 'movie'});
      } else if (m is Map) {
        allContent.add({...Map<String, dynamic>.from(m), 'content_type': 'movie'});
      }
    }
    for (final s in _series) {
      if (s is Map<String, dynamic>) {
        allContent.add({...s, 'content_type': 'series'});
      } else if (s is Map) {
        allContent.add({...Map<String, dynamic>.from(s), 'content_type': 'series'});
      }
    }

    final filtered = allContent.where((item) {
      final name = (item['name'] ?? '').toString().toLowerCase();
      return _pushCatalogSearch.isEmpty || name.contains(_pushCatalogSearch.toLowerCase());
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF121622),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFF1744).withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Create New Content Push Campaign", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              const Text("Pushes a 1-time popup modal to all users listing newly uploaded movies & series.", style: TextStyle(color: Colors.white60, fontSize: 12)),
              const SizedBox(height: 16),

              TextField(
                controller: _pushTitleCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Campaign Title",
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: const Color(0xFF1A1F2C),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  const Text("Campaign Expiry: ", style: TextStyle(color: Colors.white70)),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: _pushHoursValid,
                    dropdownColor: const Color(0xFF1A1F2C),
                    style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold),
                    items: const [
                      DropdownMenuItem(value: 24, child: Text("24 Hours (1 Day)")),
                      DropdownMenuItem(value: 48, child: Text("48 Hours (2 Days)")),
                      DropdownMenuItem(value: 72, child: Text("3 Days")),
                      DropdownMenuItem(value: 168, child: Text("7 Days")),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _pushHoursValid = val);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Text("Select Movies / Web Series (${_selectedPushItemKeys.length}/50 selected)", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() => _selectedPushItemKeys.clear()),
                    child: const Text("Clear Selection", style: TextStyle(color: Colors.redAccent)),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              TextField(
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Search content to select...",
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.cyanAccent),
                  filled: true,
                  fillColor: const Color(0xFF1A1F2C),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onChanged: (v) => setState(() => _pushCatalogSearch = v),
              ),
              const SizedBox(height: 10),

              Container(
                height: 220,
                decoration: BoxDecoration(
                  color: const Color(0xFF0D0F18),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white10),
                ),
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final item = filtered[i];
                    final id = int.tryParse('${item['id']}') ?? 0;
                    final type = item['content_type'] ?? 'movie';
                    final key = "${type}_$id";
                    final isChecked = _selectedPushItemKeys.contains(key);
                    final name = (item['name'] ?? '').toString();

                    return CheckboxListTile(
                      value: isChecked,
                      activeColor: const Color(0xFFFF1744),
                      title: Text(name, style: const TextStyle(color: Colors.white, fontSize: 13)),
                      subtitle: Text("${type.toUpperCase()} (ID: $id)", style: const TextStyle(color: Colors.white38, fontSize: 11)),
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            if (_selectedPushItemKeys.length < 50) {
                              _selectedPushItemKeys.add(key);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Maximum 50 items allowed per campaign!")));
                            }
                          } else {
                            _selectedPushItemKeys.remove(key);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _submitPushCampaign,
                  icon: const Icon(Icons.send_rounded),
                  label: Text("🚀 PUSH CAMPAIGN (${_selectedPushItemKeys.length} ITEMS)"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF1744),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        const Text("Active & Past Push Campaigns", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 10),
        if (_pushCampaignsList.isEmpty)
          const Text("No push campaigns created yet.", style: TextStyle(color: Colors.white38))
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _pushCampaignsList.length,
            itemBuilder: (ctx, idx) {
              final c = _pushCampaignsList[idx];
              final id = int.tryParse('${c['id']}') ?? 0;
              final title = (c['title'] ?? '').toString();
              final expiry = (c['expiry_at'] ?? '').toString();
              final items = json.decode(c['items'] ?? '[]') as List? ?? [];

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF161A26),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFF1744)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          Text("${items.length} Items • Expires: $expiry", style: const TextStyle(color: Colors.white54, fontSize: 11)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                      onPressed: () => _deletePushCampaign(id),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildAnnouncementSubTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF121622),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF8E2DE2).withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Broadcast Announcement to App Users", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              const Text("Displays an important notification modal to users when opening the app.", style: TextStyle(color: Colors.white60, fontSize: 12)),
              const SizedBox(height: 16),

              TextField(
                controller: _annTitleCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Announcement Title",
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: const Color(0xFF1A1F2C),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _annMessageCtrl,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Message Body",
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: const Color(0xFF1A1F2C),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _annImageUrlCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Optional Image Banner URL",
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: const Color(0xFF1A1F2C),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  const Text("Announcement Expiry: ", style: TextStyle(color: Colors.white70)),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: _annHoursValid,
                    dropdownColor: const Color(0xFF1A1F2C),
                    style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold),
                    items: const [
                      DropdownMenuItem(value: 24, child: Text("24 Hours (1 Day)")),
                      DropdownMenuItem(value: 72, child: Text("72 Hours (3 Days)")),
                      DropdownMenuItem(value: 168, child: Text("7 Days")),
                      DropdownMenuItem(value: 0, child: Text("Never Expire")),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _annHoursValid = val);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _submitAnnouncement,
                  icon: const Icon(Icons.campaign_rounded),
                  label: const Text("📢 SEND ANNOUNCEMENT TO USERS"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8E2DE2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        const Text("Past Announcements", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 10),
        if (_announcementsList.isEmpty)
          const Text("No announcements sent yet.", style: TextStyle(color: Colors.white38))
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _announcementsList.length,
            itemBuilder: (ctx, idx) {
              final a = _announcementsList[idx];
              final id = int.tryParse('${a['id']}') ?? 0;
              final title = (a['title'] ?? '').toString();
              final message = (a['message'] ?? '').toString();

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF161A26),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.campaign_rounded, color: Color(0xFF8E2DE2)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          Text(message, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                      onPressed: () => _deleteAnnouncement(id),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Future<void> _submitPushCampaign() async {
    if (_selectedPushItemKeys.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select at least 1 movie or series!")));
      return;
    }
    final itemsList = _selectedPushItemKeys.map((key) {
      final parts = key.split('_');
      return {'type': parts[0], 'id': int.tryParse(parts[1]) ?? 0};
    }).toList();

    final res = await _adminPhpApi('create_push_campaign', {
      'title': _pushTitleCtrl.text.trim(),
      'items': itemsList,
      'hours_valid': _pushHoursValid,
    });

    if (res['status'] == 'success') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Push Campaign Broadcasted Successfully!"), backgroundColor: Colors.green));
      setState(() => _selectedPushItemKeys.clear());
      _loadPushCampaigns();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${res['message']}"), backgroundColor: Colors.red));
    }
  }

  Future<void> _loadPushCampaigns() async {
    final res = await _adminPhpApi('list_push_campaigns', {});
    if (res['status'] == 'success' && res['data']?['campaigns'] != null) {
      setState(() {
        _pushCampaignsList = res['data']['campaigns'];
      });
    }
  }

  Future<void> _deletePushCampaign(int id) async {
    final res = await _adminPhpApi('delete_push_campaign', {'id': id});
    if (res['status'] == 'success') {
      _loadPushCampaigns();
    }
  }

  Future<void> _submitAnnouncement() async {
    final msg = _annMessageCtrl.text.trim();
    if (msg.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter an announcement message!")));
      return;
    }

    final res = await _adminPhpApi('create_announcement', {
      'title': _annTitleCtrl.text.trim(),
      'message': msg,
      'image_url': _annImageUrlCtrl.text.trim(),
      'hours_valid': _annHoursValid,
    });

    if (res['status'] == 'success') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Announcement Broadcasted Successfully!"), backgroundColor: Colors.green));
      _annMessageCtrl.clear();
      _annImageUrlCtrl.clear();
      _loadAnnouncements();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${res['message']}"), backgroundColor: Colors.red));
    }
  }

  Future<void> _loadAnnouncements() async {
    final res = await _adminPhpApi('list_announcements', {});
    if (res['status'] == 'success' && res['data']?['announcements'] != null) {
      setState(() {
        _announcementsList = res['data']['announcements'];
      });
    }
  }

  Future<void> _deleteAnnouncement(int id) async {
    final res = await _adminPhpApi('delete_announcement', {'id': id});
    if (res['status'] == 'success') {
      _loadAnnouncements();
    }
  }

  Future<void> _loadReports() async {
    setState(() => _reportsLoading = true);
    final res = await _adminPhpApi('list_reports', {});
    if (res['status'] == 'success' && res['data']?['reports'] != null) {
      setState(() {
        _reportsList = res['data']['reports'] as List;
      });
    }
    setState(() => _reportsLoading = false);
  }

  Widget _buildReportsManagerView() {
    if (_reportsLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
    }

    final query = _reportsQuery.trim().toLowerCase();
    final filtered = _reportsList.where((r) {
      final contentName = (r['content_name'] ?? '').toString().toLowerCase();
      final userName = (r['user_name'] ?? '').toString().toLowerCase();
      final userEmail = (r['user_email'] ?? '').toString().toLowerCase();
      final message = (r['message'] ?? '').toString().toLowerCase();
      return contentName.contains(query) || userName.contains(query) || userEmail.contains(query) || message.contains(query);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            onChanged: (v) => setState(() => _reportsQuery = v),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: "Search reports by content, user, or message...",
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
              prefixIcon: const Icon(Icons.search, color: Colors.cyanAccent, size: 18),
              suffixIcon: _reportsQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, color: Colors.white38, size: 18),
                      onPressed: () => setState(() => _reportsQuery = ''))
                  : null,
              filled: true,
              fillColor: const Color(0xFF141722),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${filtered.length} report(s) found",
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? _buildEmptyAnalyticsPlaceholder("No matching reports found.")
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final r = filtered[index];
                    final id = int.tryParse('${r['id']}') ?? 0;
                    final status = int.tryParse('${r['status']}') ?? 0;
                    final contentType = int.tryParse('${r['content_type']}') ?? 1;
                    final contentName = r['content_name'] ?? 'Unknown';
                    final contentPoster = r['content_poster'] ?? '';
                    final userName = r['user_name'] ?? 'User';
                    final userEmail = r['user_email'] ?? 'No Email';
                    final msg = r['message'] ?? '';
                    final adminReplyText = r['admin_reply'] ?? '';
                    final createdAt = r['created_at'] ?? '';

                    final replyController = TextEditingController();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10121A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: contentPoster.isNotEmpty
                                    ? Image.network(contentPoster, width: 32, height: 48, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(width: 32, height: 48, color: Colors.grey.shade900))
                                    : Container(width: 32, height: 48, color: Colors.grey.shade900, child: const Icon(Icons.movie, size: 16)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      contentName,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: contentType == 1 ? Colors.blue.withOpacity(0.12) : Colors.purple.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            contentType == 1 ? "Movie" : "Web Series",
                                            style: TextStyle(color: contentType == 1 ? Colors.blueAccent : Colors.purpleAccent, fontSize: 9, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          createdAt,
                                          style: const TextStyle(color: Colors.white38, fontSize: 10),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      backgroundColor: const Color(0xFF1A2132),
                                      title: const Text("Delete Report"),
                                      content: const Text("Are you sure you want to permanently delete this report?"),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(ctx);
                                            _deleteReport(id);
                                          },
                                          child: const Text("Delete", style: TextStyle(color: Colors.redAccent)),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.person_outline_rounded, color: Colors.cyanAccent, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                "$userName ($userEmail)",
                                style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black12,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              msg,
                              style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12, height: 1.3),
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (status == 0) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 36,
                                    child: TextField(
                                      controller: replyController,
                                      style: const TextStyle(color: Colors.white, fontSize: 12),
                                      decoration: InputDecoration(
                                        hintText: "Reply to send to user...",
                                        hintStyle: const TextStyle(color: Colors.white30, fontSize: 11),
                                        filled: true,
                                        fillColor: Colors.black12,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                TextButton(
                                  onPressed: () => _resolveReport(id, 2, replyController.text.trim()),
                                  style: TextButton.styleFrom(foregroundColor: Colors.redAccent, padding: const EdgeInsets.symmetric(horizontal: 12)),
                                  child: const Text("Reject", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                                TextButton(
                                  onPressed: () => _resolveReport(id, 1, replyController.text.trim()),
                                  style: TextButton.styleFrom(foregroundColor: Colors.greenAccent, padding: const EdgeInsets.symmetric(horizontal: 12)),
                                  child: const Text("Accept", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ] else ...[
                            Row(
                              children: [
                                Icon(
                                  status == 1 ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                  color: status == 1 ? Colors.green : Colors.red,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  status == 1 ? "ACCEPTED" : "REJECTED",
                                  style: TextStyle(color: status == 1 ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                                if (adminReplyText.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "Reply: $adminReplyText",
                                      style: const TextStyle(color: Colors.white54, fontSize: 11, fontStyle: FontStyle.italic),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _deleteReport(int reportId) async {
    setState(() => _isLoading = true);
    final res = await _adminPhpApi('delete_report', {'report_id': reportId});
    if (res['status'] == 'success') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Report deleted successfully"), backgroundColor: Colors.green),
      );
      await _loadReports();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to delete report: ${res['message']}"), backgroundColor: Colors.red),
      );
    }
    setState(() => _isLoading = false);
  }

  Future<void> _resolveReport(int reportId, int status, String adminReply) async {
    setState(() => _isLoading = true);
    final res = await _adminPhpApi('resolve_report', {
      'report_id': reportId,
      'status': status,
      'admin_reply': adminReply,
    });
    if (res['status'] == 'success') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(status == 1 ? "Report accepted and resolved" : "Report rejected and resolved"),
          backgroundColor: Colors.green,
        ),
      );
      await _loadReports();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed: ${res['message'] ?? 'Error resolving report'}"),
          backgroundColor: Colors.red,
        ),
      );
    }
    setState(() => _isLoading = false);
  }

  Future<void> _confirmDeleteUser(Map<String, dynamic> u) async {
    final name = u['name'] ?? 'User';
    final uid = int.tryParse('${u['id']}') ?? 0;
    if (uid <= 0) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2132),
        title: const Text("Delete User"),
        content: Text("Are you sure you want to permanently delete user '$name' and all their associated data (reports, favorites, logs)? This action is irreversible."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              final res = await _adminPhpApi('delete_user', {'user_id': uid});
              if (res['status'] == 'success') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("User deleted successfully"), backgroundColor: Colors.green),
                );
                final uList = await _adminPhpApi('list_users', {});
                if (uList['status'] == 'success' && uList['data']?['users'] != null) {
                  setState(() {
                    _users = uList['data']['users'] as List;
                  });
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Failed to delete user: ${res['message']}"), backgroundColor: Colors.red),
                );
              }
              setState(() => _isLoading = false);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _GrantVipDialog extends StatefulWidget {
  final Map<String, dynamic> user;
  final Future<Map<String, dynamic>> Function(
      String action, Map<String, dynamic> body) apiCall;
  final VoidCallback onGranted;

  const _GrantVipDialog({
    Key? key,
    required this.user,
    required this.apiCall,
    required this.onGranted,
  }) : super(key: key);

  @override
  State<_GrantVipDialog> createState() => _GrantVipDialogState();
}

class _GrantVipDialogState extends State<_GrantVipDialog> {
  List<dynamic> _plans = [];
  bool _loading = true;
  String? _error;
  bool _granting = false;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await widget.apiCall('list_subscription_plans', {});
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res['status'] == 'success' && res['data']?['plans'] != null) {
        _plans = res['data']['plans'];
      } else {
        _error = res['message'] ?? 'Failed to load plans';
      }
    });
  }

  Future<void> _grant(dynamic plan) async {
    if (_granting) return;
    setState(() => _granting = true);
    final res = await widget
        .apiCall('grant_vip', {'user_id': widget.user['id'], 'plan_id': plan['id']});
    if (!mounted) return;
    setState(() => _granting = false);
    if (res['status'] == 'success') {
      Navigator.pop(context);
      widget.onGranted();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed: ${res['message'] ?? 'Unknown error'}"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A2132),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: Colors.white.withOpacity(0.08))),
      title: Text("Grant VIP — ${widget.user['name'] ?? 'User'}",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      content: _loading
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(color: Color(0xFF8E2DE2))))
          : _error != null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.redAccent)),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _loadPlans,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text("Retry"),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8E2DE2)),
                    ),
                  ],
                )
              : _plans.isEmpty
                  ? const Text(
                      "No subscription plans available.\nAdd plans on the server.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70))
                  : SizedBox(
                      width: double.maxFinite,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: _plans.map((p) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: _granting ? null : () => _grant(p),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                      colors: [
                                        const Color(0xFF8E2DE2).withOpacity(0.25),
                                        const Color(0xFFE50914).withOpacity(0.15)
                                      ]),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: Colors.purpleAccent.withOpacity(0.35)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.workspace_premium,
                                        color: Colors.amber, size: 26),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(p['name'] ?? 'VIP',
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15)),
                                          Text("${p['time']} Days • ₹${p['amount']}",
                                              style: const TextStyle(
                                                  color: Colors.white60,
                                                  fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.arrow_forward_ios_rounded,
                                        color: Colors.white24, size: 14),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
      actions: [
        TextButton(
          onPressed: _granting ? null : () => Navigator.pop(context),
          child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
        ),
      ],
    );
  }

}

class _CreateCouponDialog extends StatefulWidget {
  final Future<Map<String, dynamic>> Function(
      String action, Map<String, dynamic> body) apiCall;
  final VoidCallback onCreated;

  const _CreateCouponDialog({
    Key? key,
    required this.apiCall,
    required this.onCreated,
  }) : super(key: key);

  @override
  State<_CreateCouponDialog> createState() => _CreateCouponDialogState();
}

class _CreateCouponDialogState extends State<_CreateCouponDialog> {
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _maxUseCtrl = TextEditingController(text: '1');
  List<dynamic> _plans = [];
  bool _loading = true;
  String? _error;
  dynamic _selectedPlan;
  DateTime? _expiry;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _maxUseCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPlans() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await widget.apiCall('list_subscription_plans', {});
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res['status'] == 'success' && res['data']?['plans'] != null) {
        _plans = res['data']['plans'];
        if (_plans.isNotEmpty) _selectedPlan = _plans.first;
      } else {
        _error = res['message'] ?? 'Failed to load plans';
      }
    });
  }

  String _randomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random();
    return 'RED' +
        List.generate(8, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiry ?? now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 3650)),
      builder: (ctx, child) => Theme(data: ThemeData.dark(), child: child!),
    );
    if (picked != null) setState(() => _expiry = picked);
  }

  Future<void> _save() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Coupon code is required")),
      );
      return;
    }
    final maxUse = int.tryParse(_maxUseCtrl.text.trim()) ?? 1;
    setState(() => _saving = true);
    final res = await widget.apiCall('create_coupon', {
      'name': _nameCtrl.text.trim(),
      'coupon_code': code,
      'plan_id': _selectedPlan?['id'] ?? 0,
      'max_use': maxUse,
      'expire_date': _expiry != null
          ? '${_expiry!.year}-${_expiry!.month.toString().padLeft(2, '0')}-${_expiry!.day.toString().padLeft(2, '0')}'
          : '',
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (res['status'] == 'success') {
      Navigator.pop(context);
      widget.onCreated();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed: ${res['message'] ?? 'Unknown error'}"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A2132),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: Colors.white.withOpacity(0.08))),
      title: const Text("Generate Coupon",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: _loading
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF8E2DE2))))
            : _error != null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.redAccent)),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _loadPlans,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text("Retry"),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8E2DE2)),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _nameCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: "Coupon Template Name",
                          labelStyle: const TextStyle(color: Colors.white70),
                          hintText: "e.g. NEWYEAR VIP",
                          hintStyle: const TextStyle(color: Colors.grey),
                          filled: true,
                          fillColor: const Color(0xFF090A0F),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _codeCtrl,
                              style: const TextStyle(
                                  color: Colors.white, letterSpacing: 1),
                              decoration: InputDecoration(
                                labelText: "Coupon Code",
                                labelStyle:
                                    const TextStyle(color: Colors.white70),
                                hintText: "RED12345678",
                                hintStyle: const TextStyle(color: Colors.grey),
                                filled: true,
                                fillColor: const Color(0xFF090A0F),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () =>
                                setState(() => _codeCtrl.text = _randomCode()),
                            icon: const Icon(Icons.casino_rounded, size: 16),
                            label: const Text("RANDOM"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8E2DE2),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              textStyle: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<dynamic>(
                        value: _selectedPlan,
                        dropdownColor: const Color(0xFF141722),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: "Subscription Plan",
                          labelStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: const Color(0xFF090A0F),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        items: _plans.map((p) {
                          return DropdownMenuItem<dynamic>(
                            value: p,
                            child: Text(
                              "${p['name']} • ${p['time']} Days • ₹${p['amount']}",
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 13),
                            ),
                          );
                        }).toList(),
                        onChanged: (v) =>
                            setState(() => _selectedPlan = v),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _maxUseCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: "Max Number of Uses",
                          labelStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: const Color(0xFF090A0F),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      InkWell(
                        onTap: _pickExpiry,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                              color: const Color(0xFF090A0F),
                              borderRadius: BorderRadius.circular(10)),
                          child: Row(
                            children: [
                              const Icon(Icons.event,
                                  color: Colors.cyanAccent, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                _expiry != null
                                    ? 'Expires: ${_expiry!.year}-${_expiry!.month.toString().padLeft(2, '0')}-${_expiry!.day.toString().padLeft(2, '0')}'
                                    : 'Expiry Date (tap to pick — optional)',
                                style: TextStyle(
                                    color: _expiry != null
                                        ? Colors.white
                                        : Colors.white38,
                                    fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
        ),
        TextButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      color: Color(0xFF8E2DE2), strokeWidth: 2))
              : const Text("CREATE COUPON",
                  style: TextStyle(
                      color: Colors.cyanAccent,
                      fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

}

class _MovieRepairDialog extends StatefulWidget {
  final Map<String, dynamic> item;
  final Future<Map<String, dynamic>> Function(
      String action, Map<String, dynamic> body) apiCall;
  final VoidCallback onDone;
  final Function(Function(String, {String? posterUrl}), {String defaultSearchText}) showExtractor;
  final Function(Map<String, dynamic>, String) onEdit;

  const _MovieRepairDialog({
    Key? key,
    required this.item,
    required this.apiCall,
    required this.onDone,
    required this.showExtractor,
    required this.onEdit,
  }) : super(key: key);

  @override
  State<_MovieRepairDialog> createState() => _MovieRepairDialogState();
}

class _MovieRepairDialogState extends State<_MovieRepairDialog> {
  final _newUrlCtrl = TextEditingController();
  bool _checking = false;
  String? _checkResult;
  bool _checkOk = false;
  bool _busy = false;

  Future<void> _openInBrowser(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme) return;
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not open browser")),
      );
    }
  }

  @override
  void dispose() {
    _newUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final url = _newUrlCtrl.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a new link first")),
      );
      return;
    }
    setState(() {
      _checking = true;
      _checkResult = null;
    });
    final res = await widget.apiCall('check_link', {'url': url});
    if (!mounted) return;
    final ok = res['status'] == 'success' && (res['data']?['ok'] == true);
    setState(() {
      _checking = false;
      _checkOk = ok;
      _checkResult = ok
          ? 'LIVE — HTTP ${res['data']?['code'] ?? '?'}'
          : 'FAILED — ${res['data']?['code'] ?? '?'} ${res['message'] ?? ''}';
    });
  }

  Future<void> _update() async {
    final url = _newUrlCtrl.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a new link first")),
      );
      return;
    }
    setState(() => _busy = true);
    final res = await widget.apiCall(
        'restore_content', {'type': 'movie', 'id': widget.item['id'], 'new_url': url});
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = false);
    navigator.pop();
    widget.onDone();
    messenger.showSnackBar(
      SnackBar(
        content: Text(res['status'] == 'success'
            ? "Movie link updated & restored"
            : "Failed: ${res['message'] ?? 'Unknown error'}"),
        backgroundColor: res['status'] == 'success' ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2132),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: Colors.white.withOpacity(0.08))),
        title: const Text("Delete Movie?", style: TextStyle(color: Colors.white)),
        content: Text("Permanently delete '${widget.item['name'] ?? ''}' and all its links?", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (ok == true) {
      setState(() => _busy = true);
      final res = await widget.apiCall('delete_content', {'type': 'movie', 'id': widget.item['id']});
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      navigator.pop();
      widget.onDone();
      messenger.showSnackBar(
        SnackBar(
          content: Text(res['status'] == 'success' ? "Movie deleted" : "Failed: ${res['message'] ?? 'Unknown error'}"),
          backgroundColor: res['status'] == 'success' ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final links = widget.item['dead_links'] as List? ?? [];
    return Dialog(
      backgroundColor: const Color(0xFF0F131D),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Card ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: (widget.item['poster'] ?? '').toString().isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: widget.item['poster'].toString(),
                            width: 50,
                            height: 68,
                            fit: BoxFit.cover,
                            errorWidget: (c, u, e) => Container(
                              width: 50,
                              height: 68,
                              color: const Color(0xFF1E2436),
                              child: const Icon(Icons.movie, color: Colors.white38),
                            ),
                          )
                        : Container(
                            width: 50,
                            height: 68,
                            color: const Color(0xFF1E2436),
                            child: const Icon(Icons.movie, color: Colors.white38),
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.link_off_rounded, color: Colors.redAccent, size: 12),
                              SizedBox(width: 4),
                              Text("DEAD LINK REPAIR", style: TextStyle(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.item['name'] ?? 'Movie',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.05),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Old Broken Links Section ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B28),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: links.isNotEmpty ? Colors.redAccent.withOpacity(0.25) : Colors.white.withOpacity(0.06)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(links.isNotEmpty ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                            color: links.isNotEmpty ? Colors.redAccent : Colors.greenAccent, size: 15),
                        const SizedBox(width: 6),
                        Text(
                          links.isNotEmpty ? "REPORTED BROKEN LINK" : "LINK STATUS",
                          style: TextStyle(
                            color: links.isNotEmpty ? Colors.redAccent : Colors.greenAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (links.isEmpty)
                      const Text("No broken link log recorded for this title.", style: TextStyle(color: Colors.white38, fontSize: 12))
                    else
                      ...links.map((l) => Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    "${l['url']}",
                                    style: const TextStyle(color: Color(0xFFFF8080), fontSize: 11, fontFamily: 'monospace'),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: () => _openInBrowser(l['url']?.toString() ?? ''),
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: Colors.cyanAccent.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(Icons.open_in_new_rounded, color: Colors.cyanAccent, size: 14),
                                  ),
                                ),
                              ],
                            ),
                          )),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── New Stream Link Input ──
              const Text("NEW PLAYABLE STREAM LINK", style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF141722),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: TextField(
                        controller: _newUrlCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        decoration: const InputDecoration(
                          hintText: "Paste Streamtape / MP4 / Luluvdo link...",
                          hintStyle: TextStyle(color: Colors.white30, fontSize: 11),
                          prefixIcon: Icon(Icons.link_rounded, color: Colors.cyanAccent, size: 18),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => widget.showExtractor((extractedUrl, {posterUrl}) {
                      setState(() => _newUrlCtrl.text = extractedUrl);
                    }, defaultSearchText: widget.item['name'] ?? ''),
                    icon: const Icon(Icons.bolt_rounded, size: 16),
                    label: const Text("EXTRACT", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amberAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ],
              ),

              // ── Live Check Feedback Banner ──
              if (_checkResult != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: (_checkOk ? Colors.green : Colors.red).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: (_checkOk ? Colors.greenAccent : Colors.redAccent).withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      Icon(_checkOk ? Icons.check_circle_rounded : Icons.cancel_rounded,
                          color: _checkOk ? Colors.greenAccent : Colors.redAccent, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _checkResult!,
                          style: TextStyle(color: _checkOk ? Colors.greenAccent : Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // ── Action Buttons Matrix ──
              // Primary Row: Check & Update
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy || _checking ? null : _check,
                      icon: _checking
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyanAccent))
                          : const Icon(Icons.troubleshoot_rounded, size: 16),
                      label: const Text("VERIFY LINK", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.cyanAccent,
                        side: const BorderSide(color: Colors.cyanAccent),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _busy ? null : _update,
                      icon: _busy
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                          : const Icon(Icons.check_circle_rounded, size: 16),
                      label: const Text("RESTORE LINK", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Secondary Row: Full Edit & Delete
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: _busy ? null : () {
                        Navigator.pop(context);
                        widget.onEdit(widget.item, 'movie');
                      },
                      icon: const Icon(Icons.edit_rounded, size: 15, color: Colors.orangeAccent),
                      label: const Text("Edit Full Details", style: TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.w600)),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.orangeAccent.withOpacity(0.08),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: _busy ? null : _delete,
                      icon: const Icon(Icons.delete_outline_rounded, size: 15, color: Colors.redAccent),
                      label: const Text("Delete Movie", style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600)),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.redAccent.withOpacity(0.08),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeriesRepairDialog extends StatefulWidget {
  final Map<String, dynamic> item;
  final Future<Map<String, dynamic>> Function(
      String action, Map<String, dynamic> body) apiCall;
  final VoidCallback onDone;
  final Function(Function(String, {String? posterUrl}), {String defaultSearchText}) showExtractor;
  final Function(Map<String, dynamic>, String) onEdit;

  const _SeriesRepairDialog({
    Key? key,
    required this.item,
    required this.apiCall,
    required this.onDone,
    required this.showExtractor,
    required this.onEdit,
  }) : super(key: key);

  @override
  State<_SeriesRepairDialog> createState() => _SeriesRepairDialogState();
}

class _SeriesRepairDialogState extends State<_SeriesRepairDialog> {
  dynamic _selectedEpisode;
  final _newUrlCtrl = TextEditingController();
  final _newImageCtrl = TextEditingController();
  bool _checking = false;
  String? _checkResult;
  bool _checkOk = false;
  bool _busy = false;

  Future<void> _openInBrowser(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme) return;
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not open browser")),
      );
    }
  }

  @override
  void dispose() {
    _newUrlCtrl.dispose();
    _newImageCtrl.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final url = _newUrlCtrl.text.trim();
    if (url.isEmpty) return;
    setState(() {
      _checking = true;
      _checkResult = null;
    });
    final res = await widget.apiCall('check_link', {'url': url});
    if (!mounted) return;
    final ok = res['status'] == 'success' && (res['data']?['ok'] == true);
    setState(() {
      _checking = false;
      _checkOk = ok;
      _checkResult = ok
          ? 'LIVE — HTTP ${res['data']?['code'] ?? '?'}'
          : 'FAILED — ${res['data']?['code'] ?? '?'} ${res['message'] ?? ''}';
    });
  }

  Future<void> _updateEpisode() async {
    final url = _newUrlCtrl.text.trim();
    final imgUrl = _newImageCtrl.text.trim();
    if (_selectedEpisode == null) return;
    setState(() => _busy = true);
    final res = await widget.apiCall('restore_content', {
      'type': 'series',
      'id': widget.item['id'],
      'episode_id': _selectedEpisode['episode_id'],
      'new_url': url,
      'episoade_image': imgUrl,
    });
    if (!mounted) return;
    setState(() => _busy = false);
    final eps = (widget.item['dead_episodes'] as List? ?? []);
    eps.removeWhere((e) => e['episode_id'] == _selectedEpisode['episode_id']);
    setState(() => _selectedEpisode = null);
    _newUrlCtrl.clear();
    _newImageCtrl.clear();
    _checkResult = null;
    widget.onDone();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res['status'] == 'success' ? "Episode updated & saved" : "Failed: ${res['message'] ?? 'Unknown error'}"),
        backgroundColor: res['status'] == 'success' ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _deleteEpisode() async {
    final ep = _selectedEpisode;
    if (ep == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2132),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: Colors.white.withOpacity(0.08))),
        title: const Text("Delete Episode?", style: TextStyle(color: Colors.white)),
        content: Text("Permanently delete '${ep['episode_name'] ?? ''}'?", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (ok == true) {
      setState(() => _busy = true);
      final res = await widget.apiCall('delete_content', {'type': 'episode', 'id': ep['episode_id']});
      if (!mounted) return;
      setState(() => _busy = false);
      final eps = (widget.item['dead_episodes'] as List? ?? []);
      eps.removeWhere((e) => e['episode_id'] == ep['episode_id']);
      setState(() => _selectedEpisode = null);
      _newUrlCtrl.clear();
      widget.onDone();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['status'] == 'success' ? "Episode deleted" : "Failed: ${res['message'] ?? 'Unknown error'}"),
          backgroundColor: res['status'] == 'success' ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteSeries() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2132),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: Colors.white.withOpacity(0.08))),
        title: const Text("Delete Whole Series?", style: TextStyle(color: Colors.white)),
        content: Text("Permanently delete '${widget.item['name'] ?? ''}' with all seasons, episodes and links?", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (ok == true) {
      setState(() => _busy = true);
      final res = await widget.apiCall('delete_content', {'type': 'series', 'id': widget.item['id']});
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      navigator.pop();
      widget.onDone();
      messenger.showSnackBar(
        SnackBar(
          content: Text(res['status'] == 'success' ? "Series deleted" : "Failed: ${res['message'] ?? 'Unknown error'}"),
          backgroundColor: res['status'] == 'success' ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final deadEpisodes = widget.item['dead_episodes'] as List? ?? [];
    return Dialog(
      backgroundColor: const Color(0xFF0F131D),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Card ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: (widget.item['poster'] ?? '').toString().isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: widget.item['poster'].toString(),
                            width: 50,
                            height: 68,
                            fit: BoxFit.cover,
                            errorWidget: (c, u, e) => Container(
                              width: 50,
                              height: 68,
                              color: const Color(0xFF1E2436),
                              child: const Icon(Icons.tv, color: Colors.white38),
                            ),
                          )
                        : Container(
                            width: 50,
                            height: 68,
                            color: const Color(0xFF1E2436),
                            child: const Icon(Icons.tv, color: Colors.white38),
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.purpleAccent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.purpleAccent.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.tv_rounded, color: Colors.purpleAccent, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                "${deadEpisodes.length} BROKEN EPISODE(S)",
                                style: const TextStyle(color: Colors.purpleAccent, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.item['name'] ?? 'Web Series',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.05),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_selectedEpisode == null) ...[
                // ── Level 1: Episodes Selection List ──
                const Text("SELECT EPISODE TO REPAIR", style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                const SizedBox(height: 8),
                if (deadEpisodes.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161B28),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: Text("All episodes are healthy. No broken links detected!", style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
                    ),
                  )
                else
                  ...deadEpisodes.map((ep) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141724),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.purpleAccent.withOpacity(0.2)),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          onTap: () => setState(() {
                            _selectedEpisode = ep;
                            _checkResult = null;
                            _newUrlCtrl.clear();
                            _newImageCtrl.text = (ep['episoade_image'] ?? ep['image'] ?? '').toString();
                          }),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: (ep['episoade_image'] ?? '').toString().isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: ep['episoade_image'].toString(),
                                    width: 44,
                                    height: 44,
                                    fit: BoxFit.cover,
                                    errorWidget: (c, u, e) => Container(width: 44, height: 44, color: const Color(0xFF2A3145), child: const Icon(Icons.tv, color: Colors.white24, size: 20)),
                                  )
                                : Container(width: 44, height: 44, color: const Color(0xFF2A3145), child: const Icon(Icons.tv, color: Colors.white24, size: 20)),
                          ),
                          title: Text(
                            "${ep['season_name'] ?? 'Season'} • ${ep['episode_name'] ?? 'Episode'}",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          subtitle: Text(
                            ep['old_url'] ?? '',
                            style: const TextStyle(color: Color(0xFFFF8080), fontSize: 10, fontFamily: 'monospace'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.purpleAccent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text("Fix", style: TextStyle(color: Colors.purpleAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                                SizedBox(width: 2),
                                Icon(Icons.chevron_right_rounded, color: Colors.purpleAccent, size: 16),
                              ],
                            ),
                          ),
                        ),
                      )),
                const SizedBox(height: 16),

                // Series Actions Row
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: _busy ? null : () {
                          Navigator.pop(context);
                          widget.onEdit(widget.item, 'series');
                        },
                        icon: const Icon(Icons.edit_rounded, size: 15, color: Colors.orangeAccent),
                        label: const Text("Edit Series Studio", style: TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.w600)),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.orangeAccent.withOpacity(0.08),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: _busy ? null : _deleteSeries,
                        icon: const Icon(Icons.delete_outline_rounded, size: 15, color: Colors.redAccent),
                        label: const Text("Delete Series", style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600)),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.redAccent.withOpacity(0.08),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // ── Level 2: Individual Episode Repair ──
                Row(
                  children: [
                    IconButton(
                      onPressed: _busy ? null : () => setState(() {
                        _selectedEpisode = null;
                        _checkResult = null;
                        _newUrlCtrl.clear();
                        _newImageCtrl.clear();
                      }),
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70, size: 18),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.05),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "${_selectedEpisode['season_name'] ?? 'Season'} • ${_selectedEpisode['episode_name'] ?? 'Episode'}",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Broken Link Box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 14),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedEpisode['old_url'] ?? '',
                          style: const TextStyle(color: Color(0xFFFF8080), fontSize: 11, fontFamily: 'monospace'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      InkWell(
                        onTap: () => _openInBrowser(_selectedEpisode['old_url']?.toString() ?? ''),
                        child: const Padding(
                          padding: EdgeInsets.all(4.0),
                          child: Icon(Icons.open_in_new_rounded, color: Colors.cyanAccent, size: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Episode Image Input
                const Text("EPISODE POSTER / THUMBNAIL", style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF141722),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: TextField(
                    controller: _newImageCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: "https://.../episode_thumb.jpg",
                      hintStyle: TextStyle(color: Colors.white30, fontSize: 11),
                      prefixIcon: Icon(Icons.image_outlined, color: Colors.purpleAccent, size: 18),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                ),
                if (_newImageCtrl.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: CachedNetworkImage(
                        imageUrl: _newImageCtrl.text.trim(),
                        fit: BoxFit.cover,
                        errorWidget: (c, u, e) => Container(
                          color: const Color(0xFF141722),
                          child: const Center(child: Icon(Icons.broken_image_rounded, color: Colors.white24, size: 24)),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),

                // Stream Link Input
                const Text("NEW STREAM LINK", style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF141722),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: TextField(
                          controller: _newUrlCtrl,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          decoration: const InputDecoration(
                            hintText: "Paste Streamtape / MP4 link...",
                            hintStyle: TextStyle(color: Colors.white30, fontSize: 11),
                            prefixIcon: Icon(Icons.link_rounded, color: Colors.cyanAccent, size: 18),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => widget.showExtractor((extractedUrl, {posterUrl}) {
                        setState(() {
                          _newUrlCtrl.text = extractedUrl;
                          if (posterUrl != null && posterUrl.isNotEmpty) {
                            _newImageCtrl.text = posterUrl;
                          }
                        });
                      }, defaultSearchText: widget.item['name'] ?? ''),
                      icon: const Icon(Icons.bolt_rounded, size: 16),
                      label: const Text("EXTRACT", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amberAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),

                if (_checkResult != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: (_checkOk ? Colors.green : Colors.red).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: (_checkOk ? Colors.greenAccent : Colors.redAccent).withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        Icon(_checkOk ? Icons.check_circle_rounded : Icons.cancel_rounded,
                            color: _checkOk ? Colors.greenAccent : Colors.redAccent, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _checkResult!,
                            style: TextStyle(color: _checkOk ? Colors.greenAccent : Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),

                // Episode Action Matrix
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy || _checking ? null : _check,
                        icon: _checking
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyanAccent))
                            : const Icon(Icons.troubleshoot_rounded, size: 16),
                        label: const Text("VERIFY", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.cyanAccent,
                          side: const BorderSide(color: Colors.cyanAccent),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _busy ? null : _updateEpisode,
                        icon: _busy
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                            : const Icon(Icons.check_circle_rounded, size: 16),
                        label: const Text("SAVE EPISODE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.greenAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: _busy ? null : _deleteEpisode,
                    icon: const Icon(Icons.delete_outline_rounded, size: 15, color: Colors.redAccent),
                    label: const Text("Delete This Episode", style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600)),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.redAccent.withOpacity(0.08),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Google Images WebView Widget
// ─────────────────────────────────────────────────────────────────────────────

class _GoogleImagesWebView extends StatefulWidget {
  final String query;
  final void Function(String imageUrl) onImageSelected;
  // Pass the admin API URL so the widget can upload images server-side
  final String adminApiUrl;
  final String adminApiKey;
  // OTT name hint to build better search queries (e.g. 'HotStar', 'Prime')
  final String ottHint;

  const _GoogleImagesWebView({
    Key? key,
    required this.query,
    required this.onImageSelected,
    this.adminApiUrl = '',
    this.adminApiKey = '',
    this.ottHint = '',
  }) : super(key: key);

  @override
  State<_GoogleImagesWebView> createState() => _GoogleImagesWebViewState();
}

class _GoogleImagesWebViewState extends State<_GoogleImagesWebView> {
  InAppWebViewController? _wvc;
  bool _loading = true;
  String _currentQuery = '';

  // JS that allows normal thumbnail clicks (opening Google's big preview & related images)
  // and only intercepts clicks on the enlarged detail image.
  static const String _interceptJs = r'''
    (function() {
      if (window.__pinInterceptDone) return;
      window.__pinInterceptDone = true;

      function extractFullResUrl(el) {
        var candidates = [];
        var img = el.tagName === 'IMG' ? el : el.querySelector('img');

        // Check if there is an anchor href with imgurl param anywhere in the container
        var container = el.closest('[jscontroller], [role="dialog"], div[data-ved], .tvh9oe, .eA0Zlc') || el.parentElement;
        if (container) {
          var fullLinks = container.querySelectorAll('a[href*="imgurl="]');
          for (var i = 0; i < fullLinks.length; i++) {
            var h = fullLinks[i].getAttribute('href') || '';
            var m = h.match(/imgurl=([^&]+)/);
            if (m) {
              var dec = decodeURIComponent(m[1]);
              if (dec.startsWith('http') && !dec.includes('encrypted-tbn')) candidates.unshift(dec);
            }
          }
        }

        var a = el.closest('a');
        if (a) {
          var href = a.getAttribute('href') || '';
          var m2 = href.match(/imgurl=([^&]+)/);
          if (m2) {
            var dec2 = decodeURIComponent(m2[1]);
            if (dec2.startsWith('http') && !dec2.includes('encrypted-tbn')) candidates.unshift(dec2);
          }
        }

        if (img) {
          ['src', 'data-src', 'data-iurl', 'data-url'].forEach(function(attr) {
            var v = img.getAttribute(attr);
            if (v && v.startsWith('http') && !v.includes('encrypted-tbn') && !v.includes('data:')) {
              candidates.push(v);
            }
          });
          if (img.currentSrc && img.currentSrc.startsWith('http') && !img.currentSrc.includes('encrypted-tbn')) {
            candidates.push(img.currentSrc);
          }
          if (img.src && img.src.startsWith('http')) {
            candidates.push(img.src);
          }
        }

        return candidates.find(function(u) { return u && u.startsWith('http'); }) || null;
      }

      function isBigEnlargedImage(el) {
        var img = el.tagName === 'IMG' ? el : el.querySelector('img');
        if (!img) return false;
        var r = img.getBoundingClientRect();
        // Check if rendered dimensions match enlarged detail image (> 180px height or width)
        if (r.height >= 180 || r.width >= 190) {
          return true;
        }
        // Check if inside Google Images detail viewer dialog/overlay
        var detailView = img.closest('[role="dialog"], .tvh9oe, .eA0Zlc, div.isv-r.isv-selected');
        if (detailView != null && (r.height >= 140 || r.width >= 140)) {
          return true;
        }
        return false;
      }

      document.addEventListener('click', function(e) {
        var target = e.target;
        var img = target.tagName === 'IMG' ? target : target.querySelector('img');

        // Only intercept if user clicked on the big enlarged preview image!
        if (img && isBigEnlargedImage(img)) {
          var url = extractFullResUrl(img);
          if (url) {
            e.preventDefault();
            e.stopPropagation();
            window.flutter_inappwebview.callHandler('onImageTap', url);
            return false;
          }
        }
        // Otherwise allow normal Google Images grid interaction to open the big preview
      }, true);

      window.__getCurrentlyActiveBigImage = function() {
        var imgs = document.querySelectorAll('img');
        var best = null;
        var maxArea = 0;
        for (var i = 0; i < imgs.length; i++) {
          var r = imgs[i].getBoundingClientRect();
          var area = r.width * r.height;
          if ((r.height >= 160 || r.width >= 170) && area > maxArea) {
            maxArea = area;
            best = imgs[i];
          }
        }
        if (best) return extractFullResUrl(best);
        return null;
      };
    })();
  ''';

  String _buildGoogleUrl(String query) {
    final cleanQuery = query.trim();
    final ott = widget.ottHint.trim();
    
    // Construct query: "(Name) + (OTT) + Webseries Poster Portrait"
    final List<String> parts = [];
    if (cleanQuery.isNotEmpty) parts.add(cleanQuery);
    if (ott.isNotEmpty && !cleanQuery.toLowerCase().contains(ott.toLowerCase())) {
      parts.add(ott);
    }
    parts.add('Webseries Poster Portrait');

    final fullQuery = parts.join(' ');
    final q = Uri.encodeQueryComponent(fullQuery);
    return 'https://www.google.com/search?q=$q&tbm=isch&hl=en&safe=off';
  }

  void _showPreview(BuildContext ctx, String url) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: const Color(0xFF0D1117),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: Colors.white12),
      ),
      builder: (sheetCtx) {
        // Track image load state inside the bottom sheet
        bool imageLoaded = false;
        bool imageError = false;
        bool uploading = false;

        return StatefulBuilder(
          builder: (ssCtx, ssSetState) {
            // Upload image to our server then call onImageSelected with hosted URL
            Future<void> _uploadAndSelect() async {
              ssSetState(() => uploading = true);
              try {
                final apiUrl = widget.adminApiUrl.isNotEmpty
                    ? widget.adminApiUrl
                    : 'https://red.goprivate.fun/api/admin_api.php';
                final apiKey = widget.adminApiKey.isNotEmpty
                    ? widget.adminApiKey
                    : 'ku9qFY6XKp5OC1bG';
                final res = await http.post(
                  Uri.parse(apiUrl),
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode({
                    'action': 'upload_image',
                    'api_key': apiKey,
                    'image_url': url,
                  }),
                ).timeout(const Duration(seconds: 40));
                final data = jsonDecode(res.body);
                final hostedUrl = (data['data']?['url'] ?? '').toString();
                if (ssCtx.mounted) Navigator.pop(sheetCtx);
                widget.onImageSelected(hostedUrl.isNotEmpty ? hostedUrl : url);
              } catch (_) {
                // On any upload failure fall back to original URL
                if (ssCtx.mounted) Navigator.pop(sheetCtx);
                widget.onImageSelected(url);
              }
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                  ),
                  const Row(
                    children: [
                      Icon(Icons.image_search_rounded, color: Colors.cyanAccent, size: 18),
                      SizedBox(width: 8),
                      Text('Image Preview & Import', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Image loads at full quality before the button becomes active
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      url,
                      width: double.infinity,
                      height: 250,
                      fit: BoxFit.contain,
                      loadingBuilder: (c, child, loadingProgress) {
                        if (loadingProgress == null) {
                          // Fully loaded — schedule a setState
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!imageLoaded && ssCtx.mounted) ssSetState(() => imageLoaded = true);
                          });
                          return child;
                        }
                        final total = loadingProgress.expectedTotalBytes;
                        final pct = total != null
                            ? loadingProgress.cumulativeBytesLoaded / total
                            : null;
                        return Container(
                          height: 250,
                          color: const Color(0xFF161B22),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(
                                  value: pct,
                                  color: Colors.cyanAccent,
                                  strokeWidth: 2,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  pct != null
                                      ? 'Loading ${(pct * 100).toStringAsFixed(0)}%'
                                      : 'Loading full quality…',
                                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      errorBuilder: (c, e, s) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!imageError && ssCtx.mounted) ssSetState(() { imageError = true; imageLoaded = true; });
                        });
                        return Container(
                          height: 250,
                          color: const Color(0xFF161B22),
                          child: const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.broken_image_rounded, color: Colors.white24, size: 44),
                                SizedBox(height: 8),
                                Text('Image failed to load', style: TextStyle(color: Colors.white38, fontSize: 12)),
                                SizedBox(height: 4),
                                Text('(Will still try to import the URL)', style: TextStyle(color: Colors.white24, fontSize: 11)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      url,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'monospace'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: uploading ? null : () => Navigator.pop(sheetCtx),
                          icon: const Icon(Icons.close_rounded, size: 16, color: Colors.white54),
                          label: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          // Only enabled once image is fully loaded
                          onPressed: (!imageLoaded || uploading)
                              ? null
                              : _uploadAndSelect,
                          icon: uploading
                              ? const SizedBox(
                                  width: 16, height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                )
                              : const Icon(Icons.check_circle_rounded, size: 16),
                          label: Text(
                            uploading
                                ? 'Uploading…'
                                : !imageLoaded
                                    ? 'Loading image…'
                                    : 'Use as Poster',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.cyanAccent,
                            foregroundColor: Colors.black,
                            disabledBackgroundColor: Colors.cyanAccent.withOpacity(0.3),
                            disabledForegroundColor: Colors.black45,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void didUpdateWidget(_GoogleImagesWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query && _wvc != null) {
      _wvc!.loadUrl(urlRequest: URLRequest(url: WebUri(_buildGoogleUrl(widget.query))));
      if (mounted) setState(() => _loading = true);
      _currentQuery = widget.query;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.query.trim().isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_search_rounded, color: Colors.white24, size: 52),
            SizedBox(height: 14),
            Text('Enter a title above and tap Search\nto browse Google Images',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 13, height: 1.5)),
          ],
        ),
      );
    }

    return Stack(
      children: [
        Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              color: const Color(0xFF141722),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Colors.cyanAccent, size: 14),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Tap any image to view enlarged with related images. Tap the big image (or button below) to import.',
                      style: TextStyle(color: Colors.white70, fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: InAppWebView(
                  initialUrlRequest: URLRequest(url: WebUri(_buildGoogleUrl(widget.query))),
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    userAgent: 'Mozilla/5.0 (Linux; Android 12; Pixel 6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.6367.82 Mobile Safari/537.36',
                    transparentBackground: false,
                    supportZoom: true,
                    builtInZoomControls: false,
                    displayZoomControls: false,
                    useOnLoadResource: false,
                  ),
                  onWebViewCreated: (controller) {
                    _wvc = controller;
                    controller.addJavaScriptHandler(
                      handlerName: 'onImageTap',
                      callback: (args) {
                        final url = args.isNotEmpty ? args[0].toString() : '';
                        if (url.isNotEmpty && mounted) {
                          _showPreview(context, url);
                        }
                      },
                    );
                  },
                  onLoadStart: (controller, url) {
                    if (mounted) setState(() => _loading = true);
                  },
                  onLoadStop: (controller, url) async {
                    await controller.evaluateJavascript(source: _interceptJs);
                    if (mounted) setState(() => _loading = false);
                  },
                  onReceivedError: (controller, request, error) {
                    if (mounted) setState(() => _loading = false);
                  },
                ),
              ),
            ),
          ],
        ),
        Positioned(
          bottom: 10,
          right: 10,
          child: ElevatedButton.icon(
            onPressed: () async {
              if (_wvc != null) {
                final res = await _wvc!.evaluateJavascript(source: "window.__getCurrentlyActiveBigImage ? window.__getCurrentlyActiveBigImage() : null;");
                if (res != null && res.toString().isNotEmpty && res.toString() != 'null') {
                  _showPreview(context, res.toString());
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Tap an image in Google to open it first, then tap this button or tap the big preview!"),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.bolt_rounded, color: Colors.black, size: 16),
            label: const Text("USE VIEWED POSTER", style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amberAccent,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 4,
            ),
          ),
        ),
        if (_loading)
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0D1117),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.cyanAccent, strokeWidth: 2),
                  SizedBox(height: 14),
                  Text('Loading Google Images…',
                      style: TextStyle(color: Colors.white54, fontSize: 13)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
