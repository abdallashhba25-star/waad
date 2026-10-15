// ============================================================================
//  مجاهد — تطبيق ورد قرآني يومي
//  النواة: الثوابت، النصوص، التخزين، الحالة
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:qcf_quran/qcf_quran.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:url_launcher/url_launcher.dart';

// ---------------------------------------------------------------------------
//  ثوابت عامة
// ---------------------------------------------------------------------------

const int kPages = 604;

/// رصيد كل صفحة: رقم عشوائي بين 500 و 5000 نقطة.
/// (المتوسط 2750 يُستخدم فقط في التقديرات التقريبية بالواجهة).
const int kPerPageMin = 500;
const int kPerPageMax = 5000;
const int kPerPageAvg = (kPerPageMin + kPerPageMax) ~/ 2;
final math.Random _perPageRng = math.Random();
int kPerPage() =>
    kPerPageMin + _perPageRng.nextInt(kPerPageMax - kPerPageMin + 1);
const int kSecondsToCount = 40;
const String kAppName = 'مجاهد';
const String kNote = 'رصيد رمزي للتشجيع، والجزاء الحقيقي بيد الله';

const List<String> kPrayers = ['الفجر', 'الظهر', 'العصر', 'المغرب', 'العشاء'];

// الهوية البصرية (أخضر داكن + ذهبي + كريمي)
const Color kGold = Color(0xFFC9A227);
const Color kGoldLight = Color(0xFFE7C86A);
const Color kGreen = Color(0xFF0F3D2E);
const Color kGreenDeep = Color(0xFF0A2B20);
const Color kGreenMid = Color(0xFF17573F);
const Color kCream = Color(0xFFFBF7EC);
const Color kInk = Color(0xFF1B2A24);
const Color kNightSurface = Color(0xFF101B17);
const Color kNightBg = Color(0xFF08120E);

// ---------------------------------------------------------------------------
//  نصوص إيمانية
// ---------------------------------------------------------------------------

const List<List<String>> kAyahs = [
  ['وَلَقَدْ يَسَّرْنَا الْقُرْآنَ لِلذِّكْرِ فَهَلْ مِن مُّدَّكِرٍ', 'القمر ١٧'],
  ['إِنَّ هَٰذَا الْقُرْآنَ يَهْدِي لِلَّتِي هِيَ أَقْوَمُ', 'الإسراء ٩'],
  ['وَرَتِّلِ الْقُرْآنَ تَرْتِيلًا', 'المزمل ٤'],
  ['كِتَابٌ أَنزَلْنَاهُ إِلَيْكَ مُبَارَكٌ لِّيَدَّبَّرُوا آيَاتِهِ', 'ص ٢٩'],
  ['وَنُنَزِّلُ مِنَ الْقُرْآنِ مَا هُوَ شِفَاءٌ وَرَحْمَةٌ لِّلْمُؤْمِنِينَ', 'الإسراء ٨٢'],
  ['إِنَّ الَّذِينَ يَتْلُونَ كِتَابَ اللَّهِ وَأَقَامُوا الصَّلَاةَ لَهُمْ أَجْرٌ غَيْرُ مَمْنُونٍ', 'فاطر ٢٩'],
  ['وَأَقِمِ الصَّلَاةَ إِنَّ الصَّلَاةَ تَنْهَىٰ عَنِ الْفَحْشَاءِ وَالْمُنكَرِ', 'العنكبوت ٤٥'],
  ['فَاذْكُرُونِي أَذْكُرْكُمْ وَاشْكُرُوا لِي وَلَا تَكْفُرُونِ', 'البقرة ١٥٢'],
  ['أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ', 'الرعد ٢٨'],
  ['وَمَنْ يَتَّقِ اللَّهَ يَجْعَل لَّهُ مَخْرَجًا', 'الطلاق ٢'],
];

const List<List<String>> kHadiths = [
  ['اقرؤوا القرآن فإنه يأتي يوم القيامة شفيعًا لأصحابه', 'صحيح مسلم'],
  ['خيركم من تعلّم القرآن وعلّمه', 'صحيح البخاري'],
  ['من قرأ حرفًا من كتاب الله فله به حسنة', 'سنن الترمذي'],
  ['يقال لصاحب القرآن: اقرأ وارتقِ ورتّل كما كنت ترتّل في الدنيا', 'سنن أبي داود'],
  ['مَن قرأ القرآن في أقل من ثلاث لم يفقهه', 'سنن أبي داود'],
  ['الذي لا شيء من القرآن في صدره كالبيت الخرب', 'سنن الترمذي'],
];

const List<String> kPhrases = [
  'الجنة تنتظرك',
  'الآخرة خير وأبقى',
  'القرآن يأتي شفيعًا لصاحبه',
  'خيركم من تعلّم القرآن وعلّمه',
  'اقرأ وارتقِ',
  'مع كل صفحة تقترب من الجنة',
  'اجعل للقرآن نصيبًا من يومك',
  'من قرأ حرفًا فله به حسنة',
  'وردك اليومي… عهدٌ بينك وبين ربك',
  'لا تحقرنّ صفحة واحدة',
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

/// نصوص إشعار ما بعد الصلاة.
const List<String> kAfterPrayerBodies = [
  'أشرقت أنوار الفجر… اجعل لك وردًا من القرآن قبل أن يبدأ يومك',
  'الظهر… توقّف قليلًا، اقرأ صفحتك، وارتقِ درجة',
  'العصر… وعدك مع نفسك ينتظرك، لا تؤجّله',
  'المغرب… آناء الليل وأطراف النهار، اقرأ وارتقِ',
  'العشاء… اختم يومك بصفحة، يشفع لك القرآن غدًا',
];

/// عبارات احتفاء تظهر عند إتمام ختمة اليوم كاملة.
const List<String> kKhatmaPraise = [
  'ما شاء الله! أتممت ختمة اليوم كاملة 🌟\nثباتُك اليوم نورٌ لك غدًا، وشاهدٌ لك يوم القيامة',
  'يومٌ كامل مع القرآن… مبارك! 🏆\nكل صفحة قرأتها درجةٌ ترفعك عند ربك',
  'أتممت وردك من أوله لآخره ✨\nالقرآن يحب أهله… وأنت اليوم منهم',
  'ختمة اليوم تمّت على أكمل وجه 🌙\nاستمر، فالقلب المتعلق بالقرآن لا يشقى',
  'خمس صلوات… وخمسة أوراد مكتملة 💚\nهذا هو النصر الصغير الذي يصنع العظيم',
];

/// طرق حساب مواقيت الصلاة — الترتيب مطابق لـ CalculationMethod.values.
const List<List<String>> kMethods = [
  ['رابطة العالم الإسلامي', 'muslim_world_league'],
  ['الهيئة المصرية العامة للمساحة', 'egyptian'],
  ['جامعة العلوم الإسلامية — كراتشي', 'karachi'],
  ['أم القرى — مكة المكرمة', 'umm_al_qura'],
  ['دبي', 'dubai'],
  ['قطر', 'qatar'],
  ['الكويت', 'kuwait'],
  ['رؤية القمر', 'moonsighting_committee'],
  ['سنغافورة', 'singapore'],
  ['أمريكا الشمالية (ISNA)', 'north_america'],
  ['تركيا', 'turkey'],
  ['طهران', 'tehran'],
];

/// مدن جاهزة: [الاسم، خط العرض، خط الطول، طريقة الحساب]
const List<List<Object>> kCities = [
  ['مكة المكرمة', 21.3891, 39.8579, 3],
  ['المدينة المنورة', 24.5247, 39.5692, 3],
  ['الرياض', 24.7136, 46.6753, 3],
  ['جدة', 21.4858, 39.1925, 3],
  ['الدوحة', 25.2854, 51.5310, 3],
  ['الكويت', 29.3759, 47.9774, 3],
  ['دبي', 25.2048, 55.2708, 3],
  ['أبوظبي', 24.4539, 54.3773, 3],
  ['المنامة', 26.2285, 50.5860, 3],
  ['مسقط', 23.5880, 58.3829, 3],
  ['القاهرة', 30.0444, 31.2357, 1],
  ['الإسكندرية', 31.2001, 29.9187, 1],
  ['المنصورة', 31.0409, 31.3785, 1],
  ['أسوان', 24.0889, 32.8998, 1],
  ['غزة', 31.5017, 34.4668, 1],
  ['عمّان', 31.9454, 35.9284, 3],
  ['القدس', 31.7683, 35.2137, 3],
  ['بيروت', 33.8938, 35.5018, 3],
  ['دمشق', 33.5138, 36.2765, 3],
  ['بغداد', 33.3152, 44.3661, 2],
  ['صنعاء', 15.3694, 44.1910, 3],
  ['الخرطوم', 15.5007, 32.5599, 1],
  ['طرابلس', 32.8872, 13.1913, 1],
  ['تونس', 36.8065, 10.1815, 0],
  ['الجزائر', 36.7538, 3.0588, 0],
  ['الرباط', 34.0209, -6.8416, 0],
  ['الدار البيضاء', 33.5731, -7.5898, 0],
  ['نواكشوط', 18.0735, -15.9582, 0],
  ['مقديشو', 2.0469, 45.3182, 0],
  ['إسطنبول', 41.0082, 28.9784, 10],
];

/// عدد آيات كل سورة (ترتيب المصحف) — إجمالي ٦٢٣٦ آية.
const List<int> kVerseCounts = [
  7, 286, 200, 176, 120, 165, 206, 75, 129, 109, 123, 111, 43, 52, 99, 128,
  111, 110, 98, 135, 112, 78, 118, 64, 77, 227, 93, 88, 69, 60, 34, 30, 73,
  54, 45, 83, 182, 88, 75, 85, 54, 53, 89, 59, 37, 35, 38, 29, 18, 45, 60,
  49, 62, 55, 78, 96, 29, 22, 24, 13, 14, 11, 11, 18, 12, 12, 30, 52, 52,
  44, 28, 28, 20, 56, 40, 31, 50, 40, 46, 42, 29, 19, 36, 25, 22, 17, 19,
  26, 30, 20, 15, 21, 11, 8, 8, 19, 5, 8, 8, 11, 11, 8, 3, 9, 5, 4, 7, 3,
  6, 3, 5, 4, 5, 6,
];

// ---------------------------------------------------------------------------
//  أدوات مساعدة
// ---------------------------------------------------------------------------

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

String clock(DateTime d) {
  final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '${ar('$h12')}:${ar(m)} ${d.hour < 12 ? 'ص' : 'م'}';
}

String countdown(Duration d) {
  if (d.isNegative) return '—';
  final h = d.inHours;
  final m = d.inMinutes % 60;
  if (h > 0) return '${ar('$h')} س ${ar('$m')} د';
  return '${ar('$m')} د';
}

// ---------------------------------------------------------------------------
//  نموذج المكافآت
// ---------------------------------------------------------------------------

class Item {
  final String id, emoji, name;
  final int price;
  const Item(this.id, this.emoji, this.name, this.price);
}

const List<Item> kItems = [
  Item('n', '🌴', 'نخلة', 1000000),
  Item('r', '🌊', 'نهر', 2500000),
  Item('g', '🍇', 'بستان أعناب', 50000000),
  Item('s', '⛲', 'عين سلسبيل', 200000000),
  Item('a', '🛋', 'سرر وأرائك', 500000000),
  Item('h', '🏠', 'بيت في الجنة', 1000000000),
  Item('t', '⛺', 'خيمة من لؤلؤة', 3000000000),
  Item('u', '🌸', 'حور عين', 4000000000),
  Item('d', '👘', 'ثياب من سندس وإستبرق', 8000000000),
  Item('c', '🏰', 'قصر', 1000000000000),
];

// ---------------------------------------------------------------------------
//  المخزن (الحالة + التخزين المحلي)
// ---------------------------------------------------------------------------

class Store extends ChangeNotifier {
  late SharedPreferences sp;

  // الورد والرصيد
  int bal = 0;
  int lastPage = 1;
  Map<String, List<int>> pg = {};
  Set<String> counted = {};
  Set<int> days = {};
  Map<String, int> own = {};
  List<int> bookmarks = [];
  int firstDay = 0;

  // العرض
  double zoom = 1.0;
  bool dark = false;
  bool intro = false;

  // الصلاة والإشعارات
  bool notifEnabled = true;
  bool vibrate = true;
  int notifDelay = 5;
  int method = 1;
  int madhab = 0;
  double? lat;
  double? lon;
  String city = '';

  Future<void> load() async {
    sp = await SharedPreferences.getInstance();
    final s = sp.getString('waad');
    if (s == null) return;
    try {
      final j = jsonDecode(s) as Map<String, dynamic>;
      bal = (j['bal'] as num?)?.toInt() ?? 0;
      lastPage = (j['last'] as num?)?.toInt() ?? 1;
      zoom = (j['zoom'] as num?)?.toDouble() ?? 1.0;
      dark = j['dark'] as bool? ?? false;
      intro = j['intro'] as bool? ?? false;
      pg = (j['pg'] as Map? ?? {}).map(
        (k, v) => MapEntry(k as String, List<int>.from(v as List)),
      );
      counted = Set<String>.from(j['counted'] as List? ?? const []);
      days = Set<int>.from((j['days'] as List? ?? const []).map((e) => e as int));
      own = (j['own'] as Map? ?? {}).map(
        (k, v) => MapEntry(k as String, (v as num).toInt()),
      );
      bookmarks = (j['marks'] as List? ?? const []).map((e) => (e as num).toInt()).toList();
      firstDay = (j['firstDay'] as num?)?.toInt() ?? 0;
      notifEnabled = j['notif'] as bool? ?? true;
      vibrate = j['vib'] as bool? ?? true;
      notifDelay = (j['delay'] as num?)?.toInt() ?? 5;
      method = (j['method'] as num?)?.toInt() ?? 1;
      madhab = (j['madhab'] as num?)?.toInt() ?? 0;
      lat = (j['lat'] as num?)?.toDouble();
      lon = (j['lon'] as num?)?.toDouble();
      city = j['city'] as String? ?? '';
    } catch (_) {}
    if (firstDay == 0) firstDay = today();
  }

  void save() {
    sp.setString(
      'waad',
      jsonEncode({
        'bal': bal,
        'last': lastPage,
        'zoom': zoom,
        'dark': dark,
        'intro': intro,
        'pg': pg,
        'counted': counted.toList(),
        'days': days.toList(),
        'own': own,
        'marks': bookmarks,
        'firstDay': firstDay,
        'notif': notifEnabled,
        'vib': vibrate,
        'delay': notifDelay,
        'method': method,
        'madhab': madhab,
        'lat': lat,
        'lon': lon,
        'city': city,
      }),
    );
    notifyListeners();
  }

  // --- السلسلة اليومية ---
  int streak() {
    var n = 0;
    var d = today();
    if (!days.contains(d)) d--;
    while (days.contains(d)) {
      n++;
      d--;
    }
    return n;
  }

  // --- توزيع الختمة على الصلوات الخمس ---
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
      bal += kPerPage();
      days.add(t);
    }
    if (ctx != null) {
      final l = pg.putIfAbsent(ctx, () => []);
      if (!l.contains(page)) l.add(page);
    }
    save();
  }

  void setZoom(double d) {
    zoom = (zoom + d).clamp(0.6, 2.0).toDouble();
    save();
  }

  /// يعيّن التكبير لقيمة مطلقة (يُستخدم مع التكبير بالأصابع).
  void setZoomAbs(double v, {bool persist = true}) {
    zoom = v.clamp(0.6, 2.0).toDouble();
    if (persist) {
      save();
    } else {
      notifyListeners();
    }
  }

  void buy(Item x) {
    if (bal >= x.price) {
      bal -= x.price;
      own[x.id] = (own[x.id] ?? 0) + 1;
      save();
    }
  }

  bool isBookmarked(int p) => bookmarks.contains(p);

  void toggleBookmark(int p) {
    if (bookmarks.contains(p)) {
      bookmarks.remove(p);
    } else {
      bookmarks.add(p);
    }
    bookmarks.sort();
    save();
  }

  bool hasLocation() => lat != null && lon != null;

  /// عدد الصفحات المقروءة من قائمة صفحات معيّنة في يوم اليوم.
  int pagesRead(List<int> pages) =>
      pages.where((p) => counted.contains('${today()}:$p')).length;

  /// نسبة الإنجاز من قائمة صفحات معيّنة في يوم اليوم.
  double pagesProgress(List<int> pages) =>
      pages.isEmpty ? 0 : pagesRead(pages) / pages.length;

  /// هل أُتمّت ختمة يوم معيّن (أوراد الصلوات الخمس كلها مكتملة)؟
  bool khatmaDayDone(int y, int m, int d) {
    final md = DateTime(y, m + 1, 0).day;
    final D = md < 30 ? md : 30;
    if (d < 1 || d > D) return false;
    for (var i = 0; i < 5; i++) {
      final r = plan(d, i, D);
      final got = (pg['$y-$m-$d-$i'] ?? []).length;
      if (got < r[1] - r[0] + 1) return false;
    }
    return true;
  }
}

final Store store = Store();
// ============================================================================
//  التطبيق: التهيئة، الثيم، الشاشة الافتتاحية، الهيكل العام
// ============================================================================

final NotificationService notifications = NotificationService();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // قاعدة بيانات المناطق الزمنية + المنطقة المحلية للجهاز
  tzdata.initializeTimeZones();
  var tzName = 'Africa/Cairo';
  try {
    final dynamic info = await FlutterTimezone.getLocalTimezone();
    final dynamic id = info.identifier;
    if (id is String && id.isNotEmpty) tzName = id;
  } catch (_) {}
  try {
    tz.setLocalLocation(tz.getLocation(tzName));
  } catch (_) {
    try {
      tz.setLocalLocation(tz.getLocation('Africa/Cairo'));
    } catch (_) {}
  }

  await store.load();
  await notifications.init();

  runApp(const MujahidApp());

  // إعادة جدولة إشعارات الصلاة في الخلفية دون تعطيل فتح التطبيق
  unawaited(notifications.rescheduleAll(store));
}

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final base = ThemeData(
    useMaterial3: true,
    colorSchemeSeed: kGreen,
    brightness: b,
  );
  final cs = base.colorScheme;
  return base.copyWith(
    scaffoldBackgroundColor: dark ? kNightBg : kCream,
    colorScheme: cs.copyWith(
      primary: dark ? const Color(0xFF5FBE97) : kGreen,
      secondary: kGold,
      surface: dark ? kNightSurface : Colors.white,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? kNightSurface : kGreen,
      foregroundColor: kGoldLight,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: const TextStyle(
        fontFamily: 'Amiri',
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: kGoldLight,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dark ? kNightSurface : Colors.white,
      indicatorColor: kGold.withOpacity(0.20),
      height: 68,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(
          fontFamily: 'Amiri',
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: dark ? Colors.white70 : kInk,
        ),
      ),
      iconTheme: WidgetStatePropertyAll(
        IconThemeData(color: dark ? Colors.white70 : kGreen),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: dark ? kGreenMid : kGreen,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontFamily: 'Amiri', fontSize: 17, fontWeight: FontWeight.bold),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: dark ? kGoldLight : kGreen,
        side: BorderSide(color: dark ? kGold.withOpacity(0.6) : kGreen.withOpacity(0.5)),
        textStyle: const TextStyle(fontFamily: 'Amiri', fontSize: 17, fontWeight: FontWeight.bold),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    ),
    textTheme: base.textTheme.apply(fontFamily: 'Amiri'),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: kGreenDeep,
      contentTextStyle: TextStyle(fontFamily: 'Amiri', fontSize: 16, color: Colors.white),
    ),
    dividerTheme: DividerThemeData(color: dark ? const Color(0xFF22392F) : const Color(0xFFE8DFC9)),
  );
}

class MujahidApp extends StatelessWidget {
  const MujahidApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(392.72727272727275, 800.7272727272727),
      minTextAdapt: true,
      enableScaleText: () => false,
      builder: (context, child) => ListenableBuilder(
        listenable: store,
        builder: (c, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          title: kAppName,
          themeMode: store.dark ? ThemeMode.dark : ThemeMode.light,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          builder: (c, w) => MediaQuery(
            data: MediaQuery.of(c).copyWith(textScaler: const TextScaler.linear(1)),
            child: Directionality(textDirection: TextDirection.rtl, child: w!),
          ),
          home: const SplashScreen(),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  عناصر واجهة مشتركة
// ---------------------------------------------------------------------------

/// بطاقة أنيقة بحدود ذهبية خفيفة وظل ناعم.
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Gradient? gradient;
  final Color? borderColor;
  final double radius;

  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.symmetric(vertical: 6),
    this.gradient,
    this.borderColor,
    this.radius = 18,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? (dark ? const Color(0xFF12211B) : Colors.white) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor ?? (dark ? const Color(0xFF233A30) : const Color(0xFFE7DDC4)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(dark ? 0.35 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// عنوان قسم مع أيقونة ذهبية.
class SectionTitle extends StatelessWidget {
  final String text;
  final IconData icon;
  const SectionTitle(this.text, {super.key, this.icon = Icons.auto_awesome});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: kGold),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: dark ? kGoldLight : kGreen,
            ),
          ),
        ],
      ),
    );
  }
}

/// زخرفة نجمية إسلامية خفيفة في الخلفية.
class IslamicPattern extends CustomPainter {
  final Color color;
  IslamicPattern(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const s = 68.0, r = 13.0;
    for (double y = 0; y < size.height + s; y += s) {
      for (double x = 0; x < size.width + s; x += s) {
        for (var k = 0; k < 2; k++) {
          canvas.save();
          canvas.translate(x, y);
          canvas.rotate(k * 0.785398);
          canvas.drawRect(
            Rect.fromCenter(center: Offset.zero, width: r * 2, height: r * 2),
            p,
          );
          canvas.restore();
        }
      }
    }
  }

  @override
  bool shouldRepaint(IslamicPattern o) => o.color != color;
}

/// رقم متحرك عند تغيّر الرصيد.
Widget animatedBalance(TextStyle st) => TweenAnimationBuilder<double>(
      tween: Tween<double>(end: store.bal.toDouble()),
      duration: const Duration(milliseconds: 900),
      builder: (c, v, _) => Text(fmt(v.round()), style: st),
    );

/// فاصل زخرفي.
class GoldDivider extends StatelessWidget {
  const GoldDivider({super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            const Expanded(child: Divider(color: kGold, thickness: 0.6)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.brightness_1, size: 6, color: kGold.withOpacity(0.8)),
            ),
            const Expanded(child: Divider(color: kGold, thickness: 0.6)),
          ],
        ),
      );
}

// ---------------------------------------------------------------------------
//  الشاشة الافتتاحية
// ---------------------------------------------------------------------------

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();
  final String phrase = kPhrases[math.Random().nextInt(kPhrases.length)];

  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 2600), () {
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
            colors: [kGreenDeep, kGreen, kGreenMid],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: IslamicPattern(kGold.withOpacity(0.10)))),
            Center(
              child: FadeTransition(
                opacity: c,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 118,
                      height: 118,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: kGold, width: 2),
                        gradient: const RadialGradient(colors: [kGreenMid, kGreenDeep]),
                      ),
                      child: const Center(
                        child: Icon(Icons.menu_book, size: 58, color: kGoldLight),
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      kAppName,
                      style: TextStyle(
                        fontFamily: 'Amiri',
                        fontSize: 58,
                        fontWeight: FontWeight.bold,
                        color: kGoldLight,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'وعدك مع القرآن',
                      style: TextStyle(fontSize: 17, color: Colors.white70),
                    ),
                    const SizedBox(height: 26),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 34),
                      child: Text(
                        phrase,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 21,
                          color: Colors.white,
                          height: 1.9,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// ============================================================================
//  المواقيت والإشعارات: حساب مواقيت الصلاة + جدولة إشعار بعد كل صلاة
// ============================================================================

class DayTimes {
  final DateTime fajr, sunrise, dhuhr, asr, maghrib, isha;
  const DayTimes(this.fajr, this.sunrise, this.dhuhr, this.asr, this.maghrib, this.isha);

  /// مواقيت الصلوات الخمس بالترتيب: الفجر، الظهر، العصر، المغرب، العشاء.
  List<DateTime> get prayers => [fajr, dhuhr, asr, maghrib, isha];
}

class PrayerService {
  /// يحسب مواقيت يوم معيّن بالإحداثيات والطريقة والمذهب المختارين.
  static DayTimes compute(DateTime day, {DateTime? sunriseHint}) {
    final coords = Coordinates(store.lat!, store.lon!);
    final date = DateComponents(day.year, day.month, day.day);

    var m = store.method;
    if (m < 0 || m >= CalculationMethod.values.length) m = 1;
    final params = CalculationMethod.values[m].getParameters();
    params.madhab = store.madhab == 1 ? Madhab.hanafi : Madhab.shafi;

    final t = PrayerTimes(coords, date, params);
    return DayTimes(
      t.fajr.toLocal(),
      t.sunrise.toLocal(),
      t.dhuhr.toLocal(),
      t.asr.toLocal(),
      t.maghrib.toLocal(),
      t.isha.toLocal(),
    );
  }

  /// المواقيت لعرضها في الواجهة (تاريخ اليوم أو غدًا).
  static DayTimes? forDay(DateTime day) {
    if (!store.hasLocation()) return null;
    try {
      return compute(day);
    } catch (_) {
      return null;
    }
  }

  /// الصلاة القادمة وتاريخها.
  static (String, DateTime)? next(DayTimes t) {
    final now = DateTime.now();
    final list = t.prayers;
    for (var i = 0; i < list.length; i++) {
      if (list[i].isAfter(now)) return (kPrayers[i], list[i]);
    }
    return null;
  }

  /// يحاول تحديد الموقع من الجهاز، مع إمكانية تحديد مدينة يدويًا.
  static Future<String?> locate() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return 'خدمة الموقع غير مفعّلة على الجهاز';
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      return 'لم يتم منح إذن الوصول إلى الموقع';
    }

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
    );
    store.lat = pos.latitude;
    store.lon = pos.longitude;

    var label = 'موقعك الحالي';
    try {
      final uri = Uri.parse(
        'https://api.bigdatacloud.net/data/reverse-geocode-client'
        '?latitude=${pos.latitude}&longitude=${pos.longitude}&localityLanguage=ar',
      );
      final r = await http.get(uri).timeout(const Duration(seconds: 6));
      if (r.statusCode == 200) {
        final j = jsonDecode(r.body) as Map<String, dynamic>;
        final c = (j['city'] ?? j['locality'] ?? j['principalSubdivision'] ?? '') as String;
        if (c.isNotEmpty) label = c;
      }
    } catch (_) {}

    store.city = label;
    store.save();
    return null;
  }

  /// يختار مدينة من القائمة الجاهزة.
  static void pickCity(int index) {
    final c = kCities[index];
    store.city = c[0] as String;
    store.lat = c[1] as double;
    store.lon = c[2] as double;
    store.method = c[3] as int;
    store.save();
  }
}

// ---------------------------------------------------------------------------
//  خدمة الإشعارات
// ---------------------------------------------------------------------------

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static const String _channelId = 'prayer_reminders';
  static const String _channelName = 'تذكير بعد الصلاة';
  static const String _channelDesc = 'إشعار يذكّرك بوردك من القرآن بعد كل صلاة';

  static const String _quranChannelId = 'quran_reminders';
  static const String _quranChannelName = 'تذكير الورد القرآني';

  static const int _basePrayerId = 7000;
  static const int _dailyId = 6000;

  bool _ready = false;

  /// تهيئة القناة والصلاحيات.
  Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: androidInit, iOS: iosInit);

    try {
      await _plugin.initialize(settings: settings);
      _ready = true;
    } catch (_) {
      _ready = false;
      return;
    }

    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      try {
        await android.requestNotificationsPermission();
        await android.requestExactAlarmsPermission();
      } catch (_) {}
    }
  }

  Future<void> _createChannels() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;
    try {
      await android.createNotificationChannel(const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.high,
      ));
      await android.createNotificationChannel(const AndroidNotificationChannel(
        _quranChannelId,
        _quranChannelName,
        description: 'تذكير يومي بقراءة الورد',
        importance: Importance.defaultImportance,
      ));
    } catch (_) {}
  }

  NotificationDetails _details({
    required String body,
    String channelId = _channelId,
    String channelName = _channelName,
  }) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: _channelDesc,
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: store.vibrate,
        styleInformation: BigTextStyleInformation(body),
      ),
      iOS: const DarwinNotificationDetails(),
    );
  }

  /// يجدولة إشعارًا واحدًا في وقت محدّد.
  Future<void> _scheduleAt(
    int id,
    DateTime when,
    String title,
    String body, {
    String channelId = _channelId,
    String channelName = _channelName,
    bool repeatDaily = false,
  }) async {
    if (!_ready) return;
    if (when.isBefore(DateTime.now().add(const Duration(seconds: 5)))) return;
    final tzWhen = tz.TZDateTime.from(when, tz.local);
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tzWhen,
        notificationDetails: _details(
          body: body,
          channelId: channelId,
          channelName: channelName,
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: repeatDaily ? DateTimeComponents.time : null,
      );
    } catch (_) {
      // في حال رفض إذن المنبّه الدقيق نعود إلى الجدولة غير الدقيقة
      try {
        await _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: tzWhen,
          notificationDetails: _details(
            body: body,
            channelId: channelId,
            channelName: channelName,
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: repeatDaily ? DateTimeComponents.time : null,
        );
      } catch (_) {}
    }
  }

  /// يجدد كل إشعارات الصلاة لعدد من الأيام قادمة.
  Future<void> rescheduleAll(Store s) async {
    if (!_ready) return;
    await _createChannels();
    try {
      await _plugin.cancelAll();
    } catch (_) {}

    if (!s.notifEnabled || !s.hasLocation()) return;

    final now = DateTime.now();
    for (var dayOffset = 0; dayOffset < 10; dayOffset++) {
      final day = DateTime(now.year, now.month, now.day).add(Duration(days: dayOffset));
      DayTimes times;
      try {
        times = PrayerService.compute(day);
      } catch (_) {
        continue;
      }
      final list = times.prayers;
      for (var i = 0; i < list.length; i++) {
        final when = list[i].add(Duration(minutes: s.notifDelay));
        await _scheduleAt(
          _basePrayerId + dayOffset * 10 + i,
          when,
          'حان وقت وردك 📖',
          kAfterPrayerBodies[i],
        );
      }
    }

    // تذكير يومي ثابت قبل الفجر لمن لم يقرأ بعد
    final tomorrow = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    await _scheduleAt(
      _dailyId,
      DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 21, 30),
      'لم تفتح وردك اليوم 📖',
      'صفحة واحدة تكفي لتصل. اقرأ صفحتك وارتقِ',
      channelId: _quranChannelId,
      channelName: _quranChannelName,
      repeatDaily: true,
    );
  }

  Future<void> cancelAll() async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }

  /// إشعار فوري (يستخدم عند اكتمال ورد الصلاة).
  Future<void> showNow(String title, String body) async {
    if (!_ready) return;
    try {
      await _plugin.show(
        id: _dailyId + 1,
        title: title,
        body: body,
        notificationDetails: _details(
          body: body,
          channelId: _quranChannelId,
          channelName: _quranChannelName,
        ),
      );
    } catch (_) {}
  }
}
// ============================================================================
//  الهيكل العام: شريط سفلي + تبويبات (الرئيسية، المصحف، الختمة، جنتك، الإعدادات)
// ============================================================================

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tabs = <Widget>[
      HomeTab(onGoToTab: (i) => setState(() => tab = i)),
      const MushafTab(),
      const KhatmaTab(),
      const JannahTab(),
      const SettingsTab(),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(tab == 0 ? kAppName : _titles[tab]),
        actions: [
          IconButton(
            tooltip: 'الوضع الليلي',
            icon: Icon(store.dark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () {
              store.dark = !store.dark;
              store.save();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: IslamicPattern(cs.primary.withOpacity(0.06))),
          ),
          ListenableBuilder(listenable: store, builder: (c, _) => tabs[tab]),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'المصحف'),
          NavigationDestination(icon: Icon(Icons.mosque_outlined), selectedIcon: Icon(Icons.mosque), label: 'الختمة'),
          NavigationDestination(icon: Icon(Icons.park_outlined), selectedIcon: Icon(Icons.park), label: 'جنتك'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'الإعدادات'),
        ],
      ),
    );
  }

  static const List<String> _titles = ['الرئيسية', 'المصحف', 'ختمة الشهر', 'جنتك', 'الإعدادات'];
}

/// يفتح المصحف على قائمة صفحات.
void openPages(BuildContext context, List<int> pages, [String? ctx]) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => ReaderPage(pages: pages, ctx: ctx)),
  );
}

/// يفتح المصحف بدءًا من صفحة معيّنة حتى نهاية المصحف.
void openFrom(BuildContext context, int p) {
  p = p.clamp(1, kPages);
  openPages(context, List.generate(kPages - p + 1, (i) => p + i));
}

// ---------------------------------------------------------------------------
//  تبويب الرئيسية
// ---------------------------------------------------------------------------

class HomeTab extends StatefulWidget {
  final ValueChanged<int> onGoToTab;
  const HomeTab({super.key, required this.onGoToTab});
  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  String? locating;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ayah = kAyahs[today() % kAyahs.length];
    final hadith = kHadiths[today() % kHadiths.length];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        Panel(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: dark ? const [kGreenMid, kGreenDeep] : const [kGreen, kGreenMid],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.format_quote, color: kGoldLight, size: 18),
                  SizedBox(width: 6),
                  Text('آية اليوم', style: TextStyle(color: kGoldLight, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                ayah[0],
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Amiri Quran',
                  fontSize: 25,
                  height: 2.1,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Text('﴿ ${ayah[1]} ﴾', style: const TextStyle(color: kGoldLight, fontSize: 14)),
            ],
          ),
        ),

        Panel(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('رصيد حسناتك', style: TextStyle(color: dark ? Colors.white70 : Colors.black54)),
                    const SizedBox(height: 2),
                    animatedBalance(TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: dark ? kGoldLight : kGreen,
                    )),
                    const SizedBox(height: 4),
                    const Text(kNote, style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(dark ? 0.16 : 0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 24)),
                    Text(ar('${store.streak()}'),
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const Text('يوم متتالي', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
        ),

        _nextPrayerCard(dark),

        Panel(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('صفحات اليوم: ${ar('${store.todayCount()}')}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('آخر موضع: ص ${ar('${store.lastPage}')}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => openFrom(context, store.lastPage),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('كمّل من حيث وقفت'),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => widget.onGoToTab(2),
                      icon: const Icon(Icons.event_available, size: 18),
                      label: const Text('ختمة اليوم'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => openFrom(context, 1),
                      icon: const Icon(Icons.replay, size: 18),
                      label: const Text('من الفاتحة'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Icon(Icons.format_quote, size: 16, color: kGold),
                SizedBox(width: 6),
                Text('حديث اليوم', style: TextStyle(fontWeight: FontWeight.bold, color: kGold)),
              ]),
              const SizedBox(height: 10),
              Text(hadith[0], style: const TextStyle(fontSize: 17, height: 1.9)),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('— ${hadith[1]}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ),
            ],
          ),
        ),

        _developerCard(dark),
      ],
    );
  }

  /// بطاقة مطوّر التطبيق مع رابط التواصل عبر تيليجرام.
  Widget _developerCard(bool dark) {
    return Panel(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          final uri = Uri.parse('https://t.me/abdoshhba');
          try {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } catch (_) {}
        },
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF2AABEE).withOpacity(0.14),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Text('📩', style: TextStyle(fontSize: 26)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('مطوّر التطبيق',
                      style: TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 2),
                  Text(
                    'Abdo',
                    style: TextStyle(
                      fontFamily: 'Amiri',
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: dark ? kGoldLight : kGreen,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'مش طالب غير دعوه حلوه 😊',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 3),
                  const Row(
                    children: [
                      Text('📩', style: TextStyle(fontSize: 13)),
                      SizedBox(width: 4),
                      Text(
                        '@abdoshhba',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF2AABEE),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'للتواصل عبر تيليجرام',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.open_in_new, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _nextPrayerCard(bool dark) {
    if (!store.hasLocation()) {
      return Panel(
        child: Column(
          children: [
            const Text('فعّل تحديد موقعك لعرض مواقيت الصلاة وإشعاراتها',
                textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: locating != null ? null : _locate,
                icon: const Icon(Icons.my_location, size: 18),
                label: Text(locating ?? 'تحديد موقعي الآن'),
              ),
            ),
            TextButton(
              onPressed: () => widget.onGoToTab(4),
              child: const Text('أو اختر مدينتك من الإعدادات'),
            ),
          ],
        ),
      );
    }

    final times = PrayerService.forDay(DateTime.now());
    if (times == null) return const SizedBox.shrink();
    final nx = PrayerService.next(times);

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.access_time, size: 18, color: kGold),
              const SizedBox(width: 8),
              Expanded(
                child: Text('مواقيت الصلاة — ${store.city}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
          const GoldDivider(),
          if (nx != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              decoration: BoxDecoration(
                color: kGold.withOpacity(dark ? 0.15 : 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('الصلاة القادمة: ${nx.$1}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: kGold)),
                        Text('باقي ${countdown(nx.$2.difference(DateTime.now()))}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  Text(clock(nx.$2), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < 5; i++)
                Expanded(
                  child: Column(
                    children: [
                      Text(kPrayers[i], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(clock(times.prayers[i]), style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.notifications_active, size: 15, color: kGold),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  store.notifEnabled
                      ? 'إشعار بعد كل صلاة • ${store.city}'
                      : 'الإشعارات متوقفة — فعّلها من الإعدادات',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
              IconButton(
                onPressed: _refreshPrayers,
                icon: const Icon(Icons.refresh, size: 18),
                tooltip: 'تحديث المواقيت',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _locate() async {
    setState(() => locating = 'جارٍ تحديد الموقع…');
    final err = await PrayerService.locate();
    if (!mounted) return;
    setState(() => locating = null);
    await notifications.rescheduleAll(store);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(err ?? 'تم ضبط المواقيت لـ ${store.city}، وسيصلك إشعار بعد كل صلاة'),
    ));
  }

  Future<void> _refreshPrayers() async {
    await notifications.rescheduleAll(store);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم تحديث إشعارات الصلاة للأيام القادمة')),
    );
  }
}

// ---------------------------------------------------------------------------
//  تبويب المصحف
// ---------------------------------------------------------------------------

class MushafTab extends StatefulWidget {
  const MushafTab({super.key});
  @override
  State<MushafTab> createState() => _MushafTabState();
}

class _MushafTabState extends State<MushafTab> {
  final TextEditingController gpc = TextEditingController();
  String query = '';
  List<int> surahHits = [];

  @override
  void dispose() {
    gpc.dispose();
    super.dispose();
  }

  int _parsePage(String raw) {
    final normalized = raw.replaceAllMapped(
      RegExp(r'[٠-٩]'),
      (m) => '${'٠١٢٣٤٥٦٧٨٩'.indexOf(m.group(0)!)}',
    );
    return int.tryParse(normalized.trim()) ?? 1;
  }

  void _search(String q) {
    setState(() {
      query = q;
      surahHits = [];
      if (q.trim().isEmpty) return;
      final norm = removeDiacritics(q.trim());
      for (var n = 1; n <= 114; n++) {
        if (removeDiacritics(getSurahNameArabic(n)).contains(norm)) surahHits.add(n);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        Panel(
          child: Column(
            children: [
              TextField(
                controller: gpc,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'انتقل إلى صفحة (١ - ٦٠٤)',
                  prefixIcon: Icon(Icons.tag),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => openFrom(context, _parsePage(gpc.text)),
                      child: const Text('فتح الصفحة'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => openFrom(context, store.lastPage),
                      icon: const Icon(Icons.bookmark_border, size: 18),
                      label: const Text('آخر موضع'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        if (store.bookmarks.isNotEmpty) ...[
          const SectionTitle('العلامات المرجعية', icon: Icons.bookmark),
          Panel(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in store.bookmarks)
                  ActionChip(
                    avatar: const Icon(Icons.bookmark, size: 15, color: kGold),
                    label: Text('ص ${ar('$p')}'),
                    onPressed: () => openFrom(context, p),
                  ),
              ],
            ),
          ),
        ],

        const SectionTitle('الأجزاء الثلاثون', icon: Icons.grid_view),
        Panel(
          child: GridView.count(
            crossAxisCount: 5,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.5,
            children: List.generate(
              30,
              (i) => OutlinedButton(
                style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                onPressed: () => openFrom(context, i == 0 ? 1 : 20 * i + 2),
                child: Text(ar('${i + 1}')),
              ),
            ),
          ),
        ),

        const SectionTitle('فهرس السور', icon: Icons.list_alt),
        Panel(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: TextField(
            onChanged: _search,
            decoration: const InputDecoration(
              hintText: 'ابحث باسم السورة…',
              prefixIcon: Icon(Icons.search),
              border: InputBorder.none,
            ),
          ),
        ),
        for (var n = 1; n <= 114; n++)
          if (query.trim().isEmpty || surahHits.contains(n)) _surahRow(n, dark),
      ],
    );
  }

  Widget _surahRow(int n, bool dark) {
    final verses = kVerseCounts[n - 1];
    return Panel(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => openFrom(context, getPageNumber(n, 1)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kGold.withOpacity(dark ? 0.20 : 0.14),
                  border: Border.all(color: kGold.withOpacity(0.6)),
                ),
                child: Center(
                  child: Text(ar('$n'),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kGold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('سورة ${getSurahNameArabic(n)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('${ar('$verses')} آية',
                        style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
              Text('ص ${ar('${getPageNumber(n, 1)}')}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_left, size: 18, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
// ============================================================================
//  قارئ المصحف: عرض الصفحات بخطوط QCF مع الحفاظ على هندسة الصفحة
// ============================================================================

/// يعيد اسم السورة التي تقع فيها الصفحة المطلوبة.
String surahNameForPage(int page) {
  var name = getSurahNameArabic(1);
  for (var n = 1; n <= 114; n++) {
    final first = getPageNumber(n, 1);
    if (first <= page) {
      name = getSurahNameArabic(n);
    } else {
      break;
    }
  }
  return name;
}

/// يعيد رقم السورة التي تقع فيها الصفحة المطلوبة.
int surahNumberForPage(int page) {
  var num = 1;
  for (var n = 1; n <= 114; n++) {
    if (getPageNumber(n, 1) <= page) {
      num = n;
    } else {
      break;
    }
  }
  return num;
}

class ReaderPage extends StatefulWidget {
  final List<int> pages;
  final String? ctx;
  const ReaderPage({super.key, required this.pages, this.ctx});

  @override
  State<ReaderPage> createState() => _ReaderState();
}

class _ReaderState extends State<ReaderPage> with WidgetsBindingObserver {
  late int cur = widget.pages.first;
  int sec = 0;
  int rk = 0;
  bool active = true;
  Timer? timer;
  bool counted = false;
  bool hiddenUI = false;
  final Map<int, Offset> _touches = {};
  double? _pinchDist;
  double _pinchZoom = 1.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    store.lastPage = cur;
    store.save();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!active || !mounted) return;
      sec++;
      if (sec == kSecondsToCount && !counted) counted = true;
      if (sec == kSecondsToCount) {
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
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void go(int d) {
    final n = (cur + d).clamp(widget.pages.first, widget.pages.last).toInt();
    if (n == cur) return;
    _jump(n);
  }

  void _jump(int n) {
    setState(() {
      cur = n;
      sec = 0;
      counted = false;
      rk++;
    });
    store.lastPage = n;
    store.save();
  }

  /// يختار مستوى التكبير/التصغير مع الحفاظ على تطابق حجم الخط وارتفاع السطر
  /// (وإلا تنكسر أسطر الصفحة القرآنية).
  double get _scale => store.zoom.clamp(0.8, 2.0).toDouble();

  /// حجم الخط الأساسي الذي لا تتكسر عنده الأسطر (لا يتغير أبدًا)
  static const double _base = 0.92;

  void _setZoom(double v) {
    store.zoom = double.parse(v.clamp(0.8, 2.0).toStringAsFixed(2));
    store.save();
  }

  /// شريط تكبير/تصغير رفيع أعلى الصفحة
  Widget _zoomBar() {
    final dark = store.dark;
    Widget btn(IconData i, VoidCallback f, String tip) => IconButton(
          tooltip: tip,
          onPressed: f,
          visualDensity: VisualDensity.compact,
          icon: Icon(i, size: 24),
        );
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: dark ? kNightSurface : Colors.white,
        border: Border(
            bottom: BorderSide(color: dark ? const Color(0xFF233A30) : const Color(0xFFE7DDC4))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          btn(Icons.zoom_out, () => _setZoom(store.zoom - 0.15), 'تصغير'),
          SizedBox(
            width: 70,
            child: Text('${ar('${(_scale * 100).round()}')}٪',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          btn(Icons.zoom_in, () => _setZoom(store.zoom + 0.15), 'تكبير'),
          const SizedBox(width: 14),
          btn(Icons.restart_alt, () => _setZoom(1.0), 'الحجم الأصلي'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: store, builder: (c, _) => _page(context));
  }

  Widget _page(BuildContext context) {
    final dark = store.dark;
    final theme = dark
        ? QcfThemeData(
            verseTextColor: const Color(0xFFF2EADA),
            pageBackgroundColor: const Color(0xFF0E1814),
          )
        : QcfThemeData(
            verseTextColor: const Color(0xFF14251E),
            pageBackgroundColor: const Color(0xFFFDFBF4),
          );

    final surah = surahNameForPage(cur);

    final scaffold = Scaffold(
      backgroundColor: dark ? kNightBg : kCream,
      appBar: hiddenUI ? null : AppBar(
        title: Column(
          children: [
            Text('سورة $surah', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text('صفحة ${ar('$cur')}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: store.isBookmarked(cur) ? 'إزالة العلامة' : 'علامة مرجعية',
            icon: Icon(store.isBookmarked(cur) ? Icons.bookmark : Icons.bookmark_border,
                color: store.isBookmarked(cur) ? kGoldLight : null),
            onPressed: () => store.toggleBookmark(cur),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              if (v == 'page') _askPage();
              if (v == 'zoom_in') _setZoom(store.zoom + 0.15);
              if (v == 'zoom_out') _setZoom(store.zoom - 0.15);
              if (v == 'reset') {
                store.zoom = 1.0;
                store.save();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'page', child: Text('انتقل إلى صفحة')),
              PopupMenuItem(value: 'zoom_in', child: Text('تكبير الخط')),
              PopupMenuItem(value: 'zoom_out', child: Text('تصغير الخط')),
              PopupMenuItem(value: 'reset', child: Text('الحجم الافتراضي')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (!hiddenUI) _zoomBar(),
          Expanded(
            child: LayoutBuilder(
              builder: (context, cons) {
                // الصفحة تُرسم دائمًا بحجمها الطبيعي (فلا تتكسر الأسطر مهما كبّرت)،
                // ثم تُكبَّر أو تُصغَّر كوحدة واحدة قابلة للتمرير رأسيًا وأفقيًا.
                final pw = cons.maxWidth;
                final ph = MediaQuery.of(context).size.height;
                final z = _scale;
                final page = SizedBox(
                  width: pw,
                  height: ph,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: PageviewQuran(
                        key: ValueKey(rk),
                        initialPageNumber: cur,
                        sp: _base.sp,
                        h: _base.h,
                        theme: theme,
                        onPageChanged: (p) {
                          setState(() {
                            cur = p;
                            sec = 0;
                            counted = false;
                          });
                          store.lastPage = p;
                          store.save();
                        },
                      ),
                    ),
                  ),
                );
                // عند التكبير نعطّل سحب الصفحات الجانبي ليصبح السحب للتحريك داخل
                // الصفحة المكبّرة (والتنقل بين الصفحات يتم بزرّي التالية/السابقة).
                final scaled = SizedBox(
                  width: pw * z,
                  height: ph * z,
                  child: FittedBox(
                    fit: BoxFit.fill,
                    child: IgnorePointer(ignoring: z > 1.0, child: page),
                  ),
                );
                final body = z > 1.0
                    ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: scaled)
                    : Center(child: scaled);
                return SingleChildScrollView(
                  key: ValueKey('v$rk'),
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  child: body,
                );
              },
            ),
          ),
          // علامة صح صغيرة تحت الصفحة عند احتساب قراءتها
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: store.counted.contains('${today()}:$cur')
                ? const Padding(
                    key: ValueKey('done'),
                    padding: EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.check_circle, size: 18, color: kGold),
                  )
                : const SizedBox(key: ValueKey('wait'), height: 22),
          ),
          if (!hiddenUI) _bottomBar(),
        ],
      ),
    );
    return Listener(
      onPointerDown: (e) {
        _touches[e.pointer] = e.position;
        if (_touches.length == 2) {
          final p = _touches.values.toList();
          _pinchDist = (p[0] - p[1]).distance;
          _pinchZoom = store.zoom;
        }
      },
      onPointerMove: (e) {
        if (!_touches.containsKey(e.pointer)) return;
        _touches[e.pointer] = e.position;
        if (_touches.length == 2 && _pinchDist != null && _pinchDist! > 0) {
          final p = _touches.values.toList();
          final dist = (p[0] - p[1]).distance;
          store.setZoomAbs(_pinchZoom * dist / _pinchDist!, persist: false);
        }
      },
      onPointerUp: (e) => _endTouch(e.pointer),
      onPointerCancel: (e) => _endTouch(e.pointer),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => setState(() => hiddenUI = !hiddenUI),
        child: scaffold,
      ),
    );
  }

  void _endTouch(int pointer) {
    final wasPinch = _touches.length >= 2;
    _touches.remove(pointer);
    if (_touches.length < 2) _pinchDist = null;
    if (wasPinch && _touches.isEmpty) store.save();
  }

  Widget _bottomBar() {
    final dark = store.dark;
    final progress = store.pagesProgress(widget.pages);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: dark ? kNightSurface : Colors.white,
        border: Border(top: BorderSide(color: dark ? const Color(0xFF233A30) : const Color(0xFFE7DDC4))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, size: 14, color: counted ? kGold : Colors.grey),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'ورد هذه الجلسة: ${ar('${store.pagesRead(widget.pages)}')} من ${ar('${widget.pages.length}')} صفحة',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: progress, minHeight: 5, backgroundColor: Colors.grey.withOpacity(0.2)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: cur < widget.pages.last ? () => go(1) : null,
                  child: const Text('التالية'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: cur > widget.pages.first ? () => go(-1) : null,
                  child: const Text('السابقة'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _askPage() async {
    final c = TextEditingController(text: '$cur');
    final v = await showDialog<int>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('انتقل إلى صفحة'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: '١ - ٦٠٤'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () => Navigator.pop(d, int.tryParse(c.text)),
            child: const Text('انتقال'),
          ),
        ],
      ),
    );
    if (v == null) return;
    _jump(v.clamp(1, kPages));
  }
}
// ============================================================================
//  تبويبات: الختمة، جنتك، الإعدادات
// ============================================================================

// ---------------------------------------------------------------------------
//  الختمة
// ---------------------------------------------------------------------------

class KhatmaTab extends StatelessWidget {
  const KhatmaTab({super.key});

  @override
  Widget build(BuildContext context) {
    final n = DateTime.now();
    final md = DateTime(n.year, n.month + 1, 0).day;
    final D = md < 30 ? md : 30;
    final d = n.day;

    if (d > D) {
      return ListView(padding: const EdgeInsets.all(16), children: const [
        Panel(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'اليوم راحة ومراجعة، لا صفحات جديدة 🤍\nتبدأ ختمة الشهر الجديد في أول يوم',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, height: 1.9),
            ),
          ),
        ),
      ]);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        Panel(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('ختمة اليوم ${ar('$d')} من ${ar('$D')}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('${ar('${n.day}/${n.month}')}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(value: d / D, minHeight: 9),
              ),
              const SizedBox(height: 8),
              const Text(
                'وردك اليومي مقسّم على الصلوات الخمس، لتقرأ بعد كل صلاة جزءًا يسيرًا',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
        const SectionTitle('ورد اليوم', icon: Icons.auto_stories),
        for (var i = 0; i < 5; i++) _prayerRow(context, n, d, D, i),
        if (_allDone(n, d, D)) _doneBanner(d),
      ],
    );
  }

  bool _allDone(DateTime n, int d, int D) {
    for (var i = 0; i < 5; i++) {
      if (!_isDone(n, d, D, i)) return false;
    }
    return true;
  }

  /// لافتة احتفاء تحفيزية تظهر تحت الصلوات عند إتمام ختمة اليوم.
  Widget _doneBanner(int d) {
    final dark = store.dark;
    final praise = kKhatmaPraise[d % kKhatmaPraise.length];
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: dark ? const [kGreenMid, kGreenDeep] : const [kGreen, kGreenMid],
        ),
        border: Border.all(color: kGold, width: 1.6),
        boxShadow: [BoxShadow(color: kGold.withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        children: [
          const Text('🏆', style: TextStyle(fontSize: 44)),
          const SizedBox(height: 8),
          const Text(
            'أتممت ختمة اليوم!',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kGoldLight),
          ),
          const SizedBox(height: 8),
          Text(
            praise,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: Colors.white, height: 1.9),
          ),
        ],
      ),
    );
  }

  bool _isDone(DateTime n, int d, int D, int i) {
    final r = store.plan(d, i, D);
    return (store.pg['${n.year}-${n.month}-$d-$i'] ?? []).length >= r[1] - r[0] + 1;
  }

  Widget _prayerRow(BuildContext context, DateTime n, int d, int D, int i) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final r = store.plan(d, i, D);
    final key = '${n.year}-${n.month}-$d-$i';
    final done = _isDone(n, d, D, i);
    final read = (store.pg[key] ?? []).length;
    final total = r[1] - r[0] + 1;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: done
            ? (dark ? kGreenMid.withOpacity(0.35) : kGreen.withOpacity(0.08))
            : (dark ? const Color(0xFF12211B) : Colors.white),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: done ? kGold.withOpacity(0.8) : (dark ? const Color(0xFF233A30) : const Color(0xFFE7DDC4)),
          width: done ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => openPages(context, List.generate(total, (k) => r[0] + k), key),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? kGold.withOpacity(0.18) : cs.surfaceContainerHighest.withOpacity(0.5),
                ),
                child: Icon(
                  done ? Icons.check : Icons.menu_book_outlined,
                  size: 22,
                  color: done ? kGold : Colors.grey,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(kPrayers[i], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                    const SizedBox(height: 2),
                    Text('ص ${ar('${r[0]}')} – ${ar('${r[1]}')}  •  ${ar('$read')}/${ar('$total')}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    if (read > 0 && !done) ...[
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: read / total,
                          minHeight: 4,
                          backgroundColor: Colors.grey.withOpacity(0.18),
                          valueColor: const AlwaysStoppedAnimation<Color>(kGold),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (done)
                const Text('تمت', style: TextStyle(fontWeight: FontWeight.bold, color: kGold))
              else if (read > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: kGold.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kGold.withOpacity(0.45)),
                  ),
                  child: Text(
                    'باقي ${ar('${total - read}')}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kGold),
                  ),
                )
              else
                const Icon(Icons.chevron_left, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  جنتك
// ---------------------------------------------------------------------------

class JannahTab extends StatefulWidget {
  const JannahTab({super.key});
  @override
  State<JannahTab> createState() => _JannahTabState();
}

class _JannahTabState extends State<JannahTab> {
  @override
  void initState() {
    super.initState();
    if (!store.intro) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('هذه الجنة رمزية لتحفّزك، أما جنة الله فأعظم مما تتخيل'),
          duration: Duration(seconds: 5),
        ));
        store.intro = true;
        store.save();
      });
    }
  }

  Widget _scene() {
    final h = DateTime.now().hour;
    final night = h < 6 || h >= 18;
    final total = store.own.values.fold<int>(0, (a, b) => a + b);
    final txt = kItems
        .map((x) => x.emoji * (store.own[x.id] ?? 0).clamp(0, 8))
        .join(' ')
        .trim();
    return Container(
      height: 210,
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
      child: Stack(
        children: [
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
                  child: Text(
                    txt.isEmpty ? 'جنتك تنتظر أول غرسة 🌱' : txt,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: txt.isEmpty ? 18 : 30,
                      color: night ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        _scene(),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('رصيد حسناتك'),
              animatedBalance(TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: dark ? kGoldLight : kGreen,
              )),
              const Text(kNote, style: TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
        const SectionTitle('اغرس في جنتك', icon: Icons.spa),
        for (final x in kItems) _itemCard(x, dark),
      ],
    );
  }

  Widget _itemCard(Item x, bool dark) {
    final ok = store.bal >= x.price;
    final owned = store.own[x.id] ?? 0;
    final remain = x.price > store.bal ? x.price - store.bal : 0;
    final prog = (store.bal / x.price).clamp(0, 1).toDouble();
    return Panel(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [kGold.withOpacity(0.24), kGold.withOpacity(0.05)],
                  ),
                  border: Border.all(color: kGold.withOpacity(0.55), width: 1.5),
                  boxShadow: [BoxShadow(color: kGold.withOpacity(0.18), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Center(child: Text(x.emoji, style: const TextStyle(fontSize: 52))),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(x.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                    const SizedBox(height: 4),
                    Text('${fmt(x.price)} عملة', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                    if (owned > 0) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: kGold.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: kGold.withOpacity(0.55)),
                        ),
                        child: Text(
                          'تم اقتناؤها ✓${owned > 1 ? ' ×${ar('$owned')}' : ''}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kGold),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: prog,
              minHeight: 10,
              backgroundColor: Colors.grey.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation<Color>(ok ? kGold : kGreenMid),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  ok ? 'متاحة للاقتناء الآن ✨' : 'فاضل ${fmt(remain)} عملة',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: ok ? kGold : Colors.grey,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: ok ? () => _buy(x) : null,
                icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                label: const Text('اقتناء'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _buy(Item x) {
    store.buy(x);
    _buyDialog(x);
  }

  /// رسالة احتفاء عند الاقتناء: تشجيع + تذكير بأنها رمزية والأجر عند الله.
  void _buyDialog(Item x) {
    showDialog(
      context: context,
      builder: (d) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.3, end: 1),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (c, v, _) => Transform.scale(
                scale: v,
                child: Text(x.emoji, style: const TextStyle(fontSize: 72)),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'تم الحصول عليها 🎉',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kGold),
            ),
            const SizedBox(height: 10),
            Text(
              'أضيفت «${x.name}» إلى جنتك!\nكل صفحة قرأتها قرّبتك منها… فما أعظم أن يكون لك في الجنة الحقيقية أضعافها',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, height: 1.9),
            ),
            const SizedBox(height: 10),
            const Text(
              'هذه جنة رمزية للتحفيز فقط،\nوالأجر الحقيقي على قدر نيتك عند الله 🤍',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.8),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('الحمد لله'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  الإعدادات
// ---------------------------------------------------------------------------

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});
  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  String? busy;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        const SectionTitle('الإشعارات', icon: Icons.notifications_active),
        Panel(
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: store.notifEnabled,
                title: const Text('إشعار بعد كل صلاة'),
                subtitle: const Text('يذكّرك بوردك من القرآن بعد الفجر والظهر والعصر والمغرب والعشاء',
                    style: TextStyle(fontSize: 11)),
                onChanged: (v) async {
                  store.notifEnabled = v;
                  store.save();
                  setState(() {});
                  if (v) {
                    await notifications.rescheduleAll(store);
                  } else {
                    await notifications.cancelAll();
                  }
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: store.vibrate,
                title: const Text('اهتزاز الإشعار'),
                onChanged: (v) {
                  store.vibrate = v;
                  store.save();
                  setState(() {});
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('تأخير الإشعار بعد الأذان'),
                subtitle: Text('${ar('${store.notifDelay}')} دقائق'),
              ),
              Slider(
                value: store.notifDelay.toDouble().clamp(0, 30).toDouble(),
                min: 0,
                max: 30,
                divisions: 30,
                label: '${ar('${store.notifDelay}')} دقيقة',
                onChanged: (v) => setState(() => store.notifDelay = v.round()),
                onChangeEnd: (v) async {
                  store.save();
                  await notifications.rescheduleAll(store);
                },
              ),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await notifications.showNow('حان وقت وردك 📖', 'هذه تجربة لإشعار ورد القرآن');
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم إرسال إشعار تجريبي')),
                    );
                  },
                  icon: const Icon(Icons.send, size: 18),
                  label: const Text('تجربة إشعار الآن'),
                ),
              ),
            ],
          ),
        ),

        const SectionTitle('الموقع والمواقيت', icon: Icons.location_on),
        Panel(
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.place, color: kGold),
                title: Text(store.hasLocation() ? store.city : 'لم يُحدَّد الموقع بعد'),
                subtitle: store.hasLocation()
                    ? Text('${store.lat!.toStringAsFixed(3)}، ${store.lon!.toStringAsFixed(3)}',
                        style: const TextStyle(fontSize: 11))
                    : const Text('حدّد موقعك لحساب مواقيت الصلاة بدقة', style: TextStyle(fontSize: 11)),
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: busy != null ? null : _locate,
                  icon: const Icon(Icons.my_location, size: 18),
                  label: Text(busy ?? 'تحديد موقعي تلقائيًا'),
                ),
              ),
              const SizedBox(height: 12),
              _picker<String>(
                label: 'أو اختر مدينتك',
                icon: Icons.location_city,
                value: kCities.any((c) => c[0] == store.city) ? store.city : null,
                items: [
                  for (final c in kCities)
                    DropdownMenuItem<String>(value: c[0] as String, child: Text(c[0] as String)),
                ],
                onChanged: (v) async {
                  if (v == null) return;
                  final idx = kCities.indexWhere((c) => c[0] == v);
                  if (idx < 0) return;
                  PrayerService.pickCity(idx);
                  setState(() {});
                  await notifications.rescheduleAll(store);
                },
              ),
              const SizedBox(height: 12),
              _picker<int>(
                label: 'طريقة حساب المواقيت',
                icon: Icons.calculate,
                value: store.method,
                items: [
                  for (var i = 0; i < kMethods.length; i++)
                    DropdownMenuItem<int>(value: i, child: Text(kMethods[i][0])),
                ],
                onChanged: (v) async {
                  if (v == null) return;
                  store.method = v;
                  store.save();
                  setState(() {});
                  await notifications.rescheduleAll(store);
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('مذهب العصر:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 0, label: Text('شافعي')),
                        ButtonSegment(value: 1, label: Text('حنفي')),
                      ],
                      selected: {store.madhab},
                      onSelectionChanged: (s) async {
                        store.madhab = s.first;
                        store.save();
                        setState(() {});
                        await notifications.rescheduleAll(store);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SectionTitle('عرض المصحف', icon: Icons.text_fields),
        Panel(
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: store.dark,
                title: const Text('الوضع الليلي'),
                onChanged: (v) {
                  store.dark = v;
                  store.save();
                  setState(() {});
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('حجم خط المصحف'),
                subtitle: Text('${ar('${(store.zoom * 100).round()}')}٪'),
              ),
              Slider(
                value: store.zoom.clamp(0.8, 2.0).toDouble(),
                min: 0.8,
                max: 2.0,
                divisions: 24,
                onChanged: (v) => setState(() => store.zoom = v),
                onChangeEnd: (_) => store.save(),
              ),
              const Text(
                'التكبير يكبّر الصفحة كلها بنفس تنسيق المصحف المطبوع دون تكسير الأسطر',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),

        const SectionTitle('تقرير الشهر', icon: Icons.fact_check_outlined),
        Panel(
          padding: EdgeInsets.zero,
          child: ListTile(
            leading: const Icon(Icons.calendar_month, color: kGold),
            title: const Text('تقرير ختمة الشهر', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('أيامك الثلاثون: المكتمل والفائت والقادم', style: TextStyle(fontSize: 11)),
            trailing: const Icon(Icons.chevron_left, color: Colors.grey),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReportPage()),
            ),
          ),
        ),

        const SectionTitle('عن التطبيق', icon: Icons.info_outline),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('مجاهد — وعدك مع القرآن', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 6),
              const Text(
                'تطبيق يعينك على الورد اليومي: مصحف بخطوط المصحف المدني، '
                'وختمة شهرية موزّعة على الصلوات، وتذكير بعد كل صلاة.',
                style: TextStyle(fontSize: 13, height: 1.8),
              ),
              const GoldDivider(),
              Text('ختمات مكتملة: ${ar('${(store.days.length / 30).floor()}')}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text('أيام القراءة: ${ar('${store.days.length}')}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text('صفحات مقروءة إجمالًا: ${ar('${(store.bal / kPerPageAvg).round()}')}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      ],
    );
  }

  /// قائمة اختيار متوافقة مع كل إصدارات Flutter (بدون DropdownButtonFormField).
  Widget _picker<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Future<void> _locate() async {
    setState(() => busy = 'جارٍ تحديد الموقع…');
    final err = await PrayerService.locate();
    if (!mounted) return;
    setState(() => busy = null);
    await notifications.rescheduleAll(store);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(err ?? 'تم تحديد الموقع: ${store.city}'),
    ));
  }
}

// ============================================================================
//  تقرير الشهر: متابعة أيام الختمة الثلاثين
// ============================================================================

class ReportPage extends StatelessWidget {
  const ReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final dark = Theme.of(context).brightness == Brightness.dark;
        final n = DateTime.now();
        final y = n.year, m = n.month, todayD = n.day;
        final md = DateTime(y, m + 1, 0).day;
        final D = md < 30 ? md : 30;

        // 0 = قبل تثبيت التطبيق، 1 = مكتمل، 2 = فائت، 3 = اليوم الحالي، 4 = قادم
        var done = 0, missed = 0;
        final states = List<int>.filled(D + 1, 0);
        for (var d = 1; d <= D; d++) {
          final epoch = DateTime.utc(y, m, d).difference(DateTime.utc(1970)).inDays;
          if (epoch < store.firstDay) {
            states[d] = 0;
          } else if (store.khatmaDayDone(y, m, d)) {
            states[d] = 1;
            done++;
          } else if (d < todayD) {
            states[d] = 2;
            missed++;
          } else if (d == todayD) {
            states[d] = 3;
          } else {
            states[d] = 4;
          }
        }

        return Scaffold(
          appBar: AppBar(title: const Text('تقرير الشهر')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              Panel(
                child: Row(
                  children: [
                    Expanded(
                      child: _summaryChip(
                        icon: '✅',
                        value: done,
                        label: 'يوم مكتمل',
                        color: const Color(0xFF2E7D32),
                        dark: dark,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _summaryChip(
                        icon: '❌',
                        value: missed,
                        label: 'يوم فائت',
                        color: const Color(0xFFC62828),
                        dark: dark,
                      ),
                    ),
                  ],
                ),
              ),
              const SectionTitle('أيام الشهر', icon: Icons.grid_on),
              Panel(
                child: GridView.count(
                  crossAxisCount: 5,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  children: [
                    for (var d = 1; d <= D; d++) _dayCell(d, states[d], dark),
                  ],
                ),
              ),
              const Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('دليل الألوان', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text('🟢 أخضر + ✓ : يوم أتممت فيه ختمتك كاملة',
                        style: TextStyle(fontSize: 13, height: 1.8)),
                    Text('🔴 أحمر : يوم فاتك دون إتمام الختمة',
                        style: TextStyle(fontSize: 13, height: 1.8)),
                    Text('⚪ أبيض : قبل تثبيتك التطبيق أو يوم قادم',
                        style: TextStyle(fontSize: 13, height: 1.8)),
                    Text('🟡 ذهبي : يومك الحالي',
                        style: TextStyle(fontSize: 13, height: 1.8)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _summaryChip({
    required String icon,
    required int value,
    required String label,
    required Color color,
    required bool dark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(dark ? 0.22 : 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 4),
          Text(ar('$value'),
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _dayCell(int d, int state, bool dark) {
    Color bg, fg, border;
    String mark;
    switch (state) {
      case 1:
        bg = const Color(0xFF2E7D32);
        fg = Colors.white;
        border = const Color(0xFF2E7D32);
        mark = '✓';
        break;
      case 2:
        bg = const Color(0xFFC62828);
        fg = Colors.white;
        border = const Color(0xFFC62828);
        mark = '✗';
        break;
      case 3:
        bg = kGold.withOpacity(0.16);
        fg = dark ? kGoldLight : kGreen;
        border = kGold;
        mark = '•';
        break;
      default:
        bg = dark ? kNightSurface : Colors.white;
        fg = dark ? Colors.white54 : Colors.black45;
        border = dark ? const Color(0xFF233A30) : const Color(0xFFE7DDC4);
        mark = state == 0 ? '—' : '';
    }
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: state == 3 ? 1.8 : 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(ar('$d'),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: fg)),
          if (mark.isNotEmpty)
            Text(mark,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: fg)),
        ],
      ),
    );
  }
}
