import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_profile.dart';
import '../../screens/availability/manage_availability_screen.dart';
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
    final isAdmin = profile.role == 'Admin';
    final isPsi   = profile.role == 'Psicólogo';
    final roleLabel = isAdmin ? 'Administrador' : isPsi ? 'Psicólogo' : 'Paciente';
    final roleIcon  = isAdmin ? Icons.admin_panel_settings_rounded
        : isPsi ? Icons.psychology_outlined
        : Icons.self_improvement_rounded;
    final currentUser = FirebaseAuth.instance.currentUser;

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
                      backgroundImage: profile.photoUrl != null && profile.photoUrl!.isNotEmpty
                          ? (profile.photoUrl!.startsWith('http')
                              ? NetworkImage(profile.photoUrl!)
                              : MemoryImage(base64Decode(profile.photoUrl!.split(',').last)) as ImageProvider)
                          : null,
                      child: (profile.photoUrl == null || profile.photoUrl!.isEmpty)
                          ? Text(
                              inicial,
                              style: const TextStyle(
                                fontSize: 42, color: Colors.white, fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
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

            // ── INFO DE CUENTA ────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3)),
                  ],
                ),
                child: Column(
                  children: [
                    _AccountRow(
                      icon: Icons.badge_outlined,
                      label: 'Rol',
                      value: roleLabel,
                      iconColor: isAdmin
                          ? const Color(0xFF0891B2)
                          : isPsi
                              ? const Color(0xFF7C3AED)
                              : _primary,
                    ),
                    const Divider(height: 1, indent: 56, endIndent: 16, color: Color(0xFFF1F5F9)),
                    _AccountRow(
                      icon: Icons.email_outlined,
                      label: 'Email',
                      value: currentUser?.email ?? '—',
                    ),
                    if (profile.phone != null && profile.phone!.isNotEmpty) ...[
                      const Divider(height: 1, indent: 56, endIndent: 16, color: Color(0xFFF1F5F9)),
                      _AccountRow(
                        icon: Icons.phone_iphone_rounded,
                        label: 'Teléfono',
                        value: profile.phone!,
                      ),
                    ],
                    if (profile.status.isNotEmpty) ...[
                      const Divider(height: 1, indent: 56, endIndent: 16, color: Color(0xFFF1F5F9)),
                      _AccountRow(
                        icon: Icons.verified_user_outlined,
                        label: 'Estado',
                        value: _statusLabel(profile.status),
                        valueColor: _statusColor(profile.status),
                      ),
                    ],
                  ],
                ),
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
                  if (!isAdmin)
                    _ActionRow(
                      icon: Icons.description_outlined,
                      label: isPsi ? 'Historial de Citas' : 'Historial de Bienestar',
                      subtitle: isPsi ? 'Revisa tus citas pasadas' : 'Revisa tus registros y progreso',
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
class _PublicPsychologistView extends StatefulWidget {
  final UserProfile profile;
  const _PublicPsychologistView({required this.profile});

  @override
  State<_PublicPsychologistView> createState() => _PublicPsychologistViewState();
}

class _PublicPsychologistViewState extends State<_PublicPsychologistView> {
  static const Color _primary    = Color(0xFF2B5BFF);
  static const Color _primaryDark = Color(0xFF1A3FCC);
  static const Color _background = Color(0xFFF4F6FB);
  static const Color _textMain   = Color(0xFF0D1B3E);
  static const Color _textSub    = Color(0xFF8A94A6);

  List<ScheduleSlot> _slots = [];
  bool _loadingSlots = true;

  @override
  void initState() {
    super.initState();
    _loadSlots();
  }

  Future<void> _loadSlots() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('psychologists')
          .doc(widget.profile.uid)
          .collection('settings')
          .doc('availability')
          .get();
      if (doc.exists) {
        final raw = doc.data()!['slots'] as List? ?? [];
        final loaded = raw
            .whereType<Map>()
            .map((s) => ScheduleSlot(
                  id: s['id'] as String,
                  day: s['day'] as String,
                  startTime: s['startTime'] as String,
                  endTime: s['endTime'] as String,
                ))
            .toList();
        const dayOrder = ['Lunes','Martes','Miércoles','Miercoles','Jueves','Viernes','Sábado','Domingo'];
        loaded.sort((a, b) =>
            dayOrder.indexOf(a.day).compareTo(dayOrder.indexOf(b.day)));
        if (mounted) setState(() => _slots = loaded);
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingSlots = false);
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final inicial = profile.fullName.isNotEmpty ? profile.fullName[0].toUpperCase() : 'P';

    final Map<String, List<ScheduleSlot>> byDay = {};
    for (final s in _slots) {
      byDay.putIfAbsent(s.day, () => []).add(s);
    }

    return Scaffold(
      backgroundColor: _background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 16, color: Colors.white),
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SizedBox(
          height: 54,
          child: ElevatedButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Próximamente: Agendar Cita')),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_today_rounded, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Text('Agendar Cita',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── HERO HEADER ──────────────────────────────────────
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1A3FCC), Color(0xFF2B5BFF), Color(0xFF5E81FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      // Avatar con doble anillo
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.25),
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                              child: CircleAvatar(
                                radius: 52,
                                backgroundColor: const Color(0xFF1A3FCC),
                                backgroundImage: profile.photoUrl != null && profile.photoUrl!.isNotEmpty
                                    ? (profile.photoUrl!.startsWith('http')
                                        ? NetworkImage(profile.photoUrl!)
                                        : MemoryImage(base64Decode(profile.photoUrl!.split(',').last)) as ImageProvider)
                                    : null,
                                child: (profile.photoUrl == null || profile.photoUrl!.isEmpty)
                                    ? Text(inicial, style: const TextStyle(fontSize: 44, color: Colors.white, fontWeight: FontWeight.bold))
                                    : null,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.verified_rounded, color: Colors.white, size: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Nombre
                      Text(
                        profile.fullName.isNotEmpty ? profile.fullName : 'Psicólogo',
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      // Especialidad
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: Text(
                          profile.specialty ?? 'Psicólogo',
                          style: const TextStyle(
                              fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Stats row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (profile.experienceYears != null) ...[
                            _HeroStat(
                              value: '${profile.experienceYears}',
                              label: 'Años exp.',
                              icon: Icons.workspace_premium_rounded,
                            ),
                            const _HeroDivider(),
                          ],
                          if (profile.modality != null) ...[
                            _HeroStat(
                              value: profile.modality!.contains('Online') ? 'Online' : 'Presencial',
                              label: 'Modalidad',
                              icon: Icons.video_call_rounded,
                            ),
                          ],
                          if (profile.pricePerSession != null) ...[
                            const _HeroDivider(),
                            _HeroStat(
                              value: '\$${(profile.pricePerSession! / 1000).toStringAsFixed(0)}k',
                              label: 'Por sesión',
                              icon: Icons.attach_money_rounded,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── CUERPO ───────────────────────────────────────────
            Transform.translate(
              offset: const Offset(0, -20),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF4F6FB),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── SOBRE MÍ ───────────────────────────────────────────
                      if (profile.description != null && profile.description!.isNotEmpty) ...[
                        _SectionHeader(icon: Icons.person_outline_rounded, title: 'Sobre mí'),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Text(
                            profile.description!,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF4A5568),
                              height: 1.7,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // ── INFORMACIÓN PROFESIONAL ────────────────────────────
                      _SectionHeader(icon: Icons.badge_outlined, title: 'Información profesional'),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            if (profile.specialty != null)
                              _InfoRow(
                                icon: Icons.psychology_rounded,
                                label: 'Especialidad',
                                value: profile.specialty!,
                              ),
                            if (profile.modality != null) ...[
                              const Divider(height: 20, color: Color(0xFFF1F5F9)),
                              _InfoRow(
                                icon: Icons.videocam_outlined,
                                label: 'Modalidad',
                                value: profile.modality!,
                              ),
                            ],
                            if (profile.experienceYears != null) ...[
                              const Divider(height: 20, color: Color(0xFFF1F5F9)),
                              _InfoRow(
                                icon: Icons.workspace_premium_rounded,
                                label: 'Experiencia',
                                value: '${profile.experienceYears} años',
                              ),
                            ],
                            if (profile.pricePerSession != null) ...[
                              const Divider(height: 20, color: Color(0xFFF1F5F9)),
                              _InfoRow(
                                icon: Icons.attach_money_rounded,
                                label: 'Precio/sesión',
                                value: '\$${profile.pricePerSession!.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}',
                              ),
                            ],
                            if (profile.contactPhone != null) ...[
                              const Divider(height: 20, color: Color(0xFFF1F5F9)),
                              _InfoRow(
                                icon: Icons.phone_iphone_rounded,
                                label: 'Teléfono',
                                value: profile.contactPhone!,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── DISPONIBILIDAD ─────────────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _SectionHeader(icon: Icons.schedule_rounded, title: 'Disponibilidad'),
                          if (_loadingSlots)
                            const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: _primary),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (_loadingSlots)
                        const SizedBox(height: 80)
                      else if (_slots.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEF2FF),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.event_busy_rounded,
                                    color: _primary, size: 32),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'Sin disponibilidad configurada',
                                style: TextStyle(
                                  color: _textMain, fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Este psicólogo aún no ha publicado\nsu horario de atención.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: _textSub, fontSize: 12, height: 1.5),
                              ),
                            ],
                          ),
                        )
                      else
                        ...byDay.entries.map((entry) => Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEEF2FF),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.today_rounded,
                                        color: _primary, size: 14),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    entry.key,
                                    style: const TextStyle(
                                      color: _textMain,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: entry.value.map((slot) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEEF2FF),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: _primary.withOpacity(0.2)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.access_time_rounded, size: 14, color: _primary),
                                      const SizedBox(width: 6),
                                      Text(
                                        slot.label,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: _primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                )).toList(),
                              ),
                            ],
                          ),
                        )),

                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Hero stat widget ──────────────────────────────────────────────────────────

class _HeroStat extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  const _HeroStat({required this.value, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
        Text(label,
            style: const TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _HeroDivider extends StatelessWidget {
  const _HeroDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 36,
      width: 1,
      color: Colors.white.withOpacity(0.3),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  static const Color _primary  = Color(0xFF2B5BFF);
  static const Color _textMain = Color(0xFF0D1B3E);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: _primary, size: 16),
        ),
        const SizedBox(width: 10),
        Text(title,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: _textMain)),
      ],
    );
  }
}

// ── Info row ──────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  static const Color _primary = Color(0xFF2B5BFF);
  static const Color _textSub = Color(0xFF8A94A6);
  static const Color _textMain = Color(0xFF0D1B3E);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: _primary, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(fontSize: 11, color: _textSub, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      fontSize: 14, color: _textMain, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}



// ── WIDGETS AUXILIARES ────────────────────────────────────────────────────────

// ── Account info row ──────────────────────────────────────────────────────────

class _AccountRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;
  final Color? valueColor;
  const _AccountRow({
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
    this.valueColor,
  });

  static const Color _primary  = Color(0xFF2B5BFF);
  static const Color _textSub  = Color(0xFF8A94A6);
  static const Color _textMain = Color(0xFF0D1B3E);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (iconColor ?? _primary).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: iconColor ?? _primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: _textSub, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        fontSize: 14,
                        color: valueColor ?? _textMain,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _statusLabel(String status) => switch (status) {
      'activo'    => 'Activo',
      'aprobado'  => 'Aprobado',
      'pendiente' => 'Pendiente',
      'baneado'   => 'Baneado',
      'rechazado' => 'Rechazado',
      _           => status,
    };

Color _statusColor(String status) => switch (status) {
      'activo'    => Color(0xFF2B5BFF),
      'aprobado'  => Color(0xFF2B5BFF),
      'pendiente' => Color(0xFFF59E0B),
      'baneado'   => Color(0xFFEF4444),
      'rechazado' => Color(0xFFEF4444),
      _           => Color(0xFF8A94A6),
    };

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
