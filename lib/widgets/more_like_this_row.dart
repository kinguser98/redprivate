import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/movie_model.dart';

class MoreLikeThisRow extends StatelessWidget {
  final List<MovieModel> items;
  final String itemType; // 'movie' or 'series'
  final void Function(int, String) onTap;

  const MoreLikeThisRow({
    Key? key,
    required this.items,
    required this.itemType,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'More Like This',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = items[index];
              return GestureDetector(
                onTap: () => onTap(item.id, itemType),
                child: SizedBox(
                  width: 118,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: item.poster.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: item.poster,
                                width: 118,
                                height: 165,
                                fit: BoxFit.cover,
                                errorWidget: (c, u, e) => Container(
                                    width: 118,
                                    height: 165,
                                    color: const Color(0xFF14141E),
                                    child: const Icon(Icons.movie_rounded,
                                        color: Colors.white24)),
                              )
                            : Container(
                                width: 118,
                                height: 165,
                                color: const Color(0xFF14141E),
                                child: const Icon(Icons.movie_rounded,
                                    color: Colors.white24),
                              ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
