import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'profile/view_profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color _primary  = Color(0xFF2B5BFF);
  static const Color _bg       = Color(0xFFF4F6FB);

  int    _navIndex   = 0;
  int?   _moodIndex;
  bool   _moodSaved  = false;
  bool   _savingMood = false;
  String _nombre     = '';
  String _email      = '';
  String _role       = 'Paciente';
  bool   _loading    = true;

  // 🖼️ Cambia esta URL para cambiar la imagen motivacional del dashboard
  static const String _imageUrl =
      'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800&q=80';

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadTodayMood();
  }

  Future<void> _loadUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { setState(() => _loading = false); return; }
    setState(() { _nombre = user.displayName ?? ''; _email = user.email ?? ''; });
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(user.uid).get();
      if (mounted) {
        final d = doc.exists ? doc.data()! : <String, dynamic>{};
        setState(() {
          _role   = d['role']     ?? 'Paciente';
          // Firestore puede usar 'fullName' (HU-04) o 'name' (registro antiguo)
          _nombre = d['fullName'] ?? d['name'] ?? user.displayName ?? _email;
          _email  = d['email']   ?? _email;
          _loading = false;
        });
      }
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _loadTodayMood() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(uid)
          .collection('moods').doc(MoodData.todayKey()).get();
      if (doc.exists && mounted) {
        setState(() {
          _moodIndex = doc.data()!['value'] as int;
          _moodSaved = true;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveMood() async {
    if (_moodIndex == null) return;
    setState(() => _savingMood = true);
    try {
      await MoodData.save(_moodIndex!);
      if (mounted) {
        setState(() { _moodSaved = true; _savingMood = false; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            Icon(MoodData.moods[_moodIndex!].icon,
                color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text('Estado "${MoodData.moods[_moodIndex!].label}" guardado'),
          ]),
          backgroundColor: MoodData.moods[_moodIndex!].color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (_) {
      if (mounted) setState(() => _savingMood = false);
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
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Salir',
                  style: TextStyle(color: Colors.redAccent,
                      fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (ok == true) await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(backgroundColor: _bg,
          body: Center(child: CircularProgressIndicator(color: _primary)));
    }
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
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: textoPrimario,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '¿Cómo te sientes hoy?',
                        style: TextStyle(
                          fontSize: 14,
                          color: textoSecund,
                        ),
                      ),
                    ],
                  ),
                  // Avatar con inicial
                  GestureDetector(
                    onTap: () {
                      if (user != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ViewProfileScreen(
                              uid: user.uid,
                              isOwnProfile: true,
                            ),
                          ),
                        );
                      }
                    },
                    child: CircleAvatar(
                      radius: 26,
                      backgroundColor: verdeBase,
                      child: Text(
                        inicial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    ),
  );
}

// ── HOME TAB ──────────────────────────────────────────────────────────────────
class _HomeTab extends StatelessWidget {
  final String nombre, role, imageUrl;
  final int? moodIndex;
  final bool moodSaved, savingMood;
  final ValueChanged<int> onMoodTap;
  final VoidCallback onConfirmMood, onLogout;

  static const Color _primary  = Color(0xFF2B5BFF);
  static const Color _textMain = Color(0xFF0D1B3E);
  static const Color _textSub  = Color(0xFF8A94A6);

  const _HomeTab({
    required this.nombre, required this.role, required this.imageUrl,
    required this.moodIndex, required this.moodSaved, required this.savingMood,
    required this.onMoodTap, required this.onConfirmMood, required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final first = nombre.split(' ').first.isNotEmpty ? nombre.split(' ').first : 'Usuario';
    final inicial = first[0].toUpperCase();
    final moods = MoodData.moods;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // HEADER
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('¡Hola, $first!',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900,
                    color: _textMain, letterSpacing: -0.5)),
              const SizedBox(height: 2),
              Text(role == 'Psicólogo' ? 'Panel del psicólogo' : 'Que tengas un buen día',
                style: const TextStyle(fontSize: 13, color: _textSub)),
            ]),
            // Avatar — navega al tab de Perfil
            GestureDetector(
              onTap: () {
                // Muestra un snackbar indicando que el perfil es HU-04
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Perfil disponible en HU-04'),
                    behavior: SnackBarBehavior.floating,
                  ));
              },
              child: Container(width: 46, height: 46,
                decoration: const BoxDecoration(color: _primary, shape: BoxShape.circle),
                child: Center(child: Text(inicial,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                      color: Colors.white))))),
          ]),

          const SizedBox(height: 24),

          // SELECTOR DE ÁNIMO
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('¿Cómo te sientes hoy?',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _textMain)),
            // Ver historial
            GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const MoodHistoryScreen())),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20)),
                child: const Row(children: [
                  Icon(Icons.bar_chart_rounded, color: _primary, size: 14),
                  SizedBox(width: 4),
                  Text('Ver historial', style: TextStyle(
                      fontSize: 11, color: _primary, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 14),

          // Íconos de ánimo — coloridos con etiqueta
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(moods.length, (i) {
              final m = moods[i];
              final sel = moodIndex == i;
              return GestureDetector(
                onTap: () => onMoodTap(i),
                child: SizedBox(
                  width: 58,
                  child: Column(children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: 54, height: 54,
                      decoration: BoxDecoration(
                        gradient: sel ? LinearGradient(
                          colors: [m.light, m.color],
                          begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
                        color: sel ? null : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: sel ? m.color : Colors.grey.shade200, width: 2),
                        boxShadow: [BoxShadow(
                          color: sel ? m.color.withOpacity(0.45) : Colors.black.withOpacity(0.06),
                          blurRadius: sel ? 14 : 8,
                          offset: const Offset(0, 3))],
                      ),
                      child: Icon(m.icon,
                        color: sel ? Colors.white : Colors.grey.shade400,
                        size: sel ? 30 : 26),
                    ),
                    const SizedBox(height: 6),
                    Text(m.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.normal,
                        color: sel ? m.color : Colors.grey.shade400),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  ]),
                ),
              );
            }),
          ),

          const SizedBox(height: 16),

          // Botón confirmar estado — rediseñado
          if (moodIndex != null) ...[const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim,
                    child: SlideTransition(
                      position: Tween(begin: const Offset(0, 0.15), end: Offset.zero)
                          .animate(anim), child: child)),
              child: moodSaved
                  // ── ESTADO YA CONFIRMADO ──
                  ? Container(
                      key: const ValueKey('saved'),
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            MoodData.moods[moodIndex!].light.withOpacity(0.5),
                            MoodData.moods[moodIndex!].color.withOpacity(0.15)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: MoodData.moods[moodIndex!].color.withOpacity(0.4),
                            width: 1.5)),
                      child: Row(children: [
                        Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(
                            color: MoodData.moods[moodIndex!].color.withOpacity(0.15),
                            shape: BoxShape.circle),
                          child: Icon(MoodData.moods[moodIndex!].icon,
                              color: MoodData.moods[moodIndex!].color, size: 26)),
                        const SizedBox(width: 14),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Tu estado de hoy',
                              style: TextStyle(fontSize: 11, color: Color(0xFF8A94A6))),
                            const SizedBox(height: 2),
                            Text(MoodData.moods[moodIndex!].label,
                              style: TextStyle(
                                fontSize: 17, fontWeight: FontWeight.bold,
                                color: MoodData.moods[moodIndex!].color)),
                          ],
                        )),
                        Icon(Icons.check_circle_rounded,
                            color: MoodData.moods[moodIndex!].color, size: 22),
                      ]),
                    )
                  // ── BOTÓN CONFIRMAR ──
                  : GestureDetector(
                      key: const ValueKey('confirm'),
                      onTap: savingMood ? null : onConfirmMood,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              MoodData.moods[moodIndex!].color,
                              MoodData.moods[moodIndex!].color.withOpacity(0.7)],
                            begin: Alignment.topLeft, end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [BoxShadow(
                            color: MoodData.moods[moodIndex!].color.withOpacity(0.4),
                            blurRadius: 16, offset: const Offset(0, 6))]),
                        child: Row(children: [
                          Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.25),
                              shape: BoxShape.circle),
                            child: savingMood
                                ? const Padding(
                                    padding: EdgeInsets.all(13),
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2.5, color: Colors.white))
                                : Icon(MoodData.moods[moodIndex!].icon,
                                    color: Colors.white, size: 26)),
                          const SizedBox(width: 14),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                savingMood ? 'Guardando...' : 'Me siento:',
                                style: const TextStyle(fontSize: 11,
                                    color: Colors.white70)),
                              const SizedBox(height: 2),
                              Text(MoodData.moods[moodIndex!].label,
                                style: const TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                            ],
                          )),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.send_rounded,
                                color: Colors.white, size: 18)),
                        ]),
                      ),
                    ),
            ),
          ],

          const SizedBox(height: 24),

          // TARJETA MOTIVACIONAL
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06),
                  blurRadius: 16, offset: const Offset(0, 6))]),
            child: Column(children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: Image.network(imageUrl,
                  height: 160, width: double.infinity, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 160,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFB8D4F0), Color(0xFFD4E8C2)],
                        begin: Alignment.topCenter, end: Alignment.bottomCenter)),
                    child: const Icon(Icons.landscape_rounded,
                        size: 60, color: Colors.white70))),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20,16,20,20),
                child: Column(children: [
                  const Text('Hoy va a ser un gran día',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                        color: _textMain)),
                  const SizedBox(height: 16),
                  SizedBox(width: double.infinity, height: 48,
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary, elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14))),
                      child: const Text('Siguiente',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    )),
                ]),
              ),
            ]),
          ),

          const SizedBox(height: 24),

          // PSICÓLOGOS DISPONIBLES — Firestore en tiempo real
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Psicólogos Disponibles',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _textMain)),
            const Text('Ver todos',
              style: TextStyle(fontSize: 13, color: _primary, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 14),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('role', isEqualTo: 'Psicólogo')
                .where('status', isEqualTo: 'activo')
                .limit(4).snapshots(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(color: _primary)));
              }
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return Container(
                  width: double.infinity, padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Colors.white,
                      borderRadius: BorderRadius.circular(20)),
                  child: const Column(children: [
                    Icon(Icons.people_outline_rounded, size: 40,
                        color: Color(0xFFCBD5E1)),
                    SizedBox(height: 10),
                    Text('Aún no hay psicólogos disponibles',
                        style: TextStyle(fontSize: 13, color: _textSub)),
                  ]),
                );
              }
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, crossAxisSpacing: 12,
                    mainAxisSpacing: 12, childAspectRatio: 0.85),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final d = docs[i].data() as Map<String, dynamic>;
                  return _PsychCard(
                    name: d['name'] ?? 'Sin nombre',
                    specialty: d['specialty'] ?? 'Psicólogo',
                    rating: (d['rating'] as num?)?.toDouble(),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }
}

// ── TARJETA PSICÓLOGO ─────────────────────────────────────────────────────────
class _PsychCard extends StatelessWidget {
  final String name, specialty;
  final double? rating;
  static const Color _primary  = Color(0xFF2B5BFF);
  static const Color _textMain = Color(0xFF0D1B3E);
  static const Color _textSub  = Color(0xFF8A94A6);
  const _PsychCard({required this.name, required this.specialty, this.rating});

  @override
  Widget build(BuildContext context) {
    final inicial = name.isNotEmpty ? name[0].toUpperCase() : 'P';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
              blurRadius: 10, offset: const Offset(0, 3))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Stack(children: [
          Container(width: 52, height: 52,
            decoration: BoxDecoration(color: _primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14)),
            child: Center(child: Text(inicial,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                    color: _primary)))),
          Positioned(bottom: 0, right: 0,
            child: Container(width: 12, height: 12,
              decoration: BoxDecoration(color: const Color(0xFF22C55E),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2)))),
        ]),
        const SizedBox(height: 10),
        Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
            color: _textMain), maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(specialty, style: const TextStyle(fontSize: 11, color: _textSub)),
        if (rating != null) ...[
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 14),
            const SizedBox(width: 3),
            Text(rating!.toStringAsFixed(1),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                    color: _textMain)),
          ]),
        ],
        const SizedBox(height: 4),
        Row(children: [
          Container(width: 7, height: 7, decoration: const BoxDecoration(
              color: Color(0xFF22C55E), shape: BoxShape.circle)),
          const SizedBox(width: 5),
          const Text('En línea', style: TextStyle(fontSize: 11,
              color: Color(0xFF22C55E), fontWeight: FontWeight.w600)),
        ]),
      ]),
    );
  }
}



class _ComingSoon extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  static const Color _primary = Color(0xFF2B5BFF);
  static const Color _textSub = Color(0xFF8A94A6);
  const _ComingSoon(this.icon, this.title, this.subtitle);

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 64, color: _primary.withOpacity(0.3)),
      const SizedBox(height: 16),
      Text(title, style: const TextStyle(fontSize: 20,
          fontWeight: FontWeight.bold, color: _textSub)),
      const SizedBox(height: 8),
      Text(subtitle, style: const TextStyle(fontSize: 13, color: _textSub)),
    ]));
}