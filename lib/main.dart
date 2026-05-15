import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/pending_approval_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/psychologists/psychologist_catalog_screen.dart';

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

                // Psicólogo pendiente o rechazado
                if (role == 'Psicólogo' &&
                    (status == 'pendiente' || status == 'rechazado')) {
                  return const PendingApprovalScreen();
                }
              }

              // Paciente o psicólogo aprobado → Home
              return const HomeScreen();
            },
          );
        },
        home: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: Color(0xFFF4F6FB),
                body: Center(
                  child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
                ),
              );
            }

            if (!snapshot.hasData) return const LoginScreen();

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(snapshot.data!.uid)
                  .get(),
              builder: (context, userSnap) {
                if (userSnap.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    backgroundColor: Color(0xFFF4F6FB),
                    body: Center(
                      child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
                    ),
                  );
                }

                if (userSnap.hasData && userSnap.data!.exists) {
                  final data   = userSnap.data!.data() as Map<String, dynamic>;
                  final role   = data['role']   ?? 'Paciente';
                  final status = data['status'] ?? 'activo';

                  if (role == 'Psicólogo' &&
                      (status == 'pendiente' || status == 'rechazado')) {
                    return const PendingApprovalScreen();
                  }
                }

                return const HomeScreen();
              },
            );
          },
        ),
      ),
    );
  }
}

// Pantalla temporal de pendiente (hasta que se haga merge con las demás ramas)
class _PendingScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.hourglass_top_rounded,
                  size: 64, color: Color(0xFF1D35B4)),
              const SizedBox(height: 20),
              const Text(
                'Cuenta en revisión',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Tu cuenta de psicólogo está siendo verificada.\nTe notificaremos cuando sea aprobada.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 32),
              OutlinedButton(
                onPressed: () => FirebaseAuth.instance.signOut(),
                child: const Text('Cerrar sesión'),
              ),
            ],
          ),
        ),
      ),
      routes: {
        '/login':    (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home':     (context) => const HomeScreen(),
        '/pending':  (context) => const PendingApprovalScreen(),
      },
    );
  }
}