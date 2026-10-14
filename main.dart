import 'dart:async';
import 'dart:convert';
import 'dart:math' show Random;
import 'package:adhan_dart/adhan_dart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:geolocator/geolocator.dart';
import 'package:qcf_quran/qcf_quran.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

const kPages = 604;
const kPer = 2500;
const kSecs = 20;
const gold = Color(0xFFE0B34F);
const goldDark = Color(0xFFB8892B);
const deepGreen = Color(0xFF0F3D2E);
const prayers = ['الفجر', 'الظهر', 'العصر', 'المغرب', 'العشاء'];
const phrases = [
  'الجنة تنتظرك',
  'الآخرة خير وأبقى',
  'القرآن يأتي شافعًا لصاحبه',
  'خيركم من تعلّم القرآن وعلّمه',
  'اقرأ وارتقِ',
  'مع كل صفحة، تقترب من الجنة',
  'اجعل للقرآن نصيبًا من يومك',
  'من قرأ حرفًا فله به حسنة',
  'وردك اليومي… عهدٌ بينك وبين ربك',
  'لا تحقرنّ صفحة واحدة',
  'الذي لا شيء في صدره من القرآن كالبيت الخرب',
  'ربِّ اجعل القرآن ربيع قلبي',
  'تدبّر آية خير من قراءة بلا وعي',
  'القرآن دليلك إلى الجنة',
  'هذا وعدك مع نفسك… أوفِ به',
  'كم بقي بينك وبين ختمة؟ ابدأ الآن',
  'ارفع درجتك… اقرأ صفحة',
  'الطريق إلى الجنة يبدأ ببسملة',
  'اجعل القرآن أول ما تفتتح به يومك',
  'ثباتك اليوم… فرحُك غدًا',
  'وعدٌ لن يُخلف: اقرأ ترتقِ',
];
const note = 'رصيد رمزي يشجعك، والجزاء الحقيقي بيد الله';

class Item {
  final String id, emoji, name;
  final int price;
  const Item(this.id, this.emoji, this.name, this.price);
}

const items = [
  Item('n', '🌴', 'نخلة', 100000),
  Item('r', '🌊', 'نهر', 250000),
  Item('g', '🍇', 'بستان أعناب', 5000000),
  Item('s', '⛲', 'عين سلسبيل', 20000000),
  Item('a', '🛋', 'سرر وأرائك', 50000000),
  Item('h', '🏠', 'بيت في الجنة', 100000000),
  Item('t', '⛺', 'خيمة من لؤلؤة', 300000000),
  Item('u', '🌸', 'حور عين', 400000000),
  Item('d', '👘', 'ثياب من سندس وإستبرق', 800000000),
  Item('c', '🏰', 'قصر', 100000000000),
];

String ar(String s) {
  const d = '٠١٢٣٤٥٦٧٨٩';
  return s.split('').map((c) {
    final v = int.tryParse(c);
    return v == null ? c : d[v];
  }).join();
}

String fmt(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('٬');
    b.write(s[i]);
  }
  return ar(b.toString());
}

int today() {
  final n = DateTime.now();
  return DateTime.utc(n.year, n.month, n.day).difference(DateTime.utc(1970)).inDays;
}

/// اليوم الهجري التقريبي (خوارزمية تقويمية، قد تختلف يومًا عن الرؤية)
String hijriLabel(DateTime g) {
  int jd = (g.difference(DateTime(1970, 1, 1)).inDays + 2440588);
  int l = jd - 1948440 + 10632;
  int n = (l - 1) ~/ 10631;
  l = l - 10631 * n + 354;
  int j = (10985 - l) ~/ 5316 * (50 * l ~/ 17719) + (l ~/ 5670) * (43 * l ~/ 15238);
  l = l - (30 - j) ~/ 15 * (17719 * j ~/ 50) - (j ~/ 16) * (15238 * j ~/ 43) + 29;
  int m = 24 * l ~/ 709;
  int d = l - (709 * m ~/ 24);
  int y = 30 * n + j - 30;
  const months = [
    'محرم', 'صفر', 'ربيع الأول', 'ربيع الآخر', 'جمادى الأولى', 'جمادى الآخرة',
    'رجب', 'شعبان', 'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة'
  ];
  if (m < 1 || m > 12) return '';
  return '${ar('$d')} ${months[m - 1]} ${ar('$y')}هـ';
}

class Store extends ChangeNotifier {
  late SharedPreferences sp;
  int bal = 0, last = 1;
  double zoom = 1;
  bool dark = false, intro = false;
  Map<String, List<int>> pg = {};
  Set<String> counted = {};
  Set<int> days = {};
  Map<String, int> own = {};

  Future<void> load() async {
    sp = await SharedPreferences.getInstance();
    final s = sp.getString('waad');
    if (s == null) return;
    try {
      final j = jsonDecode(s);
      bal = j['bal'] ?? 0;
      last = j['last'] ?? 1;
      zoom = (j['zoom'] ?? 1).toDouble();
      dark = j['dark'] ?? false;
      intro = j['intro'] ?? false;
      pg = (j['pg'] as Map? ?? {}).map((k, v) => MapEntry(k as String, List<int>.from(v)));
      counted = Set<String>.from(j['counted'] ?? []);
      days = Set<int>.from(j['days'] ?? []);
      own = (j['own'] as Map? ?? {}).map((k, v) => MapEntry(k as String, v as int));
    } catch (_) {}
  }

  void save() {
    sp.setString(
        'waad',
        jsonEncode({
          'bal': bal, 'last': last, 'zoom': zoom, 'dark': dark, 'intro': intro,
          'pg': pg, 'counted': counted.toList(), 'days': days.toList(),
          'own': own,
        }));
    notifyListeners();
  }

  int streak() {
    var n = 0, d = today();
    if (!days.contains(d)) d--;
    while (days.contains(d)) {
      n++;
      d--;
    }
    return n;
  }

  List<int> plan(int d, int i, int D) {
    if (D < 30) {
      final slot = (d - 1) * 5 + i, S = D * 5;
      return [slot * kPages ~/ S + 1, (slot + 1) * kPages ~/ S];
    }
    const p = 4;
    if (d < 30) {
      final s = (d - 1) * 5 * p + i * p + 1;
      return [s, s + p - 1];
    }
    final rest = kPages - 29 * 5 * p;
    final b = rest ~/ 5, r = rest % 5;
    var s = 29 * 5 * p + 1;
    for (var k = 0; k < i; k++) {
      s += b + (k < r ? 1 : 0);
    }
    return [s, s + b + (i < r ? 1 : 0) - 1];
  }

  int todayCount() => counted.where((k) => k.startsWith('${today()}:')).length;

  void countPage(int page, String? ctx) {
    final t = today();
    counted.removeWhere((k) => !k.startsWith('$t:'));
    final k = '$t:$page';
    if (!counted.contains(k)) {
      counted.add(k);
      bal += kPer;
      days.add(t);
    }
    if (ctx != null) {
      final l = pg.putIfAbsent(ctx, () => []);
      if (!l.contains(page)) l.add(page);
    }
    save();
  }

  void setZoom(double d) {
    zoom = (zoom + d).clamp(0.6, 2.2).toDouble();
    save();
  }

  void buy(Item x) {
    if (bal >= x.price) {
      bal -= x.price;
      own[x.id] = (own[x.id] ?? 0) + 1;
      save();
    }
  }
}

final store = Store();

/* ═══════════════════════════ مواقيت الصلاة والإشعارات ═══════════════════════════ */

final notif = FlutterLocalNotificationsPlugin();
const kPrayerBody = 'حان وقت وردك… صفحات قليلة تقرّبك من الختمة 🤍';

List<DateTime> prayerTimesFor(DateTime day, Coordinates coords) {
  final pt = PrayerTimes(
    coordinates: coords,
    date: DateTime(day.year, day.month, day.day),
    calculationParameters: CalculationMethodParameters.egyptian(),
    precision: true,
  );
  return [pt.fajr, pt.dhuhr, pt.asr, pt.maghrib, pt.isha]
      .map((t) => t.isUtc ? t.toLocal() : t)
      .toList();
}

Future<Coordinates> resolveCoords() async {
  try {
    if (await Geolocator.isLocationServiceEnabled()) {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm != LocationPermission.denied && perm != LocationPermission.deniedForever) {
        final pos = await Geolocator.getCurrentPosition(
            locationSettings:
                const LocationSettings(accuracy: LocationAccuracy.low))
            .timeout(const Duration(seconds: 12));
        await store.sp.setString('coords', '${pos.latitude},${pos.longitude}');
        return Coordinates(pos.latitude, pos.longitude);
      }
    }
  } catch (_) {}
  final s = store.sp.getString('coords');
  if (s != null) {
    final p = s.split(',');
    if (p.length == 2) {
      return Coordinates(double.tryParse(p[0]) ?? 30.0444, double.tryParse(p[1]) ?? 31.2357);
    }
  }
  return const Coordinates(30.0444, 31.2357); // القاهرة كاحتياطي
}

Future<void> reschedulePrayerReminders() async {
  try {
    await notif.cancelAll();
    final coords = await resolveCoords();
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'waad_reminders',
        'تذكير ورد القرآن',
        channelDescription: 'تذكير بوردك بعد كل صلاة',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    );
    final now = tz.TZDateTime.now(tz.local);
    var id = 0;
    for (var d = 0; d < 8; d++) {
      final day = DateTime(now.year, now.month, now.day).add(Duration(days: d));
      final times = prayerTimesFor(day, coords);
      for (var i = 0; i < 5; i++) {
        final when = tz.TZDateTime.from(times[i].add(const Duration(minutes: 15)), tz.local);
        if (when.isAfter(now)) {
          await notif.zonedSchedule(
            id++,
            'ورد ${prayers[i]} 📖',
            kPrayerBody,
            when,
            details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          );
        }
      }
    }
  } catch (_) {}
}

Future<void> initNotifications() async {
  try {
    tz.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {}
    await notif.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher')));
    await notif
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  } catch (_) {}
}

/* ═══════════════════════════ المصحف: رسم احترافي سطر-بسطر ═══════════════════════════ */

double mushafBaseFont(int page) {
  if (page == 1 || page == 2) return 25;
  if (page >= 550) return 22;
  if (page == 145 || page == 585) return 22.7;
  if (page == 566 || page == 565 || page == 532 || page == 533 || page == 523 || page == 577 || page == 535) return 22.5;
  if (page == 116 || page == 156) return 23.4;
  const s = {56, 57, 368, 269, 372, 376, 409, 435, 444, 460, 498, 499, 506, 513, 515, 517};
  if (s.contains(page)) return 23.2;
  return 24;
}

class MushafColors {
  final Color bg, frame, frameSoft, text, accent, headerBg;
  const MushafColors({
    required this.bg, required this.frame, required this.frameSoft,
    required this.text, required this.accent, required this.headerBg,
  });
  static const light = MushafColors(
    bg: Color(0xFFF6EFDD),
    frame: Color(0xFF9A7B2D),
    frameSoft: Color(0x339A7B2D),
    text: Color(0xFF231A08),
    accent: Color(0xFF7A5C14),
    headerBg: Color(0xFFEFE3C6),
  );
  static const dark = MushafColors(
    bg: Color(0xFF121B16),
    frame: Color(0xFF8A6D2F),
    frameSoft: Color(0x338A6D2F),
    text: Color(0xFFEDE3CB),
    accent: Color(0xFFCFA750),
    headerBg: Color(0xFF1C2820),
  );
}

class _Line {
  final InlineSpan span;
  final bool flexible;
  final int? surah;
  _Line(this.span, {this.flexible = false, this.surah});
}

/// يبني أسطر الصفحة مطابقة لتقسيم مصحف المدينة (السطر ينتهي بنهاية آية)
List<_Line> buildMushafLines(int page, MushafColors c, double fontSize, double lh) {
  final pageFont = 'QCF_P${page.toString().padLeft(3, '0')}';
  final ranges = getPageData(page);
  final lines = <_Line>[];
  for (var ri = 0; ri < ranges.length; ri++) {
    final r = ranges[ri];
    final surah = int.parse(r['surah'].toString());
    final start = int.parse(r['start'].toString());
    final end = int.parse(r['end'].toString());
    var buf = <InlineSpan>[];
    void flush({bool last = false}) {
      if (buf.isEmpty) return;
      lines.add(_Line(TextSpan(children: buf), flexible: !last && buf.isNotEmpty, surah: surah));
      buf = [];
    }
    if (start == 1) {
      lines.add(_Line(const TextSpan(text: ''), surah: surah));
      // البسملة تُطبع عند بداية كل سورة عدا الفاتحة (هي الآية الأولى) والتوبة (لا بسملة فيها)
      if (surah != 1 && surah != 9) {
        buf.add(TextSpan(
          text: ' ﱁ  ﱂﱃﱄ',
          style: TextStyle(
            fontFamily: 'QCF_P001',
            package: 'qcf_quran',
            fontSize: fontSize * 0.96,
            height: lh,
            color: c.text,
          ),
        ));
        flush();
      }
    }
    for (var v = start; v <= end; v++) {
      var t = getVerseQCF(surah, v, verseEndSymbol: false);
      if (ri == 0 && v == start && t.startsWith('\n')) t = t.replaceFirst('\n', '');
      final parts = t.split('\n');
      for (var pi = 0; pi < parts.length; pi++) {
        final part = parts[pi];
        if (part.isNotEmpty) {
          buf.add(TextSpan(text: part));
        }
        final isLastPart = pi == parts.length - 1;
        if (isLastPart) {
          buf.add(TextSpan(text: getVerseNumberQCF(surah, v)));
          flush(last: ri == ranges.length - 1 && v == end);
        } else {
          flush(last: false);
        }
      }
      if (t.isEmpty) {
        buf.add(TextSpan(text: getVerseNumberQCF(surah, v)));
        flush(last: ri == ranges.length - 1 && v == end);
      }
    }
  }
  return lines.where((l) {
    // أزل الأسطر الفارغة الناتجة عن محاذاة الحدود
    return !(l.span is TextSpan &&
        (l.span as TextSpan).children == null &&
        ((l.span as TextSpan).text ?? '').isEmpty &&
        l.surah == null);
  }).toList();
}

class MushafPageView extends StatelessWidget {
  final int page;
  final bool dark;
  final double zoom;
  final void Function(int surah, int verse)? onVerseLongPress;
  const MushafPageView({super.key, required this.page, required this.dark, required this.zoom, this.onVerseLongPress});

  List<Widget> lineWidgets(double innerW, TextStyle style, List<_Line> lines, MushafColors c) {
    return [
      for (final l in lines)
        if (l.surah != null &&
            (l.span as TextSpan).text == '' &&
            (l.span as TextSpan).children == null)
          SurahHeader(number: l.surah!, colors: c)
        else
          SizedBox(
            width: innerW,
            child: Text.rich(
              l.span,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              locale: const Locale('ar'),
              softWrap: false,
              overflow: TextOverflow.visible,
              maxLines: 1,
              style: style,
            ),
          ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final c = dark ? MushafColors.dark : MushafColors.light;
    final fs = mushafBaseFont(page) * zoom.clamp(0.6, 1.6);
    final lh = (page == 1 || page == 2) ? 2.15 : 1.9;
    final ranges = getPageData(page);
    final firstSurah = int.parse(ranges.first['surah'].toString());
    final surahName = getSurahNameArabic(firstSurah);
    final juz = getJuzNumber(firstSurah, int.parse(ranges.first['start'].toString()));
    final style = TextStyle(
      fontFamily: 'QCF_P${page.toString().padLeft(3, '0')}',
      package: 'qcf_quran',
      fontSize: fs,
      height: lh,
      color: c.text,
    );
    return LayoutBuilder(builder: (ctx, box) {
      final padH = 14.0, padTop = 10.0, padBottom = 8.0;
      final topBar = 30.0;
      final bottomBar = 26.0;
      final innerW = box.maxWidth - 2 * (padH + 10);
      var lines = buildMushafLines(page, c, fs, lh);
      final textLines = lines.where((l) => l.span is! WidgetSpan).length;
      final hasHeaderLines = lines.any((l) => l.surah != null && (l.span as TextSpan).text == '');
      final estContent = textLines * fs * lh + (hasHeaderLines ? 46 : 0) * lines.where((l) => (l.span as TextSpan).text == '' && l.surah != null).length;
      final avail = box.maxHeight - topBar - bottomBar - padTop - padBottom - 26;
      final flex = textLines > 2 && estContent < avail * 0.98;
      return Container(
        color: c.bg,
        padding: EdgeInsets.fromLTRB(padH, padTop, padH, padBottom),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: c.frame, width: 2.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Container(
            margin: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              border: Border.all(color: c.frameSoft, width: 1),
              borderRadius: BorderRadius.circular(3),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(children: [
              SizedBox(
                height: topBar,
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('سورة $surahName',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.accent)),
                  Text('الجزء ${ar('$juz')}',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.accent)),
                ]),
              ),
              Divider(height: 1, thickness: 1, color: c.frameSoft),
              const SizedBox(height: 6),
              Expanded(
                child: flex
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: lineWidgets(innerW, style, lines, c),
                      )
                    : SingleChildScrollView(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: lineWidgets(innerW, style, lines, c),
                        ),
                      ),
              ),
              const SizedBox(height: 6),
              Divider(height: 1, thickness: 1, color: c.frameSoft),
              SizedBox(
                height: bottomBar,
                child: Center(
                  child: Text('﴿ ${ar('$page')} ﴾',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.accent)),
                ),
              ),
            ]),
          ),
        ),
      );
    });
  }
}

class SurahHeader extends StatelessWidget {
  final int number;
  final MushafColors colors;
  const SurahHeader({super.key, required this.number, required this.colors});

  @override
  Widget build(BuildContext context) {
    final name = getSurahNameArabic(number);
    final place = getPlaceOfRevelation(number) == 'Makkah' ? 'مكية' : 'مدنية';
    final count = ar('${getVerseCount(number)}');
    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: colors.headerBg,
        border: Border.all(color: colors.frame, width: 1.4),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('✦', style: TextStyle(color: colors.accent, fontSize: 13)),
        const SizedBox(width: 10),
        Text('سورة $name',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: colors.accent)),
        const SizedBox(width: 10),
        Text('✦', style: TextStyle(color: colors.accent, fontSize: 13)),
        const SizedBox(width: 10),
        Text('$place • $count آية',
            style: TextStyle(fontSize: 10.5, color: colors.accent.withOpacity(0.85))),
      ]),
    );
  }
}

/* ═══════════════════════════ التطبيق ═══════════════════════════ */

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await store.load();
  await initNotifications();
  unawaited(reschedulePrayerReminders());
  runApp(const WaadApp());
}

ThemeData mk(Brightness b) {
  return ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF1F6B4F), brightness: b);
}

class WaadApp extends StatelessWidget {
  const WaadApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(392.72727272727275, 800.7272727272727),
      minTextAdapt: true,
      builder: (context, child) => ListenableBuilder(
        listenable: store,
        builder: (c, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'مجاهد',
          themeMode: store.dark ? ThemeMode.dark : ThemeMode.light,
          theme: mk(Brightness.light),
          darkTheme: mk(Brightness.dark),
          builder: (c, w) => Directionality(textDirection: TextDirection.rtl, child: w!),
          home: const Splash(),
        ),
      ),
    );
  }
}

class Splash extends StatefulWidget {
  const Splash({super.key});
  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> with SingleTickerProviderStateMixin {
  late final AnimationController c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
  final phrase = phrases[Random().nextInt(phrases.length)];

  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 2800), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, __, ___) => const Shell(),
        transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
      ));
    });
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0B2F23), Color(0xFF1F6B4F)])),
        child: Center(
          child: FadeTransition(
            opacity: c,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('مجاهد',
                  style: TextStyle(fontSize: 76, fontWeight: FontWeight.bold, color: gold)),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(phrase,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, color: Colors.white, height: 1.8)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class StarPattern extends CustomPainter {
  final Color color;
  StarPattern(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const s = 64.0, r = 14.0;
    for (double y = 0; y < size.height + s; y += s) {
      for (double x = 0; x < size.width + s; x += s) {
        for (var k = 0; k < 2; k++) {
          canvas.save();
          canvas.translate(x, y);
          canvas.rotate(k * 0.785398);
          canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: r * 2, height: r * 2), p);
          canvas.restore();
        }
      }
    }
  }

  @override
  bool shouldRepaint(StarPattern o) => o.color != color;
}

Widget card(Widget child) => Builder(builder: (c) {
      final cs = Theme.of(c).colorScheme;
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surface.withOpacity(0.92),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cs.outlineVariant),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: child,
      );
    });

Widget balanceText(TextStyle st) => TweenAnimationBuilder<double>(
      tween: Tween<double>(end: store.bal.toDouble()),
      duration: const Duration(milliseconds: 900),
      builder: (c, v, _) => Text(fmt(v.round()), style: st),
    );

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0;
  final gp = TextEditingController();

  void open(List<int> pages, [String? ctx]) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ReaderPage(pages: pages, ctx: ctx)));
  }

  void openFrom(int p) {
    p = p.clamp(1, kPages);
    open(List.generate(kPages - p + 1, (i) => p + i));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tabs = [home(), mushaf(), khatma(), const Jannah()];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('مجاهد',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 26, color: goldDark)),
        actions: [
          IconButton(
              icon: const Icon(Icons.brightness_6),
              tooltip: 'الوضع الليلي',
              onPressed: () {
                store.dark = !store.dark;
                store.save();
              }),
        ],
      ),
      body: Stack(children: [
        Positioned.fill(child: CustomPaint(painter: StarPattern(cs.primary.withOpacity(0.07)))),
        ListenableBuilder(listenable: store, builder: (c, _) => tabs[tab]),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'المصحف'),
          NavigationDestination(icon: Icon(Icons.mosque_outlined), selectedIcon: Icon(Icons.mosque), label: 'الختمة'),
          NavigationDestination(icon: Icon(Icons.park_outlined), selectedIcon: Icon(Icons.park), label: 'جنتك'),
        ],
      ),
    );
  }

  Widget home() {
    return ListView(padding: const EdgeInsets.all(16), children: [
      card(Center(
          child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(phrases[today() % phrases.length],
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: goldDark, height: 1.7)),
      ))),
      Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [goldDark, gold]),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: goldDark.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 6))],
        ),
        child: Row(children: [
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('رصيد حسناتك', style: TextStyle(color: Colors.white70)),
            balanceText(const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 4),
            const Text(note, style: TextStyle(fontSize: 11, color: Colors.white70)),
          ])),
          Column(children: [
            const Text('🔥', style: TextStyle(fontSize: 30)),
            Text(ar('${store.streak()}'),
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
            const Text('يوم متتالي', style: TextStyle(fontSize: 11, color: Colors.white70)),
          ]),
        ]),
      ),
      card(Column(children: [
        Text('صفحات اليوم: ${ar('${store.todayCount()}')}'),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
              onPressed: () => openFrom(store.last),
              child: Text('كمّل من حيث وقفت (ص ${ar('${store.last}')})')),
        ),
      ])),
    ]);
  }

  Widget mushaf() {
    return ListView(padding: const EdgeInsets.all(16), children: [
      card(Row(children: [
        Expanded(
            child: TextField(
                controller: gp,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'رقم الصفحة (1 - 604)'))),
        const SizedBox(width: 10),
        FilledButton(onPressed: () => openFrom(int.tryParse(gp.text) ?? 1), child: const Text('فتح')),
      ])),
      card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('الأجزاء'),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 6,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          children: List.generate(
              30,
              (i) => OutlinedButton(
                  style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                  onPressed: () => openFrom(i == 0 ? 1 : 20 * i + 2),
                  child: Text(ar('${i + 1}')))),
        ),
      ])),
      const Padding(
          padding: EdgeInsets.fromLTRB(6, 10, 6, 4),
          child: Text('فهرس السور', style: TextStyle(fontWeight: FontWeight.bold))),
      for (var n = 1; n <= 114; n++)
        card(InkWell(
          onTap: () => openFrom(getPageNumber(n, 1)),
          child: Row(children: [
            CircleAvatar(radius: 16, child: Text(ar('$n'), style: const TextStyle(fontSize: 12))),
            const SizedBox(width: 12),
            Expanded(
                child: Text('سورة ${getSurahNameArabic(n)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            Text('ص ${ar('${getPageNumber(n, 1)}')}', style: const TextStyle(color: Colors.grey)),
          ]),
        )),
    ]);
  }

  bool isDone(DateTime n, int d, int D, int i) {
    final r = store.plan(d, i, D);
    return (store.pg['${n.year}-${n.month}-$d-$i'] ?? []).length >= r[1] - r[0] + 1;
  }

  Widget khatma() {
    final n = DateTime.now();
    final md = DateTime(n.year, n.month + 1, 0).day;
    final D = md < 30 ? md : 30;
    final d = n.day;
    if (d > D) {
      return ListView(padding: const EdgeInsets.all(16), children: [
        card(const Center(
            child: Text('اليوم راحة ومراجعة، لا صفحات جديدة 🤍\nتبدأ ختمة الشهر الجديد في أول يوم',
                textAlign: TextAlign.center))),
      ]);
    }
    final all = List.generate(5, (i) => isDone(n, d, D, i)).every((x) => x);
    return ListView(padding: const EdgeInsets.all(16), children: [
      card(Column(children: [
        Text('ختمة اليوم ${ar('$d')} من ${ar('$D')}  (${ar('${n.day}/${n.month}')})',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        if (hijriLabel(n).isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(hijriLabel(n), style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
        const SizedBox(height: 10),
        ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: d / D, minHeight: 8)),
      ])),
      if (all)
        card(const Center(
            child: Text('ما شاء الله، أتممت ختمة اليوم 🤍',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: goldDark)))),
      for (var i = 0; i < 5; i++) prayerRow(n, d, D, i),
    ]);
  }

  Widget prayerRow(DateTime n, int d, int D, int i) {
    final cs = Theme.of(context).colorScheme;
    final r = store.plan(d, i, D);
    final key = '${n.year}-${n.month}-$d-$i';
    final done = isDone(n, d, D, i);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: done ? cs.primaryContainer : cs.surface.withOpacity(0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: done ? cs.primary : cs.outlineVariant, width: done ? 1.6 : 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(prayers[i], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        subtitle: Text('ص ${ar('${r[0]}')} – ${ar('${r[1]}')}'),
        trailing: done
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                Text('تمت', style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary)),
                const SizedBox(width: 6),
                const Icon(Icons.check_circle, size: 36, color: Colors.green),
              ])
            : const Icon(Icons.chevron_left),
        onTap: () => open(List.generate(r[1] - r[0] + 1, (k) => r[0] + k), key),
      ),
    );
  }
}

class Jannah extends StatefulWidget {
  const Jannah({super.key});
  @override
  State<Jannah> createState() => _JannahState();
}

class _JannahState extends State<Jannah> {
  @override
  void initState() {
    super.initState();
    if (!store.intro) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('هذه الجنة رمزية لتحفّزك، أما جنة الله فأعظم مما تتخيل'),
            duration: Duration(seconds: 5)));
        store.intro = true;
        store.save();
      });
    }
  }

  Widget scene() {
    final h = DateTime.now().hour;
    final night = h < 6 || h >= 18;
    final total = store.own.values.fold(0, (a, b) => a + b);
    final txt = items.map((x) => x.emoji * (store.own[x.id] ?? 0).clamp(0, 8)).join(' ').trim();
    return Container(
      height: 170,
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: night
              ? const [Color(0xFF0B1B3A), Color(0xFF24507A)]
              : const [Color(0xFF8FD3F4), Color(0xFFD8F1D0)],
        ),
      ),
      child: Stack(children: [
        Positioned(top: 12, right: 16, child: Text(night ? '🌙' : '☀️', style: const TextStyle(fontSize: 34))),
        if (night) ...const [
          Positioned(top: 20, left: 40, child: Text('✨', style: TextStyle(fontSize: 14))),
          Positioned(top: 50, left: 120, child: Text('✨', style: TextStyle(fontSize: 10))),
          Positioned(top: 30, left: 220, child: Text('✨', style: TextStyle(fontSize: 12))),
        ],
        Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TweenAnimationBuilder<double>(
              key: ValueKey(total),
              tween: Tween<double>(begin: 0.5, end: 1),
              duration: const Duration(milliseconds: 700),
              curve: Curves.elasticOut,
              builder: (c, v, _) => Transform.scale(
                scale: v,
                child: Text(txt.isEmpty ? 'جنتك تنتظر أول غرسة 🌱' : txt,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: txt.isEmpty ? 18 : 30, color: night ? Colors.white : Colors.black87)),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      scene(),
      card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('رصيد حسناتك'),
        balanceText(const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: goldDark)),
        const Text(note, style: TextStyle(fontSize: 11, color: Colors.grey)),
      ])),
      for (final x in items) itemCard(x),
    ]);
  }

  Widget itemCard(Item x) {
    final ok = store.bal >= x.price;
    final need = ((x.price - store.bal) / kPer).ceil();
    return card(Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('${x.emoji} ${x.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
        Text('${fmt(x.price)} حسنة'),
      ]),
      const SizedBox(height: 8),
      ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(value: (store.bal / x.price).clamp(0, 1).toDouble(), minHeight: 8)),
      const SizedBox(height: 4),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(ok ? 'متاح' : 'فاضل لك ${fmt(need)} صفحة', style: const TextStyle(fontSize: 12)),
        FilledButton(onPressed: ok ? () => store.buy(x) : null, child: const Text('اقتناء')),
      ]),
    ]));
  }
}

/* ═══════════════════════════ صفحة القراءة ═══════════════════════════ */

class ReaderPage extends StatefulWidget {
  final List<int> pages;
  final String? ctx;
  const ReaderPage({super.key, required this.pages, this.ctx});
  @override
  State<ReaderPage> createState() => _ReaderState();
}

class _ReaderState extends State<ReaderPage> with WidgetsBindingObserver {
  late int cur = widget.pages.first;
  late final PageController controller =
      PageController(initialPage: widget.pages.first - 1);
  int sec = 0;
  bool active = true;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    store.last = cur;
    store.save();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!active || !mounted) return;
      sec++;
      if (sec == kSecs) {
        store.countPage(cur, widget.pages.contains(cur) ? widget.ctx : null);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    active = s == AppLifecycleState.resumed;
  }

  @override
  void dispose() {
    timer?.cancel();
    controller.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void onChanged(int p) {
    setState(() {
      cur = p;
      sec = 0;
    });
    store.last = p;
    store.save();
  }

  void go(int d) {
    final n = (cur + d).clamp(widget.pages.first, widget.pages.last).toInt();
    if (n == cur) return;
    controller.animateToPage(n - 1,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (c, _) {
        final dark = store.dark;
        final colors = dark ? MushafColors.dark : MushafColors.light;
        return Scaffold(
          backgroundColor: colors.bg,
          appBar: AppBar(
            backgroundColor: colors.bg,
            elevation: 0,
            scrolledUnderElevation: 0,
            iconTheme: IconThemeData(color: colors.accent),
            title: Text('صفحة ${ar('$cur')}',
                style: TextStyle(color: colors.accent, fontWeight: FontWeight.bold)),
            actions: [
              IconButton(
                  icon: const Icon(Icons.zoom_out),
                  tooltip: 'تصغير',
                  onPressed: () => store.setZoom(-0.1)),
              IconButton(
                  icon: const Icon(Icons.zoom_in),
                  tooltip: 'تكبير',
                  onPressed: () => store.setZoom(0.1)),
            ],
          ),
          body: SafeArea(
            child: Column(children: [
              Expanded(
                child: PageView.builder(
                  controller: controller,
                  itemCount: totalPagesCount,
                  onPageChanged: (i) => onChanged(i + 1),
                  itemBuilder: (c, i) => MushafPageView(
                    page: i + 1,
                    dark: dark,
                    zoom: store.zoom,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                child: Row(children: [
                  Expanded(
                      child: FilledButton.icon(
                          onPressed: cur < widget.pages.last ? () => go(1) : null,
                          icon: const Icon(Icons.chevron_left),
                          label: const Text('التالية'))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: OutlinedButton.icon(
                          onPressed: cur > widget.pages.first ? () => go(-1) : null,
                          icon: const Icon(Icons.chevron_right),
                          label: const Text('السابقة'))),
                ]),
              ),
            ]),
          ),
        );
      },
    );
  }
}
