import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import '../mood/mood_history_screen.dart';

class PatientDetailScreen extends StatefulWidget {
  final String patientId;
  final String patientName;

  const PatientDetailScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> {
  static const Color _primary  = Color(0xFF2B5BFF);
  static const Color _bg       = Color(0xFFF4F6FB);
  static const Color _textMain = Color(0xFF0D1B3E);
  static const Color _textSub  = Color(0xFF8A94A6);

  Map<String, dynamic>? _patientData;
  bool _loadingProfile = true;
  String _resolvedName = '';

  @override
  void initState() {
    super.initState();
    _resolvedName = widget.patientName;
    _loadPatientProfile();
  }

  Future<void> _loadPatientProfile() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.patientId)
          .get();
      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _patientData = data;
          // If the appointment had a generic name, use the real one from Firestore
          final realName = data['name'] as String? ?? '';
          if (realName.isNotEmpty && (widget.patientName == 'Paciente' || widget.patientName.isEmpty)) {
            _resolvedName = realName;
          }
        });
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ],
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 16, color: _textMain),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: const Text('Perfil del Paciente',
            style: TextStyle(
                color: _textMain, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: _loadingProfile
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  const Text('Historial Emocional',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _textMain)),
                  const SizedBox(height: 12),
                  _buildEmotionsHistory(),
                  const SizedBox(height: 24),
                  const Text('Historial de Citas (Contigo)',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _textMain)),
                  const SizedBox(height: 12),
                  _buildAppointmentsHistory(),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    final photoUrl = _patientData?['photoUrl'] as String?;
    final first = _resolvedName.split(' ').first;
    final initial = first.isNotEmpty ? first[0].toUpperCase() : 'P';
    final age = _patientData?['age'];
    final gender = _patientData?['gender'] as String?;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              gradient: photoUrl == null || photoUrl.isEmpty
                  ? const LinearGradient(
                      colors: [Color(0xFF2B5BFF), Color(0xFF5E81FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              borderRadius: BorderRadius.circular(20),
              image: photoUrl != null && photoUrl.isNotEmpty
                  ? DecorationImage(
                      image: photoUrl.startsWith('http')
                          ? NetworkImage(photoUrl)
                          : MemoryImage(base64Decode(photoUrl.split(',').last))
                              as ImageProvider,
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: photoUrl == null || photoUrl.isEmpty
                ? Center(
                    child: Text(
                      initial,
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.white),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _resolvedName,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _textMain),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    if (age != null)
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.cake_rounded, size: 14, color: _textSub),
                        const SizedBox(width: 4),
                        Text('$age años',
                            style: const TextStyle(fontSize: 13, color: _textSub)),
                      ]),
                    if (gender != null && gender.isNotEmpty)
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.person_outline_rounded,
                            size: 14, color: _textSub),
                        const SizedBox(width: 4),
                        Text(gender,
                            style: const TextStyle(fontSize: 13, color: _textSub)),
                      ]),
                    if (age == null && (gender == null || gender.isEmpty))
                      const Text('Sin datos adicionales',
                          style: TextStyle(fontSize: 13, color: _textSub)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmotionsHistory() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.patientId)
          .collection('moods')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 7))))
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: _primary));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return _emptyState(
              Icons.mood_bad_rounded, 'No hay registros emocionales recientes.');
        }

        final values = docs.map((doc) => (doc.data() as Map<String, dynamic>)['value'] as int? ?? 2).toList();
        final avgValue = (values.reduce((a, b) => a + b) / values.length).round().clamp(0, 4);

        Color color;
        IconData icon;
        String label;
        switch (avgValue) {
          case 4:
            color = const Color(0xFF22C55E);
            icon = Icons.sentiment_very_satisfied_rounded;
            label = 'Genial';
            break;
          case 3:
            color = const Color(0xFF84CC16);
            icon = Icons.sentiment_satisfied_rounded;
            label = 'Bien';
            break;
          case 2:
            color = const Color(0xFFF59E0B);
            icon = Icons.sentiment_neutral_rounded;
            label = 'Más o menos';
            break;
          case 1:
            color = const Color(0xFFF97316);
            icon = Icons.sentiment_dissatisfied_rounded;
            label = 'No muy bien';
            break;
          case 0:
          default:
            color = const Color(0xFFEF4444);
            icon = Icons.sentiment_very_dissatisfied_rounded;
            label = 'Mal';
            break;
        }

        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withOpacity(0.3), width: 1.5),
                boxShadow: [
                  BoxShadow(color: color.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 36),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Tendencia Reciente', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _textSub)),
                        const SizedBox(height: 4),
                        Text(label, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
                        const SizedBox(height: 2),
                        Text('Promedio de los últimos ${docs.length} registros', style: const TextStyle(fontSize: 12, color: _textSub)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MoodHistoryScreen(patientId: widget.patientId),
                    ),
                  );
                },
                icon: const Icon(Icons.bar_chart_rounded, size: 20),
                label: const Text('Ver Análisis Detallado', style: TextStyle(fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primary,
                  side: const BorderSide(color: _primary, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAppointmentsHistory() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('psychologistId', isEqualTo: user.uid)
          .where('patientId', isEqualTo: widget.patientId)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: _primary));
        }
        var docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return _emptyState(
              Icons.event_busy_rounded, 'No hay citas registradas.');
        }

        final sorted = List.from(docs)..sort((a, b) {
            final ad = (a.data() as Map<String, dynamic>);
            final bd = (b.data() as Map<String, dynamic>);
            final aDt = DateTime.tryParse('${ad['date']} ${ad['startTime']}:00') ?? DateTime.now();
            final bDt = DateTime.tryParse('${bd['date']} ${bd['startTime']}:00') ?? DateTime.now();
            return bDt.compareTo(aDt); // Descendente (más recientes primero)
          });

        return Column(
          children: sorted.take(3).map((doc) {
            final d = doc.data() as Map<String, dynamic>;
            final dateStr = '${d['date']} · ${d['startTime']}';
            final status = d['status'] ?? 'scheduled';
            
            final dt = DateTime.tryParse('${d['date']} ${d['startTime']}:00') ?? DateTime.now();
            final isPast = dt.isBefore(DateTime.now().subtract(const Duration(hours: 1)));

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isPast ? Colors.grey.shade100 : const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.videocam_rounded,
                        color: isPast ? Colors.grey.shade500 : _primary,
                        size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isPast ? 'Sesión Pasada' : 'Próxima Sesión',
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _textMain)),
                        const SizedBox(height: 2),
                        Text(dateStr,
                            style: const TextStyle(
                                fontSize: 13, color: _textSub)),
                      ],
                    ),
                  ),
                  if (status == 'cancelled')
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('Cancelada',
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.bold)),
                    )
                  else if (isPast)
                    const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF10B981), size: 18)
                  else
                    const Icon(Icons.schedule_rounded,
                        color: _primary, size: 18)
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _emptyState(IconData icon, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFFCBD5E1), size: 40),
          const SizedBox(height: 12),
          Text(message,
              style: const TextStyle(
                  color: _textSub, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
