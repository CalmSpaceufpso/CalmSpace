import 'package:cloud_firestore/cloud_firestore.dart';

class AppointmentModel {
  final String id;
  final String psychologistId;
  final String psychologistName;
  final String patientId;
  final String slotId;
  final String date;
  final String startTime;
  final String endTime;
  final String status;
  final DateTime createdAt;
  final String? meetingUrl;

  AppointmentModel({
    required this.id,
    required this.psychologistId,
    required this.psychologistName,
    required this.patientId,
    required this.slotId,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.createdAt,
    this.meetingUrl,
  });

  factory AppointmentModel.fromFirestore(Map<String, dynamic> data, String id) {
    return AppointmentModel(
      id: id,
      psychologistId: data['psychologistId'] ?? '',
      psychologistName: data['psychologistName'] ?? '',
      patientId: data['patientId'] ?? '',
      slotId: data['slotId'] ?? '',
      date: data['date'] ?? '',
      startTime: data['startTime'] ?? '',
      endTime: data['endTime'] ?? '',
      status: data['status'] ?? 'scheduled',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      meetingUrl: data['meetingUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'psychologistId': psychologistId,
      'psychologistName': psychologistName,
      'patientId': patientId,
      'slotId': slotId,
      'date': date,
      'startTime': startTime,
      'endTime': endTime,
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
      'meetingUrl': meetingUrl,
    };
  }
}
