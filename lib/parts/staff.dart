part of '../main.dart';

// ===== المعلمون والمعلمات + بطاقة الكادر + إضافة الكادر =====

String staffKeyOf(Map<String, dynamic> t) {
  final c = '${t['category'] ?? 'teacher'}';
  if (c == 'teacher') return '${t['gender']}' == 'f' ? 'tf' : 'tm';
  return c;
}

bool canEditTeacher(Map<String, dynamic> t) =>
    session.isAdmin || (session.loggedIn && t['username'] != null && '${t['username']}' == session.username);

/// شعار المدرسة هو الصورة الافتراضية لأي عضو كادر لم يرفع صورة شخصية.
Widget staffPhoto(String? src, {BoxFit fit = BoxFit.cover}) {
  if (src == null || src.isEmpty) {
    return Image.asset('assets/images/school-logo.jpg', fit: BoxFit.contain, width: double.infinity, height: double.infinity);
  }
  return dbImage(src, fit: fit);
}

/// يستدعي دالة manage-user. يرجع رسالة خطأ أو null عند النجاح.
Future<String?> manageUser(Map<String, dynamic> body) async {
  try {
    final res = await sb.functions.invoke('manage-user', body: body);
    final d = res.data;
    if (d is Map && d['error'] != null) return '${d['error']}';
    return null;
  } on FunctionException catch (e) {
    final det = e.details;
    if (det is Map && det['error'] != null) return '${det['error']}';
    return 'تعذر التنفيذ (${e.status})';
  } catch (e) {
    return 'تعذر التنفيذ: $e';
  }
}

Future<String?> pickImageData({double maxWidth = 600}) async {
  final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: maxWidth, imageQuality: 70);
  if (f == null) return null;
  final bytes = await f.readAsBytes();
  return 'data:image/jpeg;base64,${base64Encode(bytes)}';
}

// ---------- قائمة الكادر ----------
class TeachersScreen extends StatefulWidget {
  const TeachersScreen({super.key, this.ownOnly = false});
  final bool ownOnly;
  @override
  State<TeachersScreen> createState() => _TeachersScreenState();
}

class _TeachersScreenState extends State<TeachersScreen> {
  String _cat = 'tm';
  late Future<List<Map<String, dynamic>>> _f = _load();

  Future<List<Map<String, dynamic>>> _load() async {
    final base = sb.from('teachers').select('id,username,name,specialty,photo,bio,category,gender,classes,years_experience');
    final d = widget.ownOnly
        ? await base.eq('username', session.username).order('created_at')
        : await base.order('created_at');
    return List<Map<String, dynamic>>.from(d);
  }

  void _reload() => setState(() => _f = _load());

  Future<void> _open(Map<String, dynamic> t) async {
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => TeacherCardScreen(teacher: t)));
    if (mounted) _reload();
  }

  Widget _tile(Map<String, dynamic> t) {
    final cs = Theme.of(context).colorScheme;
    final years = t['years_experience'];
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Material(
        color: cs.surface.withValues(alpha: .85),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _open(t),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              SizedBox(width: 62, height: 62, child: ClipOval(child: staffPhoto(t['photo'] as String?))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${t['name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  if ('${t['specialty'] ?? ''}'.isNotEmpty) Text('${t['specialty']}', style: TextStyle(color: cs.primary)),
                  if (years != null) Text('سنوات الخبرة: $years', style: const TextStyle(fontSize: 12.5)),
                ]),
              ),
              const Icon(Icons.chevron_left),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: 118,
        leading: const BackPill(),
        title: Text(widget.ownOnly ? 'بطاقتي' : 'المعلمون والمعلمات'),
        actions: [
          if (session.isAdmin && !widget.ownOnly)
            IconButton(
              tooltip: 'إضافة كادر',
              icon: const Icon(Icons.person_add_alt_1),
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const StaffAddScreen()));
                if (mounted) _reload();
              },
            ),
        ],
      ),
      body: Column(children: [
        if (!widget.ownOnly)
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                for (final e in staffCategories.entries)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(label: Text(e.value), selected: _cat == e.key, onSelected: (_) => setState(() => _cat = e.key)),
                  ),
              ],
            ),
          ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _f,
            builder: (c, s) {
              if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
              if (s.hasError) return Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('تعذر التحميل: ${s.error}')));
              final all = s.data ?? [];
              final list = widget.ownOnly ? all : all.where((t) => staffKeyOf(t) == _cat).toList();
              if (list.isEmpty) {
                return Center(child: Text(widget.ownOnly ? 'لا توجد بطاقة مرتبطة بحسابك بعد. اطلب من المدير إضافتها.' : 'لا يوجد أحد في هذا القسم بعد'));
              }
              return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [for (final t in list) _tile(t)]);
            },
          ),
        ),
      ]),
    );
  }
}

// ---------- صفحة بطاقة شخص ----------
class TeacherCardScreen extends StatefulWidget {
  const TeacherCardScreen({super.key, required this.teacher});
  final Map<String, dynamic> teacher;
  @override
  State<TeacherCardScreen> createState() => _TeacherCardScreenState();
}

class _TeacherCardScreenState extends State<TeacherCardScreen> {
  String? _panel;

  Map<String, dynamic> get t => widget.teacher;

  void _toggle(String p) => setState(() => _panel = _panel == p ? null : p);

  Future<void> _edit() async {
    final saved = await showDialog<bool>(context: context, builder: (_) => _EditCardDialog(teacher: t));
    if (saved == true && mounted) setState(() {});
  }

  Future<void> _resetPassword() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('كلمة سر جديدة'),
        content: TextField(controller: c, decoration: const InputDecoration(hintText: 'كلمة السر الجديدة')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
        ],
      ),
    );
    final pass = c.text;
    if (ok != true || !mounted) return;
    final problem = Session.passwordProblem(pass);
    if (problem != null) {
      toast(context, problem);
      return;
    }
    final err = await manageUser({'action': 'reset', 'username': t['username'], 'password': pass});
    if (mounted) toast(context, err ?? 'تم تغيير كلمة السر');
  }

  Future<void> _delete() async {
    if (!await confirmDialog(context, 'حذف "${t['name']}" نهائياً؟')) return;
    if (t['username'] != null) {
      final err = await manageUser({'action': 'delete', 'username': t['username']});
      if (err != null) {
        if (mounted) toast(context, err);
        return;
      }
    }
    try {
      await sb.from('teachers').delete().eq('id', t['id'] as Object);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) toast(context, 'تعذر الحذف: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final key = staffKeyOf(t);
    final edit = canEditTeacher(t);
    final years = t['years_experience'];
    final bubbles = <Widget>[];
    Widget bubble(String label, String id) => FilledButton.tonal(
          style: _panel == id ? FilledButton.styleFrom(backgroundColor: cs.primary, foregroundColor: cs.onPrimary) : null,
          onPressed: () => _toggle(id),
          child: Text(label),
        );
    if (key == 'tm' || key == 'tf') {
      bubbles.add(bubble('العلاقات الدراسية', 'classes'));
      bubbles.add(bubble('المهام والاختبارات', 'tasks'));
    } else if (key == 'assistant') {
      bubbles.add(bubble('الإعلانات', 'notices'));
    } else if (key == 'librarian') {
      bubbles.add(bubble('الكتب المستعارة', 'loans'));
    } else if (key == 'counselor' && (session.isStudent || edit)) {
      bubbles.add(FilledButton.tonal(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => session.isStudent ? const TamScreen() : const TamDashScreen()),
        ),
        child: const Text('طمأنينة'),
      ));
    }

    Widget? panel;
    if (_panel == 'classes') panel = ClassesPanel(teacher: t, canEdit: edit, onChanged: () => setState(() {}));
    if (_panel == 'tasks') panel = TasksPanel(teacher: t, canEdit: edit);
    if (_panel == 'notices') panel = NoticesPanel(teacher: t, canEdit: edit);
    if (_panel == 'loans') panel = LoansPanel(canEdit: edit);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: 118,
        leading: const BackPill(),
        title: Text('${t['name']}'),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 28), children: [
        _Panel(
          child: Column(children: [
            Row(children: [
              SizedBox(
                width: 92,
                height: 92,
                child: Container(
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: cs.primary, width: 3)),
                  child: ClipOval(child: staffPhoto(t['photo'] as String?)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${t['name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19)),
                  if ('${t['specialty'] ?? ''}'.isNotEmpty) Text('${t['specialty']}', style: TextStyle(color: cs.primary, fontSize: 15)),
                  if (years != null) Text('سنوات الخبرة: $years'),
                ]),
              ),
            ]),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(border: Border.all(color: cs.outlineVariant), borderRadius: BorderRadius.circular(14)),
              child: Text('${t['bio'] ?? ''}'.trim().isEmpty ? 'لا توجد نبذة بعد' : '${t['bio']}', style: const TextStyle(height: 1.7)),
            ),
          ]),
        ),
        if (bubbles.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Wrap(spacing: 8, runSpacing: 8, children: bubbles)),
        if (panel != null) panel,
        if (edit)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton(onPressed: _edit, child: const Text('تعديل البطاقة')),
              if (session.isAdmin && t['username'] != null)
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF64748B)),
                  onPressed: _resetPassword,
                  child: const Text('كلمة السر'),
                ),
              if (session.isAdmin)
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                  onPressed: _delete,
                  child: const Text('حذف'),
                ),
            ]),
          ),
      ]),
    );
  }
}

// ---------- تعديل البطاقة ----------
class _EditCardDialog extends StatefulWidget {
  const _EditCardDialog({required this.teacher});
  final Map<String, dynamic> teacher;
  @override
  State<_EditCardDialog> createState() => _EditCardDialogState();
}

class _EditCardDialogState extends State<_EditCardDialog> {
  late final _name = TextEditingController(text: '${widget.teacher['name'] ?? ''}');
  late final _spec = TextEditingController(text: '${widget.teacher['specialty'] ?? ''}');
  late final _bio = TextEditingController(text: '${widget.teacher['bio'] ?? ''}');
  late final _years = TextEditingController(text: widget.teacher['years_experience'] == null ? '' : '${widget.teacher['years_experience']}');
  String? _photo;
  bool _removePhoto = false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _spec.dispose();
    _bio.dispose();
    _years.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      toast(context, 'الاسم مطلوب');
      return;
    }
    final y = _years.text.trim().isEmpty ? null : (int.tryParse(_years.text.trim()) ?? 0).clamp(0, 60);
    final spec = _spec.text.trim();
    final bio = _bio.text.trim();
    setState(() => _busy = true);
    try {
      if (session.isAdmin) {
        final patch = <String, dynamic>{'name': name, 'specialty': spec, 'bio': bio, 'years_experience': y};
        if (_removePhoto) {
          patch['photo'] = null;
        } else if (_photo != null) {
          patch['photo'] = _photo;
        }
        await sb.from('teachers').update(patch).eq('id', widget.teacher['id'] as Object);
      } else {
        await sb.rpc('update_my_card_v3', params: {
          'p_name': name,
          'p_specialty': spec,
          'p_bio': bio,
          // قيمة فارغة تعني حذف الصورة في دالة قاعدة البيانات، وnull تعني عدم تغييرها.
          'p_photo': _removePhoto ? '' : _photo,
          'p_years': y,
        });
      }
      widget.teacher['name'] = name;
      widget.teacher['specialty'] = spec;
      widget.teacher['bio'] = bio;
      widget.teacher['years_experience'] = y;
      if (_removePhoto) {
        widget.teacher['photo'] = null;
      } else if (_photo != null) {
        widget.teacher['photo'] = _photo;
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        toast(context, 'تعذر الحفظ: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('تعديل البطاقة'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'الاسم')),
            TextField(controller: _spec, decoration: const InputDecoration(labelText: 'التخصص')),
            TextField(controller: _years, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'سنوات الخبرة')),
            TextField(controller: _bio, maxLines: 3, decoration: const InputDecoration(labelText: 'نبذة')),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : () async {
                final p = await pickImageData();
                if (p != null) setState(() { _photo = p; _removePhoto = false; });
              },
              icon: const Icon(Icons.photo_camera_outlined),
              label: Text(_photo == null ? 'تغيير الصورة' : 'تم اختيار صورة جديدة'),
            ),
            if (((widget.teacher['photo'] as String?)?.isNotEmpty ?? false) || _photo != null)
              TextButton.icon(
                onPressed: _busy ? null : () => setState(() { _photo = null; _removePhoto = true; }),
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: const Text('حذف الصورة الشخصية', style: TextStyle(color: Colors.red)),
              ),
          ]),
        ),
        actions: [
          TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'جارٍ الحفظ...' : 'حفظ')),
        ],
      );
}

// ---------- إضافة كادر (المدير) ----------
class StaffAddScreen extends StatefulWidget {
  const StaffAddScreen({super.key});
  @override
  State<StaffAddScreen> createState() => _StaffAddScreenState();
}

class _StaffAddScreenState extends State<StaffAddScreen> {
  String _cat = 'tm';
  final _name = TextEditingController();
  final _spec = TextEditingController();
  final _years = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  String? _photo;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _spec.dispose();
    _years.dispose();
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final name = _name.text.trim();
    final username = _user.text.trim().toLowerCase();
    if (name.isEmpty) {
      toast(context, 'اكتب الاسم');
      return;
    }
    if (username.isNotEmpty) {
      if (!RegExp(r'^[a-z0-9._-]+$').hasMatch(username)) {
        toast(context, 'اسم المستخدم بالإنجليزي (أحرف وأرقام و . _ - فقط)');
        return;
      }
      final problem = Session.passwordProblem(_pass.text);
      if (problem != null) {
        toast(context, problem);
        return;
      }
    }
    final isTeacher = _cat == 'tm' || _cat == 'tf';
    final category = isTeacher ? 'teacher' : _cat;
    final gender = _cat == 'tf' ? 'f' : 'm';
    final y = _years.text.trim().isEmpty ? null : (int.tryParse(_years.text.trim()) ?? 0).clamp(0, 60);
    setState(() => _busy = true);
    try {
      // بطاقة جاهزة بنفس الاسم وبدون حساب؟ نربط الحساب بها بدل تكرارها
      Map<String, dynamic>? existing;
      if (username.isNotEmpty) {
        final ex = await sb.from('teachers').select('id,category').eq('name', name).isFilter('username', null).limit(1);
        if (ex.isNotEmpty) existing = Map<String, dynamic>.from(ex.first);
      }
      final accountCat = existing != null ? '${existing['category']}' : category;
      if (username.isNotEmpty) {
        final err = await manageUser({
          'action': 'create',
          'username': username,
          'password': _pass.text,
          'name': name,
          'role': accountCat == 'teacher' ? 'teacher' : 'staff',
        });
        if (err != null) {
          if (mounted) toast(context, err);
          setState(() => _busy = false);
          return;
        }
      }
      final spec = _spec.text.trim();
      try {
        if (existing != null) {
          final patch = <String, dynamic>{'username': username};
          if (spec.isNotEmpty) patch['specialty'] = spec;
          if (_photo != null) patch['photo'] = _photo;
          if (y != null) patch['years_experience'] = y;
          await sb.from('teachers').update(patch).eq('id', existing['id'] as Object);
        } else {
          await sb.from('teachers').insert({
            'name': name,
            'specialty': spec,
            'username': username.isEmpty ? null : username,
            'photo': _photo,
            'category': category,
            'gender': gender,
            'years_experience': y,
          });
        }
      } catch (e) {
        if (username.isNotEmpty) await manageUser({'action': 'delete', 'username': username});
        rethrow;
      }
      if (!mounted) return;
      toast(context, username.isNotEmpty ? 'تمت الإضافة وإنشاء الحساب' : 'تمت الإضافة');
      _name.clear();
      _spec.clear();
      _years.clear();
      _user.clear();
      _pass.clear();
      setState(() {
        _photo = null;
        _busy = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        toast(context, 'تعذر الإضافة: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: 118,
        leading: const BackPill(),
        title: const Text('إضافة كادر'),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        _Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            InputDecorator(
              decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 2)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _cat,
                  items: [for (final e in staffCategories.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                  onChanged: (v) => setState(() => _cat = v ?? 'tm'),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'الاسم', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: _spec, decoration: const InputDecoration(labelText: 'التخصص', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(
              controller: _years,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'سنوات الخبرة (اختياري)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _user,
              decoration: const InputDecoration(labelText: 'اسم المستخدم بالإنجليزي (لإنشاء حساب)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _pass,
              decoration: const InputDecoration(labelText: 'كلمة السر (8+ أحرف: كبير وصغير ورقم ورمز)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                final p = await pickImageData();
                if (p != null) setState(() => _photo = p);
              },
              icon: const Icon(Icons.photo_camera_outlined),
              label: Text(_photo == null ? 'صورة (اختياري)' : 'تم اختيار صورة'),
            ),
            const SizedBox(height: 10),
            FilledButton(onPressed: _busy ? null : _add, child: Text(_busy ? 'جارٍ الإضافة...' : 'إضافة')),
          ]),
        ),
      ]),
    );
  }
}


// ---------- ملصق رمز QR لطمأنينة ----------
void showTamPoster(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 90, height: 90, child: ClipOval(child: assetImage('school-logo.jpg'))),
          const SizedBox(height: 8),
          const Text('طمأنينة', style: TextStyle(color: Color(0xFF0D9488), fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('كيف تشعر اليوم؟ امسح الرمز وأخبرنا — بسرية تامة وبدون اسم',
              textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF0F172A), height: 1.7)),
          const SizedBox(height: 10),
          QrImageView(data: '$siteUrl/#/join', size: 220, backgroundColor: Colors.white),
          const SizedBox(height: 8),
          const Text('مدرسة الملك عبد الله الثاني للتميز – الطفيلة', style: TextStyle(color: Color(0xFF0F172A), fontSize: 12)),
          const SizedBox(height: 6),
          const Text('التقط صورة للشاشة لطباعته', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
    ),
  );
}
