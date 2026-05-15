import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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

class AvailabilityRepository {
  AvailabilityRepository({
    required String psychologistId,
    FirebaseFirestore? firestore,
  }) : _psychologistId = psychologistId,
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
    final now = FieldValue.serverTimestamp();

    return _availabilityDoc.set({
      'psychologistId': _psychologistId,
      'slots': slots.map((slot) => slot.toMap()).toList(),
      'updatedAt': now,
    });
  }
}

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
  AvailabilityRepository? _repository;
  final Set<String> _selectedSlotIds = {};
  final Set<String> _occupiedSlotIds = {};
  StreamSubscription<Set<String>>? _selectedSlotsSubscription;
  StreamSubscription<Set<String>>? _occupiedSlotsSubscription;

  bool _loadedSavedSlots = false;
  bool _isSaving = false;
  String? _validationMessage;

  static const _days = [
    'Lunes',
    'Martes',
    'Miercoles',
    'Jueves',
    'Viernes',
    'Sabado',
  ];

  static const _timeRanges = [
    ('08:00', '09:00'),
    ('09:00', '10:00'),
    ('10:00', '11:00'),
    ('11:00', '12:00'),
    ('14:00', '15:00'),
    ('15:00', '16:00'),
    ('16:00', '17:00'),
    ('17:00', '18:00'),
  ];

  late final List<ScheduleSlot> _slots = [
    for (final day in _days)
      for (final range in _timeRanges)
        ScheduleSlot(
          id: '${day.toLowerCase()}-${range.$1}',
          day: day,
          startTime: range.$1,
          endTime: range.$2,
        ),
  ];

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
    if (!widget.firestoreReady) return;
    final repository = _repository;
    if (repository == null) return;

    _selectedSlotsSubscription = repository.selectedSlotIds().listen((slotIds) {
      if (!mounted || _loadedSavedSlots) return;
      setState(() {
        _selectedSlotIds
          ..clear()
          ..addAll(slotIds);
        _loadedSavedSlots = true;
      });
    });

    _occupiedSlotsSubscription = repository.occupiedSlotIds().listen((slotIds) {
      if (!mounted) return;
      setState(() {
        _occupiedSlotIds
          ..clear()
          ..addAll(slotIds);
        _selectedSlotIds.removeAll(slotIds);
      });
    });
  }

  @override
  void dispose() {
    _selectedSlotsSubscription?.cancel();
    _occupiedSlotsSubscription?.cancel();
    super.dispose();
  }

  void _toggleSlot(ScheduleSlot slot) {
    if (_occupiedSlotIds.contains(slot.id)) return;

    setState(() {
      _validationMessage = null;
      if (_selectedSlotIds.contains(slot.id)) {
        _selectedSlotIds.remove(slot.id);
      } else {
        _selectedSlotIds.add(slot.id);
      }
    });
  }

  Future<void> _saveAvailability() async {
    final selectedSlots = _slots
        .where((slot) => _selectedSlotIds.contains(slot.id))
        .where((slot) => !_occupiedSlotIds.contains(slot.id))
        .toList();

    if (selectedSlots.isEmpty) {
      setState(() {
        _validationMessage =
            'Debes seleccionar al menos un horario disponible.';
      });
      return;
    }

    if (!widget.firestoreReady) {
      setState(() {
        _validationMessage =
            'Firebase no esta configurado. Agrega la configuracion para guardar en Firestore.';
      });
      return;
    }

    final repository = _repository;
    if (repository == null) return;

    setState(() {
      _isSaving = true;
      _validationMessage = null;
    });

    try {
      await repository.saveAvailability(selectedSlots);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Horarios guardados correctamente.')),
      );
    } on Object {
      if (!mounted) return;
      setState(() {
        _validationMessage =
            'No se pudieron guardar los horarios. Intentalo nuevamente.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selectedSlotIds.length;
    final occupiedCount = _occupiedSlotIds.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestionar disponibilidad'),
        centerTitle: false,
        backgroundColor: const Color(0xFFF5F7F2),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            _AvailabilitySummary(
              selectedCount: selectedCount,
              occupiedCount: occupiedCount,
              firestoreReady: widget.firestoreReady,
            ),
            const SizedBox(height: 20),
            if (_validationMessage != null) ...[
              _ValidationMessage(message: _validationMessage!),
              const SizedBox(height: 16),
            ],
            for (final day in _days) ...[
              _DayScheduleSection(
                day: day,
                slots: _slots.where((slot) => slot.day == day).toList(),
                selectedSlotIds: _selectedSlotIds,
                occupiedSlotIds: _occupiedSlotIds,
                onSlotTap: _toggleSlot,
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: FilledButton.icon(
          onPressed: _isSaving ? null : _saveAvailability,
          icon: _isSaving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(_isSaving ? 'Guardando...' : 'Guardar horarios'),
        ),
      ),
    );
  }
}

class _AvailabilitySummary extends StatelessWidget {
  const _AvailabilitySummary({
    required this.selectedCount,
    required this.occupiedCount,
    required this.firestoreReady,
  });

  final int selectedCount;
  final int occupiedCount;
  final bool firestoreReady;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDCE5DD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Disponibilidad semanal',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _MetricPill(
                icon: Icons.event_available_outlined,
                label: '$selectedCount disponibles',
                color: const Color(0xFF356859),
              ),
              const SizedBox(width: 8),
              _MetricPill(
                icon: Icons.lock_clock_outlined,
                label: '$occupiedCount ocupados',
                color: const Color(0xFF8A5A00),
              ),
            ],
          ),
          if (!firestoreReady) ...[
            const SizedBox(height: 12),
            const Text(
              'Modo local: la UI funciona, pero Firestore requiere configurar Firebase en el proyecto.',
              style: TextStyle(color: Color(0xFF7B4B00)),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ValidationMessage extends StatelessWidget {
  const _ValidationMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3DA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE4AD48)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF8A5A00)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF5B3A00),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayScheduleSection extends StatelessWidget {
  const _DayScheduleSection({
    required this.day,
    required this.slots,
    required this.selectedSlotIds,
    required this.occupiedSlotIds,
    required this.onSlotTap,
  });

  final String day;
  final List<ScheduleSlot> slots;
  final Set<String> selectedSlotIds;
  final Set<String> occupiedSlotIds;
  final ValueChanged<ScheduleSlot> onSlotTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          day,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: slots.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 2.7,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
          ),
          itemBuilder: (context, index) {
            final slot = slots[index];
            final isSelected = selectedSlotIds.contains(slot.id);
            final isOccupied = occupiedSlotIds.contains(slot.id);

            return _ScheduleSlotButton(
              slot: slot,
              isSelected: isSelected,
              isOccupied: isOccupied,
              onTap: () => onSlotTap(slot),
            );
          },
        ),
      ],
    );
  }
}

class _ScheduleSlotButton extends StatelessWidget {
  const _ScheduleSlotButton({
    required this.slot,
    required this.isSelected,
    required this.isOccupied,
    required this.onTap,
  });

  final ScheduleSlot slot;
  final bool isSelected;
  final bool isOccupied;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isOccupied
        ? const Color(0xFFEDE3CE)
        : isSelected
        ? const Color(0xFF356859)
        : Colors.white;
    final foregroundColor = isOccupied
        ? const Color(0xFF8A5A00)
        : isSelected
        ? Colors.white
        : const Color(0xFF1F342D);
    final borderColor = isSelected
        ? const Color(0xFF356859)
        : isOccupied
        ? const Color(0xFFD6B36D)
        : const Color(0xFFDCE5DD);

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: isOccupied ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Icon(
                isOccupied
                    ? Icons.lock_clock_outlined
                    : isSelected
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: foregroundColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  slot.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foregroundColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
