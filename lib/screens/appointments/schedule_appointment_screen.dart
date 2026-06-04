import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/psychologist_model.dart';
import '../../models/appointment_model.dart';
import '../../repositories/appointment_repository.dart';
import '../availability/manage_availability_screen.dart' show ScheduleSlot;

class ScheduleAppointmentScreen extends StatefulWidget {
  final PsychologistModel psychologist;
  final String? appointmentIdToReschedule;

  const ScheduleAppointmentScreen({
    super.key, 
    required this.psychologist,
    this.appointmentIdToReschedule,
  });

  @override
  State<ScheduleAppointmentScreen> createState() => _ScheduleAppointmentScreenState();
}

class _ScheduleAppointmentScreenState extends State<ScheduleAppointmentScreen> {
  static const Color _primary = Color(0xFF1D35B4);
  static const Color _bg = Color(0xFFF4F6FB);
  static const Color _textMain = Color(0xFF1E293B);

  final AppointmentRepository _repo = AppointmentRepository();
  
  List<ScheduleSlot> _allSlots = [];
  Set<String> _occupiedSlots = {};
  
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1)); // start tomorrow
  ScheduleSlot? _selectedSlot;
  bool _loading = true;
  bool _saving = false;

  late List<DateTime> _availableDates;

  @override
  void initState() {
    super.initState();
    _generateDates();
    _loadData();
  }

  void _generateDates() {
    final now = DateTime.now();
    _availableDates = List.generate(30, (i) => now.add(Duration(days: i + 1)))
        .where((d) => d.weekday != DateTime.sunday) // Exclude sundays if needed
        .toList();
    if (_availableDates.isNotEmpty) {
      _selectedDate = _availableDates.first;
    }
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    _allSlots = await _repo.getPsychologistSlots(widget.psychologist.id);
    await _loadOccupiedSlots();
  }

  Future<void> _loadOccupiedSlots() async {
    setState(() => _loading = true);
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    _occupiedSlots = await _repo.getOccupiedSlots(widget.psychologist.id, dateStr);
    _selectedSlot = null; // reset selection
    setState(() => _loading = false);
  }

  String _getWeekdayName(int weekday) {
    switch (weekday) {
      case 1: return 'Lunes';
      case 2: return 'Martes';
      case 3: return 'Miercoles';
      case 4: return 'Jueves';
      case 5: return 'Viernes';
      case 6: return 'Sabado';
      case 7: return 'Domingo';
      default: return '';
    }
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
    _loadOccupiedSlots();
  }

  Future<void> _confirmAppointment() async {
    if (_selectedSlot == null) return;
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión para agendar')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      // Get patient name
      String patientName = 'Paciente';
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        patientName = userDoc.data()?['name'] ?? 'Paciente';
      }

      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final appointment = AppointmentModel(
        id: '', // Firestore will auto-generate
        psychologistId: widget.psychologist.id,
        psychologistName: widget.psychologist.name,
        patientId: user.uid,
        patientName: patientName,
        slotId: _selectedSlot!.id,
        date: dateStr,
        startTime: _selectedSlot!.startTime,
        endTime: _selectedSlot!.endTime,
        status: 'scheduled',
        createdAt: DateTime.now(),
        meetingUrl: 'https://meet.google.com/xyz-demo-abc', // Dummy data
      );

      if (widget.appointmentIdToReschedule != null) {
        await _repo.rescheduleAppointment(
          widget.appointmentIdToReschedule!,
          dateStr,
          _selectedSlot!.startTime,
          _selectedSlot!.endTime,
          _selectedSlot!.id,
        );
      } else {
        await _repo.createAppointment(appointment);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.appointmentIdToReschedule != null
                ? '¡Cita reprogramada con éxito para el ${DateFormat('dd/MM/yyyy').format(_selectedDate)} a las ${_selectedSlot!.startTime}!'
                : '¡Cita agendada con éxito para el ${DateFormat('dd/MM/yyyy').format(_selectedDate)} a las ${_selectedSlot!.startTime}!'
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // Go back to detail
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al agendar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dayName = _getWeekdayName(_selectedDate.weekday);
    final daySlots = _allSlots.where((s) => s.day.toLowerCase() == dayName.toLowerCase()).toList();
    daySlots.sort((a, b) => a.startTime.compareTo(b.startTime));

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: Text(widget.appointmentIdToReschedule != null ? 'Reprogramar Cita' : 'Agendar Cita', style: const TextStyle(color: _textMain, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: _textMain),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header summary
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: _primary.withOpacity(0.1),
                  backgroundImage: widget.psychologist.photoUrl != null 
                    ? NetworkImage(widget.psychologist.photoUrl!) 
                    : null,
                  child: widget.psychologist.photoUrl == null
                    ? Text(widget.psychologist.name[0], style: const TextStyle(color: _primary, fontWeight: FontWeight.bold))
                    : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.psychologist.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textMain)),
                      Text(widget.psychologist.specialty, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                    ],
                  ),
                ),
                if (widget.psychologist.pricePerSession != null)
                  Text('\$${widget.psychologist.pricePerSession!.toInt()}', 
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _primary)),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Date selector
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text('Selecciona una fecha', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textMain)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 90,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _availableDates.length,
              itemBuilder: (context, index) {
                final date = _availableDates[index];
                final isSelected = date.day == _selectedDate.day && date.month == _selectedDate.month;
                
                return GestureDetector(
                  onTap: () => _onDateSelected(date),
                  child: Container(
                    width: 65,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? _primary : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isSelected ? _primary : Colors.grey.shade300),
                      boxShadow: isSelected ? [BoxShadow(color: _primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(DateFormat('MMM').format(date).toUpperCase(), 
                          style: TextStyle(fontSize: 12, color: isSelected ? Colors.white70 : Colors.grey)),
                        const SizedBox(height: 4),
                        Text('${date.day}', 
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : _textMain)),
                        const SizedBox(height: 4),
                        Text(_getWeekdayName(date.weekday).substring(0, 3), 
                          style: TextStyle(fontSize: 12, color: isSelected ? Colors.white70 : Colors.grey)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // Time selector
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text('Selecciona una hora', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textMain)),
          ),
          const SizedBox(height: 12),
          
          Expanded(
            child: _loading 
              ? const Center(child: CircularProgressIndicator(color: _primary))
              : daySlots.isEmpty
                ? const Center(
                    child: Text('El psicólogo no tiene horarios este día.', style: TextStyle(color: Colors.grey)),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 2.5,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: daySlots.length,
                    itemBuilder: (context, index) {
                      final slot = daySlots[index];
                      final isOccupied = _occupiedSlots.contains(slot.id);
                      final isSelected = _selectedSlot?.id == slot.id;

                      return InkWell(
                        onTap: isOccupied ? null : () {
                          setState(() {
                            _selectedSlot = slot;
                          });
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isOccupied ? Colors.grey.shade200 : isSelected ? _primary : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isOccupied ? Colors.grey.shade300 : isSelected ? _primary : _primary.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            slot.startTime,
                            style: TextStyle(
                              color: isOccupied ? Colors.grey.shade400 : isSelected ? Colors.white : _primary,
                              fontWeight: FontWeight.bold,
                              decoration: isOccupied ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          
          // Bottom button
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: (_selectedSlot == null || _saving) ? null : _confirmAppointment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    disabledBackgroundColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _saving 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(widget.appointmentIdToReschedule != null ? 'Reprogramar Cita' : 'Confirmar Cita', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
