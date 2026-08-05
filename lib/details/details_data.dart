import '../models/movie_model.dart';

class DetailsData {
  final MovieModel movie;
  final List<PlayLinkModel> playLinks;
  final List<SeasonModel> seasons;
  final List<MovieModel> related;
  final List<CastMember> castMembers;
  final List<String> genres;
  final String? ottName;
  final String? ottLogo;
  final int? ottId;

  bool get isMovie => movie.itemType == 'movie' || movie.itemType == '1';

  int get totalSeasons => seasons.length;
  int get totalEpisodes =>
      seasons.fold(0, (sum, s) => sum + s.episodes.length);

  const DetailsData({
    required this.movie,
    this.playLinks = const [],
    this.seasons = const [],
    this.related = const [],
    this.castMembers = const [],
    this.genres = const [],
    this.ottName,
    this.ottLogo,
    this.ottId,
  });
}
