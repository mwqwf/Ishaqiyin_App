# تشغيل منبر ادكصهك (Flutter)

## الطريقة التلقائية (مستحسنة)
من PowerShell داخل مجلد المشروع:

```powershell
# إن لم يكن Flutter مثبتاً بعد، ثبّته تلقائياً (تنزيل كبير ~1GB):
./setup.ps1 -InstallFlutter

# أو إن كان Flutter مثبتاً مسبقاً:
./setup.ps1
```

ثم وصّل الهاتف (مع تفعيل «تصحيح USB») وشغّل:

```powershell
flutter devices
flutter run
```

## المتطلبات لمرة واحدة
- **Flutter SDK** (يتضمن Dart): https://docs.flutter.dev/get-started/install/windows
- **Android SDK + Platform tools** (عبر Android Studio أو cmdline-tools)
- **JDK 17** (يأتي عادةً مع Android Studio)
- بعد التثبيت نفّذ `flutter doctor` وعالِج أي ✗.

## ماذا يفعل setup.ps1
1. يولّد سقالة Android: `flutter create --platforms=android --org com.ali --project-name menbaradkshk .`
   - لا يلمس `lib/` ولا `pubspec.yaml` (الموجودان مسبقاً).
2. ينسخ `_overrides/AndroidManifest.xml` فوق المانيفست المولَّد (صلاحيات نظيفة + خدمة الصوت في الخلفية).
3. `flutter pub get`
4. `dart run flutter_launcher_icons` لتوليد أيقونة التطبيق.

## الإعداد اليدوي للمانيفست (لو احتجت)
بعد `flutter create`، استبدل ملف
`android/app/src/main/AndroidManifest.xml`
بمحتوى `_overrides/AndroidManifest.xml`.

## ملاحظة عن Firebase
لا حاجة لإضافة إضافة google-services في Gradle: التطبيق يهيّئ Firebase من
`lib/firebase_options.dart` مباشرةً (قراءة فقط من مشروع `mxqp-8d1e8`).
ملف `android/app/google-services.json` موجود احتياطياً فقط.

## البناء
```powershell
flutter build apk --release        # APK للتجربة/التوزيع المباشر
flutter build appbundle --release  # AAB لمتجر Google Play
```
