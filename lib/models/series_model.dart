class SeriesItemModel {
  final int id;
  final String name;
  final String description;
  final String poster;
  final String banner;
  final String releaseDate;
  List<SeriesSeasonModel> seasons;

  SeriesItemModel({
    required this.id,
    required this.name,
    this.description = '',
    this.poster = '',
    this.banner = '',
    this.releaseDate = '',
    List<SeriesSeasonModel>? seasons,
  }) : seasons = seasons ?? [];

  factory SeriesItemModel.fromJson(Map<String, dynamic> json) {
    var seasonList = (json['seasons'] as List?)
            ?.map((s) => SeriesSeasonModel.fromJson(s))
            .toList() ??
        [];
    return SeriesItemModel(
      id: int.tryParse(json['id'].toString()) ?? 0,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      poster: json['poster'] ?? '',
      banner: json['banner'] ?? '',
      releaseDate: json['release_date'] ?? '',
      seasons: seasonList,
    );
  }

  factory SeriesItemModel.fromBasicJson(Map<String, dynamic> json) {
    return SeriesItemModel(
      id: int.tryParse(json['id'].toString()) ?? 0,
      name: json['name'] ?? '',
      poster: json['poster'] ?? '',
      banner: json['banner'] ?? '',
      releaseDate: json['release_date'] ?? '',
    );
  }
}

class SeriesSeasonModel {
  final int id;
  final String name;
  final int order;
  final List<SeriesEpisodeModel> episodes;

  SeriesSeasonModel({
    required this.id,
    this.name = 'Season',
    this.order = 0,
    this.episodes = const [],
  });

  factory SeriesSeasonModel.fromJson(Map<String, dynamic> json) {
    var epList = (json['episodes'] as List?)
            ?.map((e) => SeriesEpisodeModel.fromJson(e))
            .toList() ??
        [];
    return SeriesSeasonModel(
      id: int.tryParse(json['id'].toString()) ?? 0,
      name: json['Session_Name'] ?? '',
      order: int.tryParse(json['season_order'].toString()) ?? 0,
      episodes: epList,
    );
  }
}

class SeriesEpisodeModel {
  final int id;
  final String name;
  final String image;
  final String description;
  final int order;
  final SeriesPlayLinkModel? playLink;

  SeriesEpisodeModel({
    required this.id,
    this.name = '',
    this.image = '',
    this.description = '',
    this.order = 0,
    this.playLink,
  });

  factory SeriesEpisodeModel.fromJson(Map<String, dynamic> json) {
    return SeriesEpisodeModel(
      id: int.tryParse(json['id'].toString()) ?? 0,
      name: json['Episoade_Name'] ?? '',
      image: json['episoade_image'] ?? '',
      description: json['episoade_description'] ?? '',
      order: int.tryParse(json['episoade_order'].toString()) ?? 0,
      playLink: json['play_link'] != null
          ? SeriesPlayLinkModel.fromJson(json['play_link'])
          : null,
    );
  }
}

class SeriesPlayLinkModel {
  final int id;
  final String name;
  final String url;
  final String quality;
  final String type;

  SeriesPlayLinkModel({
    required this.id,
    this.name = '',
    this.url = '',
    this.quality = '720p',
    this.type = 'StreamTape',
  });

  factory SeriesPlayLinkModel.fromJson(Map<String, dynamic> json) {
    return SeriesPlayLinkModel(
      id: int.tryParse(json['id'].toString()) ?? 0,
      name: json['name'] ?? '',
      url: json['url'] ?? '',
      quality: json['quality'] ?? '720p',
      type: json['type'] ?? 'StreamTape',
    );
  }
}
