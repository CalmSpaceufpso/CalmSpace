import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../profile/view_profile_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final String nombre = user?.displayName ?? user?.email ?? 'Usuario';
    final String inicial = nombre.isNotEmpty ? nombre[0].toUpperCase() : 'U';

    const Color verdeBase     = Color(0xFF6BAE8E);
    const Color verdeSuave    = Color(0xFFE8F5EE);
    const Color lavanda       = Color(0xFFB8A9D9);
    const Color lavandaSuave  = Color(0xFFF0EDF8);
    const Color beige         = Color(0xFFF7F3EE);
    const Color textoPrimario = Color(0xFF2D3A32);
    const Color textoSecund   = Color(0xFF7A8C81);

    return Scaffold(
      backgroundColor: beige,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── HEADER ──────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hola, ${nombre.split(' ').first} 👋',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textoPrimario),
                      ),
                      const SizedBox(height: 4),
                      const Text('¿Cómo te sientes hoy?', style: TextStyle(fontSize: 14, color: textoSecund)),
                    ],
                  ),
                  GestureDetector(
                    onTap: () {
                      if (user != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ViewProfileScreen(uid: user.uid, isOwnProfile: true),
                          ),
                        );
                      }
                    },
                    child: CircleAvatar(
                      radius: 26,
                      backgroundColor: verdeBase,
                      child: Text(inicial, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // ── TARJETA ESTADO ÁNIMO ─────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: verdeBase, borderRadius: BorderRadius.circular(20)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tu espacio seguro', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    const Text(
                      'Recuerda: pedir ayuda es un acto\nde valentía, no de debilidad.',
                      style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: ['😔', '😐', '🙂', '😊', '😄'].map((e) {
                        return GestureDetector(
                          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Estado registrado $e'),
                              backgroundColor: verdeBase,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(e, style: const TextStyle(fontSize: 22)),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── HERRAMIENTAS ────────────────────────────────────────
              const Text('Herramientas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textoPrimario)),
              const SizedBox(height: 14),
              Row(
                children: [
                  _ToolCard(icon: Icons.self_improvement_rounded, label: 'Respiración', sublabel: 'Ejercicios guiados', color: verdeBase, bgColor: verdeSuave),
                  const SizedBox(width: 12),
                  _ToolCard(icon: Icons.book_rounded, label: 'Diario', sublabel: 'Escribe tus pensamientos', color: lavanda, bgColor: lavandaSuave),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _ToolCard(icon: Icons.headphones_rounded, label: 'Meditación', sublabel: 'Sesiones de calma', color: const Color(0xFF9FC4B7), bgColor: const Color(0xFFEDF5F2)),
                  const SizedBox(width: 12),
                  _ToolCard(icon: Icons.bar_chart_rounded, label: 'Progreso', sublabel: 'Tu historial emocional', color: const Color(0xFFC9A87C), bgColor: const Color(0xFFF9F3EA)),
                ],
              ),

              const SizedBox(height: 28),

              // ── FRASE DEL DÍA ────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: lavandaSuave,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: lavanda.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.format_quote_rounded, color: lavanda, size: 20),
                        const SizedBox(width: 6),
                        Text('Frase del día', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: lavanda)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '"La salud mental es tan importante como la salud física. Cuídate con la misma dedicación."',
                      style: TextStyle(fontSize: 14, color: textoPrimario, height: 1.6, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // ── CERRAR SESIÓN ────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () => _logout(context),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Cerrar sesión'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: textoSecund,
                    side: BorderSide(color: textoSecund.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(fontSize: 15),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final Color bgColor;

  const _ToolCard({required this.icon, required this.label, required this.sublabel, required this.color, required this.bgColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Próximamente: $label'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 12),
              Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2D3A32))),
              const SizedBox(height: 3),
              Text(sublabel, style: const TextStyle(fontSize: 11, color: Color(0xFF7A8C81))),
            ],
          ),
        ),
      ),
    );
  }
}
