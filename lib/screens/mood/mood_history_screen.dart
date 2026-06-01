import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Paleta compartida de estados de ánimo
// ─────────────────────────────────────────────────────────────────────────────
class MoodData {
  static const moods = [
    MoodInfo(0, Icons.sentiment_very_dissatisfied_rounded,
        Color(0xFFEF4444), Color(0xFFFF8A80), 'Mal'),
    MoodInfo(1, Icons.sentiment_dissatisfied_rounded,
        Color(0xFFF97316), Color(0xFFFFAB40), 'No muy bien'),
    MoodInfo(2, Icons.sentiment_neutral_rounded,
        Color(0xFFF59E0B), Color(0xFFFFD740), 'Más o menos'),
    MoodInfo(3, Icons.sentiment_satisfied_rounded,
        Color(0xFF84CC16), Color(0xFFCCFF90), 'Bien'),
    MoodInfo(4, Icons.sentiment_very_satisfied_rounded,
        Color(0xFF22C55E), Color(0xFF69F0AE), 'Genial'),
  ];

  static String todayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  static String keyFor(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Guarda un nuevo registro de ánimo (permite múltiples por día)
  static Future<void> save(int value) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final now = DateTime.now();
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('moods')
        .add({
      'value': value,
      'label': moods[value].label,
      'date': keyFor(now),
      'hour': now.hour,
      'minute': now.minute,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Carga todas las entradas de hoy
  static Future<List<Map<String, dynamic>>> getTodayEntries() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];
    final today = todayKey();

    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('moods')
        .where('date', isEqualTo: today)
        .orderBy('timestamp', descending: true)
        .get();

    // También buscar el formato viejo (doc con ID = fecha)
    final oldDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('moods')
        .doc(today)
        .get();

    final results = <Map<String, dynamic>>[];

    for (final doc in snap.docs) {
      results.add(doc.data());
    }

    // Si hay un doc con formato viejo y no hay resultados nuevos, incluirlo
    if (oldDoc.exists && results.isEmpty) {
      results.add(oldDoc.data()!);
    }

    return results;
  }

  /// Carga optimizada: UNA sola query para obtener todos los registros del rango
  static Future<Map<String, List<MoodEntry>>> loadRangeOptimized(int days) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return {};

    final startDate = DateTime.now().subtract(Duration(days: days));
    final startKey = keyFor(startDate);
    final result = <String, List<MoodEntry>>{};

    // Query 1: docs con campo 'date' (formato nuevo)
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('moods')
          .where('date', isGreaterThanOrEqualTo: startKey)
          .orderBy('date')
          .get();

      for (final doc in snap.docs) {
        final data = doc.data();
        if (data.containsKey('date') && data.containsKey('value')) {
          final date = data['date'] as String;
          final value = data['value'] as int;
          final hour = data['hour'] as int? ?? 0;
          final minute = data['minute'] as int? ?? 0;
          final ts = data['timestamp'] as Timestamp?;
          result.putIfAbsent(date, () => []).add(
            MoodEntry(value: value, hour: hour, minute: minute, timestamp: ts),
          );
        }
      }
    } catch (_) {}

    // Query 2: UNA sola query para TODOS los docs de la subcolección
    // (captura docs viejos cuyo ID es la fecha, sin campo 'date')
    if (result.isEmpty) {
      try {
        final allSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('moods')
            .get();

        for (final doc in allSnap.docs) {
          final docId = doc.id;
          final data = doc.data();
          // Solo procesar docs con ID tipo fecha (YYYY-MM-DD) que no tengan campo 'date'
          if (!data.containsKey('date') &&
              data.containsKey('value') &&
              RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(docId) &&
              docId.compareTo(startKey) >= 0) {
            final v = data['value'] as int;
            final ts = data['timestamp'] as Timestamp?;
            result.putIfAbsent(docId, () => []).add(
              MoodEntry(value: v, hour: ts?.toDate().hour ?? 0, minute: ts?.toDate().minute ?? 0, timestamp: ts),
            );
          }
        }
      } catch (_) {}
    }

    // Ordenar entradas de cada día: más reciente primero
    for (final key in result.keys) {
      result[key]!.sort((a, b) {
        final aMin = a.hour * 60 + a.minute;
        final bMin = b.hour * 60 + b.minute;
        return bMin.compareTo(aMin); // Descendente: más reciente primero
      });
    }

    return result;
  }

  /// Retorna el promedio entero para una lista de entries
  static int averageOf(List<MoodEntry> entries) {
    if (entries.isEmpty) return 2;
    final avg = entries.map((e) => e.value).fold(0, (a, b) => a + b) / entries.length;
    return avg.round().clamp(0, 4);
  }
}

/// Un registro individual de ánimo con hora
class MoodEntry {
  final int value;
  final int hour;
  final int minute;
  final Timestamp? timestamp;
  const MoodEntry({required this.value, required this.hour, required this.minute, this.timestamp});

  String get timeString =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

class MoodInfo {
  final int value;
  final IconData icon;
  final Color color;
  final Color light;
  final String label;
  const MoodInfo(this.value, this.icon, this.color, this.light, this.label);
}

// ─────────────────────────────────────────────────────────────────────────────
// Pantalla principal de historial de ánimo
// ─────────────────────────────────────────────────────────────────────────────
class MoodHistoryScreen extends StatefulWidget {
  const MoodHistoryScreen({super.key});
  @override
  State<MoodHistoryScreen> createState() => _MoodHistoryScreenState();
}

class _MoodHistoryScreenState extends State<MoodHistoryScreen>
    with SingleTickerProviderStateMixin {
  static const Color _primary  = Color(0xFF2B5BFF);
  static const Color _bg       = Color(0xFFF4F6FB);

  late TabController _tabs;
  Map<String, List<MoodEntry>> _moodMap = {};
  bool _loading = true;
  DateTime _calMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final data = await MoodData.loadRangeOptimized(90);
    if (mounted) setState(() { _moodMap = data; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2B5BFF), Color(0xFF6B8FFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        title: const Text('Mi Bienestar',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.bar_chart_rounded, size: 20), text: 'Gráfica'),
            Tab(icon: Icon(Icons.calendar_month_rounded, size: 20), text: 'Calendario'),
          ],
        ),
      ),
      body: _loading
          ? _buildShimmerLoading()
          : TabBarView(controller: _tabs, children: [
              _ChartTab(moodMap: _moodMap),
              _CalendarTab(
                moodMap: _moodMap,
                month: _calMonth,
                onMonthChanged: (m) => setState(() => _calMonth = m),
              ),
            ]),
    );
  }

  Widget _buildShimmerLoading() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _shimmerCard(height: 100),
          const SizedBox(height: 20),
          _shimmerCard(height: 24, width: 140),
          const SizedBox(height: 12),
          _shimmerCard(height: 200),
          const SizedBox(height: 20),
          _shimmerCard(height: 24, width: 160),
          const SizedBox(height: 12),
          ...List.generate(3, (_) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _shimmerCard(height: 72),
          )),
        ],
      ),
    );
  }

  Widget _shimmerCard({required double height, double? width}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 0.7),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Container(
          height: height,
          width: width,
          decoration: BoxDecoration(
            color: Colors.grey.shade200.withOpacity(value),
            borderRadius: BorderRadius.circular(16),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 1 — Gráfica + Registros individuales con hora
// ─────────────────────────────────────────────────────────────────────────────
class _ChartTab extends StatelessWidget {
  final Map<String, List<MoodEntry>> moodMap;
  static const Color _primary  = Color(0xFF2B5BFF);
  static const Color _textMain = Color(0xFF0D1B3E);
  static const Color _textSub  = Color(0xFF8A94A6);

  const _ChartTab({required this.moodMap});

  @override
  Widget build(BuildContext context) {
    final days = List.generate(14, (i) =>
        DateTime.now().subtract(Duration(days: 13 - i)));
    final values = days.map((d) {
      final entries = moodMap[MoodData.keyFor(d)];
      if (entries == null || entries.isEmpty) return null;
      return MoodData.averageOf(entries);
    }).toList();

    // Promedio general
    final allEntries = moodMap.values.expand((e) => e).toList();
    final filled = values.whereType<int>().toList();
    final avg = filled.isEmpty ? null
        : filled.fold(0, (a, b) => a + b) / filled.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Resumen
        if (avg != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_primary, const Color(0xFF6B8FFF)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(
                color: _primary.withOpacity(0.3),
                blurRadius: 20, offset: const Offset(0, 8),
              )],
            ),
            child: Row(children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(MoodData.moods[avg.round().clamp(0, 4)].icon,
                    color: Colors.white, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Estado promedio',
                      style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(MoodData.moods[avg.round().clamp(0, 4)].label,
                      style: const TextStyle(color: Colors.white,
                          fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text('${allEntries.length} registros en total',
                      style: const TextStyle(color: Colors.white60, fontSize: 11)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 24),
        ],

        const Text('Últimos 14 días',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold,
                color: _textMain)),
        const SizedBox(height: 16),

        // Gráfica de barras
        Container(
          padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
                blurRadius: 16, offset: const Offset(0, 4))]),
          child: Column(children: [
            SizedBox(
              height: 180,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(14, (i) {
                  final v = values[i];
                  final d = days[i];
                  final color = v != null
                      ? MoodData.moods[v].color
                      : Colors.grey.shade200;
                  final h = v != null ? (v + 1) / 5.0 : 0.05;
                  final isToday = d.year == DateTime.now().year &&
                      d.month == DateTime.now().month &&
                      d.day == DateTime.now().day;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (v != null)
                            Icon(MoodData.moods[v].icon, size: 14, color: color),
                          const SizedBox(height: 4),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOutCubic,
                            height: 130 * h,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: v != null
                                    ? [MoodData.moods[v].light, color]
                                    : [Colors.grey.shade100, Colors.grey.shade200],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter),
                              borderRadius: BorderRadius.circular(8),
                              border: isToday
                                  ? Border.all(color: _primary, width: 2)
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            ['L', 'M', 'X', 'J', 'V', 'S', 'D'][d.weekday - 1],
                            style: TextStyle(fontSize: 10,
                                color: isToday ? _primary : _textSub,
                                fontWeight: isToday ? FontWeight.bold : FontWeight.normal)),
                          Text('${d.day}',
                              style: TextStyle(fontSize: 8,
                                  color: isToday ? _primary : _textSub.withOpacity(0.6))),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 16),
            // Leyenda
            Wrap(spacing: 12, runSpacing: 8,
              children: MoodData.moods.map((m) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 10, height: 10,
                      decoration: BoxDecoration(
                          color: m.color, shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Text(m.label, style: const TextStyle(fontSize: 10,
                      color: _textSub)),
                ],
              )).toList()),
          ]),
        ),

        const SizedBox(height: 24),

        // ── REGISTROS INDIVIDUALES CON HORA ──
        const Text('Registros recientes',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold,
                color: _textMain)),
        const SizedBox(height: 4),
        const Text('Detalle por hora de cada registro',
            style: TextStyle(fontSize: 12, color: _textSub)),
        const SizedBox(height: 14),

        ...days.reversed.take(7).where((d) =>
            moodMap.containsKey(MoodData.keyFor(d))).map((d) {
          final entries = moodMap[MoodData.keyFor(d)]!;
          final avgVal = MoodData.averageOf(entries);
          final avgMood = MoodData.moods[avgVal];

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
                  blurRadius: 10, offset: const Offset(0, 3))]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Encabezado del día
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [avgMood.light.withOpacity(0.3), avgMood.color.withOpacity(0.06)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(children: [
                    Icon(avgMood.icon, color: avgMood.color, size: 22),
                    const SizedBox(width: 10),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatDate(d),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14, color: _textMain),
                        ),
                        if (entries.length > 1)
                          Text(
                            'Promedio: ${avgMood.label} · ${entries.length} registros',
                            style: TextStyle(fontSize: 11, color: avgMood.color, fontWeight: FontWeight.w500),
                          ),
                      ],
                    )),
                  ]),
                ),

                // Cada registro individual con su hora (ordenados cronológicamente)
                ...(List<MoodEntry>.from(entries)..sort((a, b) {
                  final aMin = a.hour * 60 + a.minute;
                  final bMin = b.hour * 60 + b.minute;
                  return aMin.compareTo(bMin); // Ascendente: más antiguo primero
                })).map((entry) {
                  final m = MoodData.moods[entry.value.clamp(0, 4)];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    child: Row(children: [
                      // Hora
                      Container(
                        width: 52,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _primary.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          entry.timeString,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700,
                            color: _primary.withOpacity(0.8)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Icono
                      Container(
                        width: 34, height: 34,
                        decoration: BoxDecoration(
                          color: m.light.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(m.icon, color: m.color, size: 20),
                      ),
                      const SizedBox(width: 10),
                      // Label
                      Expanded(
                        child: Text(m.label,
                          style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600,
                            color: m.color)),
                      ),
                      // Color dot
                      Container(width: 8, height: 8,
                        decoration: BoxDecoration(
                          color: m.color, shape: BoxShape.circle)),
                    ]),
                  );
                }),
                const SizedBox(height: 8),
              ],
            ),
          );
        }),
      ]),
    );
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(d.year, d.month, d.day);
    if (date == today) return 'Hoy';
    if (date == today.subtract(const Duration(days: 1))) return 'Ayer';
    final dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    final meses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    return '${dias[d.weekday - 1]} ${d.day} ${meses[d.month - 1]}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 2 — Calendario mensual de estados
// ─────────────────────────────────────────────────────────────────────────────
class _CalendarTab extends StatelessWidget {
  final Map<String, List<MoodEntry>> moodMap;
  final DateTime month;
  final ValueChanged<DateTime> onMonthChanged;
  static const Color _primary  = Color(0xFF2B5BFF);
  static const Color _textMain = Color(0xFF0D1B3E);
  static const Color _textSub  = Color(0xFF8A94A6);

  const _CalendarTab({required this.moodMap, required this.month,
      required this.onMonthChanged});

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final startOffset = (firstDay.weekday - 1) % 7;
    final totalCells = startOffset + daysInMonth;
    final rows = (totalCells / 7).ceil();

    final monthNames = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [

        // Navegación de mes
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
                  blurRadius: 16, offset: const Offset(0, 4))]),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _navButton(Icons.chevron_left_rounded,
                  () => onMonthChanged(DateTime(month.year, month.month - 1))),
              Text('${monthNames[month.month - 1]} ${month.year}',
                  style: const TextStyle(fontSize: 17,
                      fontWeight: FontWeight.bold, color: _textMain)),
              _navButton(Icons.chevron_right_rounded,
                  () => onMonthChanged(DateTime(month.year, month.month + 1))),
            ]),
            const SizedBox(height: 16),

            // Días de semana
            Row(
              children: ['L', 'M', 'X', 'J', 'V', 'S', 'D'].map((d) =>
                Expanded(child: Center(child: Text(d,
                  style: const TextStyle(fontSize: 12,
                      fontWeight: FontWeight.bold, color: _textSub))))).toList(),
            ),
            const SizedBox(height: 10),

            // Grid de días
            ...List.generate(rows, (row) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: List.generate(7, (col) {
                  final cellIndex = row * 7 + col;
                  final dayNum = cellIndex - startOffset + 1;

                  if (dayNum < 1 || dayNum > daysInMonth) {
                    return const Expanded(child: SizedBox(height: 46));
                  }

                  final date = DateTime(month.year, month.month, dayNum);
                  final key = MoodData.keyFor(date);
                  final entries = moodMap[key];
                  final avgVal = entries != null ? MoodData.averageOf(entries) : null;
                  final m = avgVal != null ? MoodData.moods[avgVal] : null;
                  final isToday = date.year == DateTime.now().year &&
                      date.month == DateTime.now().month &&
                      date.day == DateTime.now().day;

                  return Expanded(
                    child: Container(
                      height: 46,
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        gradient: m != null ? LinearGradient(
                          colors: [m.light.withOpacity(0.3), m.color.withOpacity(0.12)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ) : null,
                        color: m == null ? Colors.transparent : null,
                        borderRadius: BorderRadius.circular(12),
                        border: isToday
                            ? Border.all(color: _primary, width: 2.5)
                            : m != null
                                ? Border.all(color: m.color.withOpacity(0.2))
                                : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (m != null)
                            Icon(m.icon, color: m.color, size: 16)
                          else
                            Text('$dayNum',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isToday
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isToday ? _primary : _textSub)),
                          if (m != null)
                            Text('$dayNum',
                                style: TextStyle(fontSize: 8,
                                    color: m.color.withOpacity(0.8))),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            )),
          ]),
        ),

        const SizedBox(height: 20),

        // Leyenda
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03),
                  blurRadius: 10)]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Referencia de estados',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                      color: _textMain)),
              const SizedBox(height: 14),
              ...MoodData.moods.map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                        color: m.light.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(10)),
                    child: Icon(m.icon, color: m.color, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Text(m.label, style: const TextStyle(fontSize: 14,
                      color: _textMain, fontWeight: FontWeight.w500)),
                ]),
              )),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _navButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: _primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: _primary, size: 24),
      ),
    );
  }
}
