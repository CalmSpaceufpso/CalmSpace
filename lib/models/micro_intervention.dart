import 'package:cloud_firestore/cloud_firestore.dart';

class MicroIntervention {
  final String id;
  final String category;
  final String text;

  MicroIntervention({
    required this.id,
    required this.category,
    required this.text,
  });

  factory MicroIntervention.fromMap(Map<String, dynamic> data, String id) {
    return MicroIntervention(
      id: id,
      category: data['category'] ?? 'General',
      text: data['text'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'category': category,
      'text': text,
    };
  }
}
