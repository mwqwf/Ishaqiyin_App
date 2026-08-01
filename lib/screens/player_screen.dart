import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models.dart';
import '../services/audio_controller.dart';
import '../services/content_repository.dart';
import '../services/download_service.dart';
import '../services/firebase_repo.dart';
import '../services/local_store.dart';
import '../theme.dart';
import '../utils/category_colors.dart';
import '../utils/lesson_display.dart';
import 'lessons_screen.dart';
import 'playlists_screen.dart';
import 'subcategories_screen.dart';

String _fmt(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  if (h > 0) {
    return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '$m:${s.toString().padLeft(2, '0')}';
}

class PlayerScreen extends StatefulWidget {
  final Lesson lesson;
  final List<Lesson> playlist;

  /// عند فتح الدرس من «لحظة» مشاركة: ابدأ التشغيل عند هذه الثانية.
  final int? startAtMs;
  const PlayerScreen({
    super.key,
    required this.lesson,
    required this.playlist,
    this.startAtMs,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final AudioController _audio = AudioController.instance;
  List<Lesson> _all = [];
  bool _downloading = false;
  double _progress = 0;

  static const _speeds = [0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  @override
  void initState() {
    super.initState();
    final repo = ContentRepository.instance;
    _all = repo.lessons;
    // شريط العنوان خارج AnimatedBuilder — نستمع للمشغّل كي تتحدّث أيقونة
    // المفضّلة (وبقية الأزرار) عند الانتقال التلقائي للدرس التالي.
    _audio.addListener(_onAudioChanged);
    _audio.setPlaylist(
        widget.playlist.isNotEmpty ? widget.playlist : [widget.lesson]);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (widget.startAtMs != null) {
        await _audio.playLesson(widget.lesson);
        if (mounted) {
          await _audio.seek(Duration(milliseconds: widget.startAtMs!));
        }
      } else if (!_audio.isActive(widget.lesson.id)) {
        await _audio.playLesson(widget.lesson);
      }
    });
  }

  @override
  void dispose() {
    _audio.removeListener(_onAudioChanged);
    super.dispose();
  }

  void _onAudioChanged() {
    if (mounted) setState(() {});
  }

  Lesson get _current => _audio.currentLesson ?? widget.lesson;

  Subcategory? _subOf(Lesson l) =>
      ContentRepository.instance.subcategoryById(l.subcategoryId);
  Category? _catOf(Lesson l) =>
      ContentRepository.instance.categoryById(l.categoryId);

  Future<void> _toggleFavorite(Lesson l) async {
    await LocalStore.toggleFavorite(l.id);
    if (mounted) setState(() {});
  }

  Future<void> _download(Lesson l) async {
    if (_downloading) return;
    if (l.audioUrl.isEmpty) {
      _snack('لا يتوفر رابط صوتي لهذا الدرس.');
      return;
    }
    setState(() {
      _downloading = true;
      _progress = 0;
    });
    try {
      await DownloadService.downloadAudio(
        l.id,
        l.audioUrl,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      _snack('تم التحميل بنجاح.');
    } catch (_) {
      _snack('تعذر التحميل.');
    }
    if (mounted) setState(() => _downloading = false);
  }

  Future<void> _share(Lesson l) async {
    final cat = _catOf(l);
    final sub = _subOf(l);
    final pos = _audio.isActive(l.id) ? _audio.player.position : Duration.zero;
    var text = lessonShareText(
      l,
      categoryName: cat?.name,
      subName: sub?.name,
      startAtSeconds: pos.inSeconds > 10 ? pos.inSeconds : null,
    );
    if (pos.inSeconds > 10) {
      text +=
          '\nمن الدقيقة ${pos.inMinutes}:${(pos.inSeconds % 60).toString().padLeft(2, '0')}';
    }
    // نشارك رابط الدرس فقط حفاظاً على حقوق التسجيل وعدم توزيع الملف الخام.
    await Share.share(text, subject: lessonDisplayTitle(l));
  }

  Future<void> _addToPlaylist(Lesson l) async {
    final playlists = LocalStore.getPlaylists();
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('إضافة إلى قائمة',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.add, color: kTeal),
              title: const Text('قائمة جديدة'),
              onTap: () async {
                final name = await askPlaylistName(ctx);
                if (name == null || name.isEmpty) return;
                final p = await LocalStore.createPlaylist(name);
                await LocalStore.addToPlaylist(p.id, l.id);
                if (ctx.mounted) Navigator.pop(ctx);
                _snack('أُضيف إلى "${p.name}"');
              },
            ),
            for (final p in playlists)
              ListTile(
                leading: const Icon(Icons.queue_music),
                title: Text(p.name),
                subtitle: Text('${p.lessonIds.length} صوتية'),
                onTap: () async {
                  await LocalStore.addToPlaylist(p.id, l.id);
                  if (ctx.mounted) Navigator.pop(ctx);
                  _snack('أُضيف إلى "${p.name}"');
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showSleepPicker() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('مؤقّت نوم',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            for (final min in [5, 10, 15, 30, 45, 60])
              ListTile(
                title: Text('$min دقيقة'),
                onTap: () {
                  _audio.setSleepTimer(Duration(minutes: min));
                  Navigator.pop(ctx);
                  _snack('سيتوقف التشغيل بعد $min دقيقة');
                },
              ),
            if (_audio.sleepEndsAt != null)
              ListTile(
                leading: const Icon(Icons.cancel, color: Colors.red),
                title: const Text('إلغاء المؤقّت'),
                onTap: () {
                  _audio.cancelSleepTimer();
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _sendFeedback(Lesson l, String type) async {
    var note = '';
    if (type != 'benefited') {
      final ctrl = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title:
              Text(type == 'audio_issue' ? 'مشكلة في الصوت' : 'إبلاغ عن مشكلة'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'صف المشكلة (اختياري)'),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('إرسال')),
          ],
        ),
      );
      if (ok != true) return;
      note = ctrl.text.trim();
    }
    try {
      await FirebaseRepo.sendFeedback(l.id, type, note);
      _snack('شكراً لك — وصلنا تفاعلك.');
    } catch (_) {
      _snack('تعذّر إرسال البلاغ. تحقق من الاتصال وحاول مجدداً.');
    }
  }

  // ---------------- «اللحظات»: علامات صوتية بتوقيت ----------------
  Future<void> _addMomentNow(Lesson l) async {
    final pos = _audio.isActive(l.id) ? _audio.player.position : Duration.zero;
    final note = await _askMomentNote();
    if (note == null) return; // ألغى
    await LocalStore.addBookmark(l.id, pos.inMilliseconds, note);
    _snack('حُفظت اللحظة عند ${_fmt(pos)}');
  }

  Future<String?> _askMomentNote() {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حفظ لحظة'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'ملاحظة (اختياري)'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('حفظ')),
        ],
      ),
    );
  }

  Future<void> _shareMoment(Lesson l, int ms) async {
    final sec = (ms / 1000).round();
    final title = lessonDisplayTitle(l);
    final t = _fmt(Duration(milliseconds: ms));
    await Share.share(
      'استمع إلى هذه اللحظة من «$title» (من $t):\n'
      '${lessonShareLink(l, startAtSeconds: sec)}',
      subject: title,
    );
  }

  void _showMoments(Lesson l) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final moments = LocalStore.getBookmarks(l.id);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('لحظات هذا الدرس',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.add_location_alt_outlined),
                    label: const Text('احفظ اللحظة الحالية'),
                    onPressed: () async {
                      await _addMomentNow(l);
                      setSheet(() {});
                    },
                  ),
                  const SizedBox(height: 8),
                  if (moments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('لا لحظات محفوظة بعد.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey)),
                    )
                  else
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: moments.map((b) {
                          final ms = b['ms'] as int;
                          final note = (b['note'] ?? '').toString();
                          final savedAt = (b['savedAt'] ?? 0) as int;
                          return ListTile(
                            leading: const Icon(Icons.play_circle_outline,
                                color: kTeal),
                            title: Text(_fmt(Duration(milliseconds: ms))),
                            subtitle: note.isNotEmpty ? Text(note) : null,
                            onTap: () {
                              if (!_audio.isActive(l.id)) {
                                _audio.playLesson(l).then((_) =>
                                    _audio.seek(Duration(milliseconds: ms)));
                              } else {
                                _audio.seek(Duration(milliseconds: ms));
                              }
                              Navigator.pop(ctx);
                            },
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'مشاركة اللحظة',
                                  icon: const Icon(Icons.share, color: kTeal),
                                  onPressed: () => _shareMoment(l, ms),
                                ),
                                IconButton(
                                  tooltip: 'حذف',
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.red),
                                  onPressed: () async {
                                    await LocalStore.removeBookmark(
                                        l.id, savedAt);
                                    setSheet(() {});
                                  },
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الآن يُشغَّل'),
        actions: [
          IconButton(
            tooltip: 'اللحظات',
            icon: const Icon(Icons.bookmark_add_outlined),
            onPressed: () => _showMoments(_current),
          ),
          IconButton(
            tooltip: 'إضافة إلى قائمة',
            icon: const Icon(Icons.playlist_add),
            onPressed: () => _addToPlaylist(_current),
          ),
          Builder(builder: (context) {
            final fav = LocalStore.isFavorite(_current.id);
            return IconButton(
              tooltip: fav ? 'إزالة من المفضّلة' : 'إضافة للمفضّلة',
              icon: Icon(
                fav ? Icons.favorite : Icons.favorite_border,
                color: fav ? Colors.red : null,
              ),
              onPressed: () => _toggleFavorite(_current),
            );
          }),
          PopupMenuButton<String>(
            tooltip: 'تفاعل',
            icon: const Icon(Icons.more_vert),
            onSelected: (v) => _sendFeedback(_current, v),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'benefited',
                child: ListTile(
                    leading: Icon(Icons.thumb_up_alt_outlined),
                    title: Text('استفدت من الدرس')),
              ),
              PopupMenuItem(
                value: 'audio_issue',
                child: ListTile(
                    leading: Icon(Icons.volume_off),
                    title: Text('مشكلة في الصوت')),
              ),
              PopupMenuItem(
                value: 'copyright',
                child: ListTile(
                    leading: Icon(Icons.copyright_outlined),
                    title: Text('انتهاك حقوق نشر')),
              ),
              PopupMenuItem(
                value: 'abuse',
                child: ListTile(
                    leading: Icon(Icons.gpp_maybe_outlined),
                    title: Text('محتوى غير مناسب')),
              ),
              PopupMenuItem(
                value: 'other',
                child: ListTile(
                    leading: Icon(Icons.report_gmailerrorred),
                    title: Text('إبلاغ عن هذا الدرس')),
              ),
            ],
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _audio,
        builder: (context, _) {
          final l = _current;
          final sub = _subOf(l);
          final cat = _catOf(l);
          final similar = FirebaseRepo.similarTo(l, _all);
          final downloaded = DownloadService.isAudioDownloaded(l.id);
          final accent = colorForCategory(l.categoryId);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_audio.error != null)
                MaterialBanner(
                  content: Text(_audio.error!),
                  leading: const Icon(Icons.error_outline, color: Colors.red),
                  actions: [
                    TextButton(
                      onPressed: () {
                        _audio.clearError();
                        _audio.playLesson(l);
                      },
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              if (_audio.isLoading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: LinearProgressIndicator(color: kTeal),
                ),
              _artwork(accent),
              const SizedBox(height: 18),
              Text(
                lessonDisplayTitle(l),
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              if (l.speaker.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(l.speaker,
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 15, color: Colors.grey.shade600)),
              ],
              const SizedBox(height: 14),
              _SeekBarLarge(audio: _audio),
              const SizedBox(height: 6),
              _skipRow(),
              const SizedBox(height: 8),
              _speedRow(),
              const SizedBox(height: 8),
              _controls(l, downloaded),
              _autoplayToggle(),
              if (_audio.sleepEndsAt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'مؤقّت النوم: ${_fmt(_audio.sleepEndsAt!.difference(DateTime.now()))}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: kOrange, fontSize: 13),
                  ),
                ),
              const Divider(height: 32),
              _sectionNav(l, sub, cat),
              const Divider(height: 32),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('صوتيات مشابهة',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              if (similar.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('لا توجد اقتراحات بعد.',
                      style: TextStyle(color: Colors.grey)),
                )
              else
                ...similar.map((s) => _similarTile(s, similar)),
            ],
          );
        },
      ),
    );
  }

  Widget _artwork(Color accent) {
    return Center(
      child: Container(
        width: 180,
        height: 180,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [accent, kSlate],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: const [
            BoxShadow(
                color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 8)),
          ],
        ),
        child: Icon(iconForCategory(_current.categoryId),
            color: Colors.white, size: 84),
      ),
    );
  }

  Widget _skipRow() {
    final sec = _audio.skipSeconds;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton.icon(
          icon: const Icon(Icons.replay_10, color: kBlue),
          label: Text('$secث'),
          onPressed: _audio.skipBackward,
        ),
        TextButton.icon(
          icon: const Icon(Icons.forward_10, color: kBlue),
          label: Text('$secث'),
          onPressed: _audio.skipForward,
        ),
        TextButton.icon(
          icon: const Icon(Icons.bedtime_outlined, color: kTeal),
          label: const Text('نوم'),
          onPressed: _showSleepPicker,
        ),
      ],
    );
  }

  Widget _speedRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _speeds.map((s) {
          final active = (_audio.speed - s).abs() < 0.01;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text('$s×'),
              selected: active,
              onSelected: (_) => _audio.setSpeed(s),
              selectedColor: kTeal.withValues(alpha: 0.3),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _controls(Lesson l, bool downloaded) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _downloading
            ? SizedBox(
                width: 48,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    Text('${_progress.toStringAsFixed(0)}%',
                        style: const TextStyle(fontSize: 11)),
                  ],
                ),
              )
            : Semantics(
                label: downloaded ? 'تم التحميل' : 'تحميل',
                button: true,
                child: IconButton(
                  tooltip:
                      downloaded ? 'تم التحميل' : 'تحميل للاستماع دون إنترنت',
                  icon: Icon(
                    downloaded ? Icons.download_done : Icons.download_outlined,
                    color: downloaded ? kGreen : kOrange,
                  ),
                  onPressed: downloaded ? null : () => _download(l),
                ),
              ),
        Semantics(
          label: 'السابق',
          button: true,
          child: IconButton(
            iconSize: 40,
            icon: const Icon(Icons.skip_previous, color: kBlue),
            onPressed: _audio.playPrevious,
          ),
        ),
        _bigPlay(l),
        Semantics(
          label: 'التالي',
          button: true,
          child: IconButton(
            iconSize: 40,
            icon: const Icon(Icons.skip_next, color: kBlue),
            onPressed: _audio.playNext,
          ),
        ),
        Semantics(
          label: 'مشاركة',
          button: true,
          child: IconButton(
            tooltip: 'مشاركة',
            icon: const Icon(Icons.share, color: kTeal),
            onPressed: () => _share(l),
          ),
        ),
      ],
    );
  }

  Widget _bigPlay(Lesson l) {
    final playing = _audio.isActive(l.id) && _audio.playing;
    final loading = _audio.isActive(l.id) && _audio.isLoading;
    return Semantics(
      label: playing ? 'إيقاف' : 'تشغيل',
      button: true,
      child: InkWell(
        onTap: loading ? null : () => _audio.toggle(l),
        borderRadius: BorderRadius.circular(36),
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: playing ? kGreen : kOrange,
            shape: BoxShape.circle,
          ),
          child: loading
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Icon(playing ? Icons.pause : Icons.play_arrow,
                  color: Colors.white, size: 42),
        ),
      ),
    );
  }

  Widget _autoplayToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.playlist_play, size: 20, color: Colors.grey),
        const SizedBox(width: 8),
        const Text('تشغيل تلقائي للتالي'),
        Switch(
          value: _audio.autoplay,
          onChanged: (v) => _audio.autoplay = v,
        ),
      ],
    );
  }

  Widget _sectionNav(Lesson l, Subcategory? sub, Category? cat) {
    final subName = (sub?.name.isNotEmpty ?? false) ? sub!.name : 'فتح القسم';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (l.subcategoryId.isNotEmpty)
          FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
                alignment: AlignmentDirectional.centerStart),
            icon: const Icon(Icons.folder_open),
            label: Text('القسم الفرعي: $subName'),
            onPressed: () {
              final s = sub ??
                  Subcategory(
                    id: l.subcategoryId,
                    name: 'القسم الفرعي',
                    categoryId: l.categoryId,
                    createdAt: l.createdAt,
                  );
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => LessonsScreen(subcategory: s)),
              );
            },
          ),
        if (cat != null) ...[
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
                alignment: AlignmentDirectional.centerStart),
            icon: const Icon(Icons.folder),
            label: Text('القسم الرئيسي: ${cat.name}'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => SubcategoriesScreen(category: cat)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _similarTile(Lesson s, List<Lesson> playlist) {
    final sub = _subOf(s);
    final active = _audio.isActive(s.id);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: active ? kGreen : colorForCategory(s.categoryId),
          child: Icon(
            active && _audio.playing ? Icons.pause : Icons.play_arrow,
            color: Colors.white,
          ),
        ),
        title: Text(lessonDisplayTitle(s),
            maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: (sub?.name.isNotEmpty ?? false)
            ? Text(sub!.name, style: const TextStyle(fontSize: 12))
            : null,
        onTap: () {
          _audio.setPlaylist(playlist);
          _audio.toggle(s);
        },
      ),
    );
  }
}

class _SeekBarLarge extends StatefulWidget {
  final AudioController audio;
  const _SeekBarLarge({required this.audio});

  @override
  State<_SeekBarLarge> createState() => _SeekBarLargeState();
}

class _SeekBarLargeState extends State<_SeekBarLarge> {
  /// موضع السحب المؤقّت — يُعرض أثناء الجرّ ويُنفَّذ seek واحد عند الإفلات
  /// (seek مع كل حركة كان يسبب تقطيعاً محسوساً في البث على الشبكات الضعيفة).
  double? _dragMs;

  AudioController get audio => widget.audio;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: audio.positionStream,
      builder: (context, snapshot) {
        final pos = snapshot.data ?? Duration.zero;
        final total = audio.duration;
        final maxMs =
            total.inMilliseconds <= 0 ? 1.0 : total.inMilliseconds.toDouble();
        final shownMs = _dragMs ?? pos.inMilliseconds.toDouble();
        final value = shownMs.clamp(0.0, maxMs);
        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(trackHeight: 3),
              child: Slider(
                min: 0,
                max: maxMs,
                value: value,
                activeColor: kGreen,
                onChanged: (v) => setState(() => _dragMs = v),
                onChangeEnd: (v) {
                  _dragMs = null;
                  audio.seek(Duration(milliseconds: v.toInt()));
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_fmt(Duration(milliseconds: value.toInt())),
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  Text(_fmt(total),
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
