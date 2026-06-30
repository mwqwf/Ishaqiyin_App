# منبر ادكصهك (Flutter)

تطبيق **صوتي** معرفي: أقسام ← أقسام فرعية ← دروس صوتية، مع بحث عربي ذكي،
تشغيل في الخلفية، مشغّل مصغّر، تنزيل للاستماع دون إنترنت، مفضّلة، ووضع ليلي.

---

## الميزات الرئيسية

- **مشغّل صوت متكامل**: سرعة 0.75×–2×، قفز ±15 ثانية، مؤقّت نوم، مشغّل مصغّر ثابت
- **بحث عربي**: تطبيع الهمزات والتشكيل، سجلّ بحث، بحث في العناوين والأقسام والشيوخ
- **تنزيلاتي**: قائمة بكل ما نزّلته مع إمكانية الحذف
- **مفضّلة** ♥ و**تابع الاستماع** مع شريط تقدّم
- **مشاركة كرابط** `menbar.app/lesson/<id>` بدل ملف خام
- **تنزيل تلقائي** (Wi‑Fi فقط، أحدث أو مقترح)
- **سلسلة استماع يومية** وإشعار «تابع الاستماع»
- **خصوصية**: كل التخصيص على الجهاز فقط؛ عدّاد `views` مجهول

---

## البنية
```
lib/
  main.dart
  models.dart
  theme.dart
  state/app_state.dart
  utils/           arabic_search, lesson_display, category_colors
  services/        firebase_repo, content_repository, audio_controller,
                   download_service, auto_download, notifications, deep_links
  widgets/         audio_item, mini_player, skeleton_loader
  screens/         home, player, lessons, subcategories, settings,
                   downloads, favorites, search_delegate
```

## التشغيل
انظر **SETUP.md**. باختصار: `./setup.ps1` ثم `flutter run`.

---

## تنبيهات أمنية
1. **قواعد Firestore**: اقرأ COMPLIANCE_AND_RULES.md — انشر قاعدة زيادة `views`.
2. **Deep Links**: يتطلب ملف `assetlinks.json` على `menbar.app` للتحقق التلقائي.
