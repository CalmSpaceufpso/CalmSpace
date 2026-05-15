class PsychologistModel {
  final String id;
  final String name;
  final String specialty;
  final String? photoUrl;
  final String? modalidad;
  final double rating;
  final int reviewCount;
  final int yearsOfExperience;
  final double? pricePerSession;
  final bool isAvailable;

  const PsychologistModel({
    required this.id,
    required this.name,
    required this.specialty,
    this.photoUrl,
    this.modalidad,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.yearsOfExperience = 0,
    this.pricePerSession,
    this.isAvailable = true,
  });

  factory PsychologistModel.fromFirestore(Map<String, dynamic> data, String id) {
    return PsychologistModel(
      id: id,
      name: data['fullName'] ?? data['name'] ?? '',
      specialty: data['specialty'] ?? '',
      photoUrl: data['photoUrl'] as String?,
      modalidad: data['modality'] ?? data['modalidad'] as String?,
      rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: (data['reviewCount'] as int?) ?? 0,
      yearsOfExperience: (data['experienceYears'] as int?) ?? 0,
      pricePerSession: (data['pricePerSession'] as num?)?.toDouble(),
      isAvailable: data['isAvailable'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'specialty': specialty,
    'photoUrl': photoUrl,
    'modalidad': modalidad,
    'rating': rating,
    'reviewCount': reviewCount,
    'yearsOfExperience': yearsOfExperience,
    'pricePerSession': pricePerSession,
    'isAvailable': isAvailable,
  };
}