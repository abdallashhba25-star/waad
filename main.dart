import 'dart:async';
import 'dart:convert';
import 'dart:math' show Random;
import 'package:flutter/material.dart';
import 'package:qcf_quran/qcf_quran.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kPages = 604;
const kPer = 2500;
const kSecs = 20;
const gold = Color(0xFFE0B34F);
const goldDark = Color(0xFFB8892B);
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
const bases = [
  'https://api.quran.com/api/v4',
  'https://apis.quran.foundation/content/api/v4',
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await store.load();
  runApp(const WaadApp());
}

ThemeData mk(Brightness b) {
  final base = ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF1F6B4F), brightness: b);
  return base;
}

class WaadApp extends StatelessWidget {
  const WaadApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
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
              Text('مجاهد',
                  style: TextStyle(fontSize: 76, fontWeight: FontWeight.bold, color: gold)),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(phrase,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, color: Colors.white, height: 1.8)),
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
        title: Text('مجاهد',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 26, color: goldDark)),
        actions: [
          IconButton(
              icon: const Icon(Icons.brightness_6),
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
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: goldDark, height: 1.7)),
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

class ReaderPage extends StatefulWidget {
  final List<int> pages;
  final String? ctx;
  const ReaderPage({super.key, required this.pages, this.ctx});
  @override
  State<ReaderPage> createState() => _ReaderState();
}

class _ReaderState extends State<ReaderPage> with WidgetsBindingObserver {
  int i = 0, sec = 0;
  bool active = true;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    store.last = widget.pages[0];
    store.save();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!active || !mounted) return;
      sec++;
      if (sec == kSecs) store.countPage(widget.pages[i], widget.ctx);
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
    final n = i + d;
    if (n < 0 || n >= widget.pages.length) return;
    setState(() {
      i = n;
      sec = 0;
    });
    store.last = widget.pages[n];
    store.save();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: store, builder: (c, _) => page(c));
  }

  Widget page(BuildContext context) {
    final p = widget.pages[i];
    const pw = 392.7272, ph = 800.7272; // التصميم المرجعي لخط المصحف
    final paper = store.dark ? const Color(0xFF14201A) : Colors.white;
    final theme = store.dark
        ? QcfThemeData(verseTextColor: const Color(0xFFEDE7D5), pageBackgroundColor: paper)
        : QcfThemeData(verseTextColor: Colors.black, pageBackgroundColor: paper);
    return Scaffold(
      appBar: AppBar(
        title: Text('صفحة ${ar('$p')}'),
        actions: [
          IconButton(icon: const Icon(Icons.zoom_out), onPressed: () => store.setZoom(-0.15)),
          IconButton(icon: const Icon(Icons.zoom_in), onPressed: () => store.setZoom(0.15)),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: paper,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: gold, width: 2),
            ),
            child: LayoutBuilder(builder: (c, cons) {
              final scale = cons.maxWidth / pw * store.zoom;
              return SingleChildScrollView(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: cons.maxWidth),
                    child: Center(
                      child: SizedBox(
                        width: pw * scale,
                        height: ph * scale,
                        child: FittedBox(
                          fit: BoxFit.fill,
                          child: SizedBox(
                            width: pw,
                            height: ph,
                            child: MediaQuery(
                              data: MediaQuery.of(c).copyWith(size: const Size(pw, ph)),
                              child: QcfPage(key: ValueKey(p), pageNumber: p, theme: theme),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Row(children: [
            Expanded(child: FilledButton(onPressed: () => go(1), child: const Text('التالية'))),
            const SizedBox(width: 10),
            Expanded(child: OutlinedButton(onPressed: () => go(-1), child: const Text('السابقة'))),
          ]),
        ),
      ]),
    );
  }
}
