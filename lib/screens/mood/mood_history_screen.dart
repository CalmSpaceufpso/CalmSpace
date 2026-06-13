import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Paleta compartida de estados de ánimo
// ─────────────────────────────────────────────────────────────────────────────
class MoodData {
  static const moods = [
    MoodInfo(0, Icons.sentiment_very_dissatisfied_rounded,
        Color(0xFFEF4444), Color(0xFFFF8A80), 'Muy mal'),
    MoodInfo(1, Icons.sentiment_dissatisfied_rounded,
        Color(0xFFF97316), Color(0xFFFFAB40), 'Mal'),
    MoodInfo(2, Icons.sentiment_neutral_rounded,
        Color(0xFFF59E0B), Color(0xFFFFD740), 'Más o menos'),
    MoodInfo(3, Icons.sentiment_satisfied_rounded,
        Color(0xFF22C55E), Color(0xFF69F0AE), 'Bien'),
    MoodInfo(4, Icons.sentiment_very_satisfied_rounded,
        Color(0xFF3B5BFE), Color(0xFF8C9EFF), 'Excelente'),
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
  static Future<Map<String, List<MoodEntry>>> loadRangeOptimized(int days, {String? patientId}) async {
    final uid = patientId ?? FirebaseAuth.instance.currentUser?.uid;
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
  final String? patientId;

  const MoodHistoryScreen({super.key, this.patientId});
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
    final data = await MoodData.loadRangeOptimized(90, patientId: widget.patientId);
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
        title: Text(widget.patientId != null ? 'Resumen Semanal' : 'Mi Bienestar',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
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
// TAB 1 — Gráfica de Anillo y Resumen
// ─────────────────────────────────────────────────────────────────────────────
class _ChartTab extends StatelessWidget {
  final Map<String, List<MoodEntry>> moodMap;
  static const Color _primary  = Color(0xFF3B5BFE); // Color azul del tema
  static const Color _textMain = Color(0xFF111111);
  static const Color _textSub  = Color(0xFF888888);
  static const Color _bgCard   = Colors.white;

  const _ChartTab({required this.moodMap});

  @override
  Widget build(BuildContext context) {
    // Datos del DÍA ACTUAL
    final today = DateTime.now();
    final entriesToday = moodMap[MoodData.keyFor(today)] ?? [];

    // 1. Calcular promedio de HOY (Tarjeta superior)
    final avg = entriesToday.isEmpty ? null : 
        entriesToday.fold(0, (a, b) => a + b.value) / entriesToday.length;
    
    // Conteo por estado para HOY
    final moodCounts = List.filled(5, 0);
    for (final e in entriesToday) {
      moodCounts[e.value.clamp(0, 4)]++;
    }
    
    // Encontrar el estado más frecuente para el centro del donut
    int mostFrequentMoodIdx = 3; // Default Bien
    int maxCount = -1;
    for (int i = 0; i < 5; i++) {
      if (moodCounts[i] > maxCount) {
        maxCount = moodCounts[i];
        mostFrequentMoodIdx = i;
      }
    }

    // 3. Datos últimos 7 días para el "Resumen de esta semana"
    final days7 = List.generate(7, (i) => DateTime.now().subtract(Duration(days: i)));
    final entries7Counts = List.filled(5, 0);
    final currentWeekEntries = <MoodEntry>[];
    
    for (final d in days7) {
      final entriesDay = moodMap[MoodData.keyFor(d)];
      if (entriesDay != null && entriesDay.isNotEmpty) {
        final avgDay = MoodData.averageOf(entriesDay);
        entries7Counts[avgDay.clamp(0, 4)]++;
        currentWeekEntries.addAll(entriesDay);
      }
    }

    // 4. Calcular tendencia real (Semana actual vs Semana anterior)
    double? currentWeekAvg;
    double? prevWeekAvg;
    
    if (currentWeekEntries.isNotEmpty) {
      currentWeekAvg = currentWeekEntries.fold(0, (a, b) => a + b.value) / currentWeekEntries.length;
    }

    final prevWeekEntries = <MoodEntry>[];
    for (int i = 7; i < 14; i++) {
      final d = today.subtract(Duration(days: i));
      if (moodMap.containsKey(MoodData.keyFor(d))) {
        prevWeekEntries.addAll(moodMap[MoodData.keyFor(d)]!);
      }
    }
    if (prevWeekEntries.isNotEmpty) {
      prevWeekAvg = prevWeekEntries.fold(0, (a, b) => a + b.value) / prevWeekEntries.length;
    }

    String trendTitle = '¡Sigue registrando!';
    String trendSubtitle = 'Registra tus emociones para ver tu tendencia de bienestar.';
    Color trendColor = _primary;
    Color trendBgColor = const Color(0xFFF5F7FF);
    IconData trendIcon = Icons.star_rounded;

    if (currentWeekAvg != null && prevWeekAvg != null) {
      // Ajuste para evitar división por cero si el promedio anterior era exactamente 0 (Muy mal)
      final safePrevAvg = prevWeekAvg == 0 ? 0.1 : prevWeekAvg; 
      
      if (currentWeekAvg > prevWeekAvg) {
        final percent = ((currentWeekAvg - prevWeekAvg) / safePrevAvg * 100).round().abs();
        trendTitle = '¡Vas en crecimiento!';
        trendSubtitle = 'Tu bienestar ha mejorado $percent% respecto a la semana pasada.';
        trendColor = _primary;
        trendIcon = Icons.trending_up_rounded;
      } else if (currentWeekAvg < prevWeekAvg) {
        final percent = ((prevWeekAvg - currentWeekAvg) / safePrevAvg * 100).round().abs();
        trendTitle = '¡Tómate un respiro!';
        trendSubtitle = 'Tu bienestar ha bajado $percent% respecto a la semana pasada.';
        trendColor = const Color(0xFFF97316); // Naranja
        trendBgColor = const Color(0xFFFFF7ED);
        trendIcon = Icons.trending_down_rounded;
      } else {
        trendTitle = '¡Te mantienes estable!';
        trendSubtitle = 'Tu bienestar se mantiene al mismo nivel que la semana pasada.';
        trendColor = const Color(0xFF22C55E); // Verde
        trendBgColor = const Color(0xFFF0FDF4);
        trendIcon = Icons.trending_flat_rounded;
      }
    } else if (currentWeekAvg != null) {
      trendTitle = '¡Buen comienzo!';
      trendSubtitle = 'Sigue registrando para compararlo con tu semana anterior.';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Tarjeta de Estado Promedio
        if (avg != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_primary, Color(0xFF7A93FF)],
                begin: Alignment.centerLeft, end: Alignment.centerRight),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: _primary.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 6))],
            ),
            child: Row(children: [
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(MoodData.moods[avg.round().clamp(0, 4)].icon, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Estado promedio', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(MoodData.moods[avg.round().clamp(0, 4)].label, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                      const SizedBox(width: 8),
                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF54E38E), shape: BoxShape.circle))
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('${entriesToday.length} registros hoy', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 24),
        ],

        if (avg == null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F2FF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(children: [
              Icon(Icons.sentiment_neutral_rounded, color: _primary, size: 40),
              SizedBox(height: 8),
              Text('Aún no hay registros hoy', style: TextStyle(color: _primary, fontWeight: FontWeight.bold)),
            ]),
          ),
          const SizedBox(height: 24),
        ],

        const Text('Hoy', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textMain)),
        const SizedBox(height: 16),

        // Tarjeta principal (Donut + Leyenda)
        Container(
          decoration: BoxDecoration(color: _bgCard, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 4))]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header de la tarjeta
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('Distribución de tus estados de ánimo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _textMain, letterSpacing: -0.2)),
                              const SizedBox(width: 6),
                              Icon(Icons.info_outline, size: 14, color: _textSub.withOpacity(0.5)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text('Porcentaje de registros del día', style: TextStyle(fontSize: 11, color: _textSub, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(10)),
                      child: const Row(
                        children: [
                          Text('Hoy', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _textSub)),
                          SizedBox(width: 4),
                          Icon(Icons.keyboard_arrow_down, size: 14, color: _textSub),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Donut Chart + Legend
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    // Donut
                    SizedBox(
                      width: 140,
                      height: 140,
                      child: entriesToday.isEmpty 
                        ? Center(child: Text("Sin registros hoy", style: TextStyle(fontSize: 11, color: _textSub, fontWeight: FontWeight.bold), textAlign: TextAlign.center))
                        : Stack(
                        children: [
                          PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 40,
                              startDegreeOffset: -90,
                              sections: List.generate(5, (i) {
                                final count = moodCounts[i];
                                final isZero = count == 0;
                                final val = isZero ? 0.0 : (count / entriesToday.length) * 100;
                                return PieChartSectionData(
                                  color: MoodData.moods[i].color,
                                  value: val,
                                  title: isZero ? '' : '${val.round()}%',
                                  radius: 30,
                                  titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                );
                              }).reversed.toList(),
                            ),
                          ),
                          // Centro del Donut
                          Center(
                            child: Icon(MoodData.moods[mostFrequentMoodIdx].icon, color: MoodData.moods[mostFrequentMoodIdx].color.withOpacity(0.3), size: 54),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    // Leyenda
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (i) {
                          final idx = 4 - i; // Orden inverso
                          final m = MoodData.moods[idx];
                          final count = moodCounts[idx];
                          final val = entriesToday.isEmpty ? 0 : (count / entriesToday.length) * 100;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                Icon(m.icon, color: m.color, size: 18),
                                const SizedBox(width: 8),
                                Text(m.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _textMain)),
                                const Spacer(),
                                Text('${val.round()}%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: m.color)),
                              ],
                            ),
                          );
                        }),
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Banner Motivacional Dinámico
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: trendBgColor, borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]),
                      child: Icon(trendIcon, color: trendColor, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(trendTitle, style: TextStyle(color: trendColor, fontWeight: FontWeight.w800, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text(trendSubtitle, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11, height: 1.3)),
                        ],
                      ),
                    ),
                    Icon(Icons.local_florist_rounded, color: trendColor.withOpacity(0.5), size: 40),
                  ],
                ),
              )
            ],
          ),
        ),

        const SizedBox(height: 24),

        const Text('Resumen de esta semana', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textMain)),
        const SizedBox(height: 16),

        // Cajas de resumen semanal
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(color: _bgCard, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 4))]),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(5, (i) {
              final idx = 4 - i;
              final m = MoodData.moods[idx];
              final count = entries7Counts[idx];
              return Column(
                children: [
                  Icon(m.icon, color: m.color, size: 26),
                  const SizedBox(height: 8),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(text: '$count ', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: _textMain)),
                        const TextSpan(text: 'días', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 10, color: _textSub)),
                      ]
                    )
                  ),
                  const SizedBox(height: 4),
                  Text(m.label, style: const TextStyle(fontSize: 9, color: _textSub, fontWeight: FontWeight.w600)),
                ],
              );
            }),
          ),
        ),

        const SizedBox(height: 24),

        // ── REGISTROS RECIENTES ──
        const Text('Registros recientes',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                color: _textMain)),
        const SizedBox(height: 4),
        const Text('Detalle por hora de cada registro',
            style: TextStyle(fontSize: 12, color: _textSub)),
        const SizedBox(height: 14),

        ...List.generate(14, (i) => DateTime.now().subtract(Duration(days: i))).take(7).where((d) =>
            moodMap.containsKey(MoodData.keyFor(d))).map((d) {
          final entries = moodMap[MoodData.keyFor(d)]!;
          final avgVal = MoodData.averageOf(entries);
          final avgMood = MoodData.moods[avgVal];
          final isToday = d.year == DateTime.now().year && d.month == DateTime.now().month && d.day == DateTime.now().day;

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(20),
              border: Border.all(color: avgMood.color.withOpacity(0.2)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02),
                  blurRadius: 10, offset: const Offset(0, 3))]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Encabezado del día
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  decoration: BoxDecoration(
                    color: avgMood.color.withOpacity(0.05),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(children: [
                    Icon(avgMood.icon, color: avgMood.color, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isToday ? 'Hoy' : _formatDate(d),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 13, color: _textMain),
                        ),
                        if (entries.isNotEmpty)
                          Text(
                            'Promedio del día: ${avgMood.label} · ${entries.length} registros',
                            style: TextStyle(fontSize: 10, color: avgMood.color, fontWeight: FontWeight.w600),
                          ),
                      ],
                    )),
                  ]),
                ),

                // Cada registro individual
                ...(List<MoodEntry>.from(entries)..sort((a, b) {
                  final aMin = a.hour * 60 + a.minute;
                  final bMin = b.hour * 60 + b.minute;
                  return bMin.compareTo(aMin);
                })).map((entry) {
                  final m = MoodData.moods[entry.value.clamp(0, 4)];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F2FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          entry.timeString,
                          style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700,
                            color: _primary),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(m.icon, color: m.color, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(m.label,
                          style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700,
                            color: m.color)),
                      ),
                      Container(width: 6, height: 6,
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
    final dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    final meses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    return '${dias[d.weekday - 1]} ${d.day} ${meses[d.month - 1]}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 2 — Calendario mensual de estados (Interactivo)
// ─────────────────────────────────────────────────────────────────────────────
class _CalendarTab extends StatefulWidget {
  final Map<String, List<MoodEntry>> moodMap;
  final DateTime month;
  final ValueChanged<DateTime> onMonthChanged;

  const _CalendarTab({required this.moodMap, required this.month, required this.onMonthChanged});

  @override
  State<_CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<_CalendarTab> {
  static const Color _primary  = Color(0xFF3B5BFE);
  static const Color _textMain = Color(0xFF111111);
  static const Color _textSub  = Color(0xFF888888);
  
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(widget.month.year, widget.month.month, 1);
    final daysInMonth = DateTime(widget.month.year, widget.month.month + 1, 0).day;
    final startOffset = (firstDay.weekday - 1) % 7;
    final totalCells = startOffset + daysInMonth;
    final rows = (totalCells / 7).ceil();

    final monthNames = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];

    // Entradas del día seleccionado
    final selectedKey = MoodData.keyFor(_selectedDate);
    final selectedEntries = widget.moodMap[selectedKey] ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Tarjeta del Calendario Interactivo
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
                  blurRadius: 16, offset: const Offset(0, 4))]),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _navButton(Icons.chevron_left_rounded,
                  () => widget.onMonthChanged(DateTime(widget.month.year, widget.month.month - 1))),
              Text('${monthNames[widget.month.month - 1]} ${widget.month.year}',
                  style: const TextStyle(fontSize: 17,
                      fontWeight: FontWeight.bold, color: _textMain)),
              _navButton(Icons.chevron_right_rounded,
                  () => widget.onMonthChanged(DateTime(widget.month.year, widget.month.month + 1))),
            ]),
            const SizedBox(height: 20),

            // Días de semana
            Row(
              children: ['L', 'M', 'X', 'J', 'V', 'S', 'D'].map((d) =>
                Expanded(child: Center(child: Text(d,
                  style: const TextStyle(fontSize: 12,
                      fontWeight: FontWeight.bold, color: _textSub))))).toList(),
            ),
            const SizedBox(height: 12),

            // Grid de días
            ...List.generate(rows, (row) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: List.generate(7, (col) {
                  final cellIndex = row * 7 + col;
                  final dayNum = cellIndex - startOffset + 1;

                  if (dayNum < 1 || dayNum > daysInMonth) {
                    return const Expanded(child: SizedBox(height: 48));
                  }

                  final date = DateTime(widget.month.year, widget.month.month, dayNum);
                  final key = MoodData.keyFor(date);
                  final entries = widget.moodMap[key];
                  final avgVal = entries != null ? MoodData.averageOf(entries) : null;
                  final m = avgVal != null ? MoodData.moods[avgVal] : null;
                  
                  final isToday = date.year == DateTime.now().year && date.month == DateTime.now().month && date.day == DateTime.now().day;
                  final isSelected = date.year == _selectedDate.year && date.month == _selectedDate.month && date.day == _selectedDate.day;

                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedDate = date),
                      child: Container(
                        height: 48,
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? _primary.withOpacity(0.1) 
                              : (m != null ? m.light.withOpacity(0.2) : Colors.transparent),
                          borderRadius: BorderRadius.circular(14),
                          border: isSelected
                              ? Border.all(color: _primary, width: 2)
                              : isToday 
                                  ? Border.all(color: Colors.grey.shade300, width: 2)
                                  : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (m != null)
                              Icon(m.icon, color: m.color, size: 18)
                            else
                              Text('$dayNum',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: (isToday || isSelected) ? FontWeight.bold : FontWeight.normal,
                                    color: (isToday || isSelected) ? _primary : _textMain)),
                            if (m != null)
                              Text('$dayNum',
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold,
                                      color: m.color.withOpacity(0.8))),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            )),
          ]),
        ),

        const SizedBox(height: 24),
        
        // Sección Dinámica: Registros del Día Seleccionado
        Text(
          _selectedDate.year == DateTime.now().year && _selectedDate.month == DateTime.now().month && _selectedDate.day == DateTime.now().day 
            ? 'Tus registros de Hoy' 
            : 'Registros del ${_selectedDate.day} de ${monthNames[_selectedDate.month - 1]}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textMain)
        ),
        const SizedBox(height: 16),

        if (selectedEntries.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
            child: const Column(
              children: [
                Icon(Icons.calendar_today_rounded, color: Colors.grey, size: 40),
                SizedBox(height: 12),
                Text('No hay registros', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _textMain)),
                SizedBox(height: 4),
                Text('No agregaste ningún estado de ánimo este día.', style: TextStyle(color: _textSub, fontSize: 12), textAlign: TextAlign.center),
              ],
            ),
          )
        else ...[
          Container(
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02),
                  blurRadius: 10, offset: const Offset(0, 3))]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...(List<MoodEntry>.from(selectedEntries)..sort((a, b) {
                  final aMin = a.hour * 60 + a.minute;
                  final bMin = b.hour * 60 + b.minute;
                  return bMin.compareTo(aMin); 
                })).map((entry) {
                  final m = MoodData.moods[entry.value.clamp(0, 4)];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F2FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          entry.timeString,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _primary),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(m.icon, color: m.color, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(m.label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: m.color)),
                      ),
                    ]),
                  );
                }),
              ],
            ),
          )
        ],
        const SizedBox(height: 30),
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
