part of '../main.dart';

// ===== الترحيب + الصفحة الرئيسية (نفس تصميم الموقع) =====

const siteUrl = 'https://nokhba.ammaralhaddar83.workers.dev';
const feedbackEmail = 'd38227194@gmail.com';
const _photoCount = 20;
const _portraitPhotos = <int>{5, 7};

String _two(int i) => i.toString().padLeft(2, '0');
String _thumbAsset(int i) => 'assets/images/t/h${_two(i)}.jpg';
String _fullAsset(int i) => 'assets/images/h/h${_two(i)}.jpg';

const _visionText =
    'نحو مدرسة رائدة في التميز والتعلم المستدام، وبيئة آمنة وشراكة فاعلة، وقيادة تشاركية عادلة وشفافة.';
const _missionText =
    'تلتزم المدرسة بتقديم تعليم نوعي يركز على تحسين تعلم الطلبة ورفع أدائهم، وتوفير بيئة مدرسية آمنة ونظيفة، '
    'وبناء شراكات فاعلة مع الأسرة والمجتمع المحلي، وتمكين الكادر المدرسي من المشاركة في القيادة وتحمل المسؤوليات '
    'بعدالة وشفافية؛ لتحقيق التحسين المستمر والتميز المدرسي.';

Future<void> openExternal(BuildContext context, String url) async {
  try {
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) toast(context, 'تعذّر فتح الرابط');
  } catch (_) {
    if (context.mounted) toast(context, 'تعذّر فتح الرابط');
  }
}

// ---------- صفحة الترحيب (صورة الشعار) ----------
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _gone = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1500), _go);
  }

  void _go() {
    if (_gone || !mounted) return;
    _gone = true;
    splashShown = true;
    Navigator.of(context).pushReplacement(PageRouteBuilder<void>(
      pageBuilder: (_, __, ___) => const LandingScreen(),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
      transitionDuration: const Duration(milliseconds: 500),
    ));
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: _go,
        child: Scaffold(
          backgroundColor: const Color(0xFFE0E0DD),
          body: SizedBox.expand(child: Image.asset('assets/images/splash.jpg', fit: BoxFit.cover)),
        ),
      );
}

// ---------- الصفحة الرئيسية ----------
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});
  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3400))..repeat();
  late final Future<List<Map<String, dynamic>>> _ann = _loadAnnouncements();
  Timer? _timer;
  int _idx = 0;
  List<Map<String, dynamic>> _db = [];

  @override
  void initState() {
    super.initState();
    splashShown = true;
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      setState(() => _idx = (_idx + 1) % (_photoCount + _db.length));
    });
    Future.delayed(const Duration(milliseconds: 2500), _loadDb);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  Future<void> _loadDb() async {
    try {
      final d = await sb.from('gallery').select('id,img').order('created_at');
      final list = List<Map<String, dynamic>>.from(d)
          .where((r) => ((r['img'] ?? '') as String).startsWith('data:image/'))
          .toList();
      if (mounted) setState(() => _db = list);
    } catch (_) {/* بدون اتصال */}
  }

  void _info(String title, String image, String text) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, textAlign: TextAlign.center, style: GoogleFonts.arefRuqaa(fontSize: 26, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(width: 130, height: 130, child: ClipOval(child: assetImage(image))),
            const SizedBox(height: 14),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(height: 1.9)),
          ]),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
      ),
    );
  }

  Widget _bubble(String label, Widget bg, VoidCallback onTap, int i, double size) => FloatBubble(
        anim: _c,
        phase: i * 0.17,
        size: size,
        onTap: onTap,
        child: Stack(fit: StackFit.expand, children: [
          bg,
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 5),
              color: const Color.fromRGBO(0, 0, 0, .6),
              child: Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      );

  Widget _photoBox(double height) {
    final cs = Theme.of(context).colorScheme;
    final total = _photoCount + _db.length;
    final i = _idx % total;
    Widget img;
    if (i < _photoCount) {
      final n = i + 1;
      img = Container(
        color: const Color(0xFF0F172A),
        child: Image.asset(_thumbAsset(n),
            fit: _portraitPhotos.contains(n) ? BoxFit.contain : BoxFit.cover, width: double.infinity, height: double.infinity),
      );
    } else {
      img = dbImage(_db[i - _photoCount]['img'] as String?, width: double.infinity, height: double.infinity);
    }
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const GalleryScreen())),
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: cs.primary, width: 3),
          boxShadow: const [BoxShadow(color: Color.fromRGBO(37, 99, 235, .3), blurRadius: 16, offset: Offset(0, 6))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(25),
          child: Stack(fit: StackFit.expand, children: [
            AnimatedSwitcher(duration: const Duration(milliseconds: 600), child: KeyedSubtree(key: ValueKey<int>(i), child: img)),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                color: const Color.fromRGBO(0, 0, 0, .55),
                child: const Text('صور المدرسة — اضغط لعرض الكل', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 13)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _annBoard() {
    final cs = Theme.of(context).colorScheme;
    return _Panel(
      pad: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('لوحة الإعلانات', style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 110),
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _ann,
            builder: (c, s) {
              if (s.connectionState != ConnectionState.done) return const LinearProgressIndicator();
              final items = s.data ?? [];
              if (items.isEmpty) return const Text('لا توجد إعلانات حالياً', style: TextStyle(fontSize: 13));
              return SingleChildScrollView(
                child: Column(children: [
                  for (final a in items)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(color: cs.surfaceContainerHighest.withValues(alpha: .6), borderRadius: BorderRadius.circular(8)),
                      child: Text('${a['text'] ?? ''}', style: const TextStyle(fontSize: 13.5)),
                    ),
                ]),
              );
            },
          ),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bubble = ((size.width - 32 - 24) / 3).floorToDouble().clamp(80.0, 112.0).toDouble();
    final photoH = (size.height * 0.27).clamp(150.0, 230.0).toDouble();
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton(
                onPressed: () => toggleThemeMode(context),
                child: Text(dark ? 'الوضع الفاتح' : 'الوضع الداكن'),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'مدرسة الملك عبد الله الثاني للتميز – الطفيلة',
              textAlign: TextAlign.center,
              style: GoogleFonts.arefRuqaa(fontSize: 26, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB), height: 1.5),
            ),
            const SizedBox(height: 8),
            _photoBox(photoH),
            _annBoard(),
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 14,
              children: [
                _bubble('الرؤية', assetImage('vision.jpg'), () => _info('رؤيتنا', 'vision.jpg', _visionText), 0, bubble),
                _bubble('الرسالة', assetImage('mission.jpg'), () => _info('رسالتنا', 'mission.jpg', _missionText), 1, bubble),
                _bubble(
                  'الإدارة',
                  ColoredBox(color: const Color(0xFFF1F5F9), child: assetImage('office.svg')),
                  () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const LoginScreen(admin: true))),
                  2,
                  bubble,
                ),
                _bubble(
                  'المعلمون',
                  assetImage('teacher-char.jpg'),
                  () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const LoginScreen())),
                  3,
                  bubble,
                ),
                _bubble(
                  'الطالب',
                  assetImage('student-char.jpg'),
                  () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const HomeScreen())),
                  4,
                  bubble,
                ),
                _bubble(
                  'رأيك',
                  assetImage('icon-feedback.svg'),
                  () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const FeedbackScreen())),
                  5,
                  bubble,
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => openExternal(context, '$siteUrl/privacy'),
              child: const Text('سياسة الخصوصية', style: TextStyle(fontSize: 12, decoration: TextDecoration.underline)),
            ),
          ]),
        ),
      ),
    );
  }
}

// ---------- عارض الصورة بتكبير ----------
class PhotoViewerScreen extends StatelessWidget {
  const PhotoViewerScreen({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        body: Stack(children: [
          Positioned.fill(child: InteractiveViewer(minScale: 1, maxScale: 5, child: Center(child: child))),
          SafeArea(
            child: Align(
              alignment: AlignmentDirectional.topStart,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton.filled(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ),
            ),
          ),
        ]),
      );
}

void openPhoto(BuildContext context, Widget child) =>
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => PhotoViewerScreen(child: child)));

// ---------- معرض الصور ----------
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});
  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  List<Map<String, dynamic>> _db = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await sb.from('gallery').select('id,img').order('created_at');
      final list = List<Map<String, dynamic>>.from(d)
          .where((r) => ((r['img'] ?? '') as String).startsWith('data:image/'))
          .toList();
      if (mounted) setState(() => _db = list);
    } catch (_) {/* بدون اتصال */}
  }

  Future<void> _add() async {
    final files = await ImagePicker().pickMultiImage(maxWidth: 1100, imageQuality: 72);
    if (files.isEmpty) return;
    setState(() => _busy = true);
    var ok = 0;
    for (final f in files) {
      try {
        final bytes = await f.readAsBytes();
        await sb.from('gallery').insert({'img': 'data:image/jpeg;base64,${base64Encode(bytes)}'});
        ok++;
      } catch (e) {
        if (mounted) toast(context, 'تعذر الرفع: $e');
        break;
      }
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok > 0) toast(context, 'تمت إضافة $ok صورة');
    _load();
  }

  Future<void> _del(Map<String, dynamic> r) async {
    if (!await confirmDialog(context, 'حذف هذه الصورة؟')) return;
    try {
      await sb.from('gallery').delete().eq('id', r['id'] as Object);
      _load();
    } catch (e) {
      if (mounted) toast(context, 'تعذر الحذف: $e');
    }
  }

  Widget _tile(Widget image, VoidCallback onTap, {VoidCallback? onDelete}) => GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(fit: StackFit.expand, children: [
            image,
            if (onDelete != null)
              Positioned(
                top: 4,
                left: 4,
                child: InkWell(
                  onTap: onDelete,
                  child: const CircleAvatar(radius: 14, backgroundColor: Colors.red, child: Icon(Icons.close, size: 16, color: Colors.white)),
                ),
              ),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: 118,
        leading: const BackPill(),
        title: const Text('صور المدرسة'),
        actions: [
          if (session.isAdmin)
            IconButton(
              tooltip: 'إضافة صور',
              onPressed: _busy ? null : _add,
              icon: _busy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.add_photo_alternate_outlined),
            ),
        ],
      ),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(12),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        children: [
          for (var n = 1; n <= _photoCount; n++)
            _tile(
              Image.asset(_thumbAsset(n), fit: BoxFit.cover),
              () => openPhoto(context, Image.asset(_fullAsset(n), fit: BoxFit.contain)),
            ),
          for (final r in _db)
            _tile(
              dbImage(r['img'] as String?),
              () => openPhoto(context, dbImage(r['img'] as String?, fit: BoxFit.contain)),
              onDelete: session.isAdmin ? () => _del(r) : null,
            ),
        ],
      ),
    );
  }
}

// ---------- رأيك (يفتح تطبيق البريد) ----------
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});
  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final msg = _c.text.trim();
    if (msg.isEmpty) {
      toast(context, 'اكتب رأيك أولاً');
      return;
    }
    final url = 'mailto:$feedbackEmail?subject=${Uri.encodeComponent('رأي في تطبيق نخبة')}&body=${Uri.encodeComponent(msg)}';
    await openExternal(context, url);
    _c.clear();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leadingWidth: 118,
          leading: const BackPill(),
          title: const Text('شاركنا رأيك'),
        ),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          _Panel(
            child: Column(children: [
              TextField(
                controller: _c,
                maxLines: 6,
                maxLength: 1000,
                decoration: const InputDecoration(hintText: 'اكتب رأيك أو اقتراحك لتحسين التطبيق...', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, child: FilledButton(onPressed: _send, child: const Text('إرسال'))),
            ]),
          ),
        ]),
      );
}
