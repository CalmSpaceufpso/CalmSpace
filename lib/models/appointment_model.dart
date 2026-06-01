import 'package:cloud_firestore/cloud_firestore.dart';

class AppointmentModel {
  final String id;
  final String psychologistId;
  final String patientId;
  final String slotId;
  final String date;
  final String startTime;
  final String endTime;
  final String status;
  final DateTime createdAt;

  AppointmentModel({
    required this.id,
    required this.psychologistId,
    required this.patientId,
    required this.slotId,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.createdAt,
  });

  factory AppointmentModel.fromFirestore(Map<String, dynamic> data, String id) {
    return AppointmentModel(
      id: id,
      psychologistId: data['psychologistId'] ?? '',
      patientId: data['patientId'] ?? '',
      slotId: data['slotId'] ?? '',
      date: data['date'] ?? '',
      startTime: data['startTime'] ?? '',
      endTime: data['endTime'] ?? '',
      status: data['status'] ?? 'scheduled',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'psychologistId': psychologistId,
      'patientId': patientId,
      'slotId': slotId,
      'date': date,
      'startTime': startTime,
      'endTime': endTime,
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
