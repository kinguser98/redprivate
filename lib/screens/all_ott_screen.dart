import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'all_movies_series_screen.dart';

class AllOttScreen extends StatefulWidget {
  final List<dynamic> ottList;
  const AllOttScreen({Key? key, this.ottList = const []}) : super(key: key);

  @override
  State<AllOttScreen> createState() => _AllOttScreenState();
}

class _AllOttScreenState extends State<AllOttScreen> {
  List<dynamic> _list = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _list = List.from(widget.ottList);
    if (_list.isEmpty) {
      _loadAllOtt();
    }
  }

  Future<void> _loadAllOtt() async {
    setState(() => _loading = true);
    final items = await ApiService.fetchOttGenres();
    if (mounted) {
      setState(() {
        _list = items;
        _loading = false;
      });
    }
  }

  void _openOtt(BuildContext context, dynamic item) {
    final name = item['name']?.toString() ?? '';
    final netId = int.tryParse(item['id']?.toString() ?? '0') ?? 0;
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF14141C),
        elevation: 0,
        title: const Text("All OTT Platforms",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFE50914)),
            )
          : _list.isEmpty
              ? const Center(
                  child: Text("No OTT platforms available",
                      style: TextStyle(color: Colors.grey)),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: _list.length,
                  itemBuilder: (context, index) {
                    final item = _list[index];
                    final name = item['name']?.toString() ?? '';
                    final iconUrl = item['icon']?.toString() ?? '';
                    return GestureDetector(
                      onTap: () => _openOtt(context, item),
                      child: Column(
                        children: [
                          Container(
                            width: 82,
                            height: 82,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E28),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white12),
                            ),
                            child: ClipOval(
                              child: iconUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: iconUrl,
                                      width: 82,
                                      height: 82,
                                      fit: BoxFit.cover,
                                      errorWidget: (c, u, e) => Center(
                                        child: Text(
                                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                                          style: const TextStyle(
                                              color: Colors.white54,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 26),
                                        ),
                                      ),
                                    )
                                  : Center(
                                      child: Text(
                                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                                        style: const TextStyle(
                                            color: Colors.white54,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 26),
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
