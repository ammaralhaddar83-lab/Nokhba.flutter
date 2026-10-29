import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Session;

// ===== core/config.dart =====
// بيانات الاتصال بـ Supabase (Project Settings > API).
// مفتاح anon عام بطبيعته، والحماية الحقيقية تأتي من سياسات RLS في قاعدة البيانات.
const supabaseUrl = 'https://loemftmfrqcupqulgwbp.supabase.co';
const supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxvZW1mdG1mcnFjdXBxdWxnd2JwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTExOTk0NzIsImV4cCI6MjEwNjc3NTQ3Mn0.HLWUOxO1v9TNxTZkIEC85Hlgc4Xekqgop0S9BNik2Ak';

/// المستخدمون يسجلون بـ username ويُحوَّل داخلياً إلى بريد بهذا النطاق.
const emailDomain = '@nokhba.school';

// ===== core/constants.dart =====
const grades = <String, String>{
  '7': 'السابع',
  '8': 'الثامن',
  '9': 'التاسع',
  '10': 'العاشر',
  '11': 'الحادي عشر',
  '12': 'الثاني عشر',
};

const sections = <String, String>{'a': 'أ', 'b': 'ب', 'c': 'ج'};

const staffCategories = <String, String>{
  'tm': 'المعلمون',
  'tf': 'المعلمات',
  'assistant': 'مساعدو المدير',
  'diwan': 'الديوان',
  'counselor': 'المرشدون',
  'librarian': 'أمين المكتبة',
  'accountant': 'المحاسبون',
  'nurse': 'الممرضات',
};

const roleLabels = <String, String>{
  'student': 'طالب',
  'teacher': 'معلم',
  'staff': 'كادر مدرسي',
  'admin': 'المدير',
};

class Mood {
  final String key, label, glyph, message;
  final Color color;
  const Mood(this.key, this.label, this.glyph, this.color, this.message);
}

const moods = <Mood>[
  Mood('joy', 'الفرح', '✦', Color(0xFFF59E0B), 'جميل أن تشعر بالفرح! حافظ على هذه الطاقة وشاركها مع من حولك.'),
  Mood('calm', 'الهدوء', '≈', Color(0xFF14B8A6), 'الهدوء نعمة. استمتع بهذه اللحظة، وتذكّر أنك قادر على الحفاظ على توازنك.'),
  Mood('sad', 'الحزن', '◐', Color(0xFF3B82F6), 'من الطبيعي أن نشعر بالحزن أحياناً، ومشاعرك مهمة. لست وحدك، وهناك من يسمعك.'),
  Mood('anxious', 'القلق', '✳', Color(0xFFA855F7), 'القلق شعور يمرّ، وأنت أقوى مما تظن. خذ نفساً عميقاً وجرّب تمرين التنفس.'),
  Mood('tired', 'الإرهاق', '▽', Color(0xFF8B5CF6), 'جسدك وعقلك يحتاجان راحة. خذ استراحة قصيرة، واشرب ماءً، وكن لطيفاً مع نفسك.'),
  Mood('bored', 'الملل', '─', Color(0xFF64748B), 'الملل إشارة من عقلك أنه يريد تجديداً. جرّب هدفاً صغيراً أو نشاطاً جديداً اليوم.'),
  Mood('angry', 'الغضب', '◆', Color(0xFFEF4444), 'الغضب شعور مشروع، والمهم كيف نتعامل معه. ابتعد لحظة وتنفّس، ثم تحدّث بهدوء مع من تثق به.'),
  Mood('fear', 'الخوف', '○', Color(0xFF6366F1), 'الخوف يخفّ حين نشاركه. أنت في مكان آمن، ويمكنك طلب مساعدة سرية في أي وقت.'),
];

const moodReasons = [
  'الدراسة والاختبارات',
  'الأصدقاء والعلاقات',
  'المنزل والأسرة',
  'الضغوطات والمسؤوليات',
  'أخرى',
];

// ===== core/session.dart =====
SupabaseClient get sb => Supabase.instance.client;

/// حالة المستخدم الحالي: الدور (طالب بدون دخول / معلم / كادر / مدير).
class Session extends ChangeNotifier {
  String role = 'student';
  String name = '';
  String username = '';

  bool get isAdmin => role == 'admin';
  bool get isStudent => role == 'student';
  bool get isStaffLike => role == 'teacher' || role == 'staff';
  bool get loggedIn => !isStudent;

  /// استعادة الجلسة المحفوظة عند فتح التطبيق.
  Future<void> restore() async {
    final user = sb.auth.currentUser;
    if (user == null) return;
    final u = (user.email ?? '').replaceAll(emailDomain, '');
    final prof = await _profile(u);
    if (prof == null) {
      await sb.auth.signOut();
      return;
    }
    _set(prof['role'] as String, (prof['name'] as String?) ?? u, u);
  }

  Future<Map<String, dynamic>?> _profile(String u) async {
    try {
      return await sb.from('profiles').select('role,name').eq('username', u).maybeSingle();
    } catch (_) {
      return null;
    }
  }

  void _set(String r, String n, String u) {
    role = r;
    name = n;
    username = u;
    notifyListeners();
  }

  /// يرجع رسالة خطأ أو null عند النجاح.
  Future<String?> login(String user, String pass, {required bool adminPortal}) async {
    final u = user.trim().toLowerCase();
    if (u.isEmpty || pass.isEmpty) return 'أدخل اسم المستخدم وكلمة السر';
    try {
      await sb.auth.signInWithPassword(email: '$u$emailDomain', password: pass);
    } on AuthException catch (e) {
      return RegExp('confirm', caseSensitive: false).hasMatch(e.message)
          ? 'الحساب غير مفعّل: فعّل Auto Confirm للمستخدم في Supabase'
          : 'اسم المستخدم أو كلمة السر غير صحيحة';
    } catch (e) {
      return 'تعذر الاتصال: $e';
    }
    final prof = await _profile(u);
    if (prof == null) {
      await sb.auth.signOut();
      return 'لا يوجد صف باسم "$u" في جدول profiles';
    }
    final r = prof['role'] as String;
    final allowed = adminPortal ? ['admin', 'staff'] : ['teacher'];
    if (!allowed.contains(r)) {
      await sb.auth.signOut();
      return 'هذا الحساب غير مخوّل للدخول من هذه البوابة';
    }
    _set(r, (prof['name'] as String?) ?? u, u);
    return null;
  }

  Future<void> logout() async {
    await sb.auth.signOut();
    _set('student', '', '');
  }

  static String? passwordProblem(String p) {
    if (p.length < 8 ||
        !RegExp('[a-z]').hasMatch(p) ||
        !RegExp('[A-Z]').hasMatch(p) ||
        !RegExp(r'\d').hasMatch(p) ||
        !RegExp('[^A-Za-z0-9]').hasMatch(p)) {
      return 'كلمة السر يجب أن تكون 8 أحرف على الأقل وتحتوي حرفاً كبيراً وحرفاً صغيراً ورقماً ورمزاً (مثل @ أو #)';
    }
    return null;
  }

  Future<String?> changePassword(String oldP, String newP, String newP2) async {
    if (!loggedIn) return 'سجّل الدخول أولاً';
    if (oldP.isEmpty || newP.isEmpty) return 'املأ جميع الخانات';
    final pw = passwordProblem(newP);
    if (pw != null) return pw;
    if (newP != newP2) return 'كلمتا السر الجديدتان غير متطابقتين';
    if (newP == oldP) return 'الجديدة يجب أن تختلف عن الحالية';
    try {
      await sb.auth.signInWithPassword(email: '$username$emailDomain', password: oldP);
    } catch (_) {
      return 'كلمة السر الحالية غير صحيحة';
    }
    try {
      await sb.auth.updateUser(UserAttributes(password: newP));
    } catch (e) {
      return 'تعذر التغيير: $e';
    }
    return null;
  }
}

/// نسخة وحيدة مشتركة في التطبيق.
final session = Session();

// ===== core/widgets.dart =====
/// صور القاعدة تُخزَّن غالباً كـ data:image/...;base64 — هذا يعرضها أو يعرض رابطاً عادياً.
Widget dbImage(String? src, {BoxFit fit = BoxFit.cover, double? width, double? height}) {
  if (src == null || src.isEmpty) return const SizedBox.shrink();
  if (src.startsWith('data:image/')) {
    try {
      final Uint8List bytes = base64Decode(src.substring(src.indexOf(',') + 1));
      return Image.memory(bytes, fit: fit, width: width, height: height, gaplessPlayback: true);
    } catch (_) {
      return const Icon(Icons.broken_image);
    }
  }
  return Image.network(src, fit: fit, width: width, height: height,
      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image));
}

void toast(BuildContext c, String msg) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(msg)));

Future<bool> confirmDialog(BuildContext c, String msg) async {
  final r = await showDialog<bool>(
    context: c,
    builder: (_) => AlertDialog(
      content: Text(msg),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
        TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('تأكيد')),
      ],
    ),
  );
  return r ?? false;
}

class Empty extends StatelessWidget {
  final String text;
  const Empty(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(padding: const EdgeInsets.all(24), child: Text(text, textAlign: TextAlign.center)),
      );
}

/// يحمّل بيانات async ويعرض تحميل/خطأ/نتيجة.
class Loader<T> extends StatelessWidget {
  final Future<T> future;
  final Widget Function(T data) builder;
  const Loader({super.key, required this.future, required this.builder});
  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
        future: future,
        builder: (c, s) {
          if (s.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (s.hasError) return Empty('تعذر التحميل: ${s.error}');
          return builder(s.data as T);
        },
      );
}

// ===== screens/support_screen.dart =====
const ticketStatus = {'new': 'جديدة', 'progress': 'قيد المعالجة', 'contacted': 'تم التواصل', 'done': 'مكتملة'};

/// رسالة سرية للمرشد (جدول support_requests). المدير/المرشد يرى الوارد ويدير الحالة والملاحظات.
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});
  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _m = TextEditingController(), _c = TextEditingController();
  late Future<List<Map<String, dynamic>>> _inbox = _load();

  Future<List<Map<String, dynamic>>> _load() async => List<Map<String, dynamic>>.from(await sb
      .from('support_requests')
      .select('id,message,contact,status,note,created_at')
      .order('created_at', ascending: false)
      .limit(100));

  Future<void> _send() async {
    final msg = _m.text.trim();
    if (msg.isEmpty) {
      toast(context, 'اكتب رسالتك أولاً');
      return;
    }
    try {
      await sb.from('support_requests').insert({
        'message': msg,
        'contact': _c.text.trim().isEmpty ? null : _c.text.trim(),
      });
      _m.clear();
      _c.clear();
      if (mounted) toast(context, 'وصلت رسالتك للمرشد بسرية. شكراً لشجاعتك 💚');
      if (session.isAdmin) setState(() => _inbox = _load());
    } catch (e) {
      if (mounted) toast(context, 'تعذر الإرسال: $e');
    }
  }

  Future<void> _update(Map<String, dynamic> r, {String? status, String? note}) async {
    try {
      await sb.from('support_requests').update({
        if (status != null) 'status': status,
        if (note != null) 'note': note.trim().isEmpty ? null : note.trim(),
      }).eq('id', r['id']);
      setState(() => _inbox = _load());
    } catch (e) {
      if (mounted) toast(context, 'تعذر التحديث: $e');
    }
  }

  Future<void> _delete(Map<String, dynamic> r) async {
    if (!await confirmDialog(context, 'حذف هذا الطلب؟')) return;
    try {
      await sb.from('support_requests').delete().eq('id', r['id']);
      setState(() => _inbox = _load());
    } catch (e) {
      if (mounted) toast(context, 'تعذر الحذف: $e');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('التواصل مع المرشد (سري)')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('يمكنك إرسال رسالتك بدون ذكر اسمك. وسيلة التواصل اختيارية.'),
          const SizedBox(height: 12),
          TextField(
            controller: _m,
            maxLines: 4,
            maxLength: 1000,
            decoration: const InputDecoration(hintText: 'اكتب رسالتك...', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _c,
            decoration: const InputDecoration(labelText: 'وسيلة تواصل (اختياري)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _send, child: const Text('إرسال')),
          if (session.isAdmin) ...[
            const Divider(height: 32),
            const Text('الوارد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Loader<List<Map<String, dynamic>>>(
              future: _inbox,
              builder: (rows) => rows.isEmpty
                  ? const Empty('لا توجد طلبات حالياً')
                  : Column(children: [
                      for (final r in rows)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${r['created_at']}'.substring(0, 16).replaceFirst('T', ' '),
                                  style: Theme.of(context).textTheme.bodySmall),
                              const SizedBox(height: 6),
                              Text('${r['message']}'),
                              const SizedBox(height: 6),
                              Text(r['contact'] != null ? 'وسيلة التواصل: ${r['contact']}' : 'مجهول الهوية',
                                  style: Theme.of(context).textTheme.bodySmall),
                              DropdownButton<String>(
                                value: ticketStatus.containsKey(r['status']) ? r['status'] as String : 'new',
                                items: [
                                  for (final e in ticketStatus.entries)
                                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                                ],
                                onChanged: (v) => v == null ? null : _update(r, status: v),
                              ),
                              TextFormField(
                                initialValue: r['note'] as String?,
                                maxLength: 1000,
                                maxLines: 2,
                                decoration: const InputDecoration(labelText: 'ملاحظات المرشد (سرية)'),
                                onFieldSubmitted: (v) => _update(r, note: v),
                              ),
                              Align(
                                alignment: AlignmentDirectional.centerEnd,
                                child: TextButton(
                                  onPressed: () => _delete(r),
                                  child: const Text('حذف', style: TextStyle(color: Colors.red)),
                                ),
                              ),
                            ]),
                          ),
                        ),
                    ]),
            ),
          ],
        ]),
      );
}

// ===== screens/announcements_screen.dart =====
class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});
  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  late Future<List<Map<String, dynamic>>> _f = _load();
  final _c = TextEditingController();

  Future<List<Map<String, dynamic>>> _load() async => List<Map<String, dynamic>>.from(
      await sb.from('announcements').select('id,text,created_at').order('created_at', ascending: false).limit(50));

  Future<void> _add() async {
    final t = _c.text.trim();
    if (t.isEmpty) return;
    try {
      await sb.from('announcements').insert({'text': t, 'by_name': session.name});
      _c.clear();
      setState(() => _f = _load());
    } catch (e) {
      if (mounted) toast(context, 'تعذر النشر: $e');
    }
  }

  Future<void> _del(dynamic id) async {
    if (!await confirmDialog(context, 'حذف الإعلان؟')) return;
    try {
      await sb.from('announcements').delete().eq('id', id);
      setState(() => _f = _load());
    } catch (e) {
      if (mounted) toast(context, 'تعذر الحذف: $e');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('إدارة الإعلانات')),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _c,
                  maxLength: 500,
                  decoration: const InputDecoration(hintText: 'اكتب إعلاناً جديداً', border: OutlineInputBorder()),
                ),
              ),
              IconButton.filled(onPressed: _add, icon: const Icon(Icons.send)),
            ]),
          ),
          Expanded(
            child: Loader<List<Map<String, dynamic>>>(
              future: _f,
              builder: (items) => items.isEmpty
                  ? const Empty('لا توجد إعلانات')
                  : ListView(children: [
                      for (final a in items)
                        ListTile(
                          title: Text(a['text'] ?? ''),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _del(a['id']),
                          ),
                        ),
                    ]),
            ),
          ),
        ]),
      );
}

// ===== screens/library_screen.dart =====
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  late Future<List<Map<String, dynamic>>> _f = _load();

  Future<List<Map<String, dynamic>>> _load() async => List<Map<String, dynamic>>.from(await sb
      .from('library_loans')
      .select('id,student_name,book_title,due_date')
      .eq('returned', false)
      .order('due_date'));

  Future<void> _add() async {
    final name = TextEditingController(), book = TextEditingController();
    DateTime due = DateTime.now().add(const Duration(days: 14));
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('إعارة جديدة'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم الطالب')),
            TextField(controller: book, decoration: const InputDecoration(labelText: 'عنوان الكتاب')),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () async {
                final d = await showDatePicker(
                    context: c, initialDate: due, firstDate: DateTime(2024), lastDate: DateTime(2100));
                if (d != null) set(() => due = d);
              },
              child: Text('الإرجاع: ${due.toIso8601String().substring(0, 10)}'),
            ),
          ]),
          actions: [TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('حفظ'))],
        ),
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    try {
      await sb.from('library_loans').insert({
        'student_name': name.text.trim(),
        'book_title': book.text.trim().isEmpty ? null : book.text.trim(),
        'due_date': due.toIso8601String().substring(0, 10),
      });
      setState(() => _f = _load());
    } catch (e) {
      if (mounted) toast(context, 'تعذر الحفظ: $e');
    }
  }

  Future<void> _returned(dynamic id) async {
    try {
      await sb.from('library_loans').update({'returned': true}).eq('id', id);
      setState(() => _f = _load());
    } catch (e) {
      if (mounted) toast(context, 'تعذر التحديث: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return Scaffold(
      appBar: AppBar(title: const Text('المكتبة - الإعارات')),
      floatingActionButton: FloatingActionButton(onPressed: _add, child: const Icon(Icons.add)),
      body: Loader<List<Map<String, dynamic>>>(
        future: _f,
        builder: (rows) => rows.isEmpty
            ? const Empty('لا توجد إعارات حالياً')
            : ListView(children: [
                for (final r in rows)
                  ListTile(
                    title: Text('${r['student_name']}'),
                    subtitle: Text('${r['book_title'] ?? '-'}  •  الإرجاع: ${r['due_date']}'),
                    leading: Icon(Icons.book,
                        color: '${r['due_date']}'.compareTo(today) < 0 ? Colors.red : null),
                    trailing: TextButton(onPressed: () => _returned(r['id']), child: const Text('تم الإرجاع')),
                  ),
              ]),
      ),
    );
  }
}

// ===== screens/password_screen.dart =====
class PasswordScreen extends StatefulWidget {
  const PasswordScreen({super.key});
  @override
  State<PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends State<PasswordScreen> {
  final _o = TextEditingController(), _n = TextEditingController(), _n2 = TextEditingController();
  String _msg = '';
  bool _ok = false;

  Future<void> _go() async {
    final err = await session.changePassword(_o.text, _n.text, _n2.text);
    setState(() {
      _ok = err == null;
      _msg = err ?? 'تم تغيير كلمة السر بنجاح';
    });
    if (err == null) { _o.clear(); _n.clear(); _n2.clear(); }
  }

  Widget _f(String l, TextEditingController c) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          obscureText: true,
          textDirection: TextDirection.ltr,
          decoration: InputDecoration(labelText: l, border: const OutlineInputBorder()),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('تغيير كلمة السر')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          _f('كلمة السر الحالية', _o),
          _f('كلمة السر الجديدة', _n),
          _f('تأكيد كلمة السر الجديدة', _n2),
          FilledButton(onPressed: _go, child: const Text('تغيير')),
          if (_msg.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_msg,
                  textAlign: TextAlign.center, style: TextStyle(color: _ok ? Colors.green : Colors.red)),
            ),
        ]),
      );
}

// ===== screens/login_screen.dart =====
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _u = TextEditingController();
  final _p = TextEditingController();
  bool _admin = false;
  bool _busy = false;
  String _msg = '';

  Future<void> _go() async {
    setState(() { _busy = true; _msg = ''; });
    final err = await session.login(_u.text, _p.text, adminPortal: _admin);
    if (!mounted) return;
    if (err == null) {
      Navigator.pop(context);
    } else {
      setState(() { _busy = false; _msg = err; });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('تسجيل الدخول')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('المعلمون')),
                ButtonSegment(value: true, label: Text('الإدارة والكادر')),
              ],
              selected: {_admin},
              onSelectionChanged: (s) => setState(() => _admin = s.first),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _u,
              autocorrect: false,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: 'اسم المستخدم', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _p,
              obscureText: true,
              textDirection: TextDirection.ltr,
              onSubmitted: (_) => _go(),
              decoration: const InputDecoration(labelText: 'كلمة السر', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _busy ? null : _go, child: Text(_busy ? 'جاري الدخول...' : 'دخول')),
            if (_msg.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_msg, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
              ),
          ],
        ),
      );
}

// ===== screens/schedule_screen.dart =====
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});
  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  String grade = '7';
  String section = 'a';
  bool exams = false;
  bool editing = false;
  int _v = 0; // لإعادة التحميل
  List<List<TextEditingController>> _ctrls = [];

  Future<List<List<String>>> _rows() async {
    final key = 'g${grade}_$section';
    try {
      final r = await sb.from('schedules').select('data').eq('key', key).maybeSingle();
      if (r != null && r['data'] is List) {
        return (r['data'] as List).map((x) => (x as List).map((e) => '$e').toList()).toList();
      }
    } catch (_) {}
    final all = jsonDecode(_defaultSchedules) as Map<String, dynamic>;
    final g = all['g$grade'] as Map<String, dynamic>?;
    final rows = (g?[section] as List?) ?? [];
    return rows.map((x) => (x as List).map((e) => '$e').toList()).toList();
  }

  Future<void> _save() async {
    final rows = _ctrls
        .map((r) => [for (var i = 0; i < r.length; i++) i == 0 ? r[i].text : (r[i].text.trim().isEmpty ? '-' : r[i].text.trim())])
        .toList();
    try {
      await sb.from('schedules').upsert({'key': 'g${grade}_$section', 'data': rows});
      if (!mounted) return;
      toast(context, 'تم حفظ الجدول لجميع المستخدمين');
      setState(() { editing = false; _v++; });
    } catch (e) {
      if (mounted) toast(context, 'تعذر الحفظ: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الجداول'),
        actions: [
          if (session.isAdmin && !exams)
            IconButton(
              icon: Icon(editing ? Icons.close : Icons.edit),
              onPressed: () => setState(() => editing = !editing),
            ),
          if (editing) IconButton(icon: const Icon(Icons.save), onPressed: _save),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('الجدول الدراسي')),
                ButtonSegment(value: true, label: Text('الامتحانات')),
              ],
              selected: {exams},
              onSelectionChanged: (s) => setState(() { exams = s.first; editing = false; }),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(children: [
              for (final g in grades.entries)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 6),
                  child: ChoiceChip(
                    label: Text(g.value),
                    selected: grade == g.key,
                    onSelected: (_) => setState(() { grade = g.key; editing = false; }),
                  ),
                ),
            ]),
          ),
          if (!exams)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(children: [
                for (final s in sections.entries)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 6),
                    child: ChoiceChip(
                      label: Text('الشعبة (${s.value})'),
                      selected: section == s.key,
                      onSelected: (_) => setState(() { section = s.key; editing = false; }),
                    ),
                  ),
              ]),
            ),
          Expanded(child: exams ? _ExamList(key: ValueKey('ex$grade'), grade: grade) : _table()),
        ],
      ),
    );
  }

  Widget _table() => Loader<List<List<String>>>(
        key: ValueKey('$grade$section$_v'),
        future: _rows(),
        builder: (rows) {
          if (rows.isEmpty) return const Empty('لا يوجد جدول لهذه الشعبة');
          if (editing) {
            _ctrls = [for (final r in rows) [for (final c in r) TextEditingController(text: c)]];
          }
          return SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 14,
                columns: [
                  const DataColumn(label: Text('اليوم')),
                  for (var i = 1; i <= 8; i++) DataColumn(label: Text('$i')),
                ],
                rows: [
                  for (var r = 0; r < rows.length; r++)
                    DataRow(cells: [
                      for (var c = 0; c < rows[r].length; c++)
                        DataCell(editing && c > 0
                            ? SizedBox(width: 70, child: TextField(controller: _ctrls[r][c]))
                            : Text(rows[r][c])),
                    ]),
                ],
              ),
            ),
          );
        },
      );
}

class _ExamList extends StatefulWidget {
  final String grade;
  const _ExamList({super.key, required this.grade});
  @override
  State<_ExamList> createState() => _ExamListState();
}

class _ExamListState extends State<_ExamList> {
  String get _key => 'exams_g${widget.grade}';
  late Future<List<Map<String, dynamic>>> _f = _load();

  Future<List<Map<String, dynamic>>> _load() async {
    final r = await sb.from('schedules').select('data').eq('key', _key).maybeSingle();
    final l = (r != null && r['data'] is List) ? List<Map<String, dynamic>>.from((r['data'] as List).map((e) => Map<String, dynamic>.from(e))) : <Map<String, dynamic>>[];
    l.sort((a, b) => '${a['date']}'.compareTo('${b['date']}'));
    return l;
  }

  Future<void> _write(List<Map<String, dynamic>> rows) async {
    try {
      await sb.from('schedules').upsert({'key': _key, 'data': rows});
      setState(() => _f = _load());
    } catch (e) {
      if (mounted) toast(context, 'تعذر الحفظ: $e');
    }
  }

  Future<void> _add(List<Map<String, dynamic>> cur) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final c = TextEditingController();
    final subject = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('المادة'),
        content: TextField(controller: c, autofocus: true),
        actions: [TextButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('إضافة'))],
      ),
    );
    if (subject == null || subject.isEmpty) return;
    await _write([...cur, {'date': date.toIso8601String().substring(0, 10), 'subject': subject}]);
  }

  @override
  Widget build(BuildContext context) => Loader<List<Map<String, dynamic>>>(
        future: _f,
        builder: (rows) {
          final today = DateTime.now().toIso8601String().substring(0, 10);
          return Scaffold(
            backgroundColor: Colors.transparent,
            floatingActionButton: session.isAdmin
                ? FloatingActionButton(onPressed: () => _add(rows), child: const Icon(Icons.add))
                : null,
            body: rows.isEmpty
                ? const Empty('لا توجد امتحانات لهذا الصف بعد')
                : ListView(
                    children: [
                      for (final r in rows)
                        ListTile(
                          enabled: '${r['date']}'.compareTo(today) >= 0,
                          title: Text('${r['subject']}'),
                          subtitle: Text('${r['date']}'),
                          trailing: session.isAdmin
                              ? IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () async {
                                    if (await confirmDialog(context, 'حذف هذا الامتحان؟')) {
                                      await _write(rows.where((x) => x != r).toList());
                                    }
                                  },
                                )
                              : null,
                        ),
                    ],
                  ),
          );
        },
      );
}

// ===== screens/my_tasks_screen.dart =====
/// مهام المعلمين للصف والشعبة (RPC: tasks_for_grade / task_images).
class MyTasksScreen extends StatefulWidget {
  const MyTasksScreen({super.key});
  @override
  State<MyTasksScreen> createState() => _MyTasksScreenState();
}

class _MyTasksScreenState extends State<MyTasksScreen> {
  String? grade, section;
  Future<List<Map<String, dynamic>>>? _f;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      grade = p.getString('mtGrade');
      section = p.getString('mtSection');
      _reload();
    });
  }

  void _reload() {
    if (grade != null && section != null) _f = _load(grade!, section!);
    if (mounted) setState(() {});
  }

  Future<void> _pick({String? g, String? s}) async {
    final p = await SharedPreferences.getInstance();
    if (g != null) { grade = g; await p.setString('mtGrade', g); }
    if (s != null) { section = s; await p.setString('mtSection', s); }
    _reload();
  }

  Future<List<Map<String, dynamic>>> _load(String g, String s) async {
    final d = await sb.rpc('tasks_for_grade', params: {'p_grade': g});
    return List<Map<String, dynamic>>.from(d as List).where((r) {
      final secs = r['sections'] is List ? List<String>.from(r['sections']) : <String>[];
      return secs.isEmpty || secs.contains(s);
    }).toList();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('مهامي')),
        body: Column(children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(8),
            child: Row(children: [
              for (final g in grades.entries)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 6),
                  child: ChoiceChip(label: Text(g.value), selected: grade == g.key, onSelected: (_) => _pick(g: g.key)),
                ),
            ]),
          ),
          Row(children: [
            const SizedBox(width: 8),
            for (final s in sections.entries)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 6),
                child: ChoiceChip(
                    label: Text('الشعبة (${s.value})'), selected: section == s.key, onSelected: (_) => _pick(s: s.key)),
              ),
          ]),
          Expanded(
            child: _f == null
                ? const Empty('اختر الصف والشعبة أولاً')
                : Loader<List<Map<String, dynamic>>>(
                    key: ValueKey('$grade$section'),
                    future: _f!,
                    builder: (rows) => rows.isEmpty
                        ? const Empty('لا توجد مهام لهذا الصف والشعبة حالياً')
                        : ListView(padding: const EdgeInsets.all(8), children: [for (final r in rows) _TaskCard(r)]),
                  ),
          ),
        ]),
      );
}

class _TaskCard extends StatefulWidget {
  final Map<String, dynamic> r;
  const _TaskCard(this.r);
  @override
  State<_TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<_TaskCard> {
  List<String>? imgs;
  bool loading = false;

  Future<void> _showImgs() async {
    setState(() => loading = true);
    try {
      final d = await sb.rpc('task_images', params: {'p_teacher': widget.r['teacher_id'], 'p_task': widget.r['task_id']});
      imgs = (d as List).map((e) => '$e').where((s) => s.startsWith('data:image/')).toList();
    } catch (e) {
      if (mounted) toast(context, 'تعذر تحميل الصور');
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.r;
    final cls = (r['classes'] as List?)?.map((k) => grades[k] ?? '$k').join('، ') ?? '';
    final secs = (r['sections'] as List?)?.map((k) => sections[k] ?? '$k').join('، ') ?? '';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${r['teacher_name'] ?? ''}${r['specialty'] != null ? ' — ${r['specialty']}' : ''}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          if (cls.isNotEmpty || secs.isNotEmpty)
            Text([if (cls.isNotEmpty) cls, if (secs.isNotEmpty) 'شعبة $secs'].join(' • '),
                style: Theme.of(context).textTheme.bodySmall),
          if (r['task_date'] != null) Text('${r['task_date']}', style: Theme.of(context).textTheme.bodySmall),
          if (r['task_text'] != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('${r['task_text']}')),
          if ((r['image_count'] ?? 0) > 0 && imgs == null)
            TextButton(
              onPressed: loading ? null : _showImgs,
              child: Text(loading ? 'جارٍ التحميل...' : 'عرض الصور (${r['image_count']})'),
            ),
          if (imgs != null)
            for (final s in imgs!)
              Padding(padding: const EdgeInsets.only(top: 8), child: dbImage(s, fit: BoxFit.contain)),
        ]),
      ),
    );
  }
}

// ===== screens/organizer_screen.dart =====
/// منظم الدراسة: مهام محلية على الجهاز (بدون قاعدة بيانات) + مؤقت لكل مهمة + شريط تقدم.
class OrganizerScreen extends StatefulWidget {
  const OrganizerScreen({super.key});
  @override
  State<OrganizerScreen> createState() => _OrganizerScreenState();
}

class _OrganizerScreenState extends State<OrganizerScreen> {
  static const types = ['قراءة', 'حفظ', 'حل واجبات', 'مراجعة'];
  List<Map<String, dynamic>> tasks = [];
  final _name = TextEditingController();
  final _min = TextEditingController(text: '25');
  String type = types.first;
  int? running; // فهرس المهمة الجارية
  int remaining = 0;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      final s = p.getString('appTasks');
      if (s != null) setState(() => tasks = List<Map<String, dynamic>>.from(jsonDecode(s)));
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  Future<void> _save() async =>
      (await SharedPreferences.getInstance()).setString('appTasks', jsonEncode(tasks));

  void _add() {
    final n = _name.text.trim();
    final m = int.tryParse(_min.text) ?? 0;
    if (n.isEmpty || m <= 0) return;
    setState(() => tasks.add({'name': n, 'type': type, 'minutes': m, 'done': false}));
    _name.clear();
    _save();
  }

  void _start(int i) {
    _t?.cancel();
    running = i;
    remaining = (tasks[i]['minutes'] as int) * 60;
    _t = Timer.periodic(const Duration(seconds: 1), (t) {
      if (remaining <= 1) {
        t.cancel();
        setState(() { tasks[i]['done'] = true; running = null; remaining = 0; });
        _save();
      } else {
        setState(() => remaining--);
      }
    });
    setState(() {});
  }

  void _stop() {
    _t?.cancel();
    setState(() => running = null);
  }

  String _fmt(int s) => '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final done = tasks.where((t) => t['done'] == true).length;
    return Scaffold(
      appBar: AppBar(title: const Text('منظم الدراسة')),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        if (tasks.isNotEmpty) ...[
          LinearProgressIndicator(value: done / tasks.length, minHeight: 10),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text('أنجزت $done من ${tasks.length}', textAlign: TextAlign.center),
          ),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'اسم المهمة')),
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: type,
                    items: [for (final t in types) DropdownMenuItem(value: t, child: Text(t))],
                    onChanged: (v) => setState(() => type = v ?? type),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 90,
                  child: TextField(
                    controller: _min,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'دقائق'),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              FilledButton(onPressed: _add, child: const Text('إضافة مهمة')),
            ]),
          ),
        ),
        for (var i = 0; i < tasks.length; i++)
          Card(
            child: ListTile(
              leading: Checkbox(
                value: tasks[i]['done'] == true,
                onChanged: (v) { setState(() => tasks[i]['done'] = v ?? false); _save(); },
              ),
              title: Text('${tasks[i]['name']}',
                  style: TextStyle(decoration: tasks[i]['done'] == true ? TextDecoration.lineThrough : null)),
              subtitle: Text(running == i
                  ? _fmt(remaining)
                  : '${tasks[i]['type']} • ${tasks[i]['minutes']} دقيقة'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  icon: Icon(running == i ? Icons.stop : Icons.play_arrow),
                  onPressed: tasks[i]['done'] == true ? null : () => running == i ? _stop() : _start(i),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    if (running == i) _stop();
                    setState(() => tasks.removeAt(i));
                    _save();
                  },
                ),
              ]),
            ),
          ),
      ]),
    );
  }
}

// ===== screens/tam_screen.dart =====
/// تمانينة: اختيار المزاج ← سبب ← رسالة + تمرين تنفس + رسالة سرية للمرشد.
class TamScreen extends StatefulWidget {
  const TamScreen({super.key});
  @override
  State<TamScreen> createState() => _TamScreenState();
}

class _TamScreenState extends State<TamScreen> {
  Mood? mood;
  bool done = false;

  Future<void> _submit(String reason) async {
    try {
      await sb.from('mood_checkins').insert({'mood': mood!.key, 'reason': reason});
    } catch (_) {/* لا نعطّل التجربة إن فشل الحفظ */}
    setState(() => done = true);
  }

  void _reset() => setState(() { mood = null; done = false; });

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (mood == null) {
      body = ListView(padding: const EdgeInsets.all(16), children: [
        const Text('كيف تشعر اليوم؟', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [
          for (final m in moods)
            ActionChip(
              avatar: Text(m.glyph, style: TextStyle(color: m.color, fontSize: 18)),
              label: Text(m.label),
              onPressed: () => setState(() => mood = m),
            ),
        ]),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          icon: const Icon(Icons.support_agent),
          label: const Text('أحتاج للتحدث مع المرشد (سري)'),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportScreen())),
        ),
      ]);
    } else if (!done) {
      body = ListView(padding: const EdgeInsets.all(16), children: [
        Text('ما سبب شعورك بـ ${mood!.label}؟', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 12),
        for (final r in [...moodReasons, 'تخطي'])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton(onPressed: () => _submit(r), child: Text(r)),
          ),
      ]);
    } else {
      body = ListView(padding: const EdgeInsets.all(16), children: [
        Center(
          child: CircleAvatar(
            radius: 36,
            backgroundColor: mood!.color,
            child: Text(mood!.glyph, style: const TextStyle(fontSize: 32, color: Colors.white)),
          ),
        ),
        const SizedBox(height: 16),
        Text(mood!.message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 16),
        FilledButton.icon(
          icon: const Icon(Icons.air),
          label: const Text('تمرين التنفس'),
          onPressed: () => showDialog(context: context, builder: (_) => const _BreathDialog()),
        ),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: _reset, child: const Text('رجوع')),
      ]);
    }
    return Scaffold(appBar: AppBar(title: const Text('تمانينة')), body: body);
  }
}

class _BreathDialog extends StatefulWidget {
  const _BreathDialog();
  @override
  State<_BreathDialog> createState() => _BreathDialogState();
}

class _BreathDialogState extends State<_BreathDialog> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
  Timer? _t;
  bool inhale = true;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 4), (_) => setState(() => inhale = !inhale));
  }

  @override
  void dispose() {
    _t?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        content: SizedBox(
          height: 220,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            AnimatedBuilder(
              animation: _c,
              builder: (_, __) => Container(
                width: 70 + 90 * _c.value,
                height: 70 + 90 * _c.value,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.35)),
              ),
            ),
            const SizedBox(height: 16),
            Text(inhale ? 'شهيق...' : 'زفير...', style: const TextStyle(fontSize: 18)),
          ]),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إنهاء'))],
      );
}

/// لوحة المرشد/المدير: إحصاءات المزاج عبر الدالة care_mood_stats.
class TamDashScreen extends StatefulWidget {
  const TamDashScreen({super.key});
  @override
  State<TamDashScreen> createState() => _TamDashScreenState();
}

class _TamDashScreenState extends State<TamDashScreen> {
  int days = 7;
  late Future<List<Map<String, dynamic>>> _f = _load();

  Future<List<Map<String, dynamic>>> _load() async =>
      List<Map<String, dynamic>>.from(await sb.rpc('care_mood_stats', params: {'p_days': days}));

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('لوحة تمانينة')),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 1, label: Text('اليوم')),
                ButtonSegment(value: 7, label: Text('أسبوع')),
                ButtonSegment(value: 30, label: Text('شهر')),
              ],
              selected: {days},
              onSelectionChanged: (s) => setState(() { days = s.first; _f = _load(); }),
            ),
          ),
          Expanded(
            child: Loader<List<Map<String, dynamic>>>(
              future: _f,
              builder: (rows) {
                final counts = {for (final r in rows) '${r['mood']}': (r['n'] as num).toInt()};
                final total = counts.values.fold<int>(0, (a, b) => a + b);
                if (total == 0) return const Empty('لا توجد بيانات في هذه الفترة');
                return ListView(padding: const EdgeInsets.all(16), children: [
                  Text('إجمالي التسجيلات: $total', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  for (final m in moods)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: [
                        SizedBox(width: 70, child: Text(m.label)),
                        Expanded(
                          child: LinearProgressIndicator(
                            value: total == 0 ? 0 : (counts[m.key] ?? 0) / total,
                            color: m.color,
                            minHeight: 10,
                          ),
                        ),
                        SizedBox(width: 40, child: Text('${counts[m.key] ?? 0}', textAlign: TextAlign.end)),
                      ]),
                    ),
                ]);
              },
            ),
          ),
        ]),
      );
}

// ===== screens/teachers_screen.dart =====
/// دليل المعلمين/الكادر. الطالب والمدير يتصفحان بالأقسام، والمعلم/الكادر يرى بطاقته فقط ويعدّلها.
class TeachersScreen extends StatefulWidget {
  final bool ownOnly;
  const TeachersScreen({super.key, this.ownOnly = false});
  @override
  State<TeachersScreen> createState() => _TeachersScreenState();
}

class _TeachersScreenState extends State<TeachersScreen> {
  String cat = 'tm';
  late Future<List<Map<String, dynamic>>> _f = _load();

  Future<List<Map<String, dynamic>>> _load() async => List<Map<String, dynamic>>.from(await sb
      .from('teachers')
      .select('id,username,name,specialty,photo,bio,category,gender,classes,tasks_text,years_experience')
      .order('created_at'));

  /// نفس منطق الويب: category + gender تحدد القسم.
  String _key(Map<String, dynamic> t) {
    final c = t['category'] as String?;
    if (c == null || c == 'teacher') return t['gender'] == 'f' ? 'tf' : 'tm';
    return c;
  }

  bool _canEdit(Map<String, dynamic> t) =>
      session.isAdmin || (session.loggedIn && t['username'] != null && t['username'] == session.username);

  Future<void> _edit(Map<String, dynamic> t) async {
    final name = TextEditingController(text: t['name'] ?? '');
    final spec = TextEditingController(text: t['specialty'] ?? '');
    final bio = TextEditingController(text: t['bio'] ?? '');
    final yrs = TextEditingController(text: '${t['years_experience'] ?? ''}');
    String? photo;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('تعديل البطاقة'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'الاسم')),
              TextField(controller: spec, decoration: const InputDecoration(labelText: 'التخصص')),
              TextField(controller: yrs, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'سنوات الخبرة')),
              TextField(controller: bio, maxLines: 3, decoration: const InputDecoration(labelText: 'نبذة')),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.photo),
                label: Text(photo == null ? 'تغيير الصورة' : 'تم اختيار صورة'),
                onPressed: () async {
                  final f = await ImagePicker().pickImage(
                      source: ImageSource.gallery, maxWidth: 300, maxHeight: 300, imageQuality: 80);
                  if (f == null) return;
                  final bytes = await File(f.path).readAsBytes();
                  set(() => photo = 'data:image/jpeg;base64,${base64Encode(bytes)}');
                },
              ),
            ]),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('حفظ'))],
        ),
      ),
    );
    if (ok != true) return;
    final patch = {
      'name': name.text.trim(),
      'specialty': spec.text.trim(),
      'bio': bio.text.trim(),
      'years_experience': int.tryParse(yrs.text),
      if (photo != null) 'photo': photo,
    };
    try {
      if (session.isAdmin) {
        await sb.from('teachers').update(patch).eq('id', t['id']);
      } else {
        await sb.rpc('update_my_card_v3', params: {
          'p_name': patch['name'],
          'p_specialty': patch['specialty'],
          'p_bio': patch['bio'],
          'p_photo': patch['photo'],
          'p_years': patch['years_experience'],
        });
      }
      if (mounted) {
        toast(context, 'تم الحفظ');
        setState(() => _f = _load());
      }
    } catch (e) {
      if (mounted) toast(context, 'تعذر الحفظ: $e');
    }
  }

  void _details(Map<String, dynamic> t) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
            child: ClipOval(child: SizedBox(width: 100, height: 100, child: dbImage(t['photo']))),
          ),
          const SizedBox(height: 12),
          Text('${t['name']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          if (t['specialty'] != null) Text('${t['specialty']}'),
          if (t['years_experience'] != null) Text('سنوات الخبرة: ${t['years_experience']}'),
          if (t['bio'] != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('${t['bio']}')),
          if (_canEdit(t))
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: FilledButton.icon(
                icon: const Icon(Icons.edit),
                label: const Text('تعديل'),
                onPressed: () { Navigator.pop(context); _edit(t); },
              ),
            ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.ownOnly ? 'بطاقتي' : 'المعلمون والمعلمات')),
        body: Column(children: [
          if (!widget.ownOnly)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(8),
              child: Row(children: [
                for (final c in staffCategories.entries)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 6),
                    child: ChoiceChip(label: Text(c.value), selected: cat == c.key, onSelected: (_) => setState(() => cat = c.key)),
                  ),
              ]),
            ),
          Expanded(
            child: Loader<List<Map<String, dynamic>>>(
              future: _f,
              builder: (all) {
                final items = widget.ownOnly
                    ? all.where((t) => t['username'] != null && t['username'] == session.username).toList()
                    : all.where((t) => _key(t) == cat).toList();
                if (items.isEmpty) {
                  return Empty(widget.ownOnly
                      ? 'لم يُربط حسابك ببطاقة بعد، تواصل مع الإدارة'
                      : 'لم تتم إضافة أحد في هذا القسم بعد');
                }
                return ListView(children: [
                  for (final t in items)
                    ListTile(
                      leading: CircleAvatar(
                        child: ClipOval(child: SizedBox(width: 40, height: 40, child: dbImage(t['photo']))),
                      ),
                      title: Text('${t['name']}'),
                      subtitle: Text('${t['specialty'] ?? ''}'),
                      onTap: () => _details(t),
                    ),
                ]);
              },
            ),
          ),
        ]),
      );
}

// ===== screens/home_screen.dart =====
class _Item {
  final IconData icon;
  final String title;
  final Set<String> roles;
  final Widget Function() page;
  const _Item(this.icon, this.title, this.roles, this.page);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Map<String, dynamic>>> _ann = _loadAnn();

  Future<List<Map<String, dynamic>>> _loadAnn() async {
    final d = await sb
        .from('announcements')
        .select('id,text,created_at')
        .order('created_at', ascending: false)
        .limit(10);
    return List<Map<String, dynamic>>.from(d);
  }

  static final _items = <_Item>[
    _Item(Icons.calendar_month, 'الجداول', {'student', 'teacher', 'staff', 'admin'}, () => const ScheduleScreen()),
    _Item(Icons.assignment, 'مهامي', {'student'}, () => const MyTasksScreen()),
    _Item(Icons.checklist, 'منظم الدراسة', {'student'}, () => const OrganizerScreen()),
    _Item(Icons.favorite, 'تمانينة', {'student'}, () => const TamScreen()),
    _Item(Icons.badge, 'بطاقتي', {'teacher', 'staff'}, () => const TeachersScreen(ownOnly: true)),
    _Item(Icons.groups, 'المعلمون والمعلمات', {'student', 'admin'}, () => const TeachersScreen()),
    _Item(Icons.campaign, 'إدارة الإعلانات', {'admin'}, () => const AnnouncementsScreen()),
    _Item(Icons.local_library, 'المكتبة', {'admin', 'staff'}, () => const LibraryScreen()),
    _Item(Icons.insights, 'لوحة تمانينة', {'admin'}, () => const TamDashScreen()),
    _Item(Icons.support_agent, 'التواصل مع المرشد', {'student', 'teacher', 'staff', 'admin'}, () => const SupportScreen()),
    _Item(Icons.lock, 'كلمة السر', {'teacher', 'staff', 'admin'}, () => const PasswordScreen()),
  ];

  void _open(Widget w) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => w)).then((_) => setState(() => _ann = _loadAnn()));

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final items = _items.where((i) => i.roles.contains(session.role)).toList();
        return Scaffold(
          appBar: AppBar(
            title: Text(session.isStudent
                ? 'نخبة'
                : '${roleLabels[session.role]} - ${session.name}'),
            actions: [
              if (session.loggedIn)
                TextButton(onPressed: session.logout, child: const Text('خروج'))
              else
                TextButton(
                  onPressed: () => _open(const LoginScreen()),
                  child: const Text('دخول الكادر'),
                ),
            ],
          ),
          body: DecoratedBox(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/school-logo.jpg'),
                fit: BoxFit.cover,
                opacity: 0.12,
              ),
            ),
            child: RefreshIndicator(
            onRefresh: () async => setState(() => _ann = _loadAnn()),
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                const Center(child: Icon(Icons.school, size: 72)),
                const SizedBox(height: 8),
                const Text('مدرسة الملك عبد الله الثاني للتميز - الطفيلة',
                    textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _announcements(),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.12,
                  children: [
                    for (final i in items)
                      Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _open(i.page()),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 58,
                                height: 58,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(i.icon, size: 32, color: Theme.of(context).colorScheme.primary),
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Text(i.title, textAlign: TextAlign.center,
                                  style: const TextStyle(fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            ),
          ),
        );
      },
    );
  }

  Widget _announcements() => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('الإعلانات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 6),
              SizedBox(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _ann,
                  builder: (c, s) {
                    if (s.connectionState != ConnectionState.done) {
                      return const LinearProgressIndicator();
                    }
                    final items = s.data ?? [];
                    if (items.isEmpty) return const Text('لا توجد إعلانات حالياً');
                    return Column(
                      children: [for (final a in items) ListTile(dense: true, title: Text(a['text'] ?? ''))],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
}

// ===== main.dart =====
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  try {
    await session.restore();
  } catch (_) {/* بدون اتصال: يبدأ كطالب */}
  runApp(const NokhbaApp());
}

class NokhbaApp extends StatelessWidget {
  const NokhbaApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF2563EB);
    return MaterialApp(
      title: 'نخبة | Nokhba',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      themeMode: ThemeMode.system,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF1F5F9),
        cardTheme: CardThemeData(
          color: Colors.white.withValues(alpha: 0.92),
          elevation: 3,
          shadowColor: const Color(0x1A000000),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFCBD5E1)),
          ),
          margin: const EdgeInsets.all(4),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF1F5F9),
          foregroundColor: Color(0xFF1E293B),
          centerTitle: true,
          elevation: 0,
        ),
        textTheme: ThemeData.light().textTheme.apply(
          bodyColor: const Color(0xFF334155),
          displayColor: const Color(0xFF1E293B),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E293B),
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF334155)),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F172A),
          foregroundColor: Color(0xFFF8FAFC),
          centerTitle: true,
          elevation: 0,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

// ===== الجداول الافتراضية (تُستخدم إن لم يوجد جدول بالقاعدة) =====
const _defaultSchedules = r'''{"g7":{"a":[["الأحد","مهني","مهني","علوم","رياضيات","عربي","إسلامية","إنجليزي","-"],["الإثنين","رياضيات","إسلامية","إنجليزي","عربي","فن","علوم","دراسات","-"],["الثلاثاء","إنجليزي","نشاط","نشاط","دراسات","مهارات","عربي","علوم","رياضيات"],["الأربعاء","مالية","رياضيات","رياضة","إنجليزي","عربي","علوم","رياضة","-"],["الخميس","عربي","إنجليزي","رياضيات","مهارات","دراسات","إسلامية","عربي","-"]],"b":[["الأحد","علوم","إسلامية","عربي","رياضة","رياضيات","دراسات","إنجليزي","-"],["الإثنين","عربي","إنجليزي","رياضة","علوم","رياضيات","مهارات","إسلامية","-"],["الثلاثاء","مالية","نشاط","نشاط","رياضيات","عربي","دراسات","إنجليزي","إسلامية"],["الأربعاء","رياضيات","فن","مهني","مهني","إنجليزي","عربي","علوم","-"],["الخميس","دراسات","مهارات","إنجليزي","عربي","رياضيات","عربي","علوم","-"]],"c":[["الأحد","إنجليزي","إسلامية","رياضيات","مهارات","دراسات","عربي","رياضة","-"],["الإثنين","علوم","إسلامية","إنجليزي","مهارات","عربي","رياضة","رياضيات","عربي"],["الثلاثاء","عربي","نشاط","نشاط","علوم","رياضيات","مهني","مهني","إنجليزي"],["الأربعاء","عربي","دراسات","رياضيات","مالية","فن","إنجليزي","علوم","-"],["الخميس","إسلامية","إنجليزي","علوم","رياضيات","عربي","دراسات","-","-"]]},"g8":{"a":[["الأحد","رياضيات","فن","علوم","إنجليزي","مالية","عربي","إسلامية","-"],["الإثنين","عربي","رياضيات","علوم","دراسات","إنجليزي","إسلامية","رياضة","فرنسي"],["الثلاثاء","عربي","نشاط","نشاط","فرنسي","رياضيات","إنجليزي","مهني","مهني"],["الأربعاء","علوم","فن","مالية","فرنسي","عربي","إسلامية","إنجليزي","رياضيات"],["الخميس","علوم","رياضة","إنجليزي","دراسات","مهارات","عربي","رياضيات","فرنسي"]],"b":[["الأحد","رياضيات","فن","علوم","إنجليزي","مالية","عربي","إسلامية","-"],["الإثنين","عربي","رياضيات","علوم","دراسات","إنجليزي","إسلامية","رياضة","فرنسي"],["الثلاثاء","عربي","نشاط","نشاط","فرنسي","رياضيات","إنجليزي","مهني","مهني"],["الأربعاء","رياضيات","علوم","عربي","رياضة","مهارات","دراسات","عربي","إنجليزي"],["الخميس","مهارات","إسلامية","فرنسي","علوم","عربي","رياضيات","إنجليزي","-"]],"c":[["الأحد","رياضيات","عربي","إسلامية","إنجليزي","رياضة","علوم","عربي","فن"],["الإثنين","إنجليزي","عربي","إسلامية","دراسات","فرنسي","رياضيات","مهني","مهني"],["الثلاثاء","عربي","نشاط","نشاط","إنجليزي","علوم","دراسات","فرنسي","رياضيات"],["الأربعاء","عربي","إنجليزي","رياضيات","مهارات","علوم","إسلامية","مالية","-"],["الخميس","علوم","رياضيات","إنجليزي","دراسات","مهارات","عربي","فرنسي","رياضة"]]},"g9":{"a":[["الأحد","رياضة","رياضيات","إنجليزي","علوم أرض","عربي","إسلامية","مهارات","فرنسي"],["الإثنين","تاريخ","علوم حياتية","رياضيات","عربي","رياضة","إنجليزي","فرنسي","عربي"],["الثلاثاء","فيزياء","نشاط","نشاط","عربي","مالية","رياضيات","فن","إنجليزي"],["الأربعاء","إنجليزي","مهارات","فيزياء","رياضيات","وطنية","إسلامية","فرنسي","عربي"],["الخميس","رياضيات","إسلامية","جغرافيا","كيمياء","مهني","مهني","عربي","إنجليزي"]],"b":[["الأحد","إنجليزي","علوم أرض","عربي","جغرافيا","مهارات","فرنسي","إسلامية","رياضيات"],["الإثنين","علوم حياتية","مالية","إنجليزي","رياضيات","وطنية","فيزياء","عربي","فرنسي"],["الثلاثاء","عربي","نشاط","نشاط","رياضة","إنجليزي","كيمياء","رياضيات","مهارات"],["الأربعاء","رياضيات","إسلامية","تاريخ","عربي","مهني","مهني","رياضة","إنجليزي"],["الخميس","رياضيات","إنجليزي","فيزياء","إسلامية","عربي","فرنسي","عربي","فن"]],"c":[["الأحد","فيزياء","إنجليزي","عربي","تاريخ","رياضيات","رياضة","مهارات","رياضة"],["الإثنين","إنجليزي","علوم أرض","عربي","رياضيات","مالية","فرنسي","إسلامية","فن"],["الثلاثاء","رياضيات","نشاط","نشاط","إسلامية","عربي","فرنسي","إنجليزي","فيزياء"],["الأربعاء","رياضيات","وطنية","مهارات","علوم حياتية","جغرافيا","إنجليزي","عربي","فرنسي"],["الخميس","مهني","مهني","عربي","إنجليزي","كيمياء","رياضيات","عربي","إسلامية"]]},"g10":{"a":[["الأحد","إنجليزي","رياضة","فيزياء","إسلامية","عربي","رياضيات","فرنسي","-"],["الإثنين","مهارات","تاريخ","وطنية","عربي","إسلامية","رياضيات","إنجليزي","-"],["الثلاثاء","إنجليزي","نشاط","نشاط","عربي","أحياء","رياضيات","كيمياء","فيزياء"],["الأربعاء","رياضيات","عربي","جغرافيا","علوم أرض","فرنسي","إنجليزي","مهارات","فن"],["الخميس","عربي","كيمياء","إسلامية","فرنسي","مالية","رياضيات","إنجليزي","-"]],"b":[["الأحد","رياضيات","فيزياء","جغرافيا","مالية","إنجليزي","عربي","فن","-"],["الإثنين","عربي","إسلامية","علوم حياتية","مهارات","إنجليزي","رياضة","رياضيات","-"],["الثلاثاء","إسلامية","نشاط","نشاط","إنجليزي","عربي","مهارات","علوم أرض","رياضيات"],["الأربعاء","إنجليزي","فيزياء","تاريخ","رياضيات","كيمياء","عربي","إسلامية","فرنسي"],["الخميس","رياضيات","وطنية","إنجليزي","كيمياء","عربي","فرنسي","فرنسي","-"]],"c":[["الأحد","إنجليزي","كيمياء","علوم حياتية","رياضيات","فيزياء","عربي","رياضيات","-"],["الإثنين","علوم أرض","إنجليزي","عربي","رياضيات","كيمياء","وطنية","فرنسي","-"],["الثلاثاء","إسلامية","نشاط","نشاط","عربي","جغرافيا","فيزياء","رياضيات","إنجليزي"],["الأربعاء","إسلامية","إنجليزي","عربي","فن","مهارات","رياضيات","فرنسي","عربي"],["الخميس","مهارات","مالية","رياضيات","فرنسي","تاريخ","إنجليزي","إسلامية","-"]]},"g11":{"a":[["الأحد","عربي","رياضيات","إسلامية","كيمياء","تاريخ","إنجليزي","مالية","-"],["الإثنين","عربي","إنجليزي","رياضيات","إسلامية","كيمياء","مهارات","عربي","-"],["الثلاثاء","رياضيات","إنجليزي","تاريخ","عربي","علوم أرض","إسلامية","فيزياء","-"],["الأربعاء","تاريخ","رياضيات","إسلامية","عربي","إنجليزي","فيزياء","مهارات","-"],["الخميس","إسلامية","عربي","رياضة","إنجليزي","رياضيات","تاريخ","علوم حياتية","-"]],"b":[["الأحد","إسلامية","تاريخ","رياضيات","عربي","إنجليزي","مالية","رياضة","-"],["الإثنين","رياضيات","تاريخ","إسلامية","عربي","إنجليزي","كيمياء","فيزياء","مهارات"],["الثلاثاء","إسلامية","تاريخ","عربي","إنجليزي","رياضيات","علوم أرض","-","-"],["الأربعاء","إسلامية","عربي","رياضيات","تاريخ","كيمياء","عربي","إنجليزي","-"],["الخميس","إسلامية","رياضيات","علوم حياتية","عربي","فيزياء","إنجليزي","مهارات","-"]],"c":[["الأحد","إسلامية","عربي","إنجليزي","رياضيات","مهارات","مهارات","كيمياء","-"],["الإثنين","رياضيات","عربي","فيزياء","إسلامية","إنجليزي","مالية","تاريخ","-"],["الثلاثاء","عربي","رياضيات","إسلامية","تاريخ","إنجليزي","كيمياء","عربي","-"],["الأربعاء","عربي","رياضيات","علوم حياتية","إسلامية","تاريخ","رياضة","إنجليزي","-"],["الخميس","إنجليزي","تاريخ","عربي","رياضيات","إسلامية","علوم أرض","فيزياء","-"]]},"g12":{"a":[["الأحد","فيزياء","إنجليزي","رياضيات","كيمياء","علوم حياتية","علوم أرض","رياضيات","-"],["الإثنين","فيزياء","رياضيات","كيمياء","إنجليزي","أحياء","علوم أرض","-","-"],["الثلاثاء","علوم أرض","علوم حياتية","إنجليزي","كيمياء","مهارات","فيزياء","رياضيات","-"],["الأربعاء","فيزياء","مهارات","إنجليزي","علوم حياتية","رياضيات","كيمياء","علوم أرض","-"],["الخميس","كيمياء","رياضيات","علوم أرض","إنجليزي","علوم حياتية","رياضة","فيزياء","-"]],"b":[["الأحد","أحياء","إنجليزي","علوم أرض","رياضيات","كيمياء","فيزياء","-","-"],["الإثنين","إنجليزي","رياضيات","فيزياء","علوم أرض","مهارات","علوم حياتية","كيمياء","-"],["الثلاثاء","فيزياء","رياضيات","كيمياء","علوم أرض","علوم حياتية","مهارات","إنجليزي","-"],["الأربعاء","علوم أرض","علوم حياتية","إنجليزي","كيمياء","رياضيات","رياضة","فيزياء","-"],["الخميس","إنجليزي","علوم أرض","رياضيات","فيزياء","كيمياء","علوم حياتية","رياضيات","-"]],"c":[["الأحد","كيمياء","إنجليزي","مهارات","علوم حياتية","علوم أرض","رياضيات","فيزياء","-"],["الإثنين","كيمياء","علوم أرض","إنجليزي","علوم حياتية","فيزياء","رياضيات","مهارات","-"],["الثلاثاء","كيمياء","إنجليزي","علوم أرض","علوم حياتية","فيزياء","رياضيات","-","-"],["الأربعاء","علوم حياتية","إنجليزي","علوم أرض","كيمياء","رياضيات","فيزياء","رياضيات","-"],["الخميس","علوم حياتية","إنجليزي","كيمياء","علوم أرض","فيزياء","رياضة","رياضيات","-"]]}}''';
