import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'providers/psychologist_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile/view_profile_screen.dart';
import 'screens/availability/manage_availability_screen.dart';
import 'screens/psychologists/psychologist_catalog_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  bool firestoreReady = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firestoreReady = true;
  } catch (_) {}

  // Inicializar servicio de notificaciones locales
  await NotificationService.instance.initialize();
  runApp(CalmSpaceApp(firestoreReady: firestoreReady));
}

class CalmSpaceApp extends StatelessWidget {
  final bool firestoreReady;
  const CalmSpaceApp({super.key, required this.firestoreReady});

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
          '/login':       (context) => const LoginScreen(),
          '/register':    (context) => const RegisterScreen(),
          '/psicologos':  (context) => const PsychologistCatalogScreen(),
          '/disponibilidad': (context) => ManageAvailabilityScreen(
                firestoreReady: firestoreReady),
          '/perfil': (context) {
            final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
            return ViewProfileScreen(uid: uid, isOwnProfile: true);
          },
        },
        home: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: Color(0xFFF4F6FB),
                body: Center(
                  child: CircularProgressIndicator(color: Color(0xFF1D35B4)),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data == null) {
              return const LoginScreen();
            }

            final uid = snapshot.data!.uid;

            return FutureBuilder<DocumentSnapshot>(
              // La key evita que se re-ejecute la consulta en cada rebuild
              key: ValueKey('user_doc_$uid'),
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
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

                // Si Firestore falla, ir al Home igual (no bloquear el login)
                if (userSnap.hasError) {
                  return HomeScreen(firestoreReady: firestoreReady);
                }

                if (userSnap.hasData && userSnap.data!.exists) {
                  final data   = userSnap.data!.data() as Map<String, dynamic>;
                  final role   = data['role']   ?? 'Paciente';
                  final status = data['status'] ?? 'activo';

                  if (status == 'baneado') {
                    return _BannedScreen();
                  }

                  if (role == 'Psicólogo' &&
                      (status == 'pendiente' || status == 'rechazado')) {
                    return _PendingScreen(status: status);
                  }
                }

                return HomeScreen(firestoreReady: firestoreReady);
              },
            );
          },
        ),
      ),
    );
  }
}

// ── PENDING / REJECTED SCREEN ──────────────────────────────────────────────
class _PendingScreen extends StatelessWidget {
  final dynamic status;

  const _PendingScreen({this.status});

  @override
  Widget build(BuildContext context) {
    final isRejected = status == 'rechazado';
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isRejected ? Icons.cancel_rounded : Icons.hourglass_top_rounded,
                  size: 64, color: isRejected ? const Color(0xFFE11D48) : const Color(0xFF1D35B4)),
              const SizedBox(height: 20),
              Text(isRejected ? 'Solicitud Rechazada' : 'Cuenta en revisión',
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B))),
              const SizedBox(height: 10),
              Text(
                isRejected 
                  ? 'Tu solicitud para ser psicólogo en CalmSpace no fue aprobada por los administradores.' 
                  : 'Tu cuenta de psicólogo está siendo verificada.\nTe notificaremos cuando sea aprobada.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
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

// ── BANNED SCREEN ──────────────────────────────────────────────────────────
class _BannedScreen extends StatelessWidget {
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
              const Icon(Icons.block_rounded, size: 64, color: Color(0xFFE11D48)),
              const SizedBox(height: 20),
              const Text('Cuenta suspendida',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B))),
              const SizedBox(height: 10),
              const Text(
                'Tu cuenta ha sido suspendida permanentemente por incumplir los términos de servicio de la plataforma.',
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