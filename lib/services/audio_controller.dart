import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../models.dart';
import 'download_service.dart';
import 'local_store.dart';
import 'firebase_repo.dart';

/// Single shared audio engine for the whole app (lessons + recent screens
/// + dedicated player). Plays the downloaded file when present, otherwise
/// streams from `audioUrl`. Supports next/previous/seek and autoplay,
/// with a lock-screen / background notification via just_audio_background.
class AudioController extends ChangeNotifier {
  AudioController._() {
    _init();
  }
  static final AudioController instance = AudioController._();

  final AudioPlayer _player = AudioPlayer();
  AudioPlayer get player => _player;

  List<Lesson> _playlist = [];
  String? _currentId;
  Lesson? _current;
  bool _autoplay = true;
  DateTime _lastPosSave = DateTime.fromMillisecondsSinceEpoch(0);

  String? get currentId => _currentId;
  Lesson? get currentLesson => _current;
  List<Lesson> get playlist => _playlist;
  bool get playing => _player.playing;
  bool get autoplay => _autoplay;
  set autoplay(bool v) {
    _autoplay = v;
    notifyListeners();
  }

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Duration get duration => _player.duration ?? Duration.zero;

  void _init() {
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        final id = _currentId;
        if (id != null) LocalStore.markCompleted(id);
        if (_autoplay) {
          playNext();
        }
      }
      notifyListeners();
    });

    // Persist playback position (throttled) so Home can offer
    // "continue listening". On-device only.
    _player.positionStream.listen((pos) {
      final id = _currentId;
      if (id == null || pos.inSeconds <= 0) return;
      final now = DateTime.now();
      if (now.difference(_lastPosSave).inSeconds >= 5) {
        _lastPosSave = now;
        LocalStore.setPosition(id, pos.inMilliseconds);
      }
    });
  }

  /// Records a play locally (private personalization) and bumps the global
  /// anonymous view counter once per day. Never blocks or breaks playback.
  void _recordPlay(Lesson lesson) {
    LocalStore.incrementPlayCount(lesson.id);
    LocalStore.addRecentPlayed(lesson.id);
    LocalStore.shouldCountView(lesson.id).then((should) {
      if (should) FirebaseRepo.incrementViews(lesson.id);
    });
  }

  void setPlaylist(List<Lesson> lessons) {
    _playlist = lessons;
  }

  bool isActive(String id) => _currentId == id;

  Future<void> toggle(Lesson lesson) async {
    if (_currentId == lesson.id) {
      if (_player.playing) {
        await _player.pause();
      } else {
        await _player.play();
      }
      notifyListeners();
    } else {
      await playLesson(lesson);
    }
  }

  Future<void> playLesson(Lesson lesson) async {
    final local = DownloadService.localAudioPath(lesson.id);
    if (local == null && lesson.audioUrl.isEmpty) return;
    final uri = local != null ? Uri.file(local) : Uri.parse(lesson.audioUrl);
    try {
      _currentId = lesson.id;
      _current = lesson;
      _recordPlay(lesson);
      notifyListeners();
      await _player.setAudioSource(
        AudioSource.uri(
          uri,
          tag: MediaItem(
            id: lesson.id,
            title: lesson.title.isEmpty ? 'درس صوتي' : lesson.title,
            album: 'تطبيق الإسحاقيين',
          ),
        ),
      );
      // Resume from the saved position when one exists ("continue listening").
      final saved = LocalStore.getPosition(lesson.id);
      if (saved > 3000) {
        await _player.seek(Duration(milliseconds: saved));
      }
      await _player.play();
    } catch (_) {
      _currentId = null;
      _current = null;
      notifyListeners();
    }
  }

  Future<void> playNext() async {
    if (_playlist.isEmpty || _currentId == null) return;
    final i = _playlist.indexWhere((l) => l.id == _currentId);
    if (i == -1) return;
    await playLesson(_playlist[(i + 1) % _playlist.length]);
  }

  Future<void> playPrevious() async {
    if (_playlist.isEmpty || _currentId == null) return;
    final i = _playlist.indexWhere((l) => l.id == _currentId);
    if (i == -1) return;
    await playLesson(
        _playlist[(i - 1 + _playlist.length) % _playlist.length]);
  }

  Future<void> seek(Duration d) => _player.seek(d);
  Future<void> pause() => _player.pause();
}
