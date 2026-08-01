import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../models.dart';
import '../services/content_repository.dart';
import '../services/submission_service.dart';
import '../theme.dart';
import '../utils/audio_merge.dart';
import '../utils/smart_title.dart';
import 'my_submissions_screen.dart';

/// 📤 «شارك درساً» — نموذج مساهمة المستمع (نفس استمارة رفع المشرفين:
/// ملف صوتي + عنوان + قسم رئيسي/فرعي حقيقيّان من أقسام التطبيق).
///
/// الفرق الجوهري عن النشر في نبراس (قرار المالك): **لا نشر مباشر** —
/// «نشر» هنا يرسل الطلب لقائمة انتظار المشرفين، وتصل النتيجة إشعاراً:
/// نُشر كما هو / نُشر بعد تعديل مع الشكر / رُفض مع السبب.
class ContributeScreen extends StatefulWidget {
  /// ملفّ وارد من مشاركة خارجية (share-to-app) — يملأ الحقل مسبقاً.
  final String? sharedFilePath;
  final String? sharedFileName;

  const ContributeScreen({super.key, this.sharedFilePath, this.sharedFileName});

  @override
  State<ContributeScreen> createState() => _ContributeScreenState();
}

class _ContributeScreenState extends State<ContributeScreen> {
  final _title = TextEditingController();
  final _name = TextEditingController();
  final _note = TextEditingController();

  String? _categoryId;
  String? _subcategoryId;

  /// الملفات المختارة بالترتيب — أكثر من ملف يعني دمجها في درس واحد.
  final List<({String path, String name})> _files = [];

  bool _submitting = false;
  bool _picking = false;
  bool _merging = false;
  double _progress = 0;
  String _error = '';
  UploadCanceller? _canceller;
  bool _rightsConfirmed = false;
  bool _contentPolicyAccepted = false;

  @override
  void initState() {
    super.initState();
    final sp = widget.sharedFilePath;
    if (sp != null && sp.isNotEmpty) {
      _files.add((
        path: sp,
        name: widget.sharedFileName ?? sp.split(RegExp(r'[/\\]')).last,
      ));
    }
    SubmissionService.getSavedSubmitterName().then((n) {
      if (mounted && n.isNotEmpty && _name.text.isEmpty) {
        setState(() => _name.text = n);
      }
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  List<Category> get _categories => ContentRepository.instance.categories;
  List<Subcategory> get _subsForCategory =>
      ContentRepository.instance.subcategories
          .where((s) => s.categoryId == _categoryId)
          .toList();

  Future<void> _pickAudio() async {
    // نسخ الملفات من منتقي النظام قد يستغرق ثواني للملفات الكبيرة —
    // مؤشر انشغال حتى لا يبدو النموذج متجمّداً وزر الإرسال «بطيئاً».
    setState(() => _picking = true);
    try {
      final res = await FilePicker.platform
          .pickFiles(type: FileType.audio, allowMultiple: true);
      final picked = res?.files
              .where((f) => f.path != null)
              .map((f) => (path: f.path!, name: f.name))
              .toList() ??
          const <({String path, String name})>[];
      if (picked.isEmpty) return;

      final existing = _files.map((f) => f.path).toSet();
      final combined = [
        ..._files,
        ...picked.where((f) => !existing.contains(f.path)),
      ];

      // الدمج المباشر (لصق الإطارات) لا يصح إلا لملفات MP3.
      if (combined.length > 1) {
        final bad = combined.where((f) => !AudioMerger.isMp3(f.name));
        if (bad.isNotEmpty) {
          setState(() => _error =
              'لدمج عدة ملفات يجب أن تكون جميعها MP3 — «${bad.first.name}» ليس كذلك.');
          return;
        }
      }

      setState(() {
        _error = combined.length > AudioMerger.maxFiles
            ? 'الحد الأقصى ${AudioMerger.maxFiles} ملفات للدرس الواحد — أُبقي أولها.'
            : '';
        _files
          ..clear()
          ..addAll(combined.take(AudioMerger.maxFiles));
        if (_title.text.trim().isEmpty && _files.isNotEmpty) {
          // استخراج ذكيّ: يزيل الترقيم وبصمات المواقع؛ الاسم الآليّ
          // البحت (تسجيلات/واتساب) يُترك فارغاً ليكتبه المساهم.
          _title.text = smartTitleFromFileName(_files.first.name);
        }
      });
    } catch (e) {
      setState(() => _error = 'تعذّر اختيار الملفات: $e');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  bool get _canSubmit =>
      !_submitting &&
      _title.text.trim().length >= 3 &&
      _categoryId != null &&
      _subcategoryId != null &&
      _files.isNotEmpty &&
      _name.text.trim().isNotEmpty &&
      _rightsConfirmed &&
      _contentPolicyAccepted;

  Future<void> _submit() async {
    if (!_canSubmit) {
      setState(() => _error =
          'أكمل الحقول المطلوبة، ثم أكّد حقك في النشر والموافقة على ضوابط المحتوى.');
      return;
    }
    setState(() {
      _submitting = true;
      _merging = false;
      _progress = 0;
      _error = '';
    });
    _canceller = UploadCanceller();
    File? mergedTemp;
    try {
      final cat = _categories.firstWhere((c) => c.id == _categoryId);
      final sub = _subsForCategory.firstWhere((s) => s.id == _subcategoryId);

      // ملف واحد يُرفع كما هو؛ أكثر من ملف يُدمج محلياً أولاً ثم يُرفع
      // الناتج كدرس واحد — فيظهر للمستمعين مقطعاً متصلاً بالترتيب المختار.
      File uploadFile;
      String uploadName;
      if (_files.length == 1) {
        uploadFile = File(_files.single.path);
        uploadName = _files.single.name;
      } else {
        var total = 0;
        for (final f in _files) {
          total += await File(f.path).length();
        }
        if (total > SubmissionService.maxFileSizeBytes) {
          throw StateError('file_too_large');
        }
        setState(() => _merging = true);
        final tmp = await getTemporaryDirectory();
        final ts = DateTime.now().millisecondsSinceEpoch;
        mergedTemp = await AudioMerger.mergeMp3(
          inputs: [for (final f in _files) File(f.path)],
          outputPath: '${tmp.path}/merged_$ts.mp3',
        );
        if (mounted) setState(() => _merging = false);
        uploadFile = mergedTemp;
        uploadName = 'merged_$ts.mp3';
      }

      await SubmissionService.submit(
        canceller: _canceller,
        file: uploadFile,
        fileName: uploadName,
        title: _title.text,
        categoryId: cat.id,
        categoryName: cat.name,
        subcategoryId: sub.id,
        subcategoryName: sub.name,
        rightsConfirmed: _rightsConfirmed,
        contentPolicyAccepted: _contentPolicyAccepted,
        submitterName: _name.text,
        note: _note.text,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.mark_email_read_outlined,
              size: 40, color: kGreen),
          title: const Text('وصل طلبك للمشرفين'),
          content: const Text(
            'سيراجع المشرفون مساهمتك، ويصلك إشعار بالنتيجة: '
            'نُشرت كما هي، أو نُشرت بعد تحسينها، أو اعتذار مع السبب.\n'
            'تابع حالتها من «مساهماتي».',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('حسناً'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      final cancelled = _canceller?.cancelled ?? false;
      setState(() {
        _submitting = false;
        _merging = false;
        _error = cancelled
            ? 'أُلغي الرفع.'
            : e is FormatException
                ? 'تعذّر دمج الملفات — تأكد أنها ملفات MP3 سليمة.'
                : e.toString().contains('file_too_large')
                    ? 'الحجم الكلي أكبر من الحدّ المسموح (100MB).'
                    : 'تعذّر إرسال المساهمة. تحقق من اتصالك وحاول مجدداً.';
      });
    } finally {
      _canceller = null;
      // الملف المدموج مؤقت — يُحذف بعد الرفع (أو الفشل) لتوفير المساحة.
      mergedTemp?.delete().ignore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('شارك درساً'),
        actions: [
          IconButton(
            tooltip: 'مساهماتي',
            icon: const Icon(Icons.history_edu_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MySubmissionsScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        // ملاحظة: لا AbsorbPointer هنا — كان سيمتصّ ضغطة «إلغاء الرفع».
        // القيم تُلتقط لحظة الإرسال، وزرّا الاختيار والإرسال معطّلان أثناءه.
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'مساهمتك تُعرض على المشرفين قبل النشر، ويصلك إشعار '
                'بالنتيجة. يُنشر الدرس ضمن أقسام التطبيق الحقيقية.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(height: 1.6),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: (_picking || _submitting) ? null : _pickAudio,
              icon: _picking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(_files.isEmpty
                      ? Icons.audiotrack_rounded
                      : Icons.playlist_add_rounded),
              label: Text(
                _picking
                    ? 'جارٍ تجهيز الملفات…'
                    : _files.isEmpty
                        ? 'اختر ملفاً صوتياً (أو عدّة ملفات لدمجها)'
                        : 'إضافة ملفات أخرى (${_files.length}/${AudioMerger.maxFiles})',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            if (_files.length > 1) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'ستُدمج ${_files.length} ملفات بالترتيب أدناه في درس واحد '
                  'متصل — اسحب المقبض ≡ لإعادة الترتيب.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(height: 1.6),
                ),
              ),
            ],
            if (_files.isNotEmpty)
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: _files.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex--;
                    _files.insert(newIndex, _files.removeAt(oldIndex));
                  });
                },
                itemBuilder: (ctx, i) {
                  final f = _files[i];
                  return ListTile(
                    key: ValueKey(f.path),
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: CircleAvatar(
                      radius: 13,
                      child: Text('${i + 1}',
                          style: const TextStyle(fontSize: 12)),
                    ),
                    title: Text(f.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'إزالة',
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: _submitting
                              ? null
                              : () => setState(() => _files.removeAt(i)),
                        ),
                        if (_files.length > 1)
                          ReorderableDragStartListener(
                            index: i,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6),
                              child: Icon(Icons.drag_handle),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 14),
            TextField(
              controller: _title,
              maxLength: 120,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'عنوان الدرس',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _name,
              maxLength: 50,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'اسمك (يظهر للمشرفين)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _categoryId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'القسم الرئيسي',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final c in _categories)
                  DropdownMenuItem(value: c.id, child: Text(c.name)),
              ],
              onChanged: (v) => setState(() {
                _categoryId = v;
                _subcategoryId = null;
              }),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _subcategoryId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'القسم الفرعي',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final s in _subsForCategory)
                  DropdownMenuItem(value: s.id, child: Text(s.name)),
              ],
              onChanged: (v) => setState(() => _subcategoryId = v),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _note,
              maxLength: 300,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'ملاحظة للمشرفين (اختياري)',
                border: OutlineInputBorder(),
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _rightsConfirmed,
              onChanged: _submitting
                  ? null
                  : (v) => setState(() => _rightsConfirmed = v ?? false),
              title: const Text('أملك حق مشاركة هذا التسجيل'),
              subtitle: const Text(
                'أؤكد أن التسجيل لي أو لدي إذن صريح بنشره في منبر.',
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _contentPolicyAccepted,
              onChanged: _submitting
                  ? null
                  : (v) => setState(() => _contentPolicyAccepted = v ?? false),
              title: const Text('أوافق على ضوابط المحتوى والمراجعة'),
              subtitle: const Text(
                'لا حقوق منتهكة، ولا كراهية أو تحريض أو محتوى غير قانوني، '
                'ويحق للمشرفين الرفض أو التعديل قبل النشر.',
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('ضوابط مشاركة الدروس'),
                    content: const SingleChildScrollView(
                      child: Text(
                        'يُمنع إرسال تسجيل لا تملك حق نشره، أو يتضمن كراهية '
                        'أو تحريضاً أو تهديداً أو انتهاك خصوصية أو نشاطاً غير '
                        'قانوني. كل مساهمة تبقى معلّقة حتى يراجعها المشرفون، '
                        'وقد تُعدّل أو تُرفض مع بيان السبب. عند اكتشاف مخالفة '
                        'يمكن حذف المساهمة وملفها نهائياً.',
                      ),
                    ),
                    actions: [
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('فهمت'),
                      ),
                    ],
                  ),
                ),
                icon: const Icon(Icons.policy_outlined),
                label: const Text('قراءة الضوابط'),
              ),
            ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                _error,
                style: TextStyle(color: scheme.error),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 8),
            if (_submitting) ...[
              LinearProgressIndicator(
                value: (!_merging && _progress > 0) ? _progress / 100 : null,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _merging
                        ? 'جارٍ دمج الملفات في مقطع واحد…'
                        : 'جارٍ الرفع… ${_progress.toStringAsFixed(0)}%',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (!_merging) ...[
                    const SizedBox(width: 12),
                    TextButton.icon(
                      onPressed: () => _canceller?.cancel(),
                      icon: Icon(Icons.close, size: 18, color: scheme.error),
                      label: Text('إلغاء الرفع',
                          style: TextStyle(color: scheme.error)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
            ],
            FilledButton.icon(
              onPressed: _canSubmit ? _submit : null,
              icon: const Icon(Icons.send_rounded),
              label: const Text('إرسال للمراجعة'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
