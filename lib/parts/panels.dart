part of '../main.dart';

// ===== لوحات بطاقة الكادر: العلاقات الدراسية، المهام، الإعلانات، الكتب المستعارة =====

const maxTaskImages = 10; // صور لكل مهمة
const maxTasks = 20; // مهام لكل معلم
const maxNotices = 30; // إعلانات لكل مساعد

/// صيغة الحفظ: "7-a,7-b,8-c" (الصف-الشعبة). والصيغة القديمة "7" تعني كل شعب الصف.
Map<String, Set<String>> parseClasses(String? str) {
  final m = <String, Set<String>>{};
  for (final raw in (str ?? '').split(',')) {
    final tok = raw.trim();
    if (tok.isEmpty) continue;
    final parts = tok.split('-');
    final g = parts[0];
    if (!grades.containsKey(g)) continue;
    final set = m.putIfAbsent(g, () => <String>{});
    if (parts.length == 1) {
      set.addAll(sections.keys);
    } else if (sections.containsKey(parts[1])) {
      set.add(parts[1]);
    }
  }
  return m;
}

Widget _tag(String text) => Chip(
      label: Text(text, style: const TextStyle(fontSize: 12.5)),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );

Widget _tagsOf(Map<String, dynamic> x) {
  final cls = (x['classes'] is List) ? List<String>.from((x['classes'] as List).map((e) => '$e')) : <String>[];
  final secs = (x['sections'] is List) ? List<String>.from((x['sections'] as List).map((e) => '$e')) : <String>[];
  return Wrap(spacing: 6, runSpacing: 2, children: [
    for (final g in cls) _tag(grades[g] ?? g),
    if (secs.isNotEmpty) _tag('شعبة ${secs.map((s) => sections[s] ?? s).join('، ')}'),
  ]);
}

// ---------- العلاقات الدراسية (الصفوف والشعب) ----------
class ClassesPanel extends StatefulWidget {
  const ClassesPanel({super.key, required this.teacher, required this.canEdit, required this.onChanged});
  final Map<String, dynamic> teacher;
  final bool canEdit;
  final VoidCallback onChanged;
  @override
  State<ClassesPanel> createState() => _ClassesPanelState();
}

class _ClassesPanelState extends State<ClassesPanel> {
  late final Map<String, Set<String>> _sel = parseClasses(widget.teacher['classes'] as String?);
  bool _saving = false;

  void _toggle(String g, String s) => setState(() {
        final set = _sel.putIfAbsent(g, () => <String>{});
        if (!set.add(s)) set.remove(s);
      });

  void _toggleAll(String g) => setState(() {
        final set = _sel.putIfAbsent(g, () => <String>{});
        if (set.length == sections.length) {
          set.clear();
        } else {
          set.addAll(sections.keys);
        }
      });

  String _encode() {
    final out = <String>[];
    for (final g in grades.keys) {
      final set = _sel[g];
      if (set == null) continue;
      for (final s in sections.keys) {
        if (set.contains(s)) out.add('$g-$s');
      }
    }
    return out.join(',');
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final v = _encode();
    try {
      if (session.isAdmin) {
        await sb.from('teachers').update({'classes': v}).eq('id', widget.teacher['id'] as Object);
      } else {
        await sb.rpc('update_my_classes', params: {'p_classes': v});
      }
      widget.teacher['classes'] = v;
      widget.onChanged();
      if (mounted) toast(context, 'تم الحفظ');
    } catch (e) {
      if (mounted) toast(context, 'تعذر الحفظ: $e');
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (final g in grades.keys) {
      final set = _sel[g] ?? <String>{};
      if (!widget.canEdit && set.isEmpty) continue;
      final all = set.length == sections.length;
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          SizedBox(width: 92, child: Text(grades[g] ?? g, style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(
            child: Wrap(spacing: 6, runSpacing: 4, children: [
              if (widget.canEdit) ...[
                FilterChip(label: const Text('الكل'), selected: all, onSelected: (_) => _toggleAll(g)),
                for (final s in sections.keys)
                  FilterChip(label: Text(sections[s] ?? s), selected: set.contains(s), onSelected: (_) => _toggle(g, s)),
              ] else if (all)
                _tag('كل الشعب')
              else
                for (final s in sections.keys)
                  if (set.contains(s)) _tag('شعبة ${sections[s]}'),
            ]),
          ),
        ]),
      ));
    }
    return _Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('الصفوف والشعب التي يدرّسها', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 6),
        if (rows.isEmpty) const Text('لم يتم تحديد الصفوف بعد'),
        ...rows,
        if (widget.canEdit)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ')),
          ),
      ]),
    );
  }
}

// ---------- المهام والاختبارات ----------
class TasksPanel extends StatefulWidget {
  const TasksPanel({super.key, required this.teacher, required this.canEdit});
  final Map<String, dynamic> teacher;
  final bool canEdit;
  @override
  State<TasksPanel> createState() => _TasksPanelState();
}

class _TasksPanelState extends State<TasksPanel> {
  List<Map<String, dynamic>>? _tasks;
  String? _error;
  String _filter = 'all';
  final Set<String> _dGrades = <String>{};
  final Set<String> _dSections = <String>{};
  final List<String> _dImages = <String>[];
  final _textC = TextEditingController();
  bool _saving = false;

  Object get _id => widget.teacher['id'] as Object;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _textC.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = await sb.from('teachers').select('tasks,tasks_text,tasks_images').eq('id', _id).single();
      var list = <Map<String, dynamic>>[];
      final raw = d['tasks'];
      if (raw is List) list = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final oldImgs = d['tasks_images'] is List ? List<String>.from((d['tasks_images'] as List).map((e) => '$e')) : <String>[];
      final oldText = '${d['tasks_text'] ?? ''}';
      if (list.isEmpty && (oldText.isNotEmpty || oldImgs.isNotEmpty)) {
        list = [
          {'id': 'legacy', 'classes': <String>[], 'sections': <String>[], 'text': oldText, 'images': oldImgs, 'date': null}
        ];
      }
      if (mounted) setState(() => _tasks = list);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<bool> _save(List<Map<String, dynamic>> all) async {
    try {
      if (session.isAdmin) {
        await sb.from('teachers').update({'tasks': all, 'tasks_text': null, 'tasks_images': null}).eq('id', _id);
      } else {
        await sb.rpc('update_my_tasks', params: {'p_tasks': all});
      }
      if (mounted) setState(() => _tasks = all);
      return true;
    } catch (e) {
      if (mounted) toast(context, 'تعذر الحفظ: $e');
      return false;
    }
  }

  Future<void> _pickImages() async {
    final files = await ImagePicker().pickMultiImage(maxWidth: 1100, imageQuality: 70);
    for (final f in files) {
      if (_dImages.length >= maxTaskImages) {
        if (mounted) toast(context, 'الحد الأقصى $maxTaskImages صور لكل مهمة');
        break;
      }
      final bytes = await f.readAsBytes();
      _dImages.add('data:image/jpeg;base64,${base64Encode(bytes)}');
    }
    if (mounted) setState(() {});
  }

  Future<void> _add() async {
    final text = _textC.text.trim();
    if (_dGrades.isEmpty) {
      toast(context, 'اختر صفاً واحداً على الأقل قبل إضافة المهمة');
      return;
    }
    if (text.isEmpty && _dImages.isEmpty) {
      toast(context, 'اكتب المهمة أو أضف صورة');
      return;
    }
    final cur = _tasks ?? <Map<String, dynamic>>[];
    if (cur.length >= maxTasks) {
      toast(context, 'وصلت للحد الأقصى ($maxTasks مهمة). احذف مهمة قديمة أولاً');
      return;
    }
    // الشعب: المختارة، وإلا شعب المعلم من العلاقات الدراسية للصفوف المختارة
    final rel = parseClasses(widget.teacher['classes'] as String?);
    var secs = sections.keys.where(_dSections.contains).toList();
    if (secs.isEmpty && rel.isNotEmpty) {
      final u = <String>{};
      for (final g in _dGrades) {
        u.addAll(rel[g] ?? <String>{});
      }
      secs = sections.keys.where(u.contains).toList();
    }
    if (secs.length == sections.length) secs = <String>[];
    final task = <String, dynamic>{
      'id': DateTime.now().millisecondsSinceEpoch.toRadixString(36),
      'classes': grades.keys.where(_dGrades.contains).toList(),
      'sections': secs,
      'text': text.length > 3000 ? text.substring(0, 3000) : text,
      'images': List<String>.from(_dImages),
      'date': _todayIso(),
    };
    final all = <Map<String, dynamic>>[task, ...cur];
    if (jsonEncode(all).length > 9000000) {
      toast(context, 'حجم الصور كبير جداً، احذف مهمة قديمة أو ارفع صوراً أصغر');
      return;
    }
    setState(() => _saving = true);
    final ok = await _save(all);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      _dGrades.clear();
      _dSections.clear();
      _dImages.clear();
      _textC.clear();
      toast(context, 'تمت إضافة المهمة');
    }
  }

  Future<void> _delete(Map<String, dynamic> t) async {
    if (!await confirmDialog(context, 'حذف هذه المهمة؟')) return;
    await _save((_tasks ?? <Map<String, dynamic>>[]).where((x) => '${x['id']}' != '${t['id']}').toList());
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return _Panel(child: Text(_error!));
    if (_tasks == null) return const _Panel(child: LinearProgressIndicator());
    final list = [..._tasks!]..sort((a, b) => '${b['date'] ?? ''}'.compareTo('${a['date'] ?? ''}'));
    final used = <String>{};
    for (final x in list) {
      if (x['classes'] is List) used.addAll((x['classes'] as List).map((e) => '$e'));
    }
    final shown = _filter == 'all'
        ? list
        : list.where((x) => x['classes'] is List && (x['classes'] as List).map((e) => '$e').contains(_filter)).toList();
    final rel = parseClasses(widget.teacher['classes'] as String?);
    final options = rel.isEmpty ? grades.keys.toList() : grades.keys.where(rel.containsKey).toList();

    return _Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('المهام والاختبارات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        if (used.length > 1)
          Wrap(spacing: 6, children: [
            ChoiceChip(label: const Text('الكل'), selected: _filter == 'all', onSelected: (_) => setState(() => _filter = 'all')),
            for (final g in grades.keys.where(used.contains))
              ChoiceChip(label: Text(grades[g] ?? g), selected: _filter == g, onSelected: (_) => setState(() => _filter = g)),
          ]),
        if (shown.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text('لا يوجد شيء بعد')),
        for (final x in shown)
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.outlineVariant), borderRadius: BorderRadius.circular(14)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _tagsOf(x),
              if (x['date'] != null) Text(fmtArDate('${x['date']}'), style: const TextStyle(fontSize: 12.5)),
              if ('${x['text'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('${x['text']}', style: const TextStyle(height: 1.7))),
              if (x['images'] is List)
                for (final src in (x['images'] as List).map((e) => '$e'))
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: GestureDetector(
                      onTap: () => openPhoto(context, dbImage(src, fit: BoxFit.contain)),
                      child: ClipRRect(borderRadius: BorderRadius.circular(12), child: dbImage(src, fit: BoxFit.fitWidth, width: double.infinity)),
                    ),
                  ),
              if (widget.canEdit)
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(onPressed: () => _delete(x), child: const Text('حذف المهمة', style: TextStyle(color: Colors.red))),
                ),
            ]),
          ),
        if (widget.canEdit) ...[
          const Divider(height: 28),
          const Text('إضافة مهمة جديدة', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('1) اختر الصفوف'),
          Wrap(spacing: 6, children: [
            for (final g in options)
              FilterChip(
                label: Text(grades[g] ?? g),
                selected: _dGrades.contains(g),
                onSelected: (v) => setState(() => v ? _dGrades.add(g) : _dGrades.remove(g)),
              ),
          ]),
          if (rel.isEmpty) const Text('لم تحدد صفوفك في «العلاقات الدراسية»، لذلك تظهر كل الصفوف.', style: TextStyle(fontSize: 12.5)),
          const SizedBox(height: 8),
          Text(rel.isNotEmpty
              ? 'الشعب (اختياري، وإذا لم تختر فنستخدم شعبك المحددة في العلاقات الدراسية)'
              : 'الشعب (اختياري، وإذا لم تختر فالمهمة لكل الشعب)'),
          Wrap(spacing: 6, children: [
            for (final s in sections.keys)
              FilterChip(
                label: Text('شعبة ${sections[s]}'),
                selected: _dSections.contains(s),
                onSelected: (v) => setState(() => v ? _dSections.add(s) : _dSections.remove(s)),
              ),
          ]),
          const SizedBox(height: 8),
          const Text('2) اكتب المهمة أو الاختبار'),
          TextField(controller: _textC, maxLines: 4, maxLength: 3000, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'اكتب المهام أو الاختبارات...')),
          Text('3) أضف صوراً (حتى $maxTaskImages)'),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (var i = 0; i < _dImages.length; i++)
              Stack(children: [
                ClipRRect(borderRadius: BorderRadius.circular(10), child: dbImage(_dImages[i], width: 80, height: 80)),
                Positioned(
                  top: 2,
                  left: 2,
                  child: InkWell(
                    onTap: () => setState(() => _dImages.removeAt(i)),
                    child: const CircleAvatar(radius: 11, backgroundColor: Colors.red, child: Icon(Icons.close, size: 14, color: Colors.white)),
                  ),
                ),
              ]),
          ]),
          const SizedBox(height: 6),
          OutlinedButton.icon(onPressed: _pickImages, icon: const Icon(Icons.add_photo_alternate_outlined), label: const Text('إضافة صور')),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: _saving ? null : _add, child: Text(_saving ? 'جارٍ الحفظ...' : 'إضافة المهمة'))),
        ],
      ]),
    );
  }
}

// ---------- إعلانات مساعد المدير ----------
class NoticesPanel extends StatefulWidget {
  const NoticesPanel({super.key, required this.teacher, required this.canEdit});
  final Map<String, dynamic> teacher;
  final bool canEdit;
  @override
  State<NoticesPanel> createState() => _NoticesPanelState();
}

class _NoticesPanelState extends State<NoticesPanel> {
  List<Map<String, dynamic>>? _list;
  String? _error;
  final _c = TextEditingController();
  bool _saving = false;

  Object get _id => widget.teacher['id'] as Object;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = await sb.from('teachers').select('notices').eq('id', _id).single();
      final raw = d['notices'];
      final list = raw is List ? raw.map((e) => Map<String, dynamic>.from(e as Map)).toList() : <Map<String, dynamic>>[];
      if (mounted) setState(() => _list = list);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<bool> _save(List<Map<String, dynamic>> all) async {
    try {
      if (session.isAdmin) {
        await sb.from('teachers').update({'notices': all}).eq('id', _id);
      } else {
        await sb.rpc('update_my_notices', params: {'p_notices': all});
      }
      if (mounted) setState(() => _list = all);
      return true;
    } catch (e) {
      if (mounted) toast(context, 'تعذر الحفظ: $e');
      return false;
    }
  }

  Future<void> _add() async {
    final text = _c.text.trim();
    if (text.isEmpty) {
      toast(context, 'اكتب نص الإعلان أولاً');
      return;
    }
    final cur = _list ?? <Map<String, dynamic>>[];
    if (cur.length >= maxNotices) {
      toast(context, 'وصلت للحد الأقصى ($maxNotices إعلاناً). احذف إعلاناً قديماً أولاً');
      return;
    }
    final n = <String, dynamic>{
      'id': DateTime.now().millisecondsSinceEpoch.toRadixString(36),
      'text': text.length > 1000 ? text.substring(0, 1000) : text,
      'date': _todayIso(),
    };
    setState(() => _saving = true);
    final ok = await _save(<Map<String, dynamic>>[n, ...cur]);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) _c.clear();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return _Panel(child: Text(_error!));
    if (_list == null) return const _Panel(child: LinearProgressIndicator());
    final list = [..._list!]..sort((a, b) {
        final c = '${b['date'] ?? ''}'.compareTo('${a['date'] ?? ''}');
        return c != 0 ? c : '${b['id']}'.compareTo('${a['id']}');
      });
    return _Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('الإعلانات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        if (list.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text('لا توجد إعلانات حالياً')),
        for (final n in list)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.outlineVariant), borderRadius: BorderRadius.circular(14)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (n['date'] != null) Text(fmtArDate('${n['date']}'), style: const TextStyle(fontSize: 12.5)),
              Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text('${n['text'] ?? ''}', style: const TextStyle(height: 1.7))),
              if (widget.canEdit)
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    onPressed: () async {
                      if (!await confirmDialog(context, 'حذف هذا الإعلان؟')) return;
                      await _save(list.where((x) => '${x['id']}' != '${n['id']}').toList());
                    },
                    child: const Text('حذف', style: TextStyle(color: Colors.red)),
                  ),
                ),
            ]),
          ),
        if (widget.canEdit) ...[
          const Divider(height: 28),
          const Text('نشر إعلان جديد', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          TextField(controller: _c, maxLines: 4, maxLength: 1000, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'اكتب الإعلان...')),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: _saving ? null : _add, child: Text(_saving ? 'جارٍ الحفظ...' : 'نشر الإعلان'))),
        ],
      ]),
    );
  }
}

// ---------- الكتب المستعارة (أمين المكتبة) ----------
class LoansPanel extends StatefulWidget {
  const LoansPanel({super.key, required this.canEdit});
  final bool canEdit;
  @override
  State<LoansPanel> createState() => _LoansPanelState();
}

class _LoansPanelState extends State<LoansPanel> {
  List<Map<String, dynamic>>? _rows;
  String? _error;
  final _nameC = TextEditingController();
  final _bookC = TextEditingController();
  DateTime? _due;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameC.dispose();
    _bookC.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = await sb.from('library_loans').select('id,student_name,book_title,due_date').eq('returned', false).order('due_date');
      if (mounted) setState(() => _rows = List<Map<String, dynamic>>.from(d));
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _due ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _due = d);
  }

  Future<void> _add() async {
    final name = _nameC.text.trim();
    if (name.isEmpty || _due == null) {
      toast(context, 'اكتب اسم الطالب/ة واختر موعد التسليم');
      return;
    }
    final book = _bookC.text.trim();
    try {
      await sb.from('library_loans').insert({
        'student_name': name,
        'book_title': book.isEmpty ? null : book,
        'due_date': _dayKey(_due!.year, _due!.month, _due!.day),
      });
      _nameC.clear();
      _bookC.clear();
      setState(() => _due = null);
      _load();
    } catch (e) {
      if (mounted) toast(context, 'تعذر الإضافة: $e');
    }
  }

  Future<void> _returned(Map<String, dynamic> r) async {
    try {
      await sb.from('library_loans').update({'returned': true}).eq('id', r['id'] as Object);
      _load();
    } catch (e) {
      if (mounted) toast(context, 'تعذر الحفظ: $e');
    }
  }

  Future<void> _delete(Map<String, dynamic> r) async {
    if (!await confirmDialog(context, 'حذف هذا السجل؟')) return;
    try {
      await sb.from('library_loans').delete().eq('id', r['id'] as Object);
      _load();
    } catch (e) {
      if (mounted) toast(context, 'تعذر الحذف: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return _Panel(child: Text(_error!));
    if (_rows == null) return const _Panel(child: LinearProgressIndicator());
    final today = _todayIso();
    return _Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('الكتب المستعارة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        if (widget.canEdit) ...[
          const SizedBox(height: 8),
          TextField(controller: _nameC, maxLength: 80, decoration: const InputDecoration(hintText: 'اسم الطالب/ة', border: OutlineInputBorder(), counterText: '')),
          const SizedBox(height: 8),
          TextField(controller: _bookC, maxLength: 120, decoration: const InputDecoration(hintText: 'اسم الكتاب (اختياري)', border: OutlineInputBorder(), counterText: '')),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.event),
            label: Text(_due == null ? 'موعد تسليم الكتاب' : fmtArDate(_dayKey(_due!.year, _due!.month, _due!.day))),
          ),
          const SizedBox(height: 8),
          FilledButton(onPressed: _add, child: const Text('إضافة')),
        ],
        if (_rows!.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('لا توجد كتب مستعارة حالياً')),
        for (final r in _rows!)
          Builder(builder: (context) {
            final due = '${r['due_date'] ?? ''}';
            final late = due.compareTo(today) < 0;
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: late ? const Color.fromRGBO(239, 68, 68, .1) : null,
                border: Border.all(color: late ? Colors.red : Theme.of(context).colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${r['student_name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    if (r['book_title'] != null) Text('${r['book_title']}', style: const TextStyle(fontSize: 13)),
                    Text('موعد التسليم: ${fmtArDate(due)}${late ? ' (متأخر)' : ''}',
                        style: TextStyle(fontSize: 13, color: late ? Colors.red : Theme.of(context).colorScheme.primary, fontWeight: late ? FontWeight.bold : FontWeight.normal)),
                  ]),
                ),
                if (widget.canEdit)
                  Column(children: [
                    FilledButton.tonal(onPressed: () => _returned(r), child: const Text('تم الإرجاع')),
                    TextButton(onPressed: () => _delete(r), child: const Text('حذف', style: TextStyle(color: Colors.red))),
                  ]),
              ]),
            );
          }),
      ]),
    );
  }
}
