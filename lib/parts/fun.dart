part of '../main.dart';

// ===== الترفيه: أسئلة السرعة + لعبة الذاكرة =====

class FunScreen extends StatelessWidget {
  const FunScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget card(String title, IconData icon, Widget Function() page) => Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Material(
            color: cs.surface.withValues(alpha: .85),
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page())),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Row(children: [
                  Icon(icon, size: 34, color: cs.primary),
                  const SizedBox(width: 16),
                  Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ]),
              ),
            ),
          ),
        );

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: 118,
        leading: const BackPill(),
        title: const Text('الترفيه'),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        card('أسئلة سرعة', Icons.bolt_rounded, () => const SpeedQuizScreen()),
        card('لعبة الذاكرة', Icons.grid_view_rounded, () => const MemoryScreen()),
      ]),
    );
  }
}

// ---------- أسئلة السرعة ----------
class SpeedQuizScreen extends StatefulWidget {
  const SpeedQuizScreen({super.key});
  @override
  State<SpeedQuizScreen> createState() => _SpeedQuizScreenState();
}

class _QOption {
  _QOption(this.text, this.ok);
  final String text;
  final bool ok;
}

class _SpeedQuizScreenState extends State<SpeedQuizScreen> {
  final _rnd = math.Random();
  Timer? _timer;
  String _phase = 'start'; // start | active | result
  int _left = 30;
  int _score = 0;
  int _idx = 0;
  late List<_QuizQ> _qs;
  List<_QOption> _opts = [];

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _qs = List<_QuizQ>.from(_quizData)..shuffle(_rnd);
    _left = 30;
    _score = 0;
    _idx = 0;
    _prepare();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _left--);
      if (_left <= 0) _end();
    });
    setState(() => _phase = 'active');
  }

  void _prepare() {
    if (_idx >= _qs.length) {
      _end();
      return;
    }
    final q = _qs[_idx];
    _opts = [for (var i = 0; i < q.options.length; i++) _QOption(q.options[i], i == q.answer)]..shuffle(_rnd);
  }

  void _answer(bool ok) {
    setState(() {
      if (ok) _score++;
      _idx++;
      _prepare();
    });
  }

  void _end() {
    _timer?.cancel();
    if (mounted) setState(() => _phase = 'result');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget body;
    if (_phase == 'start') {
      body = Column(children: [
        const SizedBox(height: 20),
        const Text('لديك 30 ثانية للإجابة على أكبر عدد ممكن من الأسئلة العامة!', textAlign: TextAlign.center, style: TextStyle(fontSize: 17)),
        const SizedBox(height: 18),
        FilledButton(onPressed: _start, child: const Padding(padding: EdgeInsets.symmetric(horizontal: 18, vertical: 8), child: Text('ابدأ التحدي الآن'))),
      ]);
    } else if (_phase == 'active') {
      final q = _idx < _qs.length ? _qs[_idx] : null;
      body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text.rich(TextSpan(children: [
            const TextSpan(text: 'الوقت المتبقي: '),
            TextSpan(text: '$_left', style: const TextStyle(color: Color(0xFFEF4444), fontSize: 20, fontWeight: FontWeight.bold)),
            const TextSpan(text: ' ثانية'),
          ]), style: const TextStyle(fontWeight: FontWeight.bold)),
          Text.rich(TextSpan(children: [
            const TextSpan(text: 'النتيجة: '),
            TextSpan(text: '$_score', style: const TextStyle(color: Color(0xFF10B981), fontSize: 20, fontWeight: FontWeight.bold)),
          ]), style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
        _Panel(child: Text(q?.q ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
        const SizedBox(height: 8),
        for (final o in _opts)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), backgroundColor: cs.surface.withValues(alpha: .8)),
              onPressed: () => _answer(o.ok),
              child: Text(o.text, style: const TextStyle(fontSize: 16)),
            ),
          ),
      ]);
    } else {
      body = Column(children: [
        const SizedBox(height: 20),
        const Text('انتهى الوقت!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Text.rich(TextSpan(children: [
          const TextSpan(text: 'أجبت على '),
          TextSpan(text: '$_score', style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold, fontSize: 22)),
          const TextSpan(text: ' أسئلة بشكل صحيح!'),
        ]), style: const TextStyle(fontSize: 17)),
        const SizedBox(height: 18),
        FilledButton(onPressed: _start, child: const Padding(padding: EdgeInsets.symmetric(horizontal: 18, vertical: 8), child: Text('إعادة التحدي'))),
      ]);
    }
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: 118,
        leading: const BackPill(),
        title: const Text('أسئلة سرعة'),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [body]),
    );
  }
}

// ---------- لعبة الذاكرة ----------
class _MemPair {
  const _MemPair(this.a, this.b, this.fact);
  final String a;
  final String b;
  final String fact;
}

const _memPairs = <_MemPair>[
  _MemPair('الأردن', 'عمان', 'عمان عاصمة الأردن، وتُعرف بمدينة التلال السبعة.'),
  _MemPair('فرنسا', 'باريس', 'باريس عاصمة فرنسا وفيها برج إيفل الشهير.'),
  _MemPair('مصر', 'القاهرة', 'القاهرة عاصمة مصر وتقع على نهر النيل.'),
  _MemPair('اليابان', 'طوكيو', 'طوكيو عاصمة اليابان وهي من أكبر مدن العالم سكاناً.'),
  _MemPair('السعودية', 'الرياض', 'الرياض هي عاصمة المملكة العربية السعودية.'),
  _MemPair('الذهب', 'Au', 'رمز الذهب Au مأخوذ من الكلمة اللاتينية aurum.'),
  _MemPair('الحديد', 'Fe', 'رمز الحديد Fe مأخوذ من الكلمة اللاتينية ferrum.'),
  _MemPair('الأكسجين', 'O', 'الأكسجين يشكل نحو 21% من هواء الغلاف الجوي.'),
  _MemPair('الماء', 'H2O', 'جزيء الماء يتكون من ذرتي هيدروجين وذرة أكسجين.'),
  _MemPair('الجمل', 'سفينة الصحراء', 'الجمل يخزن الدهون في سنامه ويتحمل العطش أياماً طويلة.'),
  _MemPair('المريخ', 'الكوكب الأحمر', 'لون المريخ الأحمر سببه أكسيد الحديد في تربته.'),
  _MemPair('الحوت الأزرق', 'أكبر حيوان', 'الحوت الأزرق أكبر حيوان عرفته الأرض، ويصل طوله إلى نحو 30 متراً.'),
  _MemPair('البتراء', 'المدينة الوردية', 'البتراء بناها الأنباط، وهي من عجائب الدنيا السبع الجديدة.'),
  _MemPair('العقبة', 'ميناء الأردن', 'العقبة هي الميناء البحري الوحيد في الأردن وتقع على البحر الأحمر.'),
  _MemPair('البحر الميت', 'أخفض نقطة', 'البحر الميت أخفض نقطة على سطح اليابسة، ويقع نحو 430 متراً تحت مستوى سطح البحر.'),
  _MemPair('نهر النيل', 'أطول نهر', 'يُعدّ النيل أطول نهر في العالم، ويبلغ طوله نحو 6650 كم.'),
];

class _MemCard {
  _MemCard(this.pair, this.text, this.fact);
  final int pair;
  final String text;
  final String fact;
  bool flipped = false;
  bool matched = false;
}

class MemoryScreen extends StatefulWidget {
  const MemoryScreen({super.key});
  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> {
  final _rnd = math.Random();
  List<_MemCard> _cards = [];
  int? _first;
  bool _lock = false;
  int _moves = 0;
  int _matched = 0;
  int _gameId = 0;
  String _fact = '';

  @override
  void initState() {
    super.initState();
    _new();
  }

  void _new() {
    final pool = List<_MemPair>.from(_memPairs)..shuffle(_rnd);
    final cards = <_MemCard>[];
    for (var i = 0; i < 8; i++) {
      cards.add(_MemCard(i, pool[i].a, pool[i].fact));
      cards.add(_MemCard(i, pool[i].b, pool[i].fact));
    }
    cards.shuffle(_rnd);
    setState(() {
      _gameId++;
      _cards = cards;
      _first = null;
      _lock = false;
      _moves = 0;
      _matched = 0;
      _fact = '';
    });
  }

  void _flip(int idx) {
    final card = _cards[idx];
    if (_lock || card.flipped || card.matched) return;
    setState(() => card.flipped = true);
    if (_first == null) {
      _first = idx;
      return;
    }
    final first = _cards[_first!];
    setState(() => _moves++);
    if (first.pair == card.pair) {
      setState(() {
        first.matched = true;
        card.matched = true;
        _matched++;
        _first = null;
        _fact = _matched == 8 ? 'أحسنت! أنهيت اللعبة في $_moves محاولة 🎉' : '💡 ${card.fact}';
      });
    } else {
      _lock = true;
      final gid = _gameId;
      Future.delayed(const Duration(milliseconds: 900), () {
        if (!mounted || gid != _gameId) return;
        setState(() {
          first.flipped = false;
          card.flipped = false;
          _first = null;
          _lock = false;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: 118,
        leading: const BackPill(),
        title: const Text('لعبة الذاكرة'),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('المحاولات: $_moves', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text('الأزواج: $_matched / 8', style: const TextStyle(fontWeight: FontWeight.bold)),
          FilledButton.tonal(onPressed: _new, child: const Text('لعبة جديدة')),
        ]),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: .85,
          children: [
            for (var i = 0; i < _cards.length; i++)
              InkWell(
                onTap: () => _flip(i),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _cards[i].matched
                        ? const Color(0xFF10B981)
                        : (_cards[i].flipped ? cs.primaryContainer : cs.primary),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    (_cards[i].flipped || _cards[i].matched) ? _cards[i].text : '؟',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: (_cards[i].flipped || _cards[i].matched) ? 13 : 24,
                      fontWeight: FontWeight.bold,
                      color: _cards[i].matched
                          ? Colors.white
                          : (_cards[i].flipped ? cs.onPrimaryContainer : cs.onPrimary),
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (_fact.isNotEmpty) _Panel(child: Text(_fact, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, height: 1.7))),
      ]),
    );
  }
}
