import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';
import 'models.dart';

class Api {
  static Future<List<Track>> search(String q, {String type = 'songs'}) async {
    final uri = Uri.parse('$kBaseUrl/search').replace(queryParameters: {'q': q, 'type': type});
    final r = await http.get(uri).timeout(const Duration(seconds: 45));
    if (r.statusCode != 200) throw Exception('Server ${r.statusCode}');
    final d = jsonDecode(utf8.decode(r.bodyBytes));
    final List list = d is List ? d : (d['results'] ?? d['items'] ?? d['data'] ?? []) as List;
    return list
        .map((e) => Track.fromJson(Map<String, dynamic>.from(e as Map)))
        .where((t) => t.id.isNotEmpty)
        .toList();
  }

  static Future<List<String>> suggest(String q) async {
    try {
      final uri = Uri.parse('$kBaseUrl/suggest').replace(queryParameters: {'q': q});
      final r = await http.get(uri).timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return [];
      final d = jsonDecode(utf8.decode(r.bodyBytes));
      final l = d is List ? d : (d['suggestions'] ?? []) as List;
      return l.map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  static final Map<String, Lyrics> _lyricsCache = {};

  static Future<Lyrics> lyrics(Track t) async {
    final cached = _lyricsCache[t.id];
    if (cached != null) return cached;
    final uri = Uri.parse('$kBaseUrl/lyrics').replace(queryParameters: {
      'id': t.id,
      'title': t.title,
      'artist': t.artist,
      'duration': (t.duration ?? 0).toString(),
    });
    final r = await http.get(uri).timeout(const Duration(seconds: 30));
    if (r.statusCode != 200) throw Exception('Server ${r.statusCode}');
    final l = Lyrics.fromJson(Map<String, dynamic>.from(jsonDecode(utf8.decode(r.bodyBytes)) as Map));
    if (l.lines.isNotEmpty) _lyricsCache[t.id] = l;
    return l;
  }

  static String streamUrl(String id) => '$kBaseUrl/stream/$id';
}
