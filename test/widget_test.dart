import 'package:calm_space/screens/availability/manage_availability_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'HU-05 muestra gestion de horarios y valida seleccion requerida',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ManageAvailabilityScreen(firestoreReady: false),
        ),
      );

      expect(find.text('Mi Disponibilidad'), findsOneWidget);
      expect(find.text('Selecciona tus horarios disponibles'), findsOneWidget);
      expect(find.text('Lunes'), findsOneWidget);
      expect(find.text('08:00 - 09:00'), findsWidgets);

      await tester.tap(find.text('Selecciona horarios primero'));
      await tester.pump();

      expect(
        find.text('Selecciona al menos un horario disponible.'),
        findsOneWidget,
      );
    },
  );
}
