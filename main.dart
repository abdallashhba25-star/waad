import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const kPages = 604;
const kPer = 2500;
const prayers = ['الفجر', 'الظهر', 'العصر', 'المغرب', 'العشاء'];
const phrases = [
  'الجنة تنتظرك',
  'الآخرة خير وأبقى',
  'صفحة اليوم تقرّبك من وعد الله',
  'خيركم من تعلّم القرآن وعلّمه',
  'اجعل القرآن أنيس يومك',
  'كل صفحة تقرؤها خطوة نحو جنتك',
  'ابدأ بصفحة واحدة الآن',
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
  Item('h', '🏠', 'بيت في الجنة', 100000000),
  Item('u', '🌸', 'حور عين', 400000000),
  Item('c', '🏰', 'قصر', 100000000000),
];

String fmt(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('٬');
    b.write(s[i]);
  }
  return ar(b.toString());
}

String ar(String s) {
  const d = '٠١٢٣٤٥٦٧٨٩';
  return s.split('').map((c) {
    final v = int.tryParse(c);
    return v == null ? c : d[v];
  }).join();
}

int today() {
  final n = DateTime.now();
  return DateTime.utc(n.year, n.month, n.day).difference(DateTime.utc(1970)).inDays;
}

class Store extends ChangeNotifier {
  late SharedPreferences sp;
  int bal = 0, last = 1;
  double fs = 26;
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
      fs = (j['fs'] ?? 26).toDouble();
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
          'bal': bal, 'last': last, 'fs': fs,
          'dark': dark, 'intro': intro, 'pg': pg, 'counted': counted.toList(),
          'days': days.toList(), 'own': own,
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

  bool countPage(int page, String? ctx) {
    final t = today();
    counted.removeWhere((k) => !k.startsWith('$t:'));
    var got = false;
    final k = '$t:$page';
    if (!counted.contains(k)) {
      counted.add(k);
      bal += kPer;
      days.add(t);
      got = true;
    }
    if (ctx != null) {
      final l = pg.putIfAbsent(ctx, () => []);
      if (!l.contains(page)) l.add(page);
    }
    save();
    return got;
  }

  void buy(Item x) {
    if (bal >= x.price) {
      bal -= x.price;
      own[x.id] = (own[x.id] ?? 0) + 1;
      save();
    }
  }

  void setFs(double d) {
    fs = (fs + d).clamp(16, 44).toDouble();
    save();
  }

  Future<String?> fetchPage(int p) async {
    final k = 'p$p';
    final c = sp.getString(k);
    if (c != null) return c;
    for (final b in bases) {
      try {
        final r = await http
            .get(Uri.parse('$b/verses/by_page/$p?fields=text_uthmani&per_page=50'))
            .timeout(const Duration(seconds: 15));
        if (r.statusCode == 200) {
          final j = jsonDecode(utf8.decode(r.bodyBytes));
          final vs = j['verses'] as List;
          final t = vs.map((v) => '${v['text_uthmani']} ﴿${ar('${v['verse_number']}')}﴾').join(' ');
          if (t.isNotEmpty) {
            await sp.setString(k, t);
            return t;
          }
        }
      } catch (_) {}
    }
    return null;
  }
}

final store = Store();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await store.load();
  runApp(const WaadApp());
}

class WaadApp extends StatelessWidget {
  const WaadApp({super.key});
  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF1F6B4F);
    return ListenableBuilder(
      listenable: store,
      builder: (c, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'وعد',
        themeMode: store.dark ? ThemeMode.dark : ThemeMode.light,
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: seed),
        darkTheme: ThemeData(useMaterial3: true, colorSchemeSeed: seed, brightness: Brightness.dark),
        builder: (c, w) => Directionality(textDirection: TextDirection.rtl, child: w!),
        home: const Shell(),
      ),
    );
  }
}

Widget card(Widget child) => Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(padding: const EdgeInsets.all(14), child: child),
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
    final tabs = [home(), mushaf(), khatma(), Jannah(open: () {})];
    return Scaffold(
      appBar: AppBar(
        title: const Text('وعد', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.text_decrease), onPressed: () => store.setFs(-2)),
          IconButton(icon: const Icon(Icons.text_increase), onPressed: () => store.setFs(2)),
          IconButton(
              icon: const Icon(Icons.brightness_6),
              onPressed: () {
                store.dark = !store.dark;
                store.save();
              }),
        ],
      ),
      body: ListenableBuilder(listenable: store, builder: (c, _) => tabs[tab]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: tab,
        type: BottomNavigationBarType.fixed,
        onTap: (i) => setState(() => tab = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'الرئيسية'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'المصحف'),
          BottomNavigationBarItem(icon: Icon(Icons.mosque), label: 'الختمة'),
          BottomNavigationBarItem(icon: Icon(Icons.park), label: 'جنتك'),
        ],
      ),
    );
  }

  Widget home() {
    final big = TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.amber.shade800);
    return ListView(padding: const EdgeInsets.all(16), children: [
      card(Center(
          child: Text(phrases[today() % phrases.length],
              style: big, textAlign: TextAlign.center))),
      card(Row(children: [
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('رصيد حسناتك'),
          Text(fmt(store.bal), style: big),
          const Text(note, style: TextStyle(fontSize: 11, color: Colors.grey)),
        ])),
        Column(children: [
          const Text('🔥', style: TextStyle(fontSize: 28)),
          Text(ar('${store.streak()}'), style: big),
          const Text('يوم متتالي', style: TextStyle(fontSize: 11)),
        ]),
      ])),
      card(Column(children: [
        Text('صفحات اليوم: ${ar('${store.todayCount()}')}'),
        const SizedBox(height: 8),
        FilledButton(
            onPressed: () => openFrom(store.last),
            child: Text('كمّل من حيث وقفت (ص ${ar('${store.last}')})')),
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
        FilledButton(
            onPressed: () => openFrom(int.tryParse(gp.text) ?? 1), child: const Text('فتح')),
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
    ]);
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
    return ListView(padding: const EdgeInsets.all(16), children: [
      card(Column(children: [
        Text('ختمة اليوم ${ar('$d')} من ${ar('$D')}  (${ar('${n.day}/${n.month}')})',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: d / D),
      ])),
      for (var i = 0; i < 5; i++) prayerRow(n, d, D, i),
    ]);
  }

  Widget prayerRow(DateTime n, int d, int D, int i) {
    final r = store.plan(d, i, D);
    final key = '${n.year}-${n.month}-$d-$i';
    final done = (store.pg[key] ?? []).length >= r[1] - r[0] + 1;
    return Card(
      child: ListTile(
        title: Text(prayers[i], style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('ص ${ar('${r[0]}')} – ${ar('${r[1]}')}'),
        trailing: Icon(done ? Icons.check_circle : Icons.chevron_left,
            color: done ? Colors.green : null),
        onTap: () => open(List.generate(r[1] - r[0] + 1, (k) => r[0] + k), key),
      ),
    );
  }
}

class Jannah extends StatefulWidget {
  final VoidCallback open;
  const Jannah({super.key, required this.open});
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

  @override
  Widget build(BuildContext context) {
    final scene = items.map((x) => x.emoji * (store.own[x.id] ?? 0).clamp(0, 10)).join(' ').trim();
    final big = TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.amber.shade800);
    return ListView(padding: const EdgeInsets.all(16), children: [
      card(Center(
          child: Text(scene.isEmpty ? 'جنتك تنتظر أول غرسة 🌱' : scene,
              style: const TextStyle(fontSize: 30), textAlign: TextAlign.center))),
      card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('رصيد حسناتك'),
        Text(fmt(store.bal), style: big),
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
      const SizedBox(height: 6),
      LinearProgressIndicator(value: (store.bal / x.price).clamp(0, 1).toDouble()),
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
  bool active = true, err = false;
  Timer? timer;
  String? text;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!active || !mounted) return;
      setState(() => sec++);
      if (sec == 20) store.countPage(widget.pages[i], widget.ctx);
    });
    load();
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

  Future<void> load() async {
    final p = widget.pages[i];
    store.last = p;
    store.save();
    setState(() {
      text = null;
      err = false;
    });
    final r = await store.fetchPage(p);
    if (!mounted || p != widget.pages[i]) return;
    setState(() {
      text = r;
      err = r == null;
    });
  }

  void go(int d) {
    final n = i + d;
    if (n < 0 || n >= widget.pages.length) return;
    setState(() {
      i = n;
      sec = 0;
    });
    load();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.pages[i];
    return Scaffold(
      appBar: AppBar(
        title: Text('صفحة ${ar('$p')}'),
        actions: [
          IconButton(icon: const Icon(Icons.text_decrease), onPressed: () => store.setFs(-2)),
          IconButton(icon: const Icon(Icons.text_increase), onPressed: () => store.setFs(2)),
        ],
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (c, _) => Column(children: [
          Expanded(
              child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: text != null
                ? Text(text!,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: store.fs, height: 2.1))
                : err
                    ? Column(children: [
                        const SizedBox(height: 40),
                        const Text('تعذّر تحميل الصفحة، تأكد من الإنترنت'),
                        TextButton(onPressed: load, child: const Text('إعادة المحاولة')),
                      ])
                    : const Padding(
                        padding: EdgeInsets.only(top: 60),
                        child: Center(child: CircularProgressIndicator())),
          )),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(child: FilledButton(onPressed: () => go(1), child: const Text('التالية'))),
              const SizedBox(width: 10),
              Expanded(
                  child: OutlinedButton(onPressed: () => go(-1), child: const Text('السابقة'))),
            ]),
          ),
        ]),
      ),
    );
  }
}
