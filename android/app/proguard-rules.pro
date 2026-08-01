# قواعد keep لنسخة release المقلَّصة بـ R8.
# مكتبات Flutter وFirebase تشحن قواعدها الاستهلاكية تلقائياً؛ ما يلي يغطي
# الحالات المعروفة التي لا تغطّيها تلك القواعد.

# flutter_local_notifications: يسترجع الإشعارات المجدولة عبر Gson بأنواع
# generics — حذف التواقيع يكسر إعادة الجدولة بعد إعادة التشغيل.
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.dexterous.** { *; }
-keep class com.google.gson.** { *; }
-keep class * extends com.google.gson.reflect.TypeToken

# just_audio_background (audio_service): استقبال أوامر أزرار الوسائط.
-keep class com.ryanheise.audioservice.** { *; }

# play-services-safetynet مُستبعَدة عمداً في build.gradle.kts (مهملة من Google)
# بينما firebase-appcheck ما زال يشير لفئاتها في مسار ميت لا يُنفَّذ
# (نستعمل Play Integrity) — بدون هذا السطر يفشل R8 بـ Missing class.
-dontwarn com.google.android.gms.safetynet.**
