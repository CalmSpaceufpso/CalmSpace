import 'package:flutter/material.dart';
import '../../models/psychologist_model.dart';

class PsychologistDetailScreen extends StatelessWidget {
  final PsychologistModel psychologist;

  static const Color _primary   = Color(0xFF1D35B4);
  static const Color _bg        = Color(0xFFF4F6FB);
  static const Color _textMain  = Color(0xFF1E293B);
  static const Color _textSub   = Color(0xFF64748B);
  static const Color _cardBg    = Colors.white;

  const PsychologistDetailScreen({super.key, required this.psychologist});

  @override
  Widget build(BuildContext context) {
    final inicial = psychologist.name.isNotEmpty
        ? psychologist.name.split(' ').map((w) => w.isEmpty ? '' : w[0]).take(2).join().toUpperCase()
        : 'P';

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(12)),
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
          child: ElevatedButton.icon(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Próximamente: Agendar cita'),
                behavior: SnackBarBehavior.floating,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            icon: const Icon(Icons.calendar_today_outlined,
                color: Colors.white, size: 18),
            label: const Text('Agendar Cita',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── AVATAR + NOMBRE ─────────────────────────────────────────────
          Center(
            child: Column(children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1D35B4), Color(0xFF4B6BFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1D35B4).withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: (psychologist.photoUrl != null &&
                        psychologist.photoUrl!.isNotEmpty)
                    ? ClipOval(
                        child: Image.network(psychologist.photoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _initialsText(inicial)))
                    : _initialsText(inicial),
              ),
              const SizedBox(height: 14),
              Text(psychologist.name,
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: _textMain,
                      letterSpacing: -0.3)),
              const SizedBox(height: 4),
              Text(psychologist.specialty,
                  style: const TextStyle(
                      fontSize: 15,
                      color: _primary,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              // Disponibilidad
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: psychologist.isAvailable
                      ? const Color(0xFFE8F5E9)
                      : const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  CircleAvatar(
                    radius: 4,
                    backgroundColor: psychologist.isAvailable
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFEF5350),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    psychologist.isAvailable ? 'Disponible' : 'No disponible',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: psychologist.isAvailable
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFFC62828),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 24),

          // ── STATS ────────────────────────────────────────────────────────
          Row(children: [
            _StatCard(
              icon: Icons.star_rounded,
              iconColor: const Color(0xFFFFC107),
              value: psychologist.rating.toStringAsFixed(1),
              label: 'Calificación',
            ),
            const SizedBox(width: 12),
            _StatCard(
              icon: Icons.work_outline_rounded,
              iconColor: _primary,
              value: '${psychologist.yearsOfExperience}',
              label: 'Años exp.',
            ),
            const SizedBox(width: 12),
            _StatCard(
              icon: Icons.chat_bubble_outline_rounded,
              iconColor: const Color(0xFF00BFA5),
              value: '${psychologist.reviewCount}',
              label: 'Reseñas',
            ),
          ]),
          const SizedBox(height: 20),

          // ── INFO CARDS ───────────────────────────────────────────────────
          if (psychologist.modalidad != null)
            _InfoRow(
              icon: Icons.location_on_outlined,
              label: 'Modalidad',
              value: psychologist.modalidad!,
            ),
          if (psychologist.pricePerSession != null)
            _InfoRow(
              icon: Icons.attach_money_rounded,
              label: 'Precio por sesión',
              value: '\$${psychologist.pricePerSession!.toStringAsFixed(0)} COP',
            ),
          const SizedBox(height: 28),

          // ── DISPONIBILIDAD ───────────────────────────────────────────────
          const Text('Disponibilidad',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _textMain)),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(children: const [
              Icon(Icons.calendar_today_outlined,
                  color: Color(0xFFCBD5E1), size: 36),
              SizedBox(height: 10),
              Text(
                'Los horarios disponibles se\nmostrarán aquí próximamente',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF8A94A6), fontSize: 13),
              ),
            ]),
          ),
          const SizedBox(height: 100),
        ]),
      ),
    );
  }

  Widget _initialsText(String i) => Center(
        child: Text(i,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.bold)),
      );
}

// ── WIDGETS AUXILIARES ─────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Column(children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B))),
          Text(label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
        ]),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFF1D35B4).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF1D35B4), size: 18),
        ),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          Text(value,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B))),
        ]),
      ]),
    );
  }
}
