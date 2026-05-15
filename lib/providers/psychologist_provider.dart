import 'package:flutter/material.dart';
import '../models/psychologist_model.dart';
import '../services/psychologist_service.dart';

class PsychologistProvider extends ChangeNotifier {
  final PsychologistService _service = PsychologistService();

  List<PsychologistModel> psychologists = [];

  bool isLoading = false;

  Future<void> loadPsychologists() async {
    isLoading = true;
    notifyListeners();

    psychologists = await _service.getPsychologists();

    isLoading = false;
    notifyListeners();
  }
}