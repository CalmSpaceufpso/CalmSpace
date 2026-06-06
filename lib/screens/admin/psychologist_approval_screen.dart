import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_profile.dart';

// ── HU-20: Aprobación de Psicólogos ──────────────────────────────────────────

class PsychologistApprovalScreen extends StatelessWidget {
  const PsychologistApprovalScreen({super.key});

  static const Color _primary   = Color(0xFF2B5BFF);
  static const Color _bg        = Color(0xFFF4F6FB);
  static const Color _textMain  = Color(0xFF0D1B3E);
  static const Color _textSub   = Color(0xFF8A94A6);
  static const Color _approved  = Color(0xFF2B5BFF);
  static const Color _rejected  = Color(0xFFEF4444);
  static const Color _pending   = Color(0xFFF59E0B);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: _buildAppBar(context),
        body: TabBarView(
          children: [
            _PsychologistList(statusFilter: 'pendiente'),
            _PsychologistList(statusFilter: 'activo'),
            _PsychologistList(statusFilter: 'rechazado'),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.white,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 2)),
          ],
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _textMain, size: 16),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Psicólogos',
            style: TextStyle(
                color: _textMain, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          Text(
            'Gestión y aprobación',
            style: TextStyle(color: _textSub, fontSize: 12),
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Container(
          color: Colors.white,
          child: TabBar(
            indicatorColor: _primary,
            indicatorWeight: 3,
            labelColor: _primary,
            unselectedLabelColor: _textSub,
            labelStyle: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700),
            unselectedLabelStyle: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500),
            tabs: [
              _StatusTab(label: 'Pendientes', color: _pending),
              _StatusTab(label: 'Aprobados', color: _approved),
              _StatusTab(label: 'Rechazados', color: _rejected),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusTab extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusTab({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }
}

// ── Lista filtrada por estado ─────────────────────────────────────────────────

class _PsychologistList extends StatelessWidget {
  final String statusFilter;
  const _PsychologistList({required this.statusFilter});

  static const Color _pending  = Color(0xFFF59E0B);
  static const Color _approved = Color(0xFF2B5BFF);
  static const Color _rejected = Color(0xFFEF4444);
  static const Color _bg       = Color(0xFFF4F6FB);
  static const Color _textSub  = Color(0xFF8A94A6);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'Psicólogo')
          .where('status', isEqualTo: statusFilter)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF2B5BFF)),
          );
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 48),
                const SizedBox(height: 12),
                Text('Error al cargar datos',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ]),
            ),
          );
        }

        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return _EmptyState(status: statusFilter);

        final psychologists = docs.map((doc) {
          try {
            return UserProfile.fromMap(doc.id, doc.data() as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        }).whereType<UserProfile>().toList();

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: psychologists.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _PsychologistCard(
            psychologist: psychologists[i],
            statusFilter: statusFilter,
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String status;
  const _EmptyState({required this.status});

  static const Color _textSub = Color(0xFF8A94A6);

  @override
  Widget build(BuildContext context) {
    final (icon, msg) = switch (status) {
      'pendiente' => (Icons.pending_actions_rounded,
          'No hay psicólogos pendientes\nde aprobación'),
      'activo'    => (Icons.verified_rounded,
          'Aún no hay psicólogos\naprobados'),
      _           => (Icons.cancel_outlined,
          'No hay psicólogos\nrechazados'),
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: Icon(icon, size: 48, color: _textSub),
          ),
          const SizedBox(height: 20),
          Text(
            msg,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 15,
                color: _textSub,
                fontWeight: FontWeight.w500,
                height: 1.5),
          ),
        ]),
      ),
    );
  }
}

// ── Tarjeta de psicólogo ──────────────────────────────────────────────────────

class _PsychologistCard extends StatefulWidget {
  final UserProfile psychologist;
  final String statusFilter;
  const _PsychologistCard(
      {required this.psychologist, required this.statusFilter});

  @override
  State<_PsychologistCard> createState() => _PsychologistCardState();
}

class _PsychologistCardState extends State<_PsychologistCard> {
  static const Color _primary  = Color(0xFF2B5BFF);
  static const Color _textMain = Color(0xFF0D1B3E);
  static const Color _textSub  = Color(0xFF8A94A6);
  static const Color _approved = Color(0xFF2B5BFF);
  static const Color _rejected = Color(0xFFEF4444);
  static const Color _pending  = Color(0xFFF59E0B);

  bool _acting = false;

  Future<void> _setStatus(String newStatus) async {
    final adminId = FirebaseAuth.instance.currentUser?.uid ?? '';
    setState(() => _acting = true);
    try {
      final batch = FirebaseFirestore.instance.batch();

      // 1. Actualizar estado del usuario
      batch.update(
        FirebaseFirestore.instance
            .collection('users')
            .doc(widget.psychologist.uid),
        {'status': newStatus},
      );

      // 2. Log de auditoría
      final logRef =
          FirebaseFirestore.instance.collection('admin_logs').doc();
      batch.set(logRef, {
        'adminId':      adminId,
        'targetUserId': widget.psychologist.uid,
        'actionType':   newStatus == 'activo' ? 'approve_psychologist' : 'reject_psychologist',
        'timestamp':    FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (!mounted) return;
      final label = newStatus == 'activo' ? 'aprobado' : 'rechazado';
      final name  = widget.psychologist.fullName.isNotEmpty
          ? widget.psychologist.fullName
          : 'El psicólogo';
      _snack(context,
          '✓ $name ha sido $label correctamente.',
          newStatus == 'activo' ? _approved : _rejected);
    } catch (e) {
      if (!mounted) return;
      _snack(context,
          '✗ Error al actualizar el estado. Inténtalo de nuevo.', _rejected);
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  void _snack(BuildContext context, String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(12),
      duration: const Duration(seconds: 3),
    ));
  }

  void _showConfirmDialog({
    required BuildContext context,
    required String action,
    required String newStatus,
  }) {
    final isApprove = newStatus == 'activo';
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isApprove
                  ? _approved.withOpacity(0.12)
                  : _rejected.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isApprove
                  ? Icons.verified_rounded
                  : Icons.cancel_rounded,
              color: isApprove ? _approved : _rejected,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isApprove ? 'Aprobar psicólogo' : 'Rechazar psicólogo',
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
        ]),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(
                fontSize: 14, color: Color(0xFF374151), height: 1.55),
            children: [
              TextSpan(
                  text: isApprove
                      ? '¿Confirmas la aprobación de '
                      : '¿Confirmas el rechazo de '),
              TextSpan(
                text: widget.psychologist.fullName.isNotEmpty
                    ? widget.psychologist.fullName
                    : 'este psicólogo',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(
                  text: isApprove
                      ? '? Podrá acceder a la plataforma como psicólogo.'
                      : '? No podrá acceder a la plataforma.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar',
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isApprove ? _approved : _rejected,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              isApprove ? 'Sí, aprobar' : 'Sí, rechazar',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) _setStatus(newStatus);
    });
  }

  @override
  Widget build(BuildContext context) {
    final psy   = widget.psychologist;
    final first = psy.fullName.isNotEmpty ? psy.fullName[0].toUpperCase() : '?';
    final isPending  = widget.statusFilter == 'pendiente';
    final isApproved = widget.statusFilter == 'activo';
    final isRejected = widget.statusFilter == 'rechazado';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: isRejected
            ? const Color(0xFFFFF8F8)
            : isApproved
                ? const Color(0xFFF0FDF4)
                : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isRejected
            ? Border.all(color: _rejected.withOpacity(0.3))
            : isApproved
                ? Border.all(color: _approved.withOpacity(0.3))
                : null,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Encabezado ──────────────────────────────────────────────────────
          Row(children: [
            // Avatar
            CircleAvatar(
              radius: 26,
              backgroundColor: _primary.withOpacity(0.12),
              backgroundImage: psy.photoUrl != null && psy.photoUrl!.isNotEmpty
                  ? (psy.photoUrl!.startsWith('http')
                      ? NetworkImage(psy.photoUrl!) as ImageProvider
                      : MemoryImage(
                          base64Decode(psy.photoUrl!.split(',').last)))
                  : null,
              child: (psy.photoUrl == null || psy.photoUrl!.isEmpty)
                  ? Text(first,
                      style: TextStyle(
                          color: _primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 20))
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  psy.fullName.isNotEmpty ? psy.fullName : 'Sin nombre',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: _textMain),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(children: [
                  const Icon(Icons.psychology_rounded,
                      size: 13, color: _textSub),
                  const SizedBox(width: 4),
                  Text(
                    psy.specialty?.isNotEmpty == true
                        ? psy.specialty!
                        : 'Especialidad no indicada',
                    style: const TextStyle(fontSize: 12, color: _textSub),
                  ),
                ]),
              ]),
            ),
            // Badge de estado
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _statusColor(widget.statusFilter).withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _statusLabel(widget.statusFilter),
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _statusColor(widget.statusFilter)),
              ),
            ),
          ]),

          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),

          // ── Datos ────────────────────────────────────────────────────────────
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (psy.contactPhone?.isNotEmpty == true)
              _InfoChip(
                  icon: Icons.phone_iphone_rounded,
                  label: psy.contactPhone!),
            // Guardamos el campo 'license' en el registro
            _LicenseChip(uid: psy.uid),
            if (psy.experienceYears != null)
              _InfoChip(
                  icon: Icons.workspace_premium_rounded,
                  label: '${psy.experienceYears} años de experiencia'),
            if (psy.modality?.isNotEmpty == true)
              _InfoChip(
                  icon: Icons.video_call_rounded, label: psy.modality!),
          ]),

          if (psy.description?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Text(
              psy.description!,
              style: const TextStyle(
                  fontSize: 12.5,
                  color: _textSub,
                  height: 1.5),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          // ── Acciones (solo para pendientes y rechazados) ─────────────────────
          if (isPending || isRejected) ...[
            const SizedBox(height: 14),
            _acting
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Color(0xFF2B5BFF))),
                    ),
                  )
                : Row(children: [
                    // Botón Rechazar (solo si pendiente)
                    if (isPending)
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showConfirmDialog(
                              context: context,
                              action: 'rechazar',
                              newStatus: 'rechazado'),
                          child: Container(
                            height: 42,
                            decoration: BoxDecoration(
                              color: _rejected.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: _rejected.withOpacity(0.3)),
                            ),
                            child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.close_rounded,
                                      color: _rejected, size: 18),
                                  SizedBox(width: 6),
                                  Text('Rechazar',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: _rejected)),
                                ]),
                          ),
                        ),
                      ),
                    if (isPending) const SizedBox(width: 10),
                    // Botón Aprobar
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _showConfirmDialog(
                            context: context,
                            action: 'aprobar',
                            newStatus: 'activo'),
                        child: Container(
                          height: 42,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                _approved,
                                _approved.withOpacity(0.8)
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                  color: _approved.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3))
                            ],
                          ),
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_circle_rounded,
                                    color: Colors.white, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  isRejected ? 'Aprobar igualmente' : 'Aprobar',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white),
                                ),
                              ]),
                        ),
                      ),
                    ),
                  ]),
          ],

          // ── Volver a pendiente (solo aprobados) ─────────────────────────────
          if (isApproved) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _showConfirmDialog(
                  context: context,
                  action: 'rechazar',
                  newStatus: 'rechazado'),
              child: Container(
                height: 38,
                decoration: BoxDecoration(
                  color: _rejected.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _rejected.withOpacity(0.25)),
                ),
                child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.remove_circle_outline_rounded,
                          color: _rejected, size: 16),
                      SizedBox(width: 6),
                      Text('Revocar acceso',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _rejected)),
                    ]),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  Color _statusColor(String status) => switch (status) {
        'activo'    => _approved,
        'rechazado' => _rejected,
        _           => _pending,
      };

  String _statusLabel(String status) => switch (status) {
        'activo'    => 'Aprobado',
        'rechazado' => 'Rechazado',
        _           => 'Pendiente',
      };
}

// ── Widget para la licencia (la lee de Firestore) ─────────────────────────────

class _LicenseChip extends StatelessWidget {
  final String uid;
  const _LicenseChip({required this.uid});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (_, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final data = snap.data!.data() as Map<String, dynamic>?;
        final license = data?['license'] as String?;
        if (license == null || license.isEmpty) return const SizedBox.shrink();
        return _InfoChip(
            icon: Icons.badge_outlined, label: 'Lic. $license');
      },
    );
  }
}

// ── Chip de información ───────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  static const Color _textSub = Color(0xFF8A94A6);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDDE3EE)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: _textSub),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _textSub)),
      ]),
    );
  }
}
