import 'dart:async';
import 'package:flutter/material.dart';
import 'api.dart';
import 'library.dart';
import 'models.dart';
import 'theme.dart';
import 'widgets.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final ctl = TextEditingController();
  final focus = FocusNode();
  Timer? _deb;
  int _sugReq = 0;
  String type = 'songs';
  String? lastQuery;
  final Map<String, List<Track>> res = {};
  bool loading = false;
  String? error;
  List<String> suggestions = [];

  @override
  void initState() {
    super.initState();
    focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _deb?.cancel();
    ctl.dispose();
    focus.dispose();
    super.dispose();
  }

  void onChanged(String v) {
    setState(() {});
    _deb?.cancel();
    if (v.trim().isEmpty) {
      setState(() => suggestions = []);
      return;
    }
    _deb = Timer(const Duration(milliseconds: 300), () async {
      final my = ++_sugReq;
      final s = await Api.suggest(v.trim());
      if (!mounted || my != _sugReq) return;
      setState(() => suggestions = s);
    });
  }

  Future<void> doSearch(String q) async {
    q = q.trim();
    if (q.isEmpty) return;
    _deb?.cancel();
    _sugReq++;
    focus.unfocus();
    ctl.text = q;
    setState(() {
      lastQuery = q;
      res.clear();
      suggestions = [];
      error = null;
    });
    await _load();
  }

  Future<void> _load() async {
    final q = lastQuery;
    if (q == null) return;
    final t = type;
    if (res.containsKey(t)) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final r = await Api.search(q, type: t);
      if (!mounted || q != lastQuery) return;
      setState(() => res[t] = r);
    } catch (e) {
      if (mounted) setState(() => error = 'Gagal mencari. Cek koneksi atau URL backend.');
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    const quick = ['Lofi', 'Pop Indonesia', 'Indie', 'Hip hop', 'Jazz', 'Akustik'];
    final showSug = focus.hasFocus && suggestions.isNotEmpty && ctl.text.trim().isNotEmpty;
    final list = res[type] ?? const <Track>[];
    final searched = lastQuery != null;

    return ListenableBuilder(
      listenable: Library.I,
      builder: (_, __) {
        final hist = Library.I.history.take(10).toList();
        return ListView(
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 2),
              child: Text('vycustic',
                  style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      color: kAccent)),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('Mau dengar apa hari ini?', style: TextStyle(color: kMuted)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: ctl,
                focusNode: focus,
                textInputAction: TextInputAction.search,
                onChanged: onChanged,
                onSubmitted: doSearch,
                decoration: InputDecoration(
                  hintText: 'Cari lagu atau artis',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: ctl.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            ctl.clear();
                            onChanged('');
                          },
                        ),
                  filled: true,
                  fillColor: kSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            if (showSug)
              for (final s in suggestions)
                ListTile(
                  leading: const Icon(Icons.search, color: kMuted),
                  title: Text(s),
                  trailing: IconButton(
                    icon: const Icon(Icons.north_west, color: kMuted, size: 18),
                    onPressed: () {
                      ctl.text = s;
                      ctl.selection = TextSelection.collapsed(offset: s.length);
                      onChanged(s);
                    },
                  ),
                  onTap: () => doSearch(s),
                )
            else ...[
              if (searched)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      for (final e in const {'songs': 'Lagu', 'videos': 'Video'}.entries)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(e.value),
                            selected: type == e.key,
                            selectedColor: kAccentSoft,
                            backgroundColor: kSurface,
                            side: BorderSide.none,
                            onSelected: (_) {
                              if (type != e.key) {
                                setState(() => type = e.key);
                                _load();
                              }
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              if (loading) const LinearProgressIndicator(color: kAccent),
              if (error != null)
                Padding(padding: const EdgeInsets.all(16), child: Text(error!)),
              if (searched && !loading && list.isEmpty && error == null)
                const Padding(padding: EdgeInsets.all(16), child: Text('Tidak ada hasil.')),
              if (list.isNotEmpty)
                for (var i = 0; i < list.length; i++)
                  TrackTile(track: list[i], list: list, index: i)
              else if (!searched) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      for (final s in quick)
                        ActionChip(
                          label: Text(s),
                          backgroundColor: kSurface,
                          side: BorderSide.none,
                          onPressed: () => doSearch(s),
                        ),
                    ],
                  ),
                ),
                if (hist.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
                    child: Text('Terakhir diputar',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                  for (var i = 0; i < hist.length; i++)
                    TrackTile(track: hist[i], list: hist, index: i),
                ],
              ],
            ],
          ],
        );
      },
    );
  }
}

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Library.I,
      builder: (_, __) {
        final f = Library.I.favorites;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Text('Favorit',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            ),
            PlayButtons(f),
            if (f.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('Belum ada favorit. Buka menu titik tiga pada lagu, lalu pilih tambah ke favorit.',
                    style: TextStyle(color: kMuted)),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: f.length,
                itemBuilder: (_, i) => TrackTile(track: f[i], list: f, index: i),
              ),
            ),
          ],
        );
      },
    );
  }
}

class PlaylistsPage extends StatelessWidget {
  const PlaylistsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Library.I,
      builder: (ctx, __) {
        final pls = Library.I.playlists;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 8, 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Playlist',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: kAccent),
                    onPressed: () async {
                      final n = await promptName(ctx, 'Playlist baru');
                      if (n != null && n.isNotEmpty) Library.I.createPlaylist(n);
                    },
                  ),
                ],
              ),
            ),
            if (pls.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('Belum ada playlist. Tekan tombol + untuk membuat.',
                    style: TextStyle(color: kMuted)),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: pls.length,
                itemBuilder: (_, i) {
                  final p = pls[i];
                  return ListTile(
                    leading: p.tracks.isEmpty
                        ? Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                                color: kSurface2, borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.queue_music, color: kMuted),
                          )
                        : Thumb(p.tracks.first.thumbnail),
                    title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${p.tracks.length} lagu',
                        style: const TextStyle(color: kMuted)),
                    onTap: () => Navigator.push(
                      ctx,
                      MaterialPageRoute(builder: (_) => PlaylistPage(playlist: p)),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class PlaylistPage extends StatelessWidget {
  final Playlist playlist;
  const PlaylistPage({required this.playlist, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kBg,
        title: ListenableBuilder(
          listenable: Library.I,
          builder: (_, __) => Text(playlist.name),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final n = await promptName(context, 'Ubah nama', initial: playlist.name);
              if (n != null && n.isNotEmpty) Library.I.renamePlaylist(playlist, n);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: kSurface2,
                  title: const Text('Hapus playlist?'),
                  content: Text('"${playlist.name}" akan dihapus.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                    FilledButton(
                        onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus')),
                  ],
                ),
              );
              if (ok == true) {
                Library.I.deletePlaylist(playlist);
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: Library.I,
        builder: (_, __) {
          final t = playlist.tracks;
          return Column(
            children: [
              PlayButtons(t),
              if (t.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Playlist masih kosong.', style: TextStyle(color: kMuted)),
                ),
              Expanded(
                child: ListView.builder(
                  itemCount: t.length,
                  itemBuilder: (_, i) =>
                      TrackTile(track: t[i], list: t, index: i, inPlaylist: playlist),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: const SafeArea(child: MiniPlayer()),
    );
  }
}
