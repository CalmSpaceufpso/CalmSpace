import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';
import '../models/micro_intervention.dart';
import 'notification_service.dart';

class MicroInterventionService {
  MicroInterventionService._();
  static final MicroInterventionService instance = MicroInterventionService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Sincroniza las frases de la base de datos y las programa localmente
  Future<void> syncInterventions() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) return;

      final profile = UserProfile.fromMap(user.uid, doc.data()!);

      if (!profile.microInterventionsEnabled || profile.preferredInterventionTimes.isEmpty) {
        // Si las apagó, cancelamos todo
        await NotificationService.instance.cancelMicroInterventions();
        return;
      }

      final category = profile.supportCategory ?? 'Ansiedad'; // Por defecto

      // Buscar mensajes de esta categoría
      final snapshot = await _firestore
          .collection('micro_interventions')
          .where('category', isEqualTo: category)
          .limit(30)
          .get();

      List<String> messages = snapshot.docs
          .map((d) => MicroIntervention.fromMap(d.data(), d.id).text)
          .toList();

      // Si no hay frases en la DB, proveemos un fallback
      if (messages.isEmpty) {
        messages = [
          'Recuerda respirar profundo. Todo estará bien.',
          'Eres más fuerte de lo que crees.',
          'Un paso a la vez.',
          'Tómate un descanso, te lo mereces.',
          'Concéntrate en el momento presente.',
        ];
      }

      // Desordenar la lista para que sea aleatoria
      messages.shuffle();

      // Convertimos 'Mañana' -> '09:00', 'Tarde' -> '14:00', 'Noche' -> '20:00'
      List<String> times = [];
      for (String pref in profile.preferredInterventionTimes) {
        if (pref == 'Mañana') times.add('09:00');
        else if (pref == 'Tarde') times.add('14:00');
        else if (pref == 'Noche') times.add('20:00');
      }

      await NotificationService.instance.scheduleMicroInterventions(messages, times);

    } catch (e) {
      print('Error syncing micro-interventions: $e');
    }
  }

  /// Dispara una intervención de prueba usando la categoría del usuario
  Future<void> sendTestIntervention() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) return;

      final profile = UserProfile.fromMap(user.uid, doc.data()!);
      final category = profile.supportCategory ?? 'Ansiedad';

      final snapshot = await _firestore
          .collection('micro_interventions')
          .where('category', isEqualTo: category)
          .limit(10)
          .get();

      List<String> messages = snapshot.docs
          .map((d) => MicroIntervention.fromMap(d.data(), d.id).text)
          .toList();

      if (messages.isEmpty) {
        messages = ['Recuerda respirar profundo. Todo estará bien.'];
      }

      messages.shuffle();
      await NotificationService.instance.showTestNotification(messages.first);
    } catch (e) {
      print('Error sending test micro-intervention: $e');
    }
  }
}
