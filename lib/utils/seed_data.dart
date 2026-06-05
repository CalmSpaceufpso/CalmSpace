import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SeedData {
  static Future<void> injectDummyPsychologists(BuildContext context) async {
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    final dummies = [
      {
        'id': 'psicologo-demo-1',
        'fullName': 'Dra. Laura Gómez',
        'specialty': 'Ansiedad y Depresión',
        'photoUrl': 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=500&q=80',
        'modalidad': 'Online',
        'rating': 4.9,
        'reviewCount': 124,
        'experienceYears': 8,
        'pricePerSession': 80000,
        'isAvailable': true,
        'role': 'Psicólogo',
        'status': 'activo',
        'email': 'laura@demo.com',
      },
      {
        'id': 'psicologo-demo-2',
        'fullName': 'Dr. Carlos Mendoza',
        'specialty': 'Terapia de Pareja',
        'photoUrl': 'https://images.unsplash.com/photo-1612349317150-e413f6a5b16d?w=500&q=80',
        'modalidad': 'Presencial y Online',
        'rating': 4.7,
        'reviewCount': 89,
        'experienceYears': 12,
        'pricePerSession': 100000,
        'isAvailable': true,
        'role': 'Psicólogo',
        'status': 'activo',
        'email': 'carlos@demo.com',
      },
      {
        'id': 'psicologo-demo-3',
        'fullName': 'Dra. Ana Torres',
        'specialty': 'Desarrollo Personal',
        'photoUrl': 'https://images.unsplash.com/photo-1559839734-2b71ea197ec2?w=500&q=80',
        'modalidad': 'Online',
        'rating': 4.8,
        'reviewCount': 45,
        'experienceYears': 5,
        'pricePerSession': 60000,
        'isAvailable': true,
        'role': 'Psicólogo',
        'status': 'activo',
        'email': 'ana@demo.com',
      }
    ];

    try {
      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inyectando datos de prueba...')),
      );

      for (var dummy in dummies) {
        final userId = dummy['id'] as String;
        final userRef = firestore.collection('users').doc(userId);

        // Remove id from dummy map before saving
        final data = Map<String, dynamic>.from(dummy);
        data.remove('id');
        data['createdAt'] = FieldValue.serverTimestamp();

        batch.set(userRef, data);

        // Define Availability Slots
        final availabilityRef = firestore
            .collection('psychologists')
            .doc(userId)
            .collection('settings')
            .doc('availability');

        final slots = [
          {'id': 'lunes-08:00', 'day': 'Lunes', 'startTime': '08:00', 'endTime': '09:00'},
          {'id': 'lunes-09:00', 'day': 'Lunes', 'startTime': '09:00', 'endTime': '10:00'},
          {'id': 'martes-14:00', 'day': 'Martes', 'startTime': '14:00', 'endTime': '15:00'},
          {'id': 'martes-15:00', 'day': 'Martes', 'startTime': '15:00', 'endTime': '16:00'},
          {'id': 'miercoles-10:00', 'day': 'Miercoles', 'startTime': '10:00', 'endTime': '11:00'},
          {'id': 'jueves-16:00', 'day': 'Jueves', 'startTime': '16:00', 'endTime': '17:00'},
        ];

        batch.set(availabilityRef, {
          'psychologistId': userId,
          'slots': slots,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Datos inyectados con éxito!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
