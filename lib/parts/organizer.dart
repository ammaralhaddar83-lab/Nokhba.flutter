part of '../main.dart';

// ===== منظم الدراسة: مهام + مؤقت + تقدم + وسام أسبوعي + روزنامة (محفوظ على الجهاز) =====

const _arMonths = <String>[
  'كانون الثاني', 'شباط', 'آذار', 'نيسان', 'أيار', 'حزيران',
  'تموز', 'آب', 'أيلول', 'تشرين الأول', 'تشرين الثاني', 'كانون الأول',
];
const _arDays = <String>['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
const _taskTypes = <String>['قراءة', 'حفظ', 'حل واجبات', 'مراجعة'];
const _funnyQuotes = <String>[
  'أصبحت أشك إنك نيوتن شخصياً!',
  'تقدمك هذا مذهل.. سيغمى عليّ من السرعة!',
  'يجب أن تأخذ وسام التميز على هذا الأداء البطولي!',
  'خفف سرعتك، القواعد الفيزيائية لا تتحمل هذا الإنجاز!',
];

String _todayIso() {
  final n = DateTime.now();
  return '${n.year}-${_two(n.month)}-${_two(n.day)}';
}

String _dayKey(int y, int m, int d) => '$y-${_two(m)}-${_two(d)}';

/// تاريخ بصيغة عربية: الأحد، 12 تشرين الأول 2026
String fmtArDate(String? iso, {bool year = true}) {
  if (iso == null || iso.length < 10) return '';
  final d = DateTime.tryParse(iso.substring(0, 10));
  if (d == null) return iso;
  return '${_arDays[d.weekday % 7]}، ${d.day} ${_arMonths[d.month - 1]}${year ? ' ${d.year}' : ''}';
}

class OrganizerScreen extends StatefulWidget {
  const OrganizerScreen({super.key});
  @override
  State<OrganizerScreen> createState() => _OrganizerScreenState();
}

class _OrganizerScreenState extends State<OrganizerScreen> {
  final _rnd = math.Random();
  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _events = [];
  int _weekDays = 0;
  String _lastCheck = '';

  final _nameC = TextEditingController();
  final _hoursC = TextEditingController(text: '0');
  final _minsC = TextEditingController(text: '0');
  String _type = _taskTypes.first;

  Timer? _timer;
  int _remaining = 0;
  bool _running = false;
  int _current = -1;
  String _quote = '';

  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  String? _selected;
  final _evTitleC = TextEditingController();
  final _evNoteC = TextEditingController();
  String _evTime = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _nameC.dispose();
    _hoursC.dispose();
    _minsC.dispose();
    _evTitleC.dispose();
    _evNoteC.dispose();
    super.dispose();
  }

  // ---------- حفظ وتحميل ----------
  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final t = p.getString('appTasks');
      final e = p.getString('appCalendar');
      final w = p.getString('weeklyProgress');
      final tasks = <Map<String, dynamic>>[];
      if (t != null) {
        for (final x in jsonDecode(t) as List) {
          final m = Map<String, dynamic>.from(x as Map);
          final mins = (m['minutes'] as num?)?.toInt() ?? 0;
          final hrs = (m['hours'] as num?)?.toInt() ?? 0;
          m['hours'] = hrs;
          m['minutes'] = mins;
          m['totalSeconds'] = (m['totalSeconds'] as num?)?.toInt() ?? (hrs * 3600 + mins * 60);
          m['done'] = m['done'] == true;
          tasks.add(m);
        }
      }
      final events = <Map<String, dynamic>>[];
      if (e != null) {
        for (final x in jsonDecode(e) as List) {
          events.add(Map<String, dynamic>.from(x as Map));
        }
      }
      var days = 0;
      var last = '';
      if (w != null) {
        final m = Map<String, dynamic>.from(jsonDecode(w) as Map);
        days = (m['completedDays'] as num?)?.toInt() ?? 0;
        last = (m['lastCheckDate'] ?? '') as String;
      }
      if (!mounted) return;
      setState(() {
        _tasks = tasks;
        _events = events;
        _weekDays = days;
        _lastCheck = last;
      });
    } catch (_) {/* بيانات تالفة: نبدأ من جديد */}
  }

  Future<void> _saveTasks() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('appTasks', jsonEncode(_tasks));
  }

  Future<void> _saveEvents() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('appCalendar', jsonEncode(_events));
  }

  Future<void> _saveWeekly() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('weeklyProgress', jsonEncode({'completedDays': _weekDays, 'lastCheckDate': _lastCheck}));
  }

  // ---------- المهام ----------
  int get _doneCount => _tasks.where((t) => t['done'] == true).length;
  int get _percent => _tasks.isEmpty ? 0 : (_doneCount * 100 / _tasks.length).round();

  String _badgeLabel() {
    if (_weekDays >= 7) return 'أصبحت حريفاً رسمياً!';
    if (_weekDays >= 4) return 'سريع الاشتعال';
    return 'مبتدئ مواظب';
  }

  void _addTask() {
    final name = _nameC.text.trim();
    if (name.isEmpty) {
      toast(context, 'اكتب اسم المهمة');
      return;
    }
    final h = int.tryParse(_hoursC.text.trim()) ?? 0;
    final m = int.tryParse(_minsC.text.trim()) ?? 0;
    if (h * 3600 + m * 60 <= 0) {
      toast(context, 'حدّد مدة المهمة (ساعات أو دقائق)');
      return;
    }
    setState(() {
      _tasks.add({'name': name, 'type': _type, 'hours': h, 'minutes': m, 'totalSeconds': h * 3600 + m * 60, 'done': false});
      _nameC.clear();
    });
    _saveTasks();
  }

  void _toggleDone(int i) {
    setState(() {
      _tasks[i]['done'] = !(_tasks[i]['done'] == true);
      if (_tasks[i]['done'] == true) _quote = _funnyQuotes[_rnd.nextInt(_funnyQuotes.length)];
    });
    _saveTasks();
    if (_percent == 100) _dayComplete();
  }

  void _delete(int i) {
    if (_current == i) _resetTimer();
    setState(() {
      _tasks.removeAt(i);
      if (_current > i) _current--;
    });
    _saveTasks();
  }

  void _dayComplete() {
    final today = _todayIso();
    if (_lastCheck != today) {
      setState(() {
        _weekDays = (_weekDays % 7) + 1;
        _lastCheck = today;
        _quote = _funnyQuotes[_rnd.nextInt(_funnyQuotes.length)];
      });
      _saveWeekly();
    }
  }

  // ---------- المؤقت ----------
  void _startTask(int i) {
    _timer?.cancel();
    setState(() {
      _current = i;
      _remaining = (_tasks[i]['totalSeconds'] as int);
      _running = true;
    });
    _runTimer();
  }

  void _runTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_remaining > 0) {
        setState(() => _remaining--);
      } else {
        t.cancel();
        setState(() => _running = false);
        if (_current >= 0 && _current < _tasks.length && _tasks[_current]['done'] != true) _toggleDone(_current);
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => _running = false);
  }

  void _resumeTimer() {
    if (_current < 0 || _remaining <= 0 || _running) return;
    setState(() => _running = true);
    _runTimer();
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _running = false;
      _remaining = 0;
      _current = -1;
    });
  }

  String get _clock {
    final h = _remaining ~/ 3600;
    final m = (_remaining % 3600) ~/ 60;
    final s = _remaining % 60;
    return '${_two(h)}:${_two(m)}:${_two(s)}';
  }

  // ---------- الروزنامة ----------
  List<Map<String, dynamic>> _eventsOf(String key) => _events.where((e) => e['date'] == key).toList();

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (t != null) setState(() => _evTime = '${_two(t.hour)}:${_two(t.minute)}');
  }

  void _addEvent() {
    final title = _evTitleC.text.trim();
    if (_selected == null) {
      toast(context, 'اختر يوماً من الروزنامة أولاً');
      return;
    }
    if (title.isEmpty) {
      toast(context, 'اكتب عنوان الموعد');
      return;
    }
    setState(() {
      _events.add({
        'id': DateTime.now().millisecondsSinceEpoch,
        'date': _selected,
        'title': title,
        'time': _evTime,
        'note': _evNoteC.text.trim(),
      });
      _evTitleC.clear();
      _evNoteC.clear();
      _evTime = '';
    });
    _saveEvents();
  }

  void _deleteEvent(Object id) {
    setState(() => _events.removeWhere((e) => e['id'] == id));
    _saveEvents();
  }

  Widget _calendar(ColorScheme cs) {
    final y = _month.year;
    final m = _month.month;
    final first = DateTime(y, m, 1);
    final lead = first.weekday % 7; // الأحد = 0
    final days = DateTime(y, m + 1, 0).day;
    final today = _todayIso();
    final cells = <Widget>[
      for (var i = 0; i < lead; i++) const SizedBox.shrink(),
      for (var d = 1; d <= days; d++)
        Builder(builder: (context) {
          final key = _dayKey(y, m, d);
          final n = _eventsOf(key).length;
          final sel = _selected == key;
          return InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _selected = key),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: sel ? cs.primary : (key == today ? cs.primaryContainer : cs.surface.withValues(alpha: .7)),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('$d', style: TextStyle(fontWeight: FontWeight.bold, color: sel ? cs.onPrimary : cs.onSurface)),
                if (n > 0) Text('• $n', style: TextStyle(fontSize: 10, color: sel ? cs.onPrimary : cs.primary)),
              ]),
            ),
          );
        }),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        FilledButton(onPressed: () => setState(() => _month = DateTime(y, m + 1)), child: const Text('لاحق')),
        Text('${_arMonths[m - 1]} $y', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        FilledButton(onPressed: () => setState(() => _month = DateTime(y, m - 1)), child: const Text('سابق')),
      ]),
      const SizedBox(height: 8),
      GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 5,
        crossAxisSpacing: 5,
        childAspectRatio: .95,
        children: cells,
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pct = _percent;
    final selKey = _selected;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: 118,
        leading: const BackPill(),
        title: const Text('منظم وقت الدراسة'),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 28), children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(value: pct / 100, minHeight: 16, color: const Color(0xFF10B981)),
        ),
        const SizedBox(height: 6),
        Text('التقدم: $pct% ($_doneCount/${_tasks.length})', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
        if (_weekDays > 0)
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFCA8A04), Color(0xFFB45309)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text('وسام التميز الأسبوعي: ${_badgeLabel()} ($_weekDays/7)',
                textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          ),
        if (_quote.isNotEmpty)
          _Panel(child: Text('🎉 $_quote', textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, height: 1.7))),
        const SizedBox(height: 10),
        TextField(controller: _nameC, decoration: const InputDecoration(hintText: 'اسم المهمة الدراسية...', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        InputDecorator(
          decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 2)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _type,
              items: [for (final t in _taskTypes) DropdownMenuItem(value: t, child: Text(t))],
              onChanged: (v) => setState(() => _type = v ?? _taskTypes.first),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _hoursC,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'ساعات', border: OutlineInputBorder()),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _minsC,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'دقائق', border: OutlineInputBorder()),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        FilledButton(onPressed: _addTask, child: const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('إضافة المهمة'))),
        const SizedBox(height: 18),
        const Text('قائمة المهام اليومية', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        if (_tasks.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('لا توجد مهام بعد', textAlign: TextAlign.center)),
        for (var i = 0; i < _tasks.length; i++)
          _Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${_tasks[i]['name']}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    decoration: _tasks[i]['done'] == true ? TextDecoration.lineThrough : null,
                  )),
              const SizedBox(height: 4),
              Text('${_tasks[i]['type']} | ${_tasks[i]['hours']}h ${_tasks[i]['minutes']}m'),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                  onPressed: () => _startTask(i),
                  child: const Text('ابدأ'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF59E0B)),
                  onPressed: () => _toggleDone(i),
                  child: Text(_tasks[i]['done'] == true ? 'إلغاء' : 'إنهاء'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                  onPressed: () => _delete(i),
                  child: const Text('حذف'),
                ),
              ]),
            ]),
          ),
        const SizedBox(height: 18),
        const Text('المؤقت الدراسـي', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(_clock, textAlign: TextAlign.center, style: const TextStyle(fontSize: 44, fontWeight: FontWeight.bold, letterSpacing: 2)),
        const SizedBox(height: 6),
        Wrap(alignment: WrapAlignment.center, spacing: 8, children: [
          FilledButton(onPressed: _running ? _pauseTimer : null, child: const Text('إيقاف مؤقت')),
          FilledButton(onPressed: (!_running && _remaining > 0) ? _resumeTimer : null, child: const Text('استئناف')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: _resetTimer,
            child: const Text('إعادة ضبط'),
          ),
        ]),
        const SizedBox(height: 22),
        const Text('الروزنامة والمواعيد', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _calendar(cs),
        const SizedBox(height: 12),
        Text(selKey == null ? 'اختر يوماً من الروزنامة' : fmtArDate(selKey, year: false),
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        if (selKey != null) ...[
          for (final e in _eventsOf(selKey))
            _Panel(
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${(e['time'] ?? '') == '' ? '' : '${e['time']}  '}${e['title']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    if ((e['note'] ?? '') != '') Text('${e['note']}', style: const TextStyle(fontSize: 13)),
                  ]),
                ),
                IconButton(onPressed: () => _deleteEvent(e['id'] as Object), icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444))),
              ]),
            ),
          const SizedBox(height: 10),
          TextField(controller: _evTitleC, decoration: const InputDecoration(hintText: 'عنوان الموعد أو الاختبار...', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _pickTime,
            icon: const Icon(Icons.access_time),
            label: Text(_evTime.isEmpty ? 'اختر الوقت (اختياري)' : _evTime),
          ),
          const SizedBox(height: 8),
          TextField(controller: _evNoteC, decoration: const InputDecoration(hintText: 'ملاحظة إضافية...', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          FilledButton(onPressed: _addEvent, child: const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('إضافة للروزنامة'))),
        ],
      ]),
    );
  }
}
