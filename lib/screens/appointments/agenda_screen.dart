import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'appointment_detail_screen.dart';

class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key});

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> with SingleTickerProviderStateMixin {
  static const Color _primary = Color(0xFF2B5BFF);
  static const Color _bg = Color(0xFFF4F6FB);
  static const Color _textMain = Color(0xFF0D1B3E);
  static const Color _textSub = Color(0xFF8A94A6);

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(child: Text('Debes iniciar sesión para ver tu agenda.')),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: false,
        title: const Text('Mi Agenda',
            style: TextStyle(color: _textMain, fontWeight: FontWeight.bold, fontSize: 24)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: _primary,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(color: _primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3)),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: _textSub,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              tabs: const [
                Tab(text: 'Próximas'),
                Tab(text: 'Pasadas'),
              ],
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('appointments')
            .where('patientId', isEqualTo: user.uid)
            .where('status', isEqualTo: 'scheduled')
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _primary));
          }
          if (snap.hasError) {
            return const Center(child: Text('Ocurrió un error al cargar las citas.', style: TextStyle(color: _textSub)));
          }

          final docs = snap.data?.docs ?? [];
          final now = DateTime.now();

          // Separar citas en próximas y pasadas
          List<QueryDocumentSnapshot> upcoming = [];
          List<QueryDocumentSnapshot> past = [];

          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final dateStr = data['date'] as String? ?? '';
            final timeStr = data['startTime'] as String? ?? '';
            final dt = DateTime.tryParse('$dateStr $timeStr:00');

            if (dt != null) {
              if (dt.isBefore(now.subtract(const Duration(hours: 1)))) {
                past.add(doc);
              } else {
                upcoming.add(doc);
              }
            } else {
              upcoming.add(doc); // Si no se puede parsear, asumir futura para no esconderla
            }
          }

          // Ordenar próximas (ascendente)
          upcoming.sort((a, b) {
            final ad = a.data() as Map<String, dynamic>;
            final bd = b.data() as Map<String, dynamic>;
            final dtA = DateTime.tryParse('${ad['date']} ${ad['startTime']}:00') ?? DateTime.now();
            final dtB = DateTime.tryParse('${bd['date']} ${bd['startTime']}:00') ?? DateTime.now();
            return dtA.compareTo(dtB);
          });

          // Ordenar pasadas (descendente)
          past.sort((a, b) {
            final ad = a.data() as Map<String, dynamic>;
            final bd = b.data() as Map<String, dynamic>;
            final dtA = DateTime.tryParse('${ad['date']} ${ad['startTime']}:00') ?? DateTime.now();
            final dtB = DateTime.tryParse('${bd['date']} ${bd['startTime']}:00') ?? DateTime.now();
            return dtB.compareTo(dtA);
          });

          return TabBarView(
            controller: _tabController,
            children: [
              _buildList(upcoming, isPast: false),
              _buildList(past, isPast: true),
            ],
          );
        },
      ),
    );
  }

  Widget _buildList(List<QueryDocumentSnapshot> docs, {required bool isPast}) {
    if (docs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isPast ? Icons.history_rounded : Icons.event_busy_rounded, size: 60, color: const Color(0xFFCBD5E1)),
            const SizedBox(height: 16),
            Text(
              isPast ? 'No tienes historial de citas' : 'No tienes citas próximas',
              style: const TextStyle(color: _textSub, fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: docs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final d = docs[index].data() as Map<String, dynamic>;
        final psychName = d['psychologistName'] ?? 'Psicólogo';
        final date = d['date'] ?? '';
        final time = d['startTime'] ?? '';

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AppointmentDetailScreen(
                  appointmentData: d,
                  isPast: isPast,
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
            ],
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isPast ? Colors.grey.shade100 : _primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.person_rounded,
                      color: isPast ? Colors.grey.shade500 : _primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          psychName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _textMain,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isPast ? 'Cita finalizada' : 'Cita confirmada',
                          style: TextStyle(
                            fontSize: 13,
                            color: isPast ? _textSub : const Color(0xFF22C55E),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(height: 1, color: Color(0xFFEEF2F6)),
              ),
              Row(
                children: [
                  _infoChip(Icons.calendar_month_rounded, date),
                  const SizedBox(width: 16),
                  _infoChip(Icons.access_time_rounded, time),
                ],
              ),
              if (!isPast) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final url = d['meetingUrl'] as String?;
                      if (url != null && url.isNotEmpty) {
                        final uri = Uri.parse(url);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('No se pudo abrir el enlace.')),
                            );
                          }
                        }
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('El psicólogo aún no ha asignado un link.')),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.videocam_rounded, color: Colors.white, size: 20),
                    label: const Text('Unirse a la sesión',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                ),
              ]
            ],
          ),
        ),
      );
    },
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: _textSub),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(color: _textMain, fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
