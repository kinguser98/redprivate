import 'dart:convert';

class CastMember {
  final String name;
  final String profileUrl;

  CastMember({required this.name, required this.profileUrl});

  factory CastMember.fromJson(Map<String, dynamic> json) {
    return CastMember(
      name: json['name']?.toString() ?? '',
      profileUrl: json['profile_url']?.toString() ?? json['photo']?.toString() ?? '',
    );
  }
}

class MovieModel {
  final int id;
  final String name;
  final String description;
  final String poster;
  final String banner;
  final String itemType;
  final String rating;
  final String releaseDate;
  final String customTag;
  final String customTagBg;
  final String customTagColor;
  final List<CastMember> castMembers;
  final List<String> genres;
  final String? ottName;
  final String? ottLogo;
  final int? ottId;

  MovieModel({
    required this.id,
    required this.name,
    this.description = '',
    this.poster = '',
    this.banner = '',
    required this.itemType,
    this.rating = '0.0',
    this.releaseDate = '',
    this.customTag = 'HD',
    this.customTagBg = '',
    this.customTagColor = '',
    this.castMembers = const [],
    this.genres = const [],
    this.ottName,
    this.ottLogo,
    this.ottId,
  });

  static String _cleanTag(dynamic raw) {
    if (raw == null) return 'HD';
    String s = raw.toString().trim();
    if (s.isEmpty) return 'HD';
    // If the value is a JSON object/array string (e.g. "{ID: 11++, Custom_TAGS...}"),
    // try to extract a sensible tag or fall back to a short default.
    if (s.startsWith('{') || s.startsWith('[')) {
      try {
        final decoded = jsonDecode(s);
        if (decoded is Map && decoded.isNotEmpty) {
          final first = decoded.values.firstWhere(
            (v) => v != null && v.toString().trim().isNotEmpty,
            orElse: () => 'HD',
          );
          s = first.toString().trim();
        } else if (decoded is List && decoded.isNotEmpty) {
          s = decoded.first.toString().trim();
        } else {
          s = 'HD';
        }
      } catch (_) {
        s = 'HD';
      }
    }
    // Strip anything that looks like a raw debug/object dump.
    if (s.contains('{') ||
        s.contains('}') ||
        s.contains('++') ||
        s.contains(':') ||
        s.length > 12) {
      s = 'HD';
    }
    return s.isEmpty ? 'HD' : s.toUpperCase();
  }

  factory MovieModel.fromJson(Map<String, dynamic> json) {
    // Custom tag can arrive in two formats:
    //  1. Flat:  { "custom_tag": "Mal", "custom_tag_bg": "#57f90b", "custom_tag_color": "#000000" }
    //  2. Dooo:  { "custom_tags": [{ "custom_tags_name": "Mal", "background_color": "...", "text_color": "..." }] }
    String tagName = 'HD';
    String tagBg = '';
    String tagColor = '';
    final flatTag = json['custom_tag'];
    if (flatTag != null) {
      tagName = _cleanTag(flatTag);
      tagBg = json['custom_tag_bg']?.toString() ?? '';
      tagColor = json['custom_tag_color']?.toString() ?? '';
    } else {
      final tagsRaw = json['custom_tags'];
      if (tagsRaw is List && tagsRaw.isNotEmpty) {
        final t = tagsRaw.first;
        if (t is Map) {
          tagName = _cleanTag(t['custom_tags_name'] ?? t['name']);
          tagBg = (t['background_color'] ?? t['custom_tag_background_color'] ?? '').toString();
          tagColor = (t['text_color'] ?? t['custom_tag_text_color'] ?? '').toString();
        }
      } else if (tagsRaw is Map && tagsRaw.isNotEmpty) {
        tagName = _cleanTag(tagsRaw['custom_tags_name'] ?? tagsRaw['name']);
        tagBg = (tagsRaw['background_color'] ?? '').toString();
        tagColor = (tagsRaw['text_color'] ?? '').toString();
      }
    }

    List<CastMember> castMembers = [];
    final castStr = json['cast']?.toString() ?? '';
    final castPhotosStr = json['cast_photos']?.toString() ?? '';
    if (castStr.isNotEmpty) {
      final names = castStr.split(',').map((s) => s.trim()).toList();
      final photos = castPhotosStr.split(',').map((s) => s.trim()).toList();
      for (int i = 0; i < names.length; i++) {
        if (names[i].isNotEmpty) {
          castMembers.add(CastMember(
            name: names[i],
            profileUrl: i < photos.length ? photos[i] : '',
          ));
        }
      }
    }

    List<String> genres = [];
    final genreStr = json['genres']?.toString() ?? json['genre']?.toString() ?? '';
    if (genreStr.isNotEmpty) {
      genres = genreStr.split(',').map((g) => g.trim()).where((g) => g.isNotEmpty).toList();
    }

    return MovieModel(
      id: int.tryParse(json['id'].toString()) ?? 0,
      name: json['name'] ?? json['Episoade_Name'] ?? json['Session_Name'] ?? '',
      description: json['description'] ?? json['episoade_description'] ?? '',
      poster: json['poster'] ?? json['episoade_image'] ?? json['banner'] ?? '',
      banner: json['banner'] ?? json['poster'] ?? '',
      itemType: json['item_type'] ?? 'movie',
      rating: json['rating']?.toString() ?? '8.5',
      releaseDate: json['release_date'] ?? '2025',
      customTag: tagName,
      customTagBg: tagBg,
      customTagColor: tagColor,
      castMembers: castMembers,
      genres: genres,
      ottName: json['ott_name']?.toString(),
      ottLogo: json['ott_logo']?.toString(),
      ottId: json['ott_id'] != null ? int.tryParse(json['ott_id'].toString()) : null,
    );
  }
}

class OttNetworkModel {
  final int id;
  final String name;
  final String logo;

  OttNetworkModel({
    required this.id,
    required this.name,
    required this.logo,
  });

  factory OttNetworkModel.fromJson(Map<String, dynamic> json) {
    return OttNetworkModel(
      id: int.tryParse(json['id'].toString()) ?? 0,
      name: json['name'] ?? json['network_name'] ?? json['name_log'] ?? '',
      logo: json['logo'] ?? json['network_logo'] ?? json['image'] ?? '',
    );
  }
}

class PlayLinkModel {
  final int id;
  final String name;
  final String quality;
  final String url;
  final String type;

  PlayLinkModel({
    required this.id,
    required this.name,
    required this.quality,
    required this.url,
    required this.type,
  });

  factory PlayLinkModel.fromJson(Map<String, dynamic> json) {
    return PlayLinkModel(
      id: int.tryParse(json['id'].toString()) ?? 0,
      name: json['name'] ?? 'Server 1',
      quality: json['quality'] ?? '720p',
      url: json['url'] ?? '',
      type: json['type'] ?? 'Streamtape',
    );
  }
}

class SeasonModel {
  final int id;
  final String seasonName;
  final int seasonOrder;
  final List<EpisodeModel> episodes;

  SeasonModel({
    required this.id,
    required this.seasonName,
    required this.seasonOrder,
    required this.episodes,
  });

  factory SeasonModel.fromJson(Map<String, dynamic> json) {
    var epList = (json['episodes'] as List?)
            ?.map((e) => EpisodeModel.fromJson(e))
            .toList() ??
        [];
    return SeasonModel(
      id: int.tryParse(json['id'].toString()) ?? 0,
      seasonName: json['Session_Name'] ?? json['season_name'] ?? 'Season 1',
      seasonOrder: int.tryParse(json['season_order'].toString()) ?? 1,
      episodes: epList,
    );
  }
}

class EpisodeModel {
  final int id;
  final String name;
  final String description;
  final String image;
  final int episodeOrder;
  final List<PlayLinkModel> playLinks;

  EpisodeModel({
    required this.id,
    required this.name,
    required this.description,
    required this.image,
    required this.episodeOrder,
    required this.playLinks,
  });

  factory EpisodeModel.fromJson(Map<String, dynamic> json) {
    var links = (json['play_links'] as List?)
            ?.map((l) => PlayLinkModel.fromJson(l))
            .toList() ??
        [];
    return EpisodeModel(
      id: int.tryParse(json['id'].toString()) ?? 0,
      name: json['Episoade_Name'] ?? 'Episode',
      description: json['episoade_description'] ?? '',
      image: json['episoade_image'] ?? '',
      episodeOrder: int.tryParse(json['episoade_order'].toString()) ?? 1,
      playLinks: links,
    );
  }
}
