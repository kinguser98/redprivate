import 'package:flutter_test/flutter_test.dart';
import 'package:red_app/services/skymovies_scraper.dart';

void main() async {
  test('verify skymovies screenshots', () async {
    final entries = await SkymoviesScraper.search('Choked');
    print("Found ${entries.length} entries for 'Choked':");
    for (final e in entries) {
      print(" - ${e.title} -> ${e.pageUrl}");
    }

    if (entries.isNotEmpty) {
      final shots = await SkymoviesScraper.fetchScreenshots(entries.first.pageUrl);
      print("\nExtracted ${shots.length} screenshots for '${entries.first.title}':");
      for (final s in shots) {
        print("  * $s");
      }
      expect(shots.length, greaterThanOrEqualTo(4));
    }

    final entries2 = await SkymoviesScraper.search('Desi Kisse Na Umra Ki Seema Ho');
    print("\nFound ${entries2.length} entries for 'Desi Kisse':");
    if (entries2.isNotEmpty) {
      final shots2 = await SkymoviesScraper.fetchScreenshots(entries2.first.pageUrl);
      print("Extracted ${shots2.length} screenshots for '${entries2.first.title}':");
      for (final s in shots2) {
        print("  * $s");
      }
      expect(shots2.length, greaterThanOrEqualTo(4));
    }
  });
}
