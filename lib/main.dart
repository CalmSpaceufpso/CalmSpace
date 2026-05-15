import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/psychologist_provider.dart';
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
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PsychologistProvider()),
      ],
      child: MaterialApp(
        title: 'CalmSpace',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primaryColor: const Color(0xFF1D35B4),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1D35B4),
          ),
          scaffoldBackgroundColor: const Color(0xFFF4F6FB),
          useMaterial3: true,
        ),
        routes: {
          '/login':    (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/pending':  (context) => const PendingApprovalScreen(),
          '/psicologos': (context) => const PsychologistCatalogScreen(),
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