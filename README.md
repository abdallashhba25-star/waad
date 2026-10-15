# مجاهد — وعدك مع القرآن

تطبيق Flutter (Android) للورد القرآني اليومي: مصحف بخطوط المصحف المدني، ختمة شهرية
موزّعة على الصلوات الخمس، وإشعار تذكيري بعد كل صلاة.

## طريقة البناء على GitHub
1. ارفع محتوى هذا المجلد إلى مستودع GitHub كما هو (الملفات في الجذر).
2. من تبويب **Actions** شغّل الوركفلو **Build APK** يدويًا (Run workflow).
3. بعد انتهاء البناء نزّل الـ Artifact باسم `mujahid-apk` واستخرج منه `app-release.apk`.

الملفات التي يجب أن تكون في جذر المستودع:

```
.github/workflows/build.yml   ← أو ارفعه باسم build.yml ثم انسخه إلى .github/workflows/
pubspec.yaml
main.dart
patch_android.py
icon.png
icon_fg.png
assets/fonts/Amiri-Regular.ttf
assets/fonts/Amiri-Bold.ttf
assets/fonts/AmiriQuran-Regular.ttf
```

> ملاحظة: ملف الوركفلو يجب أن يكون في `.github/workflows/build.yml`.
> إن رفعت الملف باسم `build.yml` في الجذر فقط، فانقله إلى المسار أعلاه.

## ما الذي تغيّر في هذه النسخة (v2.0.0+4 — إصلاح فشل البناء)

### ١) سبب فشل البناء السابق
مكتبة `flutter_local_notifications` بدءًا من الإصدار **22.0.0** حوّلت معاملاتها من
«موضعية» (positional) إلى «مسمّاة» (named) في الدوال: `initialize` و`show` و`cancel`
و`zonedSchedule` و`periodicallyShow`. لذلك ظهرت الأخطاء التالية في السجل:

```
lib/main.dart:914:31:  Error: Too many positional arguments: 0 allowed, but 1 found.
lib/main.dart:978:34:  Error: Too many positional arguments: 0 allowed, but 5 found.
lib/main.dart:990:36:  Error: Too many positional arguments: 0 allowed, but 5 found.
lib/main.dart:1058:25: Error: Too many positional arguments: 0 allowed, but 4 found.
Target kernel_snapshot_program failed: Exception
```

### ٢) الإصلاح
أُعيدت كتابة نداءات الإشعارات في `main.dart` بالصيغة المسمّاة الصحيحة:

```dart
await _plugin.initialize(settings: settings);

await _plugin.zonedSchedule(
  id: id,
  title: title,
  body: body,
  scheduledDate: tzWhen,
  notificationDetails: _details(body: body, channelId: channelId, channelName: channelName),
  androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
  matchDateTimeComponents: repeatDaily ? DateTimeComponents.time : null,
);

await _plugin.show(
  id: _dailyId + 1,
  title: title,
  body: body,
  notificationDetails: _details(body: body, channelId: _quranChannelId, channelName: _quranChannelName),
);
```

كما صار `_details` يأخذ نص الإشعار (`body`) ويعرضه عبر `BigTextStyleInformation(body)`
بدل نص فارغ، فصار الإشعار الطويل يُعرض كاملًا في لوحة التنبيهات.

### ٣) متطلبات النسخة الجديدة من المكتبة
- Flutter **3.38.1** على الأقل، وDart **3.10.0** على الأقل (المكتبة تشترط ذلك).
- `compileSdk = 36` و`minSdk = 24` (أي Android 7.0+) و`targetSdk = 36` — وهي القيم
  التي يضبطها قالب Flutter 3.47.7 تلقائيًا في `android/app/build.gradle.kts`،
  فلا حاجة لأي تعديل يدوي عليها.
- core library desugaring مع `desugar_jdk_libs:2.1.4` — يفعّله `patch_android.py` تلقائيًا.

### ٤) تحصين الوركفلو ضد أي فشل صامت
- تثبيت نسخة Flutter على `3.47.7` بدل `channel: stable` المتغيّر.
- حذف `app/test` الافتراضي الذي يسبب أخطاء تحليل زائفة (لأنه يشير إلى تطبيق القالب).
- إضافة خطوة `flutter analyze` كبوابة جودة تفشل البناء على أي خطأ Dart قبل الوصول للـ APK.
- إضافة `if-no-files-found: error` على خطوة رفع الـ Artifact.

### ٥) ما تم التحقق منه فعليًا قبل التسليم
- أُنشئ مشروع حقيقي بنفس خطوات الوركفلو بالترتيب:
  `flutter create` ← نسخ `pubspec.yaml` و`main.dart` والخطوط ← `python3 patch_android.py app`
  ← `flutter pub get`.
- ثم شُغّل `flutter analyze lib`: **صفر أخطاء**، و17 ملاحظة `info` فقط كلها تنبيهات
  إهمال `withOpacity` (لا توقف البناء). والأخطاء الأربعة الأصلية
  `Too many positional arguments` اختفت تمامًا؛ لأن `flutter analyze` هو نفس فحص
  الأنواع الذي كان يُسقط خطوة `kernel_snapshot_program` سابقًا.
- لم يتبقَّ سوى تجميع الـ APK النهائي، وهو ما يحدث على سيرفر GitHub (ذاكرة 16GB)
  عبر خطوة `flutter build apk --release` في الوركفلو.

### ٦) تحسينات هذه الحزمة (تمرير المصحف + بطاقة المطوّر)
- **إصلاح قصّ أسفل صفحة المصحف عند تكبير الخط**: كانت الصفحة ثابتة على ارتفاع
  الشاشة، فإذا كبّرت الخط اختفى الجزء السفلي دون إمكانية النزول إليه. الآن صفحة
  القراءة أصبحت قابلة للتمرير الرأسي كلما تجاوز المحتوى ارتفاع الشاشة
  (التمرير الأفقي بين الصفحات يعمل كما هو).
- **بطاقة «مطوّر التطبيق» في الصفحة الرئيسية**: بخط Amiri الجميل باسم **Abdo**
  ومعها زر التواصل عبر تيليجرام ✈️ ‎@abdoshhba (يفتح https://t.me/abdoshhba).
  أُضيفت حزمة `url_launcher` لهذا الغرض.

## ما الذي تغيّر في نسخة v2.0.0 (الميزات)

### ١) إصلاح شكل القرآن
كان عرض المصحف يمرّر معاملي التحجيم بشكل معكوس:
`sp: (1 / store.zoom).sp` مع `h: 1.h` — أي أن حجم الخط يتغيّر بينما ارتفاع السطر
ثابت، فتنكسر أسطر الصفحة القرآنية إلى كلمات مفردة في وسط السطر.

الآن:
- `sp` و`h` يتغيّران معًا بنفس القيمة، فتبقى هندسة الصفحة مطابقة للمصحف المطبوع.
- حجم افتراضي ١٠٠٪، ومدى تكبير من ٧٥٪ إلى ١٥٠٪ مع زر إعادة للحجم الافتراضي.
- خلفية ورقية كريمية وإطار دائري للصفحة، وخط المصحف الرسمي (QCF) لكل صفحة.
- شريط علوي يعرض اسم السورة ورقم الصفحة، وشريط سفلي فيه شريط تقدّم للورد
  وزرّا «التالية» و«السابقة»، وعلامات مرجعية.

### ٢) إشعار بعد كل صلاة
- حساب مواقيت الصلوات الخمس محليًا داخل الجهاز بمكتبة `adhan`
  (بدون إنترنت)، مع اختيار طريقة الحساب ومذهب العصر.
- تحديد الموقع تلقائيًا عبر GPS، أو اختيار المدينة من قائمة جاهزة (٣٠ مدينة).
- إشعار بعد كل صلاة (بتأخير قابل للضبط ٠–٣٠ دقيقة)، ويُعاد جدولتها تلقائيًا
  لعشرة أيام قادمة، مع إعادة جدولة بعد إعادة تشغيل الجهاز.
- إشعار تجريبي فوري من الإعدادات للتأكد من عمل الإشعارات.

### ٣) تجديد الواجهة
- هوية بصرية موحّدة (أخضر داكن + ذهبي + كريمي) وخط `Amiri` للنصوص.
- خط `Amiri Quran` لعرض الآيات والأحاديث.
- وضع ليلي كامل، وبطاقة «آية اليوم» و«حديث اليوم»، وبطاقة الرصيد والسلسلة.
- تبويب خامس جديد: الإعدادات (الإشعارات، الموقع، طريقة الحساب، حجم خط المصحف).

## الأذونات التي يضيفها `patch_android.py` تلقائيًا
`INTERNET`, `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`,
`SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM`, `VIBRATE`,
`ACCESS_COARSE_LOCATION`, `ACCESS_FINE_LOCATION`

كما يسجّل مستقبِلات `flutter_local_notifications` ويفعّل core library desugaring
المطلوب للإشعارات المجدولة، ويضبط اسم التطبيق الظاهر إلى «مجاهد».

## ملاحظة عند أول تشغيل
افتح التطبيق ← الإعدادات ← «تحديد موقعي تلقائيًا» (أو اختر مدينتك)، ثم اسمح
بإذن الإشعارات والمنبّهات. بعدها سيصلك إشعار بعد كل صلاة.
