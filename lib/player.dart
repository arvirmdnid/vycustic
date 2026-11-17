import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'api.dart';
import 'library.dart';
import 'models.dart';

class PlayerController extends ChangeNotifier {
  PlayerController._() {
    _p.playerStateStream.listen((s) {
      playing = s.playing;
      loading = s.processingState == ProcessingState.loading ||
          s.processingState == ProcessingState.buffering;
      notifyListeners();
    });
    _p.currentIndexStream.listen((i) {
      if (i == null || i < 0 || i >= queue.length) return;
      index = i;
      error = null;
      Library.I.addHistory(queue[i]);
      notifyListeners();
    });
    _p.playbackEventStream.listen((_) {}, onError: (Object e, StackTrace st) {
      error = 'Gagal memutar lagu ini';
      loading = false;
      notifyListeners();
    });
  }
  static final PlayerController instance = PlayerController._();

  final AudioPlayer _p = AudioPlayer();
  List<Track> queue = [];
  int index = -1;
  bool playing = false;
  bool loading = false;
  String? error;

  Stream<Duration> get positionStream => _p.positionStream;
  Stream<Duration?> get durationStream => _p.durationStream;

  Track? get current => (index >= 0 && index < queue.length) ? queue[index] : null;

  Future<void> playQueue(List<Track> list, int i) async {
    if (list.isEmpty) return;
    queue = List.of(list);
    index = i;
    error = null;
    loading = true;
    notifyListeners();
    try {
      final src = ConcatenatingAudioSource(
        useLazyPreparation: true,
        children: [
          for (final t in queue)
            AudioSource.uri(
              Uri.parse(Api.streamUrl(t.id)),
              tag: MediaItem(
                id: t.id,
                title: t.title,
                artist: t.artist,
                artUri: Uri.tryParse(t.thumbnail),
              ),
            ),
        ],
      );
      await _p.setAudioSource(src, initialIndex: i);
      _p.play();
    } catch (e) {
      error = 'Gagal memutar lagu ini';
      loading = false;
      notifyListeners();
    }
  }

  void toggle() => playing ? _p.pause() : _p.play();
  Future<void> next() => _p.seekToNext();
  Future<void> prev() async {
    if (_p.position.inSeconds > 3) {
      await _p.seek(Duration.zero);
    } else {
      await _p.seekToPrevious();
    }
  }

  Future<void> seek(Duration d) => _p.seek(d);
}
