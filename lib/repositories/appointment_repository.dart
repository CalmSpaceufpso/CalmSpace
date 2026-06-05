import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/appointment_model.dart';
import '../screens/availability/manage_availability_screen.dart' show ScheduleSlot;

class AppointmentRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<ScheduleSlot>> getPsychologistSlots(String psychologistId) async {
    final doc = await _firestore
        .collection('psychologists')
        .doc(psychologistId)
        .collection('settings')
        .doc('availability')
        .get();
        
    if (!doc.exists) return [];
    
    final data = doc.data();
    if (data == null || data['slots'] == null) return [];
    
    final slotsList = data['slots'] as List;
    return slotsList.map((s) => ScheduleSlot(
      id: s['id'] ?? '',
      day: s['day'] ?? '',
      startTime: s['startTime'] ?? '',
      endTime: s['endTime'] ?? '',
    )).toList();
  }

  Future<Set<String>> getOccupiedSlots(String psychologistId, String date) async {
    final query = await _firestore
        .collection('appointments')
        .where('psychologistId', isEqualTo: psychologistId)
        .where('date', isEqualTo: date)
        .where('status', whereIn: ['scheduled', 'confirmed'])
        .get();
        
    return query.docs.map((doc) => doc.data()['slotId'] as String).toSet();
  }

  Future<void> createAppointment(AppointmentModel appointment) async {
    await _firestore.collection('appointments').add(appointment.toMap());
  }
}
