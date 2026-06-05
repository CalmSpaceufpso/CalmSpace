import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime sentAt;
  final bool isPending; // true when sent without internet

  const MessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.sentAt,
    this.isPending = false,
  });

  factory MessageModel.fromFirestore(Map<String, dynamic> data, String id) {
    return MessageModel(
      id: id,
      senderId: data['senderId'] as String? ?? '',
      senderName: data['senderName'] as String? ?? '',
      text: data['text'] as String? ?? '',
      sentAt: (data['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isPending: false,
    );
  }

  Map<String, dynamic> toMap() => {
        'senderId': senderId,
        'senderName': senderName,
        'text': text,
        'sentAt': FieldValue.serverTimestamp(),
      };

  /// Creates a local optimistic copy while the message is being uploaded.
  MessageModel copyAsPending() => MessageModel(
        id: id,
        senderId: senderId,
        senderName: senderName,
        text: text,
        sentAt: sentAt,
        isPending: true,
      );
}

/// Represents a chat conversation between a patient and a psychologist,
/// identified by their shared appointment.
class ChatConversation {
  final String chatId;         // appointmentId (used as document ID)
  final String patientId;
  final String patientName;
  final String psychologistId;
  final String psychologistName;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final String appointmentDate;
  final String appointmentTime;

  const ChatConversation({
    required this.chatId,
    required this.patientId,
    required this.patientName,
    required this.psychologistId,
    required this.psychologistName,
    this.lastMessage,
    this.lastMessageAt,
    required this.appointmentDate,
    required this.appointmentTime,
  });

  factory ChatConversation.fromFirestore(Map<String, dynamic> data, String id) {
    return ChatConversation(
      chatId: id,
      patientId: data['patientId'] as String? ?? '',
      patientName: data['patientName'] as String? ?? 'Paciente',
      psychologistId: data['psychologistId'] as String? ?? '',
      psychologistName: data['psychologistName'] as String? ?? 'Psicólogo',
      lastMessage: data['lastMessage'] as String?,
      lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.toDate(),
      appointmentDate: data['date'] as String? ?? '',
      appointmentTime: data['startTime'] as String? ?? '',
    );
  }
}
