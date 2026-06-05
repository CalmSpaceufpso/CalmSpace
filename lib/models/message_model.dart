import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single chat message.
class MessageModel {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime sentAt;

  /// true = optimistic insert, Firestore write in progress
  final bool isPending;

  /// true = Firestore write failed (no internet / error) — stays in UI for retry
  final bool isFailed;

  const MessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.sentAt,
    this.isPending = false,
    this.isFailed = false,
  });

  factory MessageModel.fromFirestore(Map<String, dynamic> data, String id) {
    return MessageModel(
      id: id,
      senderId: data['senderId'] as String? ?? '',
      senderName: data['senderName'] as String? ?? '',
      text: data['text'] as String? ?? '',
      sentAt: (data['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'senderId': senderId,
        'senderName': senderName,
        'text': text,
        'sentAt': FieldValue.serverTimestamp(),
      };

  MessageModel copyWith({bool? isPending, bool? isFailed}) => MessageModel(
        id: id,
        senderId: senderId,
        senderName: senderName,
        text: text,
        sentAt: sentAt,
        isPending: isPending ?? this.isPending,
        isFailed: isFailed ?? this.isFailed,
      );
}

/// Represents a chat conversation preview (tied to an appointment).
class ChatConversation {
  final String chatId;
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
