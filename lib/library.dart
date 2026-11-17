import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

/// Penyimpanan lokal: favorit, riwayat, playlist.
class Library extends ChangeNotifier {
  Library._();
  static final Library I = Library._();

  SharedPreferences? _sp;
  List<Track> favorites = [];
  List<Track> history = [];
  List<Playlist> playlists = [];

  Future<void> load() async {
    _sp = await SharedPreferences.getInstance();
    favorites = _readTracks('favorites');
    history = _readTracks('history');
    final raw = _sp!.getString('playlists');
    if (raw != null) {
      try {
        playlists = (jsonDecode(raw) as List)
            .map((e) => Playlist.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } catch (_) {}
    }
  }

  List<Track> _readTracks(String key) {
    final raw = _sp?.getString(key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => Track.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  void _save() {
    final sp = _sp;
    if (sp != null) {
      sp.setString('favorites', jsonEncode(favorites.map((t) => t.toJson()).toList()));
      sp.setString('history', jsonEncode(history.map((t) => t.toJson()).toList()));
      sp.setString('playlists', jsonEncode(playlists.map((p) => p.toJson()).toList()));
    }
    notifyListeners();
  }

  bool isFav(String id) => favorites.any((t) => t.id == id);

  void toggleFav(Track t) {
    if (isFav(t.id)) {
      favorites.removeWhere((x) => x.id == t.id);
    } else {
      favorites.insert(0, t);
    }
    _save();
  }

  void addHistory(Track t) {
    history.removeWhere((x) => x.id == t.id);
    history.insert(0, t);
    if (history.length > 50) history = history.sublist(0, 50);
    _save();
  }

  Playlist createPlaylist(String name) {
    final p = Playlist(id: DateTime.now().microsecondsSinceEpoch.toString(), name: name);
    playlists.add(p);
    _save();
    return p;
  }

  void renamePlaylist(Playlist p, String name) {
    p.name = name;
    _save();
  }

  void deletePlaylist(Playlist p) {
    playlists.removeWhere((x) => x.id == p.id);
    _save();
  }

  void addToPlaylist(Playlist p, Track t) {
    if (!p.tracks.any((x) => x.id == t.id)) p.tracks.add(t);
    _save();
  }

  void removeFromPlaylist(Playlist p, Track t) {
    p.tracks.removeWhere((x) => x.id == t.id);
    _save();
  }
}
