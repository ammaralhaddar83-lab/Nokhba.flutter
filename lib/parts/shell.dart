part of '../main.dart';

// ===== shell: الوضع الداكن، زر الرجوع، السهم العائم، جذر التطبيق =====

final themeMode = ValueNotifier<ThemeMode>(ThemeMode.system);
final showBackArrow = ValueNotifier<bool>(false);
final navKey = GlobalKey<NavigatorState>();
final canGoBack = ValueNotifier<bool>(false);

/// يصبح true بعد عرض صفحة الترحيب مرة واحدة في هذه الجلسة.
bool splashShown = false;

Future<void> loadThemeMode() async {
  try {
    final p = await SharedPreferences.getInstance();
    final v = p.getString('themeMode');
    themeMode.value = v == 'dark' ? ThemeMode.dark : (v == 'light' ? ThemeMode.light : ThemeMode.system);
  } catch (_) {/* تجاهل */}
}

Future<void> toggleThemeMode(BuildContext c) async {
  final dark = Theme.of(c).brightness == Brightness.dark;
  themeMode.value = dark ? ThemeMode.light : ThemeMode.dark;
  try {
    final p = await SharedPreferences.getInstance();
    await p.setString('themeMode', dark ? 'light' : 'dark');
  } catch (_) {/* تجاهل */}
}

/// سهم برأس منحني ناعم (نفس شكل سهم الموقع).
class _ArrowPainter extends CustomPainter {
  const _ArrowPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(4.5 * s, 12 * s)
      ..lineTo(19 * s, 12 * s)
      ..moveTo(13.2 * s, 5.6 * s)
      ..cubicTo(14.6 * s, 8.8 * s, 16.6 * s, 10.8 * s, 19.6 * s, 12 * s)
      ..cubicTo(16.6 * s, 13.2 * s, 14.6 * s, 15.2 * s, 13.2 * s, 18.4 * s);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ArrowPainter oldDelegate) => oldDelegate.color != color;
}

class ArrowIcon extends StatelessWidget {
  const ArrowIcon({super.key, this.size = 24, this.color = Colors.white});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size(size, size), painter: _ArrowPainter(color));
}

/// زر "رجوع" داخل الصفحة (يظهر فقط إذا كانت هناك صفحة سابقة).
class BackPill extends StatelessWidget {
  const BackPill({super.key});

  @override
  Widget build(BuildContext context) {
    final can = ModalRoute.of(context)?.canPop ?? false;
    if (!can) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 12, top: 8, bottom: 8),
        child: Material(
          color: cs.surface,
          shape: StadiumBorder(side: BorderSide(color: cs.outlineVariant)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () => navKey.currentState?.maybePop(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ArrowIcon(size: 22, color: cs.primary),
                  const SizedBox(width: 6),
                  Text('رجوع', style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BackObserver extends NavigatorObserver {
  void _upd() => WidgetsBinding.instance.addPostFrameCallback((_) {
        canGoBack.value = navKey.currentState?.canPop() ?? false;
        showBackArrow.value = false;
      });

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _upd();
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _upd();
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => _upd();
}

/// السهم العائم: يظهر أعلى اليسار بعد التمرير لأسفل (عند اختفاء زر "رجوع" الصفحة).
Widget _floatingArrow(BuildContext context) {
  final top = MediaQuery.of(context).padding.top + 12;
  return Positioned(
    left: 12,
    top: top,
    child: ValueListenableBuilder<bool>(
      valueListenable: canGoBack,
      builder: (_, can, __) => ValueListenableBuilder<bool>(
        valueListenable: showBackArrow,
        builder: (_, scrolled, __) {
          final visible = can && scrolled;
          return IgnorePointer(
            ignoring: !visible,
            child: AnimatedSlide(
              offset: visible ? Offset.zero : const Offset(0, -1.5),
              duration: const Duration(milliseconds: 220),
              child: AnimatedOpacity(
                opacity: visible ? 1 : 0,
                duration: const Duration(milliseconds: 220),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => navKey.currentState?.maybePop(),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF0EA5E9)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(color: const Color.fromRGBO(255, 255, 255, .75), width: 2),
                        boxShadow: const [BoxShadow(color: Color.fromRGBO(37, 99, 235, .4), blurRadius: 18, offset: Offset(0, 6))],
                      ),
                      child: const Center(child: ArrowIcon(size: 26)),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

/// الخلفية: شعار المدرسة ثابت مع بلور خفيف + سهم الرجوع العائم عند التمرير.
Widget _appShell(BuildContext context, Widget? child) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return Stack(children: [
    Positioned.fill(child: ColoredBox(color: dark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9))),
    Positioned.fill(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
        child: Opacity(opacity: dark ? .45 : .85, child: Image.asset('assets/images/school-logo.jpg', fit: BoxFit.cover)),
      ),
    ),
    if (child != null)
      Positioned.fill(
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.depth == 0 && n.metrics.axis == Axis.vertical) {
              final show = n.metrics.pixels > 90;
              if (showBackArrow.value != show) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  showBackArrow.value = show;
                });
              }
            }
            return false;
          },
          child: child,
        ),
      ),
    _floatingArrow(context),
  ]);
}

class NokhbaApp extends StatelessWidget {
  const NokhbaApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF2563EB);
    ThemeData theme(Brightness b) {
      final base = ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: b), useMaterial3: true);
      return base.copyWith(
        scaffoldBackgroundColor: Colors.transparent,
        textTheme: GoogleFonts.cairoTextTheme(base.textTheme),
        appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0, scrolledUnderElevation: 0),
      );
    }

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeMode,
      builder: (_, mode, __) => MaterialApp(
        title: 'نخبة | Nokhba',
        debugShowCheckedModeBanner: false,
        navigatorKey: navKey,
        navigatorObservers: [_BackObserver()],
        builder: _appShell,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        themeMode: mode,
        theme: theme(Brightness.light),
        darkTheme: theme(Brightness.dark),
        home: ListenableBuilder(
          listenable: session,
          builder: (_, __) => session.loggedIn
              ? const HomeScreen()
              : (splashShown ? const LandingScreen() : const SplashScreen()),
        ),
      ),
    );
  }
}
