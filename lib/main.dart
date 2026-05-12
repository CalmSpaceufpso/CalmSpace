import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';

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
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1D35B4)),
        useMaterial3: true,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Cargando
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Color(0xFFF4F6FB),
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFF1D35B4)),
              ),
            );
          }

          // Sin sesión → Login
          if (!snapshot.hasData) return const LoginScreen();

          // Con sesión → verificar rol en Firestore
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
                    child: CircularProgressIndicator(color: Color(0xFF1D35B4)),
                  ),
                );
              }

              if (userSnap.hasData && userSnap.data!.exists) {
                final data   = userSnap.data!.data() as Map<String, dynamic>;
                final role   = data['role']   ?? 'Paciente';
                final status = data['status'] ?? 'activo';

                // Psicólogo pendiente → pantalla de espera
                if (role == 'Psicólogo' &&
                    (status == 'pendiente' || status == 'rechazado')) {
                  return _PendingScreen();
                }
              }

              return HomeScreen();
            },
          );
        },
      ),
      routes: {
        '/login':    (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home':     (context) => HomeScreen(),
      },
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
    );
  }
}