class UserProfile {
  final String uid;
  final String fullName;
  final String role;
  final String? photoUrl;
  // 'activo' para pacientes, 'pendiente'|'aprobado'|'rechazado' para psicólogos
  final String status;

  // Campos para Paciente
  final String? phone;
  final String? birthDate;
  final String? gender;
  final String? supportReason; // max 300

  // Campos para Psicólogo
  final String? specialty;
  final int? experienceYears;
  final String? modality; // presencial, virtual, ambas
  final String? description; // max 500
  final String? contactPhone;

  UserProfile({
    required this.uid,
    required this.fullName,
    required this.role,
    this.photoUrl,
    this.status = 'activo',
    this.phone,
    this.birthDate,
    this.gender,
    this.supportReason,
    this.specialty,
    this.experienceYears,
    this.modality,
    this.description,
    this.contactPhone,
  });

  factory UserProfile.fromMap(String uid, Map<String, dynamic> data) {
    return UserProfile(
      uid: uid,
      fullName: data['name'] ?? '',
      role: data['role'] ?? 'Paciente',
      photoUrl: data['photoUrl'],
      status: data['status'] ?? 'activo',
      phone: data['phone'],
      birthDate: data['birthDate'],
      gender: data['gender'],
      supportReason: data['supportReason'],
      specialty: data['specialty'],
      experienceYears: data['experienceYears'],
      modality: data['modality'],
      description: data['description'],
      contactPhone: data['contactPhone'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': fullName,
      'role': role,
      'status': status,
      'photoUrl': photoUrl,
      'phone': phone,
      'birthDate': birthDate,
      'gender': gender,
      'supportReason': supportReason,
      'specialty': specialty,
      'experienceYears': experienceYears,
      'modality': modality,
      'description': description,
      'contactPhone': contactPhone,
    }..removeWhere((key, value) => value == null);
  }
}
