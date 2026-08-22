import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';

class UpcomingScreen extends StatefulWidget {
  const UpcomingScreen({Key? key}) : super(key: key);

  @override
  State<UpcomingScreen> createState() => _UpcomingScreenState();
}

class _UpcomingScreenState extends State<UpcomingScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _upcomingList = [];

  @override
  void initState() {
    super.initState();
    _loadUpcoming();
  }

  Future<void> _loadUpcoming() async {
    setState(() => _isLoading = true);
    final data = await ApiService.fetchUpcomingContents();
    setState(() {
      _upcomingList = data;
      _isLoading = false;
    });
  }

  void _launchTrailer(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF14141C),
        elevation: 0,
        title: const Text(
          "Upcoming Releases",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFE50914)))
          : _upcomingList.isEmpty
              ? const Center(
                  child: Text(
                    "No upcoming releases found.",
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _upcomingList.length,
                  itemBuilder: (context, index) {
                    final item = _upcomingList[index];
                    final String title = item['name'] ?? 'Upcoming Movie';
                    final String desc = item['description'] ?? '';
                    final String poster = item['poster'] ?? item['banner'] ?? '';
                    final String releaseDate = item['release_date'] ?? 'Coming Soon';
                    final String trailerUrl = item['trailer_url'] ?? item['youtube_trailer'] ?? '';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF181824),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Stack(
                            children: [
                              CachedNetworkImage(
                                imageUrl: poster,
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorWidget: (c, u, e) => Container(
                                  height: 200,
                                  color: Colors.grey[900],
                                  child: const Icon(Icons.movie,
                                      color: Colors.grey, size: 50),
                                ),
                              ),
                              Container(
                                height: 200,
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.transparent, Color(0xFF181824)],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 12,
                                right: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE50914),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    releaseDate,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (desc.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    desc,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.white60, fontSize: 13),
                                  ),
                                ],
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    if (trailerUrl.isNotEmpty)
                                      ElevatedButton.icon(
                                        onPressed: () => _launchTrailer(trailerUrl),
                                        icon: const Icon(Icons.play_arrow_rounded),
                                        label: const Text("Watch Trailer"),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFE50914),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                      ),
                                    const Spacer(),
                                    IconButton(
                                      icon: const Icon(Icons.notifications_active_outlined,
                                          color: Colors.yellowAccent),
                                      onPressed: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text("Reminder set for $title!"),
                                            backgroundColor: const Color(0xFF1E1E28),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
