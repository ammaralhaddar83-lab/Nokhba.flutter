part of '../main.dart';

// ===== القائمة الرئيسية (فقاعات الأقسام) =====

class _Item {
  const _Item(this.title, this.image, this.roles, this.build);
  final String title;
  final String image;
  final List<String> roles;
  final Widget Function() build;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3400))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  List<_Item> get _items => <_Item>[
        _Item('الجداول', 'char-schedule.svg', ['student', 'teacher', 'staff', 'admin'], () => const ScheduleScreen()),
        _Item('مهماتي', 'icon-mytasks.svg', ['student'], () => const MyTasksScreen()),
        _Item('منظم الدراسة', 'char-organizer.svg', ['student'], () => const OrganizerScreen()),
        _Item('الترفيه', 'char-fun.svg', ['student'], () => const FunScreen()),
        _Item('طمأنينة', 'icon-tam.svg', ['student'], () => const TamScreen()),
        _Item('بطاقتي', 'teacher-char.jpg', ['teacher', 'staff'], () => const TeachersScreen(ownOnly: true)),
        _Item('المعلمون والمعلمات', 'teacher-char.jpg', ['student', 'admin'], () => const TeachersScreen()),
        _Item('إدارة الإعلانات', 'char-feedback.svg', ['admin'], () => const AnnouncementsScreen()),
        _Item('إضافة كادر', 'office.svg', ['admin'], () => const StaffAddScreen()),
        _Item('تغيير كلمة السر', 'char-password.svg', ['teacher', 'staff', 'admin'], () => const PasswordScreen()),
      ];

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? const Color(0xFF0F172A) : Colors.white;
    final fg = dark ? Colors.white : const Color(0xFF0F172A);
    final size = ((w - 32 - 16) / 2).floorToDouble().clamp(130.0, 190.0).toDouble();
    final visible = _items.where((e) => e.roles.contains(session.role)).toList();
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            const BackPill(),
            Row(children: [
              Expanded(child: Text(roleLabels[session.role] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              OutlinedButton(onPressed: () => toggleThemeMode(context), child: Text(dark ? 'الوضع الفاتح' : 'الوضع الداكن')),
              if (session.loggedIn) ...[
                const SizedBox(width: 8),
                FilledButton.tonal(onPressed: () => session.logout(), child: const Text('خروج')),
              ],
            ]),
            const SizedBox(height: 14),
            Text('تطبيق نخبة',
                textAlign: TextAlign.center,
                style: GoogleFonts.arefRuqaa(fontSize: 40, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB))),
            const SizedBox(height: 4),
            const Text('اختر القسم للبدء', textAlign: TextAlign.center),
            const SizedBox(height: 18),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 18,
              children: [
                for (var i = 0; i < visible.length; i++)
                  FloatBubble(
                    anim: _c,
                    phase: i * 0.13,
                    size: size,
                    onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => visible[i].build())),
                    child: Container(
                      color: bg,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Container(
                          width: size * 0.52,
                          height: size * 0.52,
                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFF3B82F6), width: 3)),
                          child: ClipOval(child: assetImage(visible[i].image)),
                        ),
                        const SizedBox(height: 8),
                        Text(visible[i].title,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 14.5, height: 1.2)),
                      ]),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
