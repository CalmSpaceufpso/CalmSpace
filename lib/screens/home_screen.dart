import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ── PALETA ───────────────────────────────────────────────────────────────────
  static const Color _primary   = Color(0xFF1D35B4);
  static const Color _bg        = Color(0xFFF4F6FB);
  static const Color _textMain  = Color(0xFF1E293B);
  static const Color _textSub   = Color(0xFF64748B);
  static const Color _cardBg    = Colors.white;

  String _nombre  = 'Usuario';
  String _inicial = 'U';
  String _role    = 'Paciente';
  bool   _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _nombre  = user.displayName ?? user.email ?? 'Usuario';
    _inicial = _nombre.isNotEmpty ? _nombre[0].toUpperCase() : 'U';

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _role    = data['role'] ?? 'Paciente';
          _nombre  = data['name'] ?? _nombre;
          _inicial = _nombre.isNotEmpty ? _nombre[0].toUpperCase() : 'U';
          _loading = false;
        });
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cerrar sesión',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('¿Estás seguro que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: _textSub)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salir',
                style: TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (ok == true) await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(child: CircularProgressIndicator(color: _primary)),
      );
    }

    final isPsi = _role == 'Psicólogo';
    final greeting = 'Hola, ${_nombre.split(' ').first} 👋';

    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          // ── HEADER ──────────────────────────────────────────────────────────
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1D35B4), Color(0xFF3B5CE6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                child: Row(
                  children: [
                    // Texto bienvenida
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(greeting,
                            style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold,
                              color: Colors.white)),
                          const SizedBox(height: 4),
                          Text(
                            isPsi ? 'Panel del psicólogo' : '¿Cómo te sientes hoy?',
                            style: const TextStyle(
                              fontSize: 13, color: Colors.white70)),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20)),
                            child: Text(_role,
                              style: const TextStyle(
                                fontSize: 11, color: Colors.white,
                                fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                    // Logout + Avatar
                    Row(
                      children: [
                        // Botón logout
                        GestureDetector(
                          onTap: _logout,
                          child: Container(
                            width: 38, height: 38,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.15)),
                            child: const Icon(
                              Icons.power_settings_new_rounded,
                              color: Colors.white70, size: 18),
                          ),
                        ),
                        // Avatar
                        Container(
                          width: 50, height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.25),
                            border: Border.all(color: Colors.white60, width: 2)),
                          child: Center(
                            child: Text(_inicial,
                              style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold,
                                color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── CONTENIDO ───────────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Tarjeta bienvenida
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _cardBg,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 12, offset: const Offset(0, 4))]),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(14)),
                          child: const Icon(Icons.spa_rounded,
                            color: _primary, size: 28),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Bienvenido a CalmSpace',
                                style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold,
                                  color: _textMain)),
                              SizedBox(height: 4),
                              Text('Tu espacio de bienestar emocional',
                                style: TextStyle(
                                  fontSize: 12, color: _textSub)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  const Text('Herramientas',
                    style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold,
                      color: _textMain)),
                  const SizedBox(height: 12),

                  // Grid de herramientas
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.2,
                    children: [
                      if (!isPsi) ...[
                        _ToolCard(icon: Icons.calendar_month_outlined,
                          label: 'Mis Citas', color: const Color(0xFF1D35B4)),
                        _ToolCard(icon: Icons.self_improvement_rounded,
                          label: 'Bienestar', color: const Color(0xFF7C3AED)),
                        _ToolCard(icon: Icons.psychology_outlined,
                          label: 'Psicólogos', color: const Color(0xFF0891B2)),
                        _ToolCard(icon: Icons.article_outlined,
                          label: 'Recursos', color: const Color(0xFF059669)),
                      ] else ...[
                        _ToolCard(icon: Icons.people_outline_rounded,
                          label: 'Mis Pacientes', color: const Color(0xFF1D35B4)),
                        _ToolCard(icon: Icons.schedule_rounded,
                          label: 'Disponibilidad', color: const Color(0xFF7C3AED)),
                        _ToolCard(icon: Icons.bar_chart_rounded,
                          label: 'Estadísticas', color: const Color(0xFF0891B2)),
                        _ToolCard(icon: Icons.settings_outlined,
                          label: 'Configuración', color: const Color(0xFF059669)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _ToolCard({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label — próximamente'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 10),
            Text(label,
              style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B))),
          ],
        ),
      ),
    );
  }
}