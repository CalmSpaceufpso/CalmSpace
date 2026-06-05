import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/appointment_model.dart';
import 'appointment_detail_screen.dart';

class AppointmentHistoryScreen extends StatefulWidget {
  const AppointmentHistoryScreen({super.key});

  @override
  State<AppointmentHistoryScreen> createState() =>
      _AppointmentHistoryScreenState();
}

class _AppointmentHistoryScreenState extends State<AppointmentHistoryScreen>
    with SingleTickerProviderStateMixin {
  static const Color _primary = Color(0xFF2B5BFF);
  static const Color _bg = Color(0xFFF4F6FB);
  static const Color _textMain = Color(0xFF0D1B3E);
  static const Color _textSub = Color(0xFF8A94A6);
  static const Color _success = Color(0xFF10B981);
  static const Color _danger = Color(0xFFEF4444);

  late final TabController _tabController;
  String _role = 'Paciente';
  bool _loadingRole = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadRole();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loadingRole = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get(const GetOptions(source: Source.cache));
      if (doc.exists && mounted) {
        setState(() => _role = doc.data()?['role'] ?? 'Paciente');
      }
    } catch (_) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists && mounted) {
          setState(() => _role = doc.data()?['role'] ?? 'Paciente');
        }
      } catch (_) {}
    } finally {
      if (mounted) setState(() => _loadingRole = false);
    }
  }

  bool get _isPsychologist => _role == 'Psicólogo' || _role == 'PsicÃ³logo';

  Stream<QuerySnapshot<Map<String, dynamic>>> _appointmentsStream(String uid) {
    return FirebaseFirestore.instance
        .collection('appointments')
        .where(_isPsychologist ? 'psychologistId' : 'patientId', isEqualTo: uid)
        .snapshots(includeMetadataChanges: true);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        backgroundColor: _bg,
        body: _EmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'Inicia sesión',
          message: 'Debes iniciar sesión para ver tu historial de citas.',
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: _textMain),
        title: const Text(
          'Historial de citas',
          style: TextStyle(
            color: _textMain,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: _HistoryTabs(controller: _tabController),
        ),
      ),
      body: _loadingRole
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _appointmentsStream(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _HistoryLoading();
                }

                if (snapshot.hasError) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            size: 64,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          const Text(
            'No se pudo cargar el historial',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Revisa tu conexión e inténtalo nuevamente.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {});
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    ),
  );
}
                final appointments = _historyAppointments(snapshot);
                final all = appointments;
                final completed = appointments
                    .where((item) => item.historyStatus == _HistoryStatus.done)
                    .toList();
                final cancelled = appointments
                    .where(
                      (item) => item.historyStatus == _HistoryStatus.cancelled,
                    )
                    .toList();

                final fromCache = snapshot.data?.metadata.isFromCache ?? false;

                return Column(
                  children: [
                    _CacheBanner(fromCache: fromCache),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _HistoryList(
                            items: all,
                            isPsychologist: _isPsychologist,
                            emptyTitle: 'Aún no tienes historial',
                            emptyMessage:
                                'Las citas finalizadas o canceladas aparecerán aquí.',
                          ),
                          _HistoryList(
                            items: completed,
                            isPsychologist: _isPsychologist,
                            emptyTitle: 'Sin citas finalizadas',
                            emptyMessage:
                                'Cuando una cita pase o se complete, la verás en esta sección.',
                          ),
                          _HistoryList(
                            items: cancelled,
                            isPsychologist: _isPsychologist,
                            emptyTitle: 'Sin citas canceladas',
                            emptyMessage:
                                'Las citas canceladas aparecerán en esta pestaña.',
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  List<_HistoryAppointment> _historyAppointments(
    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
  ) {
    final now = DateTime.now();
    final items = <_HistoryAppointment>[];

    for (final doc in snapshot.data?.docs ?? []) {
      final appointment = AppointmentModel.fromFirestore(doc.data(), doc.id);
      final status = _statusOf(appointment, now);
      if (status == null) continue;
      items.add(_HistoryAppointment(appointment: appointment, status: status));
    }

    items.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    return items;
  }

  _HistoryStatus? _statusOf(AppointmentModel appointment, DateTime now) {
    final status = appointment.status.trim().toLowerCase();
    if (status == 'cancelled' ||
        status == 'canceled' ||
        status == 'cancelada') {
      return _HistoryStatus.cancelled;
    }
    if (status == 'completed' ||
        status == 'complete' ||
        status == 'finalizada') {
      return _HistoryStatus.done;
    }

    final dateTime = _parseDateTime(appointment);
    if (dateTime != null &&
        dateTime.isBefore(now.subtract(const Duration(hours: 1)))) {
      return _HistoryStatus.done;
    }

    return null;
  }
}

class _HistoryTabs extends StatelessWidget {
  const _HistoryTabs({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TabBar(
        controller: controller,
        indicator: BoxDecoration(
          color: _AppointmentHistoryScreenState._primary,
          borderRadius: BorderRadius.circular(11),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: _AppointmentHistoryScreenState._textSub,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        tabs: const [
          Tab(text: 'Todas'),
          Tab(text: 'Finalizadas'),
          Tab(text: 'Canceladas'),
        ],
      ),
    );
  }
}

class _CacheBanner extends StatelessWidget {
  const _CacheBanner({required this.fromCache});

  final bool fromCache;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: fromCache
          ? Container(
              key: const ValueKey('cache-banner'),
              margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.cloud_off_rounded,
                    color: Color(0xFFD97706),
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Mostrando datos guardados en caché offline.',
                      style: TextStyle(
                        color: Color(0xFF92400E),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(key: ValueKey('no-cache-banner')),
    );
  }
}

class _HistoryLoading extends StatelessWidget {
  const _HistoryLoading();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: 4,
      separatorBuilder: (context, index) => const SizedBox(height: 14),
      itemBuilder: (context, index) => Container(
        height: 128,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            color: _AppointmentHistoryScreenState._primary,
          ),
        ),
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({
    required this.items,
    required this.isPsychologist,
    required this.emptyTitle,
    required this.emptyMessage,
  });

  final List<_HistoryAppointment> items;
  final bool isPsychologist;
  final String emptyTitle;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _EmptyState(
        icon: Icons.history_rounded,
        title: emptyTitle,
        message: emptyMessage,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        return _HistoryCard(item: items[index], isPsychologist: isPsychologist);
      },
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.item, required this.isPsychologist});

  final _HistoryAppointment item;
  final bool isPsychologist;

  @override
  Widget build(BuildContext context) {
    final appointment = item.appointment;
    final personName = isPsychologist
        ? appointment.patientName
        : appointment.psychologistName;
    final personLabel = isPsychologist ? 'Paciente' : 'Psicólogo';
    final statusColor = item.historyStatus == _HistoryStatus.cancelled
        ? _AppointmentHistoryScreenState._danger
        : _AppointmentHistoryScreenState._success;
    final statusLabel = item.historyStatus == _HistoryStatus.cancelled
        ? 'Cancelada'
        : 'Finalizada';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AppointmentDetailScreen(
              appointmentData: appointment.toDisplayMap(),
              isPast: true,
            ),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      item.historyStatus == _HistoryStatus.cancelled
                          ? Icons.event_busy_rounded
                          : Icons.check_circle_rounded,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          personName.isEmpty ? personLabel : personName,
                          style: const TextStyle(
                            color: _AppointmentHistoryScreenState._textMain,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          personLabel,
                          style: const TextStyle(
                            color: _AppointmentHistoryScreenState._textSub,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(height: 1, color: Color(0xFFEEF2F6)),
              ),
              Wrap(
                spacing: 14,
                runSpacing: 10,
                children: [
                  _InfoChip(
                    icon: Icons.calendar_month_rounded,
                    text: item.formattedDate,
                  ),
                  _InfoChip(
                    icon: Icons.access_time_rounded,
                    text: item.timeRange,
                  ),
                  _InfoChip(
                    icon: Icons.video_call_rounded,
                    text: appointment.meetingUrl?.isNotEmpty == true
                        ? 'Con enlace'
                        : 'Sin enlace',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: _AppointmentHistoryScreenState._textSub, size: 16),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: _AppointmentHistoryScreenState._textMain,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Icon(
                icon,
                color: _AppointmentHistoryScreenState._primary,
                size: 38,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _AppointmentHistoryScreenState._textMain,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _AppointmentHistoryScreenState._textSub,
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryAppointment {
  const _HistoryAppointment({required this.appointment, required this.status});

  final AppointmentModel appointment;
  final _HistoryStatus status;

  _HistoryStatus get historyStatus => status;

  DateTime get dateTime => _parseDateTime(appointment) ?? appointment.createdAt;

  String get formattedDate {
    final parsed = DateTime.tryParse(appointment.date);
    if (parsed == null) {
      return appointment.date.isEmpty ? 'Sin fecha' : appointment.date;
    }
    return DateFormat('dd/MM/yyyy').format(parsed);
  }

  String get timeRange {
    if (appointment.endTime.isEmpty) return appointment.startTime;
    return '${appointment.startTime} - ${appointment.endTime}';
  }
}

enum _HistoryStatus { done, cancelled }

DateTime? _parseDateTime(AppointmentModel appointment) {
  return DateTime.tryParse('${appointment.date} ${appointment.startTime}:00');
}

extension on AppointmentModel {
  Map<String, dynamic> toDisplayMap() {
    return {
      'id': id,
      'psychologistId': psychologistId,
      'psychologistName': psychologistName,
      'patientId': patientId,
      'patientName': patientName,
      'slotId': slotId,
      'date': date,
      'startTime': startTime,
      'endTime': endTime,
      'status': status,
      'meetingUrl': meetingUrl,
    };
  }
}
