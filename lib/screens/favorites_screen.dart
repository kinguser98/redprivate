import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/app_error_widget.dart';
import 'navigation_helper.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({Key? key}) : super(key: key);

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final list = await ApiService.getFavorites();
    if (!mounted) return;
    setState(() {
      _items = list;
      _loading = false;
    });
  }

  String _typeOf(dynamic item) {
    final it = (item['item_type'] ?? '').toString();
    if (it.isNotEmpty) return it;
    return int.tryParse('${item['content_type']}') == 2 ? 'series' : 'movie';
  }

  void _removeItem(dynamic item) async {
    final id = int.tryParse('${item['content_id']}') ?? 0;
    final type = _typeOf(item);
    final res = await ApiService.removeFavorite(id, type);
    if (!mounted) return;
    if (res['status'] == 'success') {
      setState(() => _items.removeWhere((f) =>
          int.tryParse('${f['content_id']}') == id));
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res['status'] == 'success'
            ? "Removed from Favorites"
            : "Couldn't remove. Try again."),
        backgroundColor:
            res['status'] == 'success' ? Colors.green : Colors.grey.shade700,
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
        title: const Text("My Favorites",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
      ),
      body: _loading
          ? const AppLoadingView(label: "Loading favorites...")
          : _error != null
              ? AppErrorView(message: _error!, onRetry: _load)
              : _items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.favorite_border_rounded,
                              color: Colors.white24, size: 64),
                          const SizedBox(height: 16),
                          const Text("No favorites yet.\nTap the heart on any movie or series.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white38, fontSize: 14)),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 0.62,
                      ),
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        final id = int.tryParse('${item['content_id']}') ?? 0;
                        final type = _typeOf(item);
                        final name = item['name']?.toString() ?? '';
                        final poster = item['poster']?.toString() ?? '';
                        return GestureDetector(
                          onTap: () => navigateToContent(context, id, type),
                          onLongPress: () => _removeItem(item),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: poster.isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl: poster,
                                              fit: BoxFit.cover,
                                              errorWidget: (c, u, e) => Container(
                                                  color: const Color(0xFF1E1E28),
                                                  child: const Icon(Icons.movie_rounded,
                                                      color: Colors.white24)),
                                            )
                                          : Container(
                                              color: const Color(0xFF1E1E28),
                                              child: const Icon(Icons.movie_rounded,
                                                  color: Colors.white24),
                                            ),
                                    ),
                                    Positioned(
                                      top: 6,
                                      right: 6,
                                      child: GestureDetector(
                                        onTap: () => _removeItem(item),
                                        child: Container(
                                          padding: const EdgeInsets.all(5),
                                          decoration: const BoxDecoration(
                                            color: Color(0xB3000000),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.close_rounded,
                                              color: Colors.white70, size: 14),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 11),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}
