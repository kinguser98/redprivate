import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart' hide CarouselController;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/movie_model.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/app_image_cache.dart';
import '../widgets/app_error_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'details_screen.dart';
import 'all_movies_series_screen.dart';
import 'upcoming_screen.dart';
import 'subscription_vip_screen.dart';
import 'all_ott_screen.dart';
import 'navigation_helper.dart';
import 'downloads_screen.dart';
import 'fly_mode_screen.dart';

class OttSectionModel {
  final int networkId;
  final String title;
  final String logo;
  final List<MovieModel> items;

  OttSectionModel({
    required this.networkId,
    required this.title,
    required this.logo,
    required this.items,
  });
}

class HomeScreen extends StatefulWidget {
  final UserModel user;
  const HomeScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<MovieModel> _heroSlider = [];
  List<dynamic> _castData = [];
  List<MovieModel> _newlyAdded = [];
  List<dynamic> _continuePlaying = [];
  List<MovieModel> _top10Popular = [];
  List<MovieModel> _weeklyTrending = [];
  List<MovieModel> _webSeriesOnlyForYou = [];
  List<MovieModel> _moviesOnlyForYou = [];
  List<OttSectionModel> _ottSections = [];
  List<dynamic> _ottData = [];
  List<dynamic> _allOttData = [];
  String _telegramLink = 'https://t.me/+_g20_redapp';

  bool get _isVip => AppSession.user?.isVip ?? widget.user.isVip;

  Color _tagBgColor(MovieModel movie) {
    final bg = movie.customTagBg.trim();
    if (bg.isNotEmpty) {
      final c = _hexColor(bg);
      if (c != null) return c;
    }
    return const Color(0xFFE50914);
  }

  Color _tagTextColor(MovieModel movie) {
    final tc = movie.customTagColor.trim();
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

  @override
  void initState() {
    super.initState();
    _loadHomeData();
  }

  Future<void> _loadHomeData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    // Load cached parked IDs immediately (fast), refresh in background
    await ApiService.loadParkedIdsFromCache();
    unawaited(ApiService.refreshParkedIds());
    final res = await ApiService.fetchHomeData(widget.user.id);
    if (res['status'] == 'success') {
      final data = (res['data'] is Map<String, dynamic>) ? res['data'] : res;
      List<MovieModel> safeList(List? list) {
        if (list == null) return [];
        return list
            .whereType<Map<String, dynamic>>()
            .map((e) {
              try {
                return MovieModel.fromJson(e);
              } catch (_) {
                return null;
              }
            })
            .whereType<MovieModel>()
            .toList();
      }

      final rawOttSecs = data['ott_sections'] as List? ?? [];
      final parsedOttSections = rawOttSecs
          .whereType<Map<String, dynamic>>()
          .map((sec) {
            final items = ApiService.filterParked(safeList(sec['items']));
            if (items.isEmpty) return null;
            return OttSectionModel(
              networkId: int.tryParse(sec['network_id']?.toString() ?? '0') ?? 0,
              title: (sec['title'] ?? 'OTT Hits').toString().toUpperCase(),
              logo: (sec['logo'] ?? '').toString(),
              items: items,
            );
          })
          .whereType<OttSectionModel>()
          .toList();

      setState(() {
        _heroSlider = ApiService.filterParked(safeList(data['hero_slider']));
        _castData = data['ott_networks'] as List? ?? [];
        _ottData = data['ott_genres'] as List? ?? [];
        _allOttData = data['all_ott_genres'] as List? ?? _ottData;
        _newlyAdded = ApiService.filterParked(safeList(data['newly_added']));
        _continuePlaying = data['continue_playing'] as List? ?? [];
        _top10Popular = ApiService.filterParked(safeList(data['top_10'] ?? data['trending_series']));
        _weeklyTrending = ApiService.filterParked(safeList(data['weekly_trending'] ?? data['popular_movies']));
        _webSeriesOnlyForYou = ApiService.filterParked(safeList(data['popular_series'] ?? data['trending_series']));
        _moviesOnlyForYou = ApiService.filterParked(safeList(data['popular_movies'] ?? data['random_row']));
        _ottSections = parsedOttSections;
        if (data['telegram_link'] != null) {
          _telegramLink = data['telegram_link'].toString();
        }
        _errorMessage = null;
      });

      // If backend ott_sections is empty, asynchronously populate for visible OTT genres
      if (_ottSections.isEmpty && _ottData.isNotEmpty) {
        unawaited(_loadClientOttSections());
      }

      // Check and show 1-time Push Campaign or Announcement Modal
      _checkAndShowPushCampaignOrAnnouncement(data);
    } else {
      setState(() {
        _errorMessage =
            res['message'] ?? 'Failed to load content from database';
      });
    }
    setState(() => _isLoading = false);
  }

  Future<void> _loadClientOttSections() async {
    try {
      final List<OttSectionModel> sections = [];
      // Take visible OTT genres (status = 1)
      final visibleOtts = _ottData.take(12).toList();
      for (final ott in visibleOtts) {
        final name = (ott['name'] ?? '').toString().trim();
        final netId = int.tryParse(ott['id']?.toString() ?? '0') ?? 0;
        final icon = (ott['icon'] ?? '').toString();
        if (name.isEmpty) continue;

        // Fetch mixed content for this OTT
        final res = await ApiService.fetchContent(
          genre: name,
          networkId: netId,
          type: 'all',
        );
        if (res.isNotEmpty) {
          final shuffled = List<MovieModel>.from(ApiService.filterParked(res))..shuffle();
          if (shuffled.isNotEmpty) {
            sections.add(OttSectionModel(
              networkId: netId,
              title: name.toUpperCase(),
              logo: icon,
              items: shuffled.take(15).toList(),
            ));
          }
        }
      }

      if (mounted && sections.isNotEmpty) {
        setState(() {
          _ottSections = sections;
        });
      }
    } catch (_) {}
  }

  Future<void> _checkAndShowPushCampaignOrAnnouncement(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Check Push Campaign
      final campaignData = data['push_campaign'];
      if (campaignData is Map<String, dynamic>) {
        final cId = "${campaignData['id']}_${campaignData['title']}_${campaignData['expiry_at'] ?? ''}";
        final seenCampaigns = prefs.getStringList('seen_push_campaigns') ?? [];
        if (cId.isNotEmpty && !seenCampaigns.contains(cId)) {
          seenCampaigns.add(cId);
          await prefs.setStringList('seen_push_campaigns', seenCampaigns);

          if (mounted) {
            _showPushCampaignModal(campaignData);
            return;
          }
        }
      }

      // 2. Check Announcement
      final annData = data['announcement'];
      if (annData is Map<String, dynamic>) {
        final aId = "${annData['id']}_${annData['title']}_${annData['message'] ?? ''}";
        final seenAnnouncements = prefs.getStringList('seen_announcements') ?? [];
        if (aId.isNotEmpty && !seenAnnouncements.contains(aId)) {
          seenAnnouncements.add(aId);
          await prefs.setStringList('seen_announcements', seenAnnouncements);

          if (mounted) {
            _showAnnouncementModal(annData);
          }
        }
      }
      
      // 3. Check Report Resolutions
      await _checkAndShowReportResolutions();
    } catch (e) {
      print("Check push modal error: $e");
    }
  }

  void _showPushCampaignModal(Map<String, dynamic> campaignData) {
    final title = (campaignData['title'] ?? 'Newly Uploaded Today!').toString();
    final items = campaignData['items'] as List? ?? [];
    if (items.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.82,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF0F121C).withOpacity(0.85),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.18), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF1744).withOpacity(0.25),
                    blurRadius: 30,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.6),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Glass Header Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFFF1744).withOpacity(0.25),
                          const Color(0xFF8E2DE2).withOpacity(0.15),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF1744), Color(0xFFFF5252)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF1744).withOpacity(0.4),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                "${items.length} Fresh Releases Uploaded Today",
                                style: const TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(50),
                            onTap: () => Navigator.pop(ctx),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Scrollable Items List (up to 50 items)
                  Flexible(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(14),
                      shrinkWrap: true,
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final itemId = int.tryParse('${item['id']}') ?? 0;
                        final itemType = (item['item_type'] ?? item['type'] ?? 'movie').toString();
                        final name = (item['name'] ?? 'Untitled').toString();
                        final poster = (item['poster'] ?? '').toString();
                        final rawOtt = (item['ott_name'] ?? item['network_name'] ?? item['genre_name'] ?? 'RED EXCLUSIVE').toString();
                        final ottName = rawOtt.isEmpty ? 'RED EXCLUSIVE' : rawOtt;

                        return Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.12)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              // Poster Thumbnail with Tag
                              Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(
                                      poster,
                                      width: 58,
                                      height: 84,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        width: 58,
                                        height: 84,
                                        color: const Color(0xFF1E2235),
                                        child: const Icon(Icons.movie_rounded, color: Colors.white38),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    left: 4,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF1744),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        itemType.toUpperCase(),
                                        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 14),

                              // Content Title & OTT Platform Badge
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, height: 1.2),
                                    ),
                                    const SizedBox(height: 6),
                                    // OTT Platform Capsule Tag
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            const Color(0xFF00E5FF).withOpacity(0.2),
                                            const Color(0xFF8E2DE2).withOpacity(0.2),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.4)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.tv_rounded, color: Color(0xFF00E5FF), size: 12),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              ottName.toUpperCase(),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),

                              // New Modern Neon Play Button
                              Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFFF1744), Color(0xFFD50000)],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFFF1744).withOpacity(0.4),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () {
                                      Navigator.pop(ctx);
                                      navigateToContent(context, itemId, itemType);
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                                          SizedBox(width: 4),
                                          Text(
                                            "PLAY",
                                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  // Bottom Close Action
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text("DISMISS", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAnnouncementModal(Map<String, dynamic> ann) {
    final title = (ann['title'] ?? 'Announcement').toString();
    final message = (ann['message'] ?? '').toString();
    final imgUrl = (ann['image_url'] ?? '').toString();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF141722).withOpacity(0.95),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF8E2DE2).withOpacity(0.4)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8E2DE2).withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.campaign_rounded, color: Color(0xFF8E2DE2), size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (imgUrl.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    imgUrl,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                message,
                style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8E2DE2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text("GOT IT", style: TextStyle(fontWeight: FontWeight.bold)),
              )),
            ],
          ),
        ),
      ),
    );
  }

  void _showProfileSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141722),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Builder(builder: (ctx2) {
                  final u = AppSession.user ?? widget.user;
                  final pic = u.profilePic.trim();
                  return CircleAvatar(
                    radius: 26,
                    backgroundColor: _isVip ? Colors.amber : const Color(0xFFFF1744),
                    backgroundImage: pic.isNotEmpty ? CachedNetworkImageProvider(pic) : null,
                    child: pic.isEmpty
                        ? Text(
                            (u.name.isNotEmpty ? u.name[0] : 'U').toUpperCase(),
                            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 22),
                          )
                        : null,
                  );
                }),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.user.name.isNotEmpty ? widget.user.name : "Red App User",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.user.email.isNotEmpty ? widget.user.email : "VIP Member",
                        style: const TextStyle(color: Colors.white60, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isVip ? Colors.amber : const Color(0xFFFF1744),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _isVip ? "VIP ACTIVE" : "FREE USER",
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(color: Colors.white10),
            ListTile(
              leading: const Icon(Icons.download_for_offline_rounded, color: Colors.cyanAccent),
              title: const Text("My Downloads", style: TextStyle(color: Colors.white, fontSize: 14)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const DownloadsScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.workspace_premium_rounded, color: Colors.amber),
              title: const Text("VIP Subscription", style: TextStyle(color: Colors.white, fontSize: 14)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => SubscriptionVipScreen(user: widget.user)));
              },
            ),
            ListTile(
              leading: const Icon(Icons.refresh_rounded, color: Colors.greenAccent),
              title: const Text("Refresh Home Content", style: TextStyle(color: Colors.white, fontSize: 14)),
              onTap: () {
                Navigator.pop(ctx);
                _loadHomeData();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D12),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(65),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0D0D12).withOpacity(0.92),
            border: Border(
              bottom: BorderSide(
                color: const Color(0xFFFF1744).withOpacity(0.2),
                width: 1.5,
              ),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF1744), Color(0xFFB71C1C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF1744).withOpacity(0.4),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Text(
                      "R C",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        letterSpacing: -1.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFFFFFFFF), Color(0xFFFF5252), Color(0xFFFF1744)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                    child: const Text(
                      "RED CHILLIES",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.8,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      if (!_isVip) {
                        showFlyModeVipGate(context);
                        return;
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const FlyModeScreen()),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00c6ff), Color(0xFF0072ff)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.cyanAccent.withOpacity(0.4),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.flight_takeoff_rounded, color: Colors.white, size: 18),
                          SizedBox(width: 4),
                          Text(
                            "FLY",
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.search_rounded, color: Colors.white70, size: 22),
                    tooltip: 'Search Catalog',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AllMoviesSeriesScreen(
                            title: 'Search Catalog',
                            initialType: 'all',
                          ),
                        ),
                      );
                    },
                  ),
                  if (!_isVip)
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SubscriptionVipScreen(user: widget.user),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withOpacity(0.4),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.workspace_premium_rounded, color: Colors.black, size: 15),
                            SizedBox(width: 3),
                            Text("VIP", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                  GestureDetector(
                    onTap: () => _showProfileSheet(context),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: _isVip
                              ? [const Color(0xFFFFD700), const Color(0xFFFF8C00)]
                              : [const Color(0xFFFF1744), const Color(0xFF8E2DE2)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (_isVip ? Colors.amber : const Color(0xFFFF1744)).withOpacity(0.4),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Builder(builder: (context) {
                        final u = AppSession.user ?? widget.user;
                        final pic = u.profilePic.trim();
                        return CircleAvatar(
                          radius: 15,
                          backgroundColor: const Color(0xFF141722),
                          backgroundImage: pic.isNotEmpty ? CachedNetworkImageProvider(pic) : null,
                          child: pic.isEmpty
                              ? Text(
                                  (u.name.isNotEmpty ? u.name[0] : 'U').toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                )
                              : null,
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _loadHomeData,
            color: const Color(0xFFE50914),
            backgroundColor: const Color(0xFF1E1E28),
            child: _isLoading
                ? _buildShimmerLoading()
                : SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_errorMessage != null)
                          Container(
                            margin: const EdgeInsets.all(16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A1517),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: const Color(0xFFE50914), width: 1),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline,
                                    color: Color(0xFFE50914), size: 28),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    friendlyError(_errorMessage,
                                        'Failed to load content'),
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 13),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _loadHomeData,
                                  child: const Text("RETRY",
                                      style: TextStyle(
                                          color: Color(0xFFE50914),
                                          fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),

                        // Auto-Scrolling Top 10 Hero Banner
                        if (_heroSlider.isNotEmpty)
                          _buildAutoScrollHeroBanner(),

                        const SizedBox(height: 24),

                        // Popular Cast & Networks
                        if (_castData.isNotEmpty) ...[
                          _buildCastRow(),
                          const SizedBox(height: 24),
                        ],

                        // OTT Platforms (Genres)
                        if (_ottData.isNotEmpty) ...[
                          _buildOttPlatformsRow(),
                          const SizedBox(height: 24),
                        ],

                        // Continue Playing Section
                        if (_continuePlaying.isNotEmpty) ...[
                          _buildSectionHeader("Continue Playing"),
                          _buildContinuePlayingRow(),
                          const SizedBox(height: 24),
                        ],

                        // Top 10 Popular Series or Movies (Mixed, Numbered 1 to 10)
                        if (_top10Popular.isNotEmpty) ...[
                          _buildSectionHeader("Top 10 Popular Movies & Series"),
                          _buildNumberedTrendingRow(_top10Popular),
                          const SizedBox(height: 24),
                        ],

                        // Weekly Trending Row (Mixed Movies & Series)
                        if (_weeklyTrending.isNotEmpty) ...[
                          _buildSectionHeader("Weekly Trending"),
                          _buildMovieHorizontalList(_weeklyTrending),
                          const SizedBox(height: 24),
                        ],

                        // Web Series Only For You
                        if (_webSeriesOnlyForYou.isNotEmpty) ...[
                          _buildSectionHeader("Web Series Only For You"),
                          _buildMovieHorizontalList(_webSeriesOnlyForYou),
                          const SizedBox(height: 24),
                        ],

                        // Movies Only For You
                        if (_moviesOnlyForYou.isNotEmpty) ...[
                          _buildSectionHeader("Movies Only For You"),
                          _buildMovieHorizontalList(_moviesOnlyForYou),
                          const SizedBox(height: 24),
                        ],

                        // Dynamic OTT-Based Rows (visible OTTs, one by one with mixed & random content)
                        for (final sec in _ottSections) ...[
                          _buildOttSectionRow(sec),
                          const SizedBox(height: 24),
                        ],

                        const SizedBox(height: 90),
                      ],
                    ),
                  ),
          ),

          // Floating Glassmorphic Category Bar & Telegram Action Button
          Positioned(
            bottom: 18,
            left: 14,
            right: 14,
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(35),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF1E2230).withOpacity(0.88),
                              const Color(0xFF12141D).withOpacity(0.95),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(35),
                          border: Border.all(
                            color: const Color(0x44FF1744),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                            BoxShadow(
                              color: const Color(0xFFFF1744).withOpacity(0.15),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildPillTab(
                              icon: Icons.movie_outlined,
                              label: "Movies",
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AllMoviesSeriesScreen(
                                    title: 'Movies Catalog',
                                    initialType: 'movie',
                                  ),
                                ),
                              ),
                            ),
                            Container(width: 1, height: 16, color: Colors.white12),
                            _buildPillTab(
                              icon: Icons.tv_outlined,
                              label: "Web Series",
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AllMoviesSeriesScreen(
                                    title: 'Web Series Catalog',
                                    initialType: 'series',
                                  ),
                                ),
                              ),
                            ),
                            Container(width: 1, height: 16, color: Colors.white12),
                            _buildPillTab(
                              icon: Icons.auto_awesome_outlined,
                              label: "Upcoming",
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const UpcomingScreen(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () async {
                    final Uri url = Uri.parse(_telegramLink);
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0072FF).withOpacity(0.5),
                          blurRadius: 14,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 24),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillTab({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFFFF5252), size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAutoScrollHeroBanner() {
    return CarouselSlider.builder(
      itemCount: _heroSlider.length,
      options: CarouselOptions(
        height: 440,
        autoPlay: true,
        autoPlayInterval: const Duration(seconds: 4),
        viewportFraction: 1.0,
        enlargeCenterPage: false,
      ),
      itemBuilder: (context, index, realIndex) {
        final movie = _heroSlider[index];
        return GestureDetector(
          onTap: () => navigateToContent(context, movie.id, movie.itemType),
          child: SizedBox(
            height: 440,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl:
                      movie.poster.isNotEmpty ? movie.poster : movie.banner,
                  fit: BoxFit.cover,
                          cacheManager: AppImageCache.posters,
                          memCacheWidth: AppImageCache.posterMaxWidth,
                          memCacheHeight: AppImageCache.posterMaxHeight,
                  placeholder: (c, u) =>
                      Container(color: const Color(0xFF1E1E28)),
                  errorWidget: (c, u, e) =>
                      Container(color: const Color(0xFF1E1E28)),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.6),
                        Colors.transparent,
                        Colors.black.withOpacity(0.9)
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.4, 1.0],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 24,
                  left: 16,
                  right: 16,
                  child: Column(
                    children: [
                      Text(
                        movie.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.add_rounded,
                                  color: Colors.white, size: 26),
                              SizedBox(height: 4),
                              Text("My List",
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF33333E).withOpacity(0.9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Row(
                              children: const [
                                Icon(Icons.play_arrow_rounded,
                                    color: Colors.white, size: 22),
                                SizedBox(width: 6),
                                Text(
                                  "WATCH NOW",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      letterSpacing: 0.5),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.info_outline_rounded,
                                  color: Colors.white, size: 24),
                              SizedBox(height: 4),
                              Text("Info",
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ],
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
  }

  Widget _buildCastRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: const [
              Text("POPULAR ",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white)),
              Text("Actress & Cast",
                  style: TextStyle(fontSize: 14, color: Colors.white60)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _castData.length,
            itemBuilder: (context, index) {
              final item = _castData[index];
              final String name = item['name'] ?? 'Cast';
              final String logoUrl = item['logo'] ?? '';
              final int netId = int.tryParse(item['id']?.toString() ?? '0') ?? 0;
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AllMoviesSeriesScreen(
                        initialSearch: name,
                        initialNetworkId: netId,
                        title: name,
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: const Color(0xFF1E1E28),
                        child: ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: logoUrl,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorWidget: (c, u, e) => Container(
                              color: const Color(0xFF1E1E28),
                              child: const Icon(Icons.person,
                                  color: Colors.grey, size: 28),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: 70,
                        child: Text(
                          name,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.white70),
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

  Widget _buildOttPlatformsRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("OTT Platforms",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AllOttScreen(ottList: _allOttData),
                    ),
                  );
                },
                icon: const Icon(Icons.grid_view_rounded,
                    color: Color(0xFFE50914), size: 16),
                label: const Text("View All",
                    style: TextStyle(
                        color: Color(0xFFE50914),
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _ottData.length + 1,
            itemBuilder: (context, index) {
              if (index == _ottData.length) {
                // "View All" card at the end
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AllOttScreen(ottList: _allOttData),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4, right: 12),
                    child: Column(
                      children: [
                        Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFE50914), Color(0xFF8B0000)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: const Center(
                            child: Icon(Icons.grid_view_rounded,
                                color: Colors.white, size: 28),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const SizedBox(
                          width: 76,
                          child: Text(
                            "View All",
                            maxLines: 1,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11, color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              final item = _ottData[index];
              final String name = item['name'] ?? '';
              final String iconUrl = item['icon'] ?? '';
              final int netId = int.tryParse(item['id']?.toString() ?? '0') ?? 0;
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AllMoviesSeriesScreen(
                        initialGenre: name,
                        initialNetworkId: netId,
                        title: name,
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Column(
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E28),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: CachedNetworkImage(
                            imageUrl: iconUrl,
                            width: 76,
                            height: 76,
                            fit: BoxFit.contain,
                            errorWidget: (c, u, e) => Center(
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: const TextStyle(
                                    color: Colors.white54,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 22),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: 76,
                        child: Text(
                          name,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.white70),
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

  Widget _buildNumberedTrendingRow(List<MovieModel> list) {
    return SizedBox(
      height: 210,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: list.length > 10 ? 10 : list.length,
        itemBuilder: (context, index) {
          final movie = list[index];
          return GestureDetector(
            onTap: () => navigateToContent(context, movie.id, movie.itemType),
            child: Container(
              width: 150,
              margin: const EdgeInsets.only(right: 12),
              child: Stack(
                children: [
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: 125,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CachedNetworkImage(
                            imageUrl: movie.poster,
                            fit: BoxFit.cover,
                            errorWidget: (c, u, e) =>
                                Container(color: const Color(0xFF1E1E28)),
                          ),
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _tagBgColor(movie),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                movie.customTag,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: _tagTextColor(movie)),
                              ),
                            ),
                          ),
                          if (!_isVip)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.amber,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(Icons.workspace_premium_rounded,
                                    color: Colors.black, size: 14),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    bottom: -10,
                    child: Text(
                      "${index + 1}",
                      style: TextStyle(
                        fontSize: 90,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                              color: Colors.black.withOpacity(0.9),
                              blurRadius: 10,
                              offset: const Offset(-2, 2)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMovieHorizontalList(List<MovieModel> list) {
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final movie = list[index];
          return GestureDetector(
            onTap: () => navigateToContent(context, movie.id, movie.itemType),
            child: Container(
              width: 135,
              margin: const EdgeInsets.only(right: 14),
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
                            imageUrl: movie.poster,
                            fit: BoxFit.cover,
                            cacheManager: AppImageCache.posters,
                            memCacheWidth: AppImageCache.posterMaxWidth,
                            memCacheHeight: AppImageCache.posterMaxHeight,
                            errorWidget: (c, u, e) =>
                                Container(color: const Color(0xFF1E1E28)),
                          ),
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _tagBgColor(movie),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                movie.customTag,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: _tagTextColor(movie)),
                              ),
                            ),
                          ),
                          if (!_isVip)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.amber,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(Icons.workspace_premium_rounded,
                                    color: Colors.black, size: 14),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    movie.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    movie.releaseDate.isNotEmpty ? movie.releaseDate : '2025',
                    style: const TextStyle(fontSize: 11, color: Colors.white54),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOttSectionRow(OttSectionModel sec) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE50914),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    sec.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AllMoviesSeriesScreen(
                        initialGenre: sec.title,
                        initialNetworkId: sec.networkId,
                        title: sec.title,
                      ),
                    ),
                  );
                },
                child: const Text(
                  "See All",
                  style: TextStyle(
                    color: Color(0xFFE50914),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        _buildMovieHorizontalList(sec.items),
      ],
    );
  }

  Widget _buildContinuePlayingRow() {
    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _continuePlaying.length,
        itemBuilder: (context, index) {
          final item = _continuePlaying[index];
          return ContinuePlayingCard(item: item, isVip: _isVip);
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
            fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1E1E28),
      highlightColor: const Color(0xFF2D2D3C),
      child: Column(
        children: [
          Container(height: 440, width: double.infinity, color: Colors.black),
          const SizedBox(height: 20),
          Container(height: 80, width: double.infinity, color: Colors.black),
        ],
      ),
    );
  }

  Future<void> _checkAndShowReportResolutions() async {
    try {
      final userId = AppSession.user?.id ?? 0;
      if (userId <= 0) return;

      final notifications = await ApiService.fetchUserReportReplies(userId);
      if (notifications.isEmpty) return;

      final notif = notifications.first;
      if (mounted) {
        _showReportResolutionModal(notif);
      }
    } catch (e) {
      print("Check report resolution error: ");
    }
  }

  void _showReportResolutionModal(Map<String, dynamic> notif) {
    final status = int.tryParse('') ?? 0;
    final isAccepted = status == 1;
    final contentName = notif['content_name'] ?? 'Unknown';
    final adminReply = notif['admin_reply'] ?? '';
    final originalReport = notif['message'] ?? '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF0F121C).withOpacity(0.85),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: (isAccepted ? Colors.greenAccent : Colors.redAccent).withOpacity(0.15),
                    blurRadius: 30,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: (isAccepted ? Colors.green : Colors.red).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isAccepted ? Icons.check_circle_outline_rounded : Icons.report_gmailerrorred_rounded,
                      color: isAccepted ? Colors.greenAccent : Colors.redAccent,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Title
                  Text(
                    isAccepted ? "Report Accepted!" : "Report Reviewed",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Content name
                  Text(
                    contentName,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  // Divider
                  Container(
                    height: 1,
                    color: Colors.white.withOpacity(0.1),
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  const SizedBox(height: 16),
                  // Admin Reply Section
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "ADMIN RESPONSE:",
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      adminReply.isNotEmpty
                          ? adminReply
                          : (isAccepted
                              ? "Report accepted. Thank you, the link has been updated!"
                              : "This content is already working. Report rejected."),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (originalReport.isNotEmpty) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Your comment: \"$originalReport\"",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  // Close Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isAccepted ? Colors.green.shade800 : Colors.grey.shade800,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        "Close",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ContinuePlayingCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final bool isVip;
  const ContinuePlayingCard({Key? key, required this.item, required this.isVip}) : super(key: key);

  @override
  State<ContinuePlayingCard> createState() => _ContinuePlayingCardState();
}

class _ContinuePlayingCardState extends State<ContinuePlayingCard> {
  double _percent = 0.0;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final contentId = widget.item['content_id']?.toString() ?? '';
      if (contentId.isNotEmpty) {
        final progress = prefs.getInt('progress_$contentId') ?? 0;
        final duration = prefs.getInt('duration_$contentId') ?? 0;
        if (duration > 0 && progress > 0) {
          setState(() {
            _percent = (progress / duration).clamp(0.0, 1.0);
          });
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => navigateToContent(
        context,
        int.tryParse(widget.item['content_id'].toString()) ?? 0,
        widget.item['content_type'].toString() == '1' ? 'movie' : 'series',
      ),
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: widget.item['poster']?.toString() ?? '',
                fit: BoxFit.cover,
                cacheManager: AppImageCache.posters,
                memCacheWidth: AppImageCache.posterMaxWidth,
                memCacheHeight: AppImageCache.posterMaxHeight,
                errorWidget: (c, u, e) => Container(color: const Color(0xFF1E1E28)),
              ),
              if (!widget.isVip)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.workspace_premium_rounded, color: Colors.black, size: 14),
                  ),
                ),
              const Center(
                child: Icon(Icons.play_circle_fill_rounded, color: Color(0xFFE50914), size: 44),
              ),
              if (_percent > 0.0)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 5,
                    color: Colors.black45,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: _percent,
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
