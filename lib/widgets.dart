import 'dart:async';
import 'package:flutter/material.dart';
import 'api.dart';
import 'library.dart';
import 'models.dart';
import 'player.dart';
import 'theme.dart';

String fmt(Duration d) {
  final m = d.inMinutes.toString();
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}

class TrackThumb extends StatelessWidget {
  final String url;
  final double size;
  final double radius;
  const TrackThumb(this.url, {this.size = 52, this.radius = 12, super.key});
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          color: kSurface2,
          child: const Icon(Icons.music_note, color: kMuted),
        ),
      ),
    );
  }
}

Future<String?> promptName(BuildContext context, String title, {String initial = ''}) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: kSurface2,
      title: Text(title),
      content: TextField(
        controller: c,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Nama playlist'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, c.text.trim()),
          child: const Text('Simpan'),
        ),
      ],
    ),
  );
}

void showAddToPlaylist(BuildContext context, Track t) {
  showModalBottomSheet(
    context: context,
    backgroundColor: kSurface,
    builder: (ctx) {
      final lib = Library.I;
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Tambah ke playlist',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            ListTile(
              leading: const Icon(Icons.add, color: kAccent),
              title: const Text('Playlist baru'),
              onTap: () async {
                Navigator.pop(ctx);
                final n = await promptName(context, 'Playlist baru');
                if (n != null && n.isNotEmpty) {
                  final p = lib.createPlaylist(n);
                  lib.addToPlaylist(p, t);
                }
              },
            ),
            for (final p in lib.playlists)
              ListTile(
                leading: const Icon(Icons.queue_music, color: kMuted),
                title: Text(p.name),
                subtitle: Text('${p.tracks.length} lagu'),
                onTap: () {
                  lib.addToPlaylist(p, t);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Ditambahkan ke ${p.name}')),
                  );
                },
              ),
          ],
        ),
      );
    },
  );
}

class PlayButtons extends StatelessWidget {
  final List<Track> tracks;
  const PlayButtons(this.tracks, {super.key});
  @override
  Widget build(BuildContext context) {
    final p = PlayerController.instance;
    final empty = tracks.isEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: kAccent, foregroundColor: Colors.black),
              onPressed: empty ? null : () => p.playQueue(tracks, 0),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Putar'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: empty
                  ? null
                  : () {
                      final l = List<Track>.of(tracks)..shuffle();
                      p.playQueue(l, 0);
                    },
              icon: const Icon(Icons.shuffle),
              label: const Text('Acak'),
            ),
          ),
        ],
      ),
    );
  }
}

class TrackTile extends StatelessWidget {
  final Track track;
  final List<Track> list;
  final int index;
  final Playlist? inPlaylist;
  const TrackTile({
    required this.track,
    required this.list,
    required this.index,
    this.inPlaylist,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final p = PlayerController.instance;
    final lib = Library.I;
    return ListenableBuilder(
      listenable: Listenable.merge([p, lib]),
      builder: (_, __) {
        final active = p.current?.id == track.id;
        final fav = lib.isFav(track.id);
        return ListTile(
          leading: TrackThumb(track.thumbnail),
          title: Text(
            track.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: active ? kAccent : null, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(track.artist,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kMuted)),
          trailing: PopupMenuButton<String>(
            color: kSurface2,
            icon: const Icon(Icons.more_vert, color: kMuted),
            onSelected: (v) {
              if (v == 'fav') lib.toggleFav(track);
              if (v == 'pl') showAddToPlaylist(context, track);
              if (v == 'rm' && inPlaylist != null) lib.removeFromPlaylist(inPlaylist!, track);
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                  value: 'fav',
                  child: Text(fav ? 'Hapus dari favorit' : 'Tambah ke favorit')),
              const PopupMenuItem(value: 'pl', child: Text('Tambah ke playlist')),
              if (inPlaylist != null)
                const PopupMenuItem(value: 'rm', child: Text('Hapus dari playlist')),
            ],
          ),
          onTap: () => p.playQueue(list, index),
        );
      },
    );
  }
}

void openFullPlayer(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: kBg,
    builder: (_) => const FullPlayer(),
  );
}

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});
  @override
  Widget build(BuildContext context) {
    final p = PlayerController.instance;
    return ListenableBuilder(
      listenable: p,
      builder: (_, __) {
        final t = p.current;
        if (t == null) return const SizedBox.shrink();
        return GestureDetector(
          onTap: () => openFullPlayer(context),
          child: Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 6),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: kSurface2,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                TrackThumb(t.thumbnail, size: 44, radius: 10),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(p.error ?? t.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12,
                              color: p.error != null ? Colors.redAccent : kMuted)),
                    ],
                  ),
                ),
                if (p.loading)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: kAccent),
                    ),
                  )
                else
                  IconButton(
                    icon: Icon(p.playing ? Icons.pause : Icons.play_arrow),
                    onPressed: p.toggle,
                  ),
                IconButton(icon: const Icon(Icons.skip_next), onPressed: p.next),
              ],
            ),
          ),
        );
      },
    );
  }
}

class FullPlayer extends StatefulWidget {
  const FullPlayer({super.key});
  @override
  State<FullPlayer> createState() => _FullPlayerState();
}

class _FullPlayerState extends State<FullPlayer> {
  bool showLyrics = false;

  @override
  Widget build(BuildContext context) {
    final p = PlayerController.instance;
    final lib = Library.I;
    return ListenableBuilder(
      listenable: Listenable.merge([p, lib]),
      builder: (_, __) {
        final t = p.current;
        if (t == null) return const SizedBox(height: 200);
        final w = (MediaQuery.of(context).size.width - 64).clamp(120.0, 340.0).toDouble();
        final fav = lib.isFav(t.id);
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              children: [
                if (showLyrics)
                  Container(
                    width: double.infinity,
                    height: w,
                    decoration: BoxDecoration(
                      color: kSurface,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: LyricsView(track: t),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [BoxShadow(color: kAccentSoft, blurRadius: 40)],
                    ),
                    child: TrackThumb(t.thumbnail, size: w, radius: 24),
                  ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(t.artist, style: const TextStyle(color: kMuted)),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Lirik',
                      icon: Icon(Icons.lyrics_outlined, color: showLyrics ? kAccent : kMuted),
                      onPressed: () => setState(() => showLyrics = !showLyrics),
                    ),
                    IconButton(
                      icon: Icon(fav ? Icons.favorite : Icons.favorite_border,
                          color: fav ? kAccent : kMuted),
                      onPressed: () => lib.toggleFav(t),
                    ),
                    IconButton(
                      icon: const Icon(Icons.playlist_add, color: kMuted),
                      onPressed: () => showAddToPlaylist(context, t),
                    ),
                  ],
                ),
                if (p.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(p.error!, style: const TextStyle(color: Colors.redAccent)),
                  ),
                const SizedBox(height: 12),
                StreamBuilder<Duration?>(
                  stream: p.durationStream,
                  builder: (_, ds) {
                    final dur = ds.data ?? Duration.zero;
                    return StreamBuilder<Duration>(
                      stream: p.positionStream,
                      builder: (_, ps) {
                        final pos = ps.data ?? Duration.zero;
                        final max = dur.inMilliseconds.toDouble();
                        final top = max <= 0 ? 1.0 : max;
                        final val = pos.inMilliseconds.toDouble().clamp(0.0, top).toDouble();
                        return Column(
                          children: [
                            Slider(
                              value: val,
                              max: top,
                              activeColor: kAccent,
                              inactiveColor: kSurface2,
                              onChanged: max <= 0
                                  ? null
                                  : (v) => p.seek(Duration(milliseconds: v.toInt())),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(fmt(pos), style: const TextStyle(color: kMuted)),
                                  Text(fmt(dur), style: const TextStyle(color: kMuted)),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                        iconSize: 38,
                        icon: const Icon(Icons.skip_previous),
                        onPressed: p.prev),
                    const SizedBox(width: 12),
                    Container(
                      decoration:
                          const BoxDecoration(color: kAccent, shape: BoxShape.circle),
                      child: p.loading
                          ? const Padding(
                              padding: EdgeInsets.all(20),
                              child: SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                    strokeWidth: 3, color: Colors.black),
                              ),
                            )
                          : IconButton(
                              iconSize: 44,
                              color: Colors.black,
                              icon: Icon(p.playing ? Icons.pause : Icons.play_arrow),
                              onPressed: p.toggle,
                            ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                        iconSize: 38, icon: const Icon(Icons.skip_next), onPressed: p.next),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class LyricsView extends StatefulWidget {
  final Track track;
  const LyricsView({required this.track, super.key});
  @override
  State<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<LyricsView> {
  Lyrics? _data;
  bool _loading = true;
  int _req = 0;
  int _active = -1;
  List<GlobalKey> _keys = [];
  StreamSubscription<Duration>? _sub;

  @override
  void initState() {
    super.initState();
    _load();
    _sub = PlayerController.instance.positionStream.listen(_onPos);
  }

  @override
  void didUpdateWidget(LyricsView old) {
    super.didUpdateWidget(old);
    if (old.track.id != widget.track.id) setState(_load);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _load() {
    final my = ++_req;
    _data = null;
    _loading = true;
    _active = -1;
    _keys = [];
    Api.lyrics(widget.track).then((d) {
      if (!mounted || my != _req) return;
      setState(() {
        _data = d;
        _loading = false;
        _keys = List.generate(d.lines.length, (_) => GlobalKey());
      });
    }).catchError((_) {
      if (!mounted || my != _req) return;
      setState(() {
        _data = null;
        _loading = false;
      });
    });
  }

  void _onPos(Duration pos) {
    final d = _data;
    if (d == null || !d.synced) return;
    final ms = pos.inMilliseconds;
    var idx = -1;
    for (var i = 0; i < d.lines.length; i++) {
      final t = d.lines[i].t;
      if (t != null && t <= ms) idx = i;
    }
    if (idx != _active && idx >= 0 && idx < _keys.length) {
      setState(() => _active = idx);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _keys[idx].currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            alignment: 0.35,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: kAccent));
    }
    final d = _data;
    if (d == null || d.lines.isEmpty) {
      return const Center(
        child: Text('Lirik tidak ditemukan', style: TextStyle(color: kMuted)),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
      child: Column(
        children: [
          for (var i = 0; i < d.lines.length; i++)
            InkWell(
              key: _keys[i],
              onTap: d.synced && d.lines[i].t != null
                  ? () => PlayerController.instance.seek(Duration(milliseconds: d.lines[i].t!))
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Text(
                  d.lines[i].text.isEmpty ? '\u266A' : d.lines[i].text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: d.synced ? (i == _active ? 22 : 18) : 17,
                    fontWeight: FontWeight.w700,
                    color: d.synced ? (i == _active ? kAccent : kMuted) : Colors.white70,
                  ),
                ),
              ),
            ),
          if (d.source.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Text(d.source, style: const TextStyle(fontSize: 11, color: kMuted)),
            ),
        ],
      ),
    );
  }
}
