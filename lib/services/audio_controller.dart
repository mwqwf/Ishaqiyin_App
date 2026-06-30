import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../models.dart';
import '../utils/lesson_display.dart';
import 'download_service.dart';
import 'local_store.dart';
import 'firebase_repo.dart';

/// Single shared audio engine for the whole app.
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

  double _speed = 1.0;
  int _skipSeconds = 15;
  Timer? _sleepTimer;
  DateTime? _sleepEndsAt;

  bool _loading = false;
  String? _error;

  String? get currentId => _currentId;
  Lesson? get currentLesson => _current;
  List<Lesson> get playlist => _playlist;
  bool get playing => _player.playing;
  bool get isLoading => _loading;
  String? get error => _error;
  double get speed => _speed;
  int get skipSeconds => _skipSeconds;
  DateTime? get sleepEndsAt => _sleepEndsAt;

  bool get autoplay => _autoplay;
  set autoplay(bool v) {
    _autoplay = v;
    notifyListeners();
  }

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Duration get duration => _player.duration ?? Duration.zero;

  void _init() {
    _speed = LocalStore.getPlaybackSpeed();
    _skipSeconds = LocalStore.getSkipSeconds();

    _player.playerStateStream.listen((state) {
      _loading = state.processingState == ProcessingState.loading ||
          state.processingState == ProcessingState.buffering;
      if (state.processingState == ProcessingState.completed) {
        final id = _currentId;
        if (id != null) LocalStore.markCompleted(id);
        if (_autoplay) {
          _playNextInternal(wrap: false);
        }
      }
      notifyListeners();
    });

    _player.positionStream.listen((pos) {
      final id = _currentId;
      if (id == null || pos.inSeconds <= 0) return;
      final now = DateTime.now();
      if (now.difference(_lastPosSave).inSeconds >= 5) {
        _lastPosSave = now;
        LocalStore.setPosition(id, pos.inMilliseconds);
      }
    });

    _player.durationStream.listen((d) {
      final id = _currentId;
      if (id != null && d != null && d.inMilliseconds > 0) {
        LocalStore.setDurationMs(id, d.inMilliseconds);
      }
    });
  }

  void _recordPlay(Lesson lesson) {
    LocalStore.incrementPlayCount(lesson.id);
    LocalStore.addRecentPlayed(lesson.id);
    LocalStore.trackEvent('play');
    LocalStore.shouldCountView(lesson.id).then((should) {
      if (should) FirebaseRepo.incrementViews(lesson.id);
    });
  }

  void setPlaylist(List<Lesson> lessons) {
    _playlist = lessons;
  }

  bool isActive(String id) => _currentId == id;

  void clearError() {
    _error = null;
    notifyListeners();
  }

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
    if (local == null && lesson.audioUrl.isEmpty) {
      _error = 'لا يتوفر رابط صوتي لهذا الدرس.';
      notifyListeners();
      return;
    }
    final uri = local != null ? Uri.file(local) : Uri.parse(lesson.audioUrl);
    _error = null;
    _loading = true;
    _currentId = lesson.id;
    _current = lesson;
    notifyListeners();
    try {
      _recordPlay(lesson);
      await _player.setAudioSource(
        AudioSource.uri(
          uri,
          tag: MediaItem(
            id: lesson.id,
            title: lessonDisplayTitle(lesson),
            album: 'منبر ادكصهك',
          ),
        ),
      );
      await _player.setSpeed(_speed);
      final saved = LocalStore.getPosition(lesson.id);
      if (saved > 3000) {
        await _player.seek(Duration(milliseconds: saved));
      }
      await _player.play();
      _loading = false;
      notifyListeners();
    } catch (e) {
      _loading = false;
      _currentId = null;
      _current = null;
      _error = 'تعذّر تشغيل الدرس. تحقّق من الاتصال بالإنترنت.';
      debugPrint('playLesson error: $e');
      notifyListeners();
    }
  }

  Future<void> playNext() => _playNextInternal(wrap: true);

  Future<void> _playNextInternal({required bool wrap}) async {
    if (_playlist.isEmpty || _currentId == null) return;
    final i = _playlist.indexWhere((l) => l.id == _currentId);
    if (i == -1) return;
    if (i >= _playlist.length - 1) {
      if (!wrap) {
        await _player.pause();
        await _player.seek(Duration.zero);
        notifyListeners();
        return;
      }
    }
    final next = _playlist[(i + 1) % _playlist.length];
    await playLesson(next);
  }

  Future<void> playPrevious() async {
    if (_playlist.isEmpty || _currentId == null) return;
    final pos = _player.position;
    if (pos.inSeconds > 5) {
      await seek(Duration.zero);
      return;
    }
    final i = _playlist.indexWhere((l) => l.id == _currentId);
    if (i == -1) return;
    if (i <= 0) {
      await seek(Duration.zero);
      return;
    }
    await playLesson(_playlist[i - 1]);
  }

  Future<void> skipForward() async {
    final pos = _player.position;
    final total = _player.duration ?? Duration.zero;
    final next = pos + Duration(seconds: _skipSeconds);
    await seek(next > total ? total : next);
  }

  Future<void> skipBackward() async {
    final pos = _player.position;
    final next = pos - Duration(seconds: _skipSeconds);
    await seek(next.isNegative ? Duration.zero : next);
  }

  Future<void> seek(Duration d) => _player.seek(d);

  Future<void> pause() => _player.pause();

  Future<void> setSpeed(double v) async {
    _speed = v.clamp(0.75, 2.0);
    await LocalStore.setPlaybackSpeed(_speed);
    if (_player.playing || _currentId != null) {
      await _player.setSpeed(_speed);
    }
    notifyListeners();
  }

  Future<void> setSkipSeconds(int sec) async {
    _skipSeconds = sec;
    await LocalStore.setSkipSeconds(sec);
    notifyListeners();
  }

  void setSleepTimer(Duration? duration) {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepEndsAt = null;
    if (duration != null) {
      _sleepEndsAt = DateTime.now().add(duration);
      _sleepTimer = Timer(duration, () async {
        await pause();
        _sleepEndsAt = null;
        notifyListeners();
      });
    }
    notifyListeners();
  }

  void cancelSleepTimer() => setSleepTimer(null);

  double progressFor(String lessonId) {
    if (lessonId != _currentId) {
      final saved = LocalStore.getPosition(lessonId);
      final dur = LocalStore.getDurationMs(lessonId);
      if (dur > 0) return (saved / dur).clamp(0.0, 1.0);
      return 0;
    }
    final dur = _player.duration?.inMilliseconds ?? 0;
    if (dur <= 0) return 0;
    return (_player.position.inMilliseconds / dur).clamp(0.0, 1.0);
  }
}
