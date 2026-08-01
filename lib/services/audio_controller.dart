import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
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
  bool _notifyPending = false;

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
    _notifySafely();
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
      _notifySafely();
    });

    _player.positionStream.listen((pos) {
      final id = _currentId;
      if (id == null || pos.inSeconds <= 0) return;
      final now = DateTime.now();
      if (now.difference(_lastPosSave).inSeconds >= 5) {
        // احتساب زمن الاستماع الفعلي (لـ«حصادك» والهدف الأسبوعي).
        final elapsed = now.difference(_lastPosSave).inSeconds;
        if (_player.playing && elapsed > 0 && elapsed <= 30) {
          LocalStore.addListenSeconds(elapsed);
        }
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

  /// يمنع استدعاء setState ضمنياً أثناء مرحلة بناء واجهة المشغّل.
  void _notifySafely() {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      if (_notifyPending) return;
      _notifyPending = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _notifyPending = false;
        if (hasListeners) notifyListeners();
      });
      return;
    }
    notifyListeners();
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
    _notifySafely();
  }

  Future<void> toggle(Lesson lesson) async {
    if (_currentId == lesson.id) {
      if (_player.playing) {
        await _player.pause();
      } else {
        unawaited(_player.play());
      }
      _notifySafely();
    } else {
      await playLesson(lesson);
    }
  }

  Future<void> playLesson(Lesson lesson) async {
    final local = DownloadService.localAudioPath(lesson.id);
    if (local == null && lesson.audioUrl.isEmpty) {
      _error = 'لا يتوفر رابط صوتي لهذا الدرس.';
      _notifySafely();
      return;
    }
    _error = null;
    _loading = true;
    _currentId = lesson.id;
    _current = lesson;
    _notifySafely();
    try {
      try {
        await _setLessonSource(
          lesson,
          local != null ? Uri.file(local) : Uri.parse(lesson.audioUrl),
        );
      } catch (localError) {
        // إن تلف الملف المحلي نحذفه ونعود للبث بدلاً من تعطيل الدرس كلياً.
        if (local == null || lesson.audioUrl.isEmpty) rethrow;
        debugPrint('Local audio failed, falling back to network: $localError');
        try {
          await DownloadService.deleteDownload(lesson.id);
        } catch (_) {}
        await _setLessonSource(lesson, Uri.parse(lesson.audioUrl));
      }
      await _player.setSpeed(_speed);
      final saved = LocalStore.getPosition(lesson.id);
      if (saved > 3000) {
        await _player.seek(Duration(milliseconds: saved));
      }
      // Future الخاص بـ just_audio لا يكتمل إلا عند انتهاء/إيقاف المقطع؛
      // لذلك نبدأ التشغيل دون جعل الواجهة تنتظر نهاية الدرس.
      unawaited(_player.play().catchError((Object e, StackTrace st) {
        _error = 'توقّف تشغيل الدرس. حاول مجدداً أو تحقق من الاتصال.';
        debugPrint('Async playback error: $e');
        _notifySafely();
      }));
      _recordPlay(lesson);
      _loading = false;
      _notifySafely();
    } catch (e) {
      _loading = false;
      _currentId = null;
      _current = null;
      _error = 'تعذّر تشغيل الدرس. تحقّق من الاتصال بالإنترنت.';
      debugPrint('playLesson error: $e');
      _notifySafely();
    }
  }

  Future<void> _setLessonSource(Lesson lesson, Uri uri) async {
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
        _notifySafely();
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
    _notifySafely();
  }

  Future<void> setSkipSeconds(int sec) async {
    _skipSeconds = sec;
    await LocalStore.setSkipSeconds(sec);
    _notifySafely();
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
        _notifySafely();
      });
    }
    _notifySafely();
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
