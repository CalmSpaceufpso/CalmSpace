import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

feature/HU-05-gestionar-disponibilidad-horaria
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

import 'screens/auth/register_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/pending_approval_screen.dart';
import 'screens/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CalmSpace',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6BAE8E)),
        useMaterial3: true,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Cargando estado de sesión
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Color(0xFFF7F3EE),
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFF6BAE8E)),
              ),
            );
          }

          // Sin sesión → Login
          if (!snapshot.hasData) return const LoginScreen();

          // Con sesión → verificar rol y status en Firestore
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(snapshot.data!.uid)
                .get(),
            builder: (context, userSnap) {
              if (userSnap.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  backgroundColor: Color(0xFFF7F3EE),
                  body: Center(
                    child: CircularProgressIndicator(color: Color(0xFF6BAE8E)),
                  ),
                );
              }

              if (userSnap.hasData && userSnap.data!.exists) {
                final data = userSnap.data!.data() as Map<String, dynamic>;
                final role = data['role'] ?? 'Paciente';
                final status = data['status'] ?? 'activo';

                // Psicólogo pendiente de aprobación
                if (role == 'Psicólogo' && status == 'pendiente') {
                  return const PendingApprovalScreen();
                }

                // Psicólogo rechazado
                if (role == 'Psicólogo' && status == 'rechazado') {
                  return const PendingApprovalScreen();
                }
              }

              // Paciente o psicólogo aprobado → Home normal
              return HomeScreen();
            },
          );
        },
      ),
      routes: {
        '/login':    (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home':     (context) => HomeScreen(),
        '/pending':  (context) => const PendingApprovalScreen(),
 main
      },
    );
  }
}