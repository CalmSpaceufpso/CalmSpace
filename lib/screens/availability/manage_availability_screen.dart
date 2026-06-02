import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// ── DATA MODELS ──────────────────────────────────────────────────────────────

class ScheduleSlot {
  const ScheduleSlot({
    required this.id,
    required this.day,
    required this.startTime,
    required this.endTime,
  });

  final String id;
  final String day;
  final String startTime;
  final String endTime;

  String get label => '$startTime - $endTime';

  Map<String, dynamic> toMap() {
    return {'id': id, 'day': day, 'startTime': startTime, 'endTime': endTime};
  }
}

// ── REPOSITORY ───────────────────────────────────────────────────────────────

class AvailabilityRepository {
  AvailabilityRepository({
    required String psychologistId,
    FirebaseFirestore? firestore,
  })  : _psychologistId = psychologistId,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final String _psychologistId;
  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _availabilityDoc => _firestore
      .collection('psychologists')
      .doc(_psychologistId)
      .collection('settings')
      .doc('availability');

  Stream<Set<String>> selectedSlotIds() {
    return _availabilityDoc.snapshots().map((snapshot) {
      final data = snapshot.data();
      final slots = data?['slots'];
      if (slots is! List) return <String>{};
      return slots
          .whereType<Map>()
          .map((slot) => slot['id'])
          .whereType<String>()
          .toSet();
    });
  }

  Stream<Set<String>> occupiedSlotIds() {
    return _firestore
        .collection('appointments')
        .where('psychologistId', isEqualTo: _psychologistId)
        .where('status', whereIn: ['scheduled', 'confirmed'])
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => doc.data()['slotId'])
              .whereType<String>()
              .toSet();
        });
  }

  Future<void> saveAvailability(List<ScheduleSlot> slots) {
    return _availabilityDoc.set({
      'psychologistId': _psychologistId,
      'slots': slots.map((slot) => slot.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

// ── SCREEN ───────────────────────────────────────────────────────────────────

class ManageAvailabilityScreen extends StatefulWidget {
  const ManageAvailabilityScreen({
    super.key,
    required this.firestoreReady,
    this.psychologistId = 'psicologo-demo',
  });

  static const routeName = '/availability';

  final bool firestoreReady;
  final String psychologistId;

  @override
  State<ManageAvailabilityScreen> createState() =>
      _ManageAvailabilityScreenState();
}

class _ManageAvailabilityScreenState extends State<ManageAvailabilityScreen> {
  // ── THEME CONSTANTS ───────────────────────────────────────────────────────
  static const Color _primary   = Color(0xFF2B5BFF);
  static const Color _bg        = Color(0xFFF4F6FB);
  static const Color _textMain  = Color(0xFF0D1B3E);
  static const Color _textSub   = Color(0xFF8A94A6);
  static const Color _occupied  = Color(0xFFFF6B35);
  static const Color _selected  = Color(0xFF2B5BFF);
  static const Color _success   = Color(0xFF10B981);

  // ── STATE ─────────────────────────────────────────────────────────────────
  AvailabilityRepository? _repository;
  final Set<String> _selectedSlotIds = {};
  final Set<String> _occupiedSlotIds = {};
  StreamSubscription<Set<String>>? _selectedSub;
  StreamSubscription<Set<String>>? _occupiedSub;

  bool _loadedSavedSlots = false;
  bool _isSaving = false;
  String? _errorMessage;

  // ── DATA ──────────────────────────────────────────────────────────────────
  static const _days = [
    'Lunes', 'Martes', 'Miercoles', 'Jueves', 'Viernes', 'Sabado',
  ];

  static const _dayLabels = {
    'Lunes': 'Lun', 'Martes': 'Mar', 'Miercoles': 'Mié',
    'Jueves': 'Jue', 'Viernes': 'Vie', 'Sabado': 'Sáb',
  };

  static const _timeRanges = [
    ('08:00', '09:00'), ('09:00', '10:00'),
    ('10:00', '11:00'), ('11:00', '12:00'),
    ('14:00', '15:00'), ('15:00', '16:00'),
    ('16:00', '17:00'), ('17:00', '18:00'),
  ];

  late final List<ScheduleSlot> _slots = [
    for (final day in _days)
      for (final r in _timeRanges)
        ScheduleSlot(
          id: '${day.toLowerCase()}-${r.$1}',
          day: day,
          startTime: r.$1,
          endTime: r.$2,
        ),
  ];

  // ── LIFECYCLE ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    if (widget.firestoreReady) {
      _repository = AvailabilityRepository(
        psychologistId: widget.psychologistId,
      );
    }
    _listenToFirestore();
  }

  void _listenToFirestore() {
    if (!widget.firestoreReady || _repository == null) return;

    _selectedSub = _repository!.selectedSlotIds().listen((ids) {
      if (!mounted || _loadedSavedSlots) return;
      setState(() {
        _selectedSlotIds..clear()..addAll(ids);
        _loadedSavedSlots = true;
      });
    });

    _occupiedSub = _repository!.occupiedSlotIds().listen((ids) {
      if (!mounted) return;
      setState(() {
        _occupiedSlotIds..clear()..addAll(ids);
        _selectedSlotIds.removeAll(ids);
      });
    });
  }

  @override
  void dispose() {
    _selectedSub?.cancel();
    _occupiedSub?.cancel();
    super.dispose();
  }

  // ── ACTIONS ───────────────────────────────────────────────────────────────
  void _toggleSlot(ScheduleSlot slot) {
    if (_occupiedSlotIds.contains(slot.id)) return;
    setState(() {
      _errorMessage = null;
      if (_selectedSlotIds.contains(slot.id)) {
        _selectedSlotIds.remove(slot.id);
      } else {
        _selectedSlotIds.add(slot.id);
      }
    });
  }

  void _toggleDay(String day) {
    final daySlots = _slots
        .where((s) => s.day == day && !_occupiedSlotIds.contains(s.id))
        .toList();
    final allSelected = daySlots.every((s) => _selectedSlotIds.contains(s.id));
    setState(() {
      _errorMessage = null;
      if (allSelected) {
        for (final s in daySlots) _selectedSlotIds.remove(s.id);
      } else {
        for (final s in daySlots) _selectedSlotIds.add(s.id);
      }
    });
  }

  Future<void> _save() async {
    final selectedSlots = _slots
        .where((s) =>
            _selectedSlotIds.contains(s.id) &&
            !_occupiedSlotIds.contains(s.id))
        .toList();

    if (selectedSlots.isEmpty) {
      setState(() => _errorMessage = 'Selecciona al menos un horario disponible.');
      return;
    }

    if (!widget.firestoreReady || _repository == null) {
      setState(() => _errorMessage = 'Firebase no está configurado.');
      return;
    }

    setState(() { _isSaving = true; _errorMessage = null; });

    try {
      await _repository!.saveAvailability(selectedSlots);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text('${selectedSlots.length} horarios guardados correctamente'),
          ]),
          backgroundColor: _success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'No se pudieron guardar. Inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final totalSelected = _selectedSlotIds.length;
    final totalOccupied = _occupiedSlotIds.length;
    final totalHours = totalSelected; // cada slot = 1 hora

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
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)],
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 16, color: _textMain),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: const Text(
          'Mi Disponibilidad',
          style: TextStyle(
            color: _textMain,
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
        children: [

          // ── HEADER CARD CON GRADIENTE ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2B5BFF), Color(0xFF5E81FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: _primary.withOpacity(0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.schedule_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Configuración semanal',
                        style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
                      SizedBox(height: 2),
                      Text('Selecciona tus horarios disponibles',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 20),
                Row(children: [
                  _StatBubble(
                    icon: Icons.access_time_rounded,
                    value: '$totalHours h',
                    label: 'Disponibles',
                    color: Colors.white,
                  ),
                  const SizedBox(width: 12),
                  _StatBubble(
                    icon: Icons.event_busy_rounded,
                    value: '$totalOccupied',
                    label: 'Con cita',
                    color: const Color(0xFFFFD580),
                  ),
                  const SizedBox(width: 12),
                  _StatBubble(
                    icon: Icons.calendar_month_rounded,
                    value: '${_days.length}',
                    label: 'Días',
                    color: const Color(0xFF90EFD4),
                  ),
                ]),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── LEYENDA ────────────────────────────────────────────────────────
          Row(children: [
            _LegendItem(color: _selected, label: 'Disponible'),
            const SizedBox(width: 16),
            _LegendItem(color: _bg, label: 'Sin marcar', bordered: true),
            const SizedBox(width: 16),
            _LegendItem(color: _occupied.withOpacity(0.15), label: 'Con cita', iconColor: _occupied),
          ]),

          const SizedBox(height: 8),

          // ── ERROR ──────────────────────────────────────────────────────────
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F0),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red.shade400, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(_errorMessage!,
                  style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600, fontSize: 13))),
              ]),
            ),
            const SizedBox(height: 8),
          ],

          // ── DÍA POR DÍA ───────────────────────────────────────────────────
          for (final day in _days) ...[
            const SizedBox(height: 16),
            _DaySection(
              day: day,
              dayLabel: _dayLabels[day] ?? day,
              slots: _slots.where((s) => s.day == day).toList(),
              selectedSlotIds: _selectedSlotIds,
              occupiedSlotIds: _occupiedSlotIds,
              onSlotTap: _toggleSlot,
              onToggleAll: () => _toggleDay(day),
              primaryColor: _primary,
              occupiedColor: _occupied,
              textMain: _textMain,
              textSub: _textSub,
            ),
          ],
        ],
      ),

      // ── BOTÓN GUARDAR ────────────────────────────────────────────────────
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        decoration: BoxDecoration(
          color: _bg,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, -4)),
          ],
        ),
        child: GestureDetector(
          onTap: _isSaving ? null : _save,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 56,
            decoration: BoxDecoration(
              gradient: _isSaving
                  ? null
                  : const LinearGradient(
                      colors: [Color(0xFF2B5BFF), Color(0xFF5E81FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              color: _isSaving ? Colors.grey.shade300 : null,
              borderRadius: BorderRadius.circular(18),
              boxShadow: _isSaving
                  ? []
                  : [BoxShadow(color: _primary.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6))],
            ),
            child: Center(
              child: _isSaving
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.cloud_upload_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        _selectedSlotIds.isEmpty
                            ? 'Selecciona horarios primero'
                            : 'Guardar ${_selectedSlotIds.length} horario${_selectedSlotIds.length != 1 ? 's' : ''}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ── STAT BUBBLE ──────────────────────────────────────────────────────────────

class _StatBubble extends StatelessWidget {
  final IconData icon;
  final String value, label;
  final Color color;
  const _StatBubble({required this.icon, required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900)),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}

// ── LEYENDA ───────────────────────────────────────────────────────────────────

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final bool bordered;
  final Color? iconColor;
  const _LegendItem({required this.color, required this.label, this.bordered = false, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 12, height: 12,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
          border: bordered ? Border.all(color: const Color(0xFFCBD5E1)) : null,
        ),
        child: iconColor != null
            ? Icon(Icons.lock_rounded, color: iconColor, size: 8)
            : null,
      ),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF8A94A6), fontWeight: FontWeight.w500)),
    ]);
  }
}

// ── DÍA SECTION ──────────────────────────────────────────────────────────────

class _DaySection extends StatelessWidget {
  final String day, dayLabel;
  final List<ScheduleSlot> slots;
  final Set<String> selectedSlotIds, occupiedSlotIds;
  final ValueChanged<ScheduleSlot> onSlotTap;
  final VoidCallback onToggleAll;
  final Color primaryColor, occupiedColor, textMain, textSub;

  const _DaySection({
    required this.day, required this.dayLabel,
    required this.slots, required this.selectedSlotIds,
    required this.occupiedSlotIds, required this.onSlotTap,
    required this.onToggleAll, required this.primaryColor,
    required this.occupiedColor, required this.textMain, required this.textSub,
  });

  @override
  Widget build(BuildContext context) {
    final freeSlots = slots.where((s) => !occupiedSlotIds.contains(s.id)).toList();
    final selectedInDay = freeSlots.where((s) => selectedSlotIds.contains(s.id)).length;
    final allSelected = freeSlots.isNotEmpty && selectedInDay == freeSlots.length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Cabecera del día ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 12, 0),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                gradient: selectedInDay > 0
                    ? LinearGradient(colors: [primaryColor, primaryColor.withOpacity(0.7)])
                    : null,
                color: selectedInDay == 0 ? const Color(0xFFF1F5F9) : null,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  dayLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: selectedInDay > 0 ? Colors.white : const Color(0xFF8A94A6),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(day,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: textMain)),
                Text(
                  selectedInDay == 0
                      ? 'Ningún horario seleccionado'
                      : '$selectedInDay de ${freeSlots.length} horas marcadas',
                  style: TextStyle(
                    fontSize: 11,
                    color: selectedInDay > 0 ? primaryColor : textSub,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ]),
            ),
            // Botón seleccionar/deseleccionar todo el día
            GestureDetector(
              onTap: freeSlots.isEmpty ? null : onToggleAll,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: allSelected
                      ? primaryColor.withOpacity(0.1)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  allSelected ? 'Quitar todo' : 'Todo el día',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: allSelected ? primaryColor : textSub,
                  ),
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 12),

        // ── Chips de tiempo ─────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: slots.map((slot) {
              final isSelected = selectedSlotIds.contains(slot.id);
              final isOccupied = occupiedSlotIds.contains(slot.id);
              return _TimeChip(
                slot: slot,
                isSelected: isSelected,
                isOccupied: isOccupied,
                onTap: isOccupied ? null : () => onSlotTap(slot),
                primaryColor: primaryColor,
                occupiedColor: occupiedColor,
                textMain: textMain,
                textSub: textSub,
              );
            }).toList(),
          ),
        ),
      ]),
    );
  }
}

// ── TIME CHIP ─────────────────────────────────────────────────────────────────

class _TimeChip extends StatelessWidget {
  final ScheduleSlot slot;
  final bool isSelected, isOccupied;
  final VoidCallback? onTap;
  final Color primaryColor, occupiedColor, textMain, textSub;

  const _TimeChip({
    required this.slot, required this.isSelected, required this.isOccupied,
    required this.onTap, required this.primaryColor, required this.occupiedColor,
    required this.textMain, required this.textSub,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg = isOccupied
        ? occupiedColor.withOpacity(0.10)
        : isSelected
            ? primaryColor
            : Colors.white;

    final Color textColor = isOccupied
        ? occupiedColor
        : isSelected
            ? Colors.white
            : textMain;

    final Color border = isOccupied
        ? occupiedColor.withOpacity(0.3)
        : isSelected
            ? primaryColor
            : const Color(0xFFE2E8F0);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border, width: isSelected ? 1.5 : 1),
          boxShadow: isSelected
              ? [BoxShadow(color: primaryColor.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 3))]
              : [],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          // Ícono de estado
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: isOccupied
                ? Icon(Icons.lock_rounded, color: occupiedColor, size: 14, key: const ValueKey('lock'))
                : isSelected
                    ? Icon(Icons.check_rounded, color: Colors.white, size: 14, key: const ValueKey('check'))
                    : Icon(Icons.add_rounded, color: textSub, size: 14, key: const ValueKey('add')),
          ),
          const SizedBox(width: 6),
          Text(
            slot.label,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ]),
      ),
    );
  }
}
