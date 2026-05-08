import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'screens/availability/manage_availability_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final firestoreReady = await _initializeFirebase();

  runApp(CalmSpaceApp(firestoreReady: firestoreReady));
}

Future<bool> _initializeFirebase() async {
  try {
    await Firebase.initializeApp();
    return true;
  } on Object {
    return false;
  }
}

class CalmSpaceApp extends StatelessWidget {
  const CalmSpaceApp({super.key, required this.firestoreReady});

  final bool firestoreReady;

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF356859);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CalmSpace',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7F2),
        useMaterial3: true,
      ),
      home: ManageAvailabilityScreen(firestoreReady: firestoreReady),
      routes: {
        ManageAvailabilityScreen.routeName: (context) =>
            ManageAvailabilityScreen(firestoreReady: firestoreReady),
      },
    );
  }
}
