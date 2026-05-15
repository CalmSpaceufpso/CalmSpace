import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/psychologist_model.dart';

class PsychologistService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<PsychologistModel>> getPsychologists() async {
    final snapshot = await _firestore.collection('psychologists').get();

    return snapshot.docs.map((doc) {
      return PsychologistModel.fromFirestore(doc.data(), doc.id);
    }).toList();
  }
}