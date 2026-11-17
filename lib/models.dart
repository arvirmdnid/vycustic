class Track {
  final String id;
  final String title;
  final String artist;
  final String thumbnail;
  final int? duration;

  Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.thumbnail,
    this.duration,
  });

  factory Track.fromJson(Map<String, dynamic> j) {
    final id = (j['id'] ?? j['videoId'] ?? j['video_id'] ?? '').toString();
    final thumb = (j['thumbnail'] ?? j['thumb'] ?? j['image'] ?? '').toString();
    final d = j['duration'];
    return Track(
      id: id,
      title: (j['title'] ?? 'Tanpa judul').toString(),
      artist: (j['artist'] ?? j['uploader'] ?? j['channel'] ?? '').toString(),
      thumbnail: thumb.isNotEmpty ? thumb : 'https://i.ytimg.com/vi/$id/hqdefault.jpg',
      duration: d is num ? d.toInt() : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'thumbnail': thumbnail,
        'duration': duration,
      };
}

class Playlist {
  final String id;
  String name;
  final List<Track> tracks;

  Playlist({required this.id, required this.name, List<Track>? tracks})
      : tracks = tracks ?? [];

  factory Playlist.fromJson(Map<String, dynamic> j) => Playlist(
        id: j['id'].toString(),
        name: j['name'].toString(),
        tracks: ((j['tracks'] ?? []) as List)
            .map((e) => Track.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'tracks': tracks.map((t) => t.toJson()).toList(),
      };
}

class LyricLine {
  final int? t; // milidetik, null kalau lirik tanpa waktu
  final String text;
  LyricLine(this.t, this.text);
}

class Lyrics {
  final bool synced;
  final List<LyricLine> lines;
  final String source;
  Lyrics({required this.synced, required this.lines, this.source = ''});

  factory Lyrics.fromJson(Map<String, dynamic> j) {
    final ls = ((j['lines'] ?? []) as List).map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      final t = m['t'];
      return LyricLine(t is num ? t.toInt() : null, (m['text'] ?? '').toString());
    }).toList();
    return Lyrics(
      synced: j['synced'] == true && ls.isNotEmpty,
      lines: ls,
      source: (j['source'] ?? '').toString(),
    );
  }
}
