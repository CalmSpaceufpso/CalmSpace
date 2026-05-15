import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PendingApprovalScreen extends StatelessWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color verdeBase = Color(0xFF6BAE8E);
    const Color beige = Color(0xFFF7F3EE);
    const Color textoPrimario = Color(0xFF2D3A32);
    const Color textoSecund = Color(0xFF7A8C81);

    return Scaffold(
      backgroundColor: beige,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5EE),
                  borderRadius: BorderRadius.circular(60),
                ),
                child: const Icon(Icons.hourglass_top_rounded, size: 60, color: verdeBase),
              ),
              const SizedBox(height: 36),
              const Text(
                'Cuenta en revisión',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: textoPrimario),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Tu solicitud como psicólogo está siendo revisada por nuestro equipo. '
                'Este proceso puede tardar entre 24 y 48 horas hábiles.',
                style: TextStyle(fontSize: 15, color: textoSecund, height: 1.6),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE8F5EE), width: 2),
                ),
                child: const Column(
                  children: [
                    _InfoRow(icon: Icons.verified_user_outlined, text: 'Verificamos tu licencia profesional'),
                    SizedBox(height: 12),
                    _InfoRow(icon: Icons.email_outlined, text: 'Recibirás un correo cuando seas aprobado'),
                    SizedBox(height: 12),
                    _InfoRow(icon: Icons.security_outlined, text: 'Esto protege a los pacientes de la plataforma'),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () async => await FirebaseAuth.instance.signOut(),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Cerrar sesión', style: TextStyle(fontSize: 15)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: textoSecund,
                    side: BorderSide(color: textoSecund.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF6BAE8E), size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 13, color: Color(0xFF2D3A32), height: 1.4)),
        ),
      ],
    );
  }
}
