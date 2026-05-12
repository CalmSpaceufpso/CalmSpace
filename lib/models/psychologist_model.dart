class PsychologistModel {
  final String id;
  final String name;
  final String specialty;

  PsychologistModel({
    required this.id,
    required this.name,
    required this.specialty,
  });

  factory PsychologistModel.fromFirestore(Map<String, dynamic> data, String id) {
    return PsychologistModel(
      id: id,
      name: data['name'] ?? '',
      specialty: data['specialty'] ?? '',
    );
  }
}