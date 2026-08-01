import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';
import 'anonymous_identity_service.dart';
import 'local_store.dart';

/// حالة مساهمة مستمع واحدة كما تُعرض في «مساهماتي».
class LessonSubmission {
  final String id;
  final String title;
  final String categoryName;
  final String subcategoryName;
  final String status; // pending | approved | approved_edited | rejected
  final String rejectReason;
  final String storagePath;
  final DateTime? createdAt;

  /// لحظة حسم القرار بالمللي ثانية (0 إن لم تُحسم المساهمة بعد).
  final int decidedAtMs;

  const LessonSubmission({
    required this.id,
    required this.title,
    required this.categoryName,
    required this.subcategoryName,
    required this.status,
    this.rejectReason = '',
    this.storagePath = '',
    this.createdAt,
    this.decidedAtMs = 0,
  });

  factory LessonSubmission.fromDoc(DocumentSnapshot doc) {
    final d = (doc.data() as Map<String, dynamic>?) ?? const {};
    String s(dynamic v) => (v ?? '').toString();
    DateTime? parseDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    // لحظة القرار: Timestamp خادمي إن وُجد، وإلا النص القديم، وإلا 0.
    int decidedMs() {
      final ts = d['decidedAtTs'];
      if (ts is Timestamp) return ts.millisecondsSinceEpoch;
      final parsed = DateTime.tryParse(s(d['decidedAt']));
      return parsed?.millisecondsSinceEpoch ?? 0;
    }

    return LessonSubmission(
      id: doc.id,
      title: s(d['title']),
      categoryName: s(d['categoryName']),
      subcategoryName: s(d['subcategoryName']),
      status: s(d['status']).isEmpty ? 'pending' : s(d['status']),
      rejectReason: s(d['rejectReason']),
      storagePath: s(d['storagePath']),
      createdAt: parseDate(d['createdAt']),
      decidedAtMs: decidedMs(),
    );
  }
}

/// مقبض إلغاء لرفع جارٍ: زر «إلغاء الرفع» في النموذج يستدعي [cancel]
/// فيتوقف الرفع فوراً ويُرمى خطأ 'canceled' يعالجه النموذج برسالة لطيفة.
class UploadCanceller {
  UploadTask? _task;
  bool _cancelled = false;
  bool get cancelled => _cancelled;

  void attach(UploadTask task) {
    _task = task;
    if (_cancelled) task.cancel();
  }

  Future<void> cancel() async {
    _cancelled = true;
    try {
      await _task?.cancel();
    } catch (_) {}
  }
}

/// 📤 «شارك درساً» — مساهمات المستمعين في منبر ادكصهك.
///
/// سياسة منبر (قرار المالك — عكس نبراس المفتوح): **لا يُنشر شيء مباشرة**؛
/// المساهمة تذهب طلباً معلّقاً في `lesson_submissions` يراجعه المشرفون في
/// تطبيق الإدارة (يوافقون كما هي / يعدّلونها ثم ينشرون / يرفضون بسبب)،
/// وتصل النتيجة للمساهم إشعاراً.
///
/// الهويّة: دخول مجهول (Anonymous Auth) يُنشأ بصمت عند أوّل مساهمة —
/// بلا أيّ شاشة تسجيل، ويكفي لربط المساهمات بصاحبها في قواعد الأمان.
class SubmissionService {
  SubmissionService._();

  static const String collection = 'lesson_submissions';
  static const int maxFileSizeBytes = 100 * 1024 * 1024;
  static const String contentPolicyVersion = '2026-07-16';
  static const _prefsKnownStatuses = 'submission_known_statuses_v1';
  static const _prefsSubmitterName = 'submitter_name_v1';

  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static FirebaseFunctions get _functions => FirebaseFunctions.instance;
  static StreamSubscription<QuerySnapshot>? _watcher;
  static StreamSubscription<String>? _tokenWatcher;

  /// دخول مجهول كسول — لا يعمل شيئاً إن كانت الجلسة قائمة.
  static Future<User> ensureSignedIn() async {
    return AnonymousIdentityService.ensureSignedIn();
  }

  /// هل سبق للمستخدم أن ساهم؟ (نستعملها لتفعيل مراقب النتائج عند الإقلاع
  /// بلا إنشاء جلسات مجهولة لمن لم يساهم قط.)
  static bool get hasIdentity => FirebaseAuth.instance.currentUser != null;

  static Future<String> getSavedSubmitterName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefsSubmitterName) ?? '';
  }

  /// يرفع الصوت ثم ينشئ طلب المساهمة. يعيد معرّف الطلب.
  static Future<String> submit({
    required File file,
    required String fileName,
    required String title,
    required String categoryId,
    required String categoryName,
    required String subcategoryId,
    required String subcategoryName,
    required bool rightsConfirmed,
    required bool contentPolicyAccepted,
    String submitterName = '',
    String note = '',
    void Function(double percent)? onProgress,
    UploadCanceller? canceller,
  }) async {
    if (!rightsConfirmed || !contentPolicyAccepted) {
      throw StateError('content_terms_required');
    }
    final user = await ensureSignedIn();

    final size = await file.length();
    if (size > maxFileSizeBytes) {
      throw StateError('file_too_large');
    }

    final prefs = await SharedPreferences.getInstance();
    if (submitterName.trim().isNotEmpty) {
      await prefs.setString(_prefsSubmitterName, submitterName.trim());
    }

    final id = 'sub_${DateTime.now().millisecondsSinceEpoch}';
    final storagePath = 'submissions/${user.uid}/$id/$fileName';
    final ref = FirebaseStorage.instance.ref(storagePath);
    final task = ref.putFile(
      file,
      SettableMetadata(contentType: _mimeFor(fileName)),
    );
    canceller?.attach(task);
    task.snapshotEvents.listen((s) {
      if (s.totalBytes > 0 && onProgress != null) {
        onProgress(s.bytesTransferred / s.totalBytes * 100);
      }
    }, onError: (_) {});
    var uploaded = false;
    var callableStarted = false;
    try {
      await task;
      uploaded = true;
      final url = await ref.getDownloadURL();
      String fcmToken = '';
      if (LocalStore.getNotificationsEnabled()) {
        try {
          fcmToken = await FirebaseMessaging.instance.getToken() ?? '';
        } catch (_) {}
      }

      final payload = <String, dynamic>{
        'id': id,
        'uid': user.uid,
        'submitterName': submitterName.trim(),
        'title': title.trim(),
        'categoryId': categoryId,
        'categoryName': categoryName,
        'subcategoryId': subcategoryId,
        'subcategoryName': subcategoryName,
        'note': note.trim(),
        'audioUrl': url,
        'storagePath': storagePath,
        'fileName': fileName,
        'fileSize': size,
        'fcmToken': fcmToken,
        'rightsConfirmed': rightsConfirmed,
        'contentPolicyVersion': contentPolicyVersion,
        'termsAcceptedAt': DateTime.now().toUtc().toIso8601String(),
      };
      HttpsCallableResult<dynamic> result;
      try {
        callableStarted = true;
        result =
            await _functions.httpsCallable('createSubmission').call(payload);
      } catch (_) {
        // إعادة آمنة بنفس المعرّف: الخادم idempotent، وهذا يحمي من ضياع ACK.
        await Future<void>.delayed(const Duration(milliseconds: 300));
        result =
            await _functions.httpsCallable('createSubmission').call(payload);
      }
      final data = result.data;
      final returnedId = data is Map ? (data['id'] ?? '').toString() : '';
      if (returnedId.isEmpty) throw StateError('invalid_server_response');

      startDecisionWatcher();
      return returnedId;
    } catch (error) {
      if (callableStarted) {
        try {
          final existing = await _db.collection(collection).doc(id).get();
          final data = existing.data();
          if (existing.exists && data?['storagePath'] == storagePath) {
            startDecisionWatcher();
            return id;
          }
        } catch (_) {}
      }
      // لا نحذف في خطأ شبكة مبهم؛ قد يكون الخادم أنشأ السجل وضاع الرد.
      final shouldRollback = !callableStarted || _isDefinitiveRejection(error);
      if (uploaded && shouldRollback) {
        try {
          await ref.delete();
        } catch (e) {
          debugPrint('submission rollback failed for $storagePath: $e');
        }
      }
      rethrow;
    }
  }

  static bool _isDefinitiveRejection(Object error) {
    if (error is! FirebaseFunctionsException) return false;
    return const <String>{
      'invalid-argument',
      'permission-denied',
      'unauthenticated',
      'resource-exhausted',
      'failed-precondition',
    }.contains(error.code);
  }

  static String _mimeFor(String fileName) {
    final ext =
        fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    switch (ext) {
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'ogg':
        return 'audio/ogg';
      case 'opus':
        return 'audio/opus';
      case 'aac':
        return 'audio/aac';
      case 'm4a':
        return 'audio/mp4';
      case 'amr':
        return 'audio/amr';
      case 'flac':
        return 'audio/flac';
      default:
        return 'audio/mpeg';
    }
  }

  /// مساهمات المستخدم الحالي (الأحدث أولاً) لشاشة «مساهماتي».
  static Stream<List<LessonSubmission>> watchMine() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(const []);
    return _db
        .collection(collection)
        .where('uid', isEqualTo: uid)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map(LessonSubmission.fromDoc).toList();
      list.sort((a, b) =>
          (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return list;
    });
  }

  /// حذف طلب معلّق (تراجع المساهم قبل المراجعة).
  static Future<void> deletePending(LessonSubmission s) async {
    if (s.status != 'pending') return;
    await _functions.httpsCallable('deleteMySubmission').call<void>({
      'submissionId': s.id,
    });
  }

  /// يحدّث رموز الإشعار في الطلبات المعلّقة عند تدوير FCM للرمز.
  static Future<void> refreshPendingToken([String? suppliedToken]) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    var token = '';
    if (LocalStore.getNotificationsEnabled()) {
      token =
          suppliedToken ?? await FirebaseMessaging.instance.getToken() ?? '';
      if (token.isEmpty) return;
    }
    final snap = await _db
        .collection(collection)
        .where('uid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .get();
    if (snap.docs.isEmpty) return;
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'fcmToken': token});
    }
    await batch.commit();
  }

  /// حذف بيانات الحساب السحابية عبر الخادم ثم إنهاء الهوية المحلية.
  static Future<void> deleteMyData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _functions.httpsCallable('deleteMyData').call();
    await FirebaseAuth.instance.signOut();
    stopDecisionWatcher();
  }

  /// مراقب قرارات المشرفين: عند تحوّل حالة مساهمة يعرض إشعاراً محليّاً
  /// (يعمل والتطبيق مفتوح؛ وعند إغلاقه تصل رسالة FCM من دالة السحابة).
  static void startDecisionWatcher() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _watcher != null) return;
    refreshPendingToken().catchError((Object e) {
      debugPrint('initial submission token sync failed: $e');
    });
    _tokenWatcher ??= FirebaseMessaging.instance.onTokenRefresh.listen(
      (token) => refreshPendingToken(token).catchError((Object e) {
        debugPrint('refresh submission token failed: $e');
      }),
    );
    _watcher = _db
        .collection(collection)
        .where('uid', isEqualTo: uid)
        .snapshots()
        .listen((snap) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final known = prefs.getStringList(_prefsKnownStatuses) ?? const [];
        final knownMap = <String, String>{
          for (final e in known)
            if (e.contains('=')) e.split('=').first: e.split('=').last,
        };
        var changed = false;
        for (final doc in snap.docs) {
          final s = LessonSubmission.fromDoc(doc);
          final prev = knownMap[s.id];
          knownMap[s.id] = s.status;
          if (prev == null || prev == s.status) {
            changed = changed || prev == null;
            continue;
          }
          changed = true;
          if (s.status == 'approved') {
            await NotificationService.showContentNotification(
              'نُشرت مساهمتك 🎉',
              'وافق المشرفون على «${s.title}» ونُشرت كما هي. شكراً لمساهمتك!',
              payload: 'submissions',
            );
          } else if (s.status == 'approved_edited') {
            await NotificationService.showContentNotification(
              'نُشرت مساهمتك بعد تعديل 🎉',
              'نُشرت «${s.title}» بعد تحسينها من المشرفين. شكراً لمساهمتك!',
              payload: 'submissions',
            );
          } else if (s.status == 'rejected') {
            await NotificationService.showContentNotification(
              'اعتذار عن نشر مساهمتك',
              s.rejectReason.isEmpty
                  ? 'لم يوافق المشرفون على «${s.title}».'
                  : 'لم تُنشر «${s.title}»: ${s.rejectReason}',
              payload: 'submissions',
            );
          }
        }
        if (changed) {
          await prefs.setStringList(
            _prefsKnownStatuses,
            knownMap.entries.map((e) => '${e.key}=${e.value}').toList(),
          );
        }
      } catch (e) {
        debugPrint('decision watcher failed: $e');
      }
    }, onError: (Object e) {
      debugPrint('decision watcher stream error: $e');
    });
  }

  static void stopDecisionWatcher() {
    _watcher?.cancel();
    _watcher = null;
    _tokenWatcher?.cancel();
    _tokenWatcher = null;
  }
}
