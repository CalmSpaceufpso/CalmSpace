import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_profile.dart';
import 'edit_profile_screen.dart';

class ViewProfileScreen extends StatefulWidget {
  final String uid;
  final bool isOwnProfile;

  const ViewProfileScreen({super.key, required this.uid, required this.isOwnProfile});

  @override
  State<ViewProfileScreen> createState() => _ViewProfileScreenState();
}

class _ViewProfileScreenState extends State<ViewProfileScreen> {
  UserProfile? _profile;
  bool _isLoading = true;

  static const Color _primary   = Color(0xFF2563EB);
  static const Color _background = Color(0xFFF0F2F5);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.uid).get();
      if (doc.exists) setState(() => _profile = UserProfile.fromMap(widget.uid, doc.data()!));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(backgroundColor: _background, body: Center(child: CircularProgressIndicator(color: _primary)));
    }
    if (_profile == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Perfil no encontrado')));
    }

    if (widget.isOwnProfile) return _OwnProfileView(profile: _profile!, onRefresh: _load);
    return _PublicPsychologistView(profile: _profile!);
  }
}

// ── VISTA PROPIA (MI PERFIL) ────────────────────────────────────────────────
class _OwnProfileView extends StatelessWidget {
  final UserProfile profile;
  final VoidCallback onRefresh;

  static const Color _primary    = Color(0xFF2563EB);
  static const Color _background = Color(0xFFF0F2F5);
  static const Color _textMain   = Color(0xFF111827);

  const _OwnProfileView({required this.profile, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final inicial = profile.fullName.isNotEmpty ? profile.fullName[0].toUpperCase() : 'U';
    final isPsi = profile.role == 'Psicólogo';
    final roleLabel = isPsi ? 'Psicólogo' : 'Paciente';
    final roleIcon  = isPsi ? Icons.psychology_outlined : Icons.self_improvement_rounded;

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('Mi Perfil',
            style: TextStyle(color: _textMain, fontWeight: FontWeight.bold, fontSize: 20)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: _textMain),
            onPressed: () async {
              final result = await Navigator.push(
                context, MaterialPageRoute(builder: (_) => const EditProfileScreen()),
              );
              if (result == true) onRefresh();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [

            // ── HEADER CON GRADIENTE ───────────────────────────
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF60A5FA)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  // Avatar con borde blanco
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: CircleAvatar(
                      radius: 52,
                      backgroundColor: const Color(0xFF1D4ED8),
                      child: Text(
                        inicial,
                        style: const TextStyle(
                          fontSize: 42, color: Colors.white, fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Nombre
                  Text(
                    profile.fullName,
                    style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Badge de rol
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(roleIcon, size: 14, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          roleLabel,
                          style: const TextStyle(
                            fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Ver datos de cuenta
                  GestureDetector(
                    onTap: () async {
                      final result = await Navigator.push(
                        context, MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                      );
                      if (result == true) onRefresh();
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Ver datos de cuenta',
                          style: TextStyle(
                            color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500,
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right, color: Colors.white, size: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── TARJETAS INFO ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _InfoCard(
                    icon: Icons.calendar_today_outlined,
                    title: 'Próxima Cita',
                    subtitle: 'Próximamente',
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEEF3FF), Color(0xFFDBEAFE)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                  ),
                  const SizedBox(width: 12),
                  _InfoCard(
                    icon: Icons.psychology_outlined,
                    title: 'Mi Psicólogo',
                    subtitle: 'Próximamente',
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF5F3FF), Color(0xFFEDE9FE)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    iconColor: const Color(0xFF7C3AED),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── ACCIONES RÁPIDAS ───────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Acciones Rápidas',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textMain),
                  ),
                  const SizedBox(height: 12),
                  _ActionRow(
                    icon: Icons.lock_outline,
                    label: 'Seguridad y Contraseña',
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Próximamente')),
                    ),
                  ),
                  _ActionRowToggle(
                    icon: Icons.notifications_none_outlined,
                    label: 'Notificaciones',
                  ),
                  _ActionRow(
                    icon: Icons.description_outlined,
                    label: 'Historial de Bienestar',
                    subtitle: 'Revisa tus registros y progreso',
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Próximamente')),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── CERRAR SESIÓN ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () async => await FirebaseAuth.instance.signOut(),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Cerrar Sesión',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primary,
                    side: const BorderSide(color: _primary, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── VISTA PÚBLICA PSICÓLOGO ──────────────────────────────────────────────────

class _PublicPsychologistView extends StatelessWidget {
  final UserProfile profile;

  static const Color _primary    = Color(0xFF2563EB);
  static const Color _background = Color(0xFFF0F2F5);
  static const Color _textMain   = Color(0xFF111827);

  const _PublicPsychologistView({required this.profile});

  @override
  Widget build(BuildContext context) {
    final inicial = profile.fullName.isNotEmpty ? profile.fullName[0].toUpperCase() : 'P';

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 16, color: _textMain),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: SizedBox(
          height: 54,
          child: ElevatedButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Próximamente: Agendar Cita')),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: const Text('Agendar Cita', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── AVATAR ────────────────────────────────────────
            Center(
              child: CircleAvatar(
                radius: 70,
                backgroundColor: _primary,
                child: Text(inicial, style: const TextStyle(fontSize: 56, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 16),

            // ── NOMBRE + ESPECIALIDAD ──────────────────────────
            Center(
              child: Column(
                children: [
                  Text(profile.fullName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _textMain)),
                  const SizedBox(height: 4),
                  Text(
                    profile.specialty ?? 'Psicólogo',
                    style: const TextStyle(fontSize: 15, color: _primary, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── BADGES ────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (profile.experienceYears != null)
                  _Badge(icon: Icons.shield_outlined, label: '${profile.experienceYears} años experiencia'),
                if (profile.experienceYears != null && profile.modality != null)
                  const SizedBox(width: 12),
                if (profile.modality != null)
                  _Badge(icon: Icons.location_on_outlined, label: 'Modalidad ${profile.modality}'),
              ],
            ),

            const SizedBox(height: 28),

            // ── SOBRE MÍ ──────────────────────────────────────
            if (profile.description != null && profile.description!.isNotEmpty) ...[
              const Text('Sobre mí', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textMain)),
              const SizedBox(height: 10),
              Text(
                profile.description!,
                style: const TextStyle(fontSize: 14, color: Color(0xFF4A4A6A), height: 1.6),
              ),
              const SizedBox(height: 28),
            ],

            // ── PRÓXIMOS HORARIOS ──────────────────────────────
            const Text('Disponibilidad',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textMain)),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.grey.shade200)),
              child: Column(children: const [
                Icon(Icons.calendar_today_outlined,
                    color: Color(0xFFCBD5E1), size: 40),
                SizedBox(height: 12),
                Text('Este psicólogo aún no ha\nconfigurado su disponibilidad',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF8A94A6), fontSize: 13)),
              ]),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}

// ── WIDGETS AUXILIARES ────────────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Gradient? gradient;
  final Color? iconColor;
  static const Color _primary = Color(0xFF2563EB);

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.gradient,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: gradient,
          color: gradient == null ? Colors.white : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? _primary, size: 22),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF9E9E9E))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  static const Color _primary = Color(0xFF2563EB);

  const _ActionRow({required this.icon, required this.label, this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: _primary, size: 22),
        title: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E))),
        subtitle: subtitle != null ? Text(subtitle!, style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))) : null,
        trailing: const Icon(Icons.chevron_right, color: Color(0xFF9E9E9E)),
      ),
    );
  }
}

class _ActionRowToggle extends StatefulWidget {
  final IconData icon;
  final String label;
  const _ActionRowToggle({required this.icon, required this.label});

  @override
  State<_ActionRowToggle> createState() => _ActionRowToggleState();
}

class _ActionRowToggleState extends State<_ActionRowToggle> {
  bool _enabled = true;
  static const Color _primary = Color(0xFF2563EB);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: ListTile(
        leading: Icon(widget.icon, color: _primary, size: 22),
        title: Text(widget.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E))),
        trailing: Switch(
          value: _enabled,
          onChanged: (v) => setState(() => _enabled = v),
          activeThumbColor: _primary,
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  static const Color _primary = Color(0xFF2563EB);

  const _Badge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: _primary),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A2E), fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
