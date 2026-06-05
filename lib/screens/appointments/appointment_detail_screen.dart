import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AppointmentDetailScreen extends StatelessWidget {
  final Map<String, dynamic> appointmentData;
  final bool isPast;

  const AppointmentDetailScreen({
    super.key, 
    required this.appointmentData,
    required this.isPast,
  });

  static const Color _primary = Color(0xFF2B5BFF);
  static const Color _bg = Color(0xFFF4F6FB);
  static const Color _textMain = Color(0xFF0D1B3E);
  static const Color _textSub = Color(0xFF8A94A6);

  @override
  Widget build(BuildContext context) {
    final psychName = appointmentData['psychologistName'] ?? 'Psicólogo';
    final date = appointmentData['date'] ?? '';
    final time = appointmentData['startTime'] ?? '';
    final endTime = appointmentData['endTime'] ?? '';
    final meetingUrl = appointmentData['meetingUrl'] as String?;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('Detalles de la Cita', style: TextStyle(color: _textMain, fontWeight: FontWeight.bold)),
        backgroundColor: _bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: _textMain),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: _primary.withOpacity(0.1),
                    child: const Icon(Icons.person_rounded, color: _primary, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          psychName,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textMain),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isPast ? 'Cita finalizada' : 'Cita confirmada',
                          style: TextStyle(
                            fontSize: 14,
                            color: isPast ? _textSub : const Color(0xFF22C55E),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            const Text('Información de la sesión', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textMain)),
            const SizedBox(height: 16),
            
            // Info grid
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  _infoRow(Icons.calendar_month_rounded, 'Fecha', date),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
                  _infoRow(Icons.access_time_rounded, 'Horario', '$time - $endTime'),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
                  _infoRow(Icons.videocam_rounded, 'Modalidad', 'Videollamada online'),
                ],
              ),
            ),

            const SizedBox(height: 24),
            const Text('Instrucciones', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textMain)),
            const SizedBox(height: 16),
            
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.orange.withOpacity(0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isPast 
                        ? 'Esta sesión ya concluyó. Puedes reservar una nueva sesión desde el catálogo.'
                        : 'Por favor, conéctate 5 minutos antes de la hora acordada. Asegúrate de estar en un lugar tranquilo y con buena conexión a internet.',
                      style: const TextStyle(color: Colors.orange, height: 1.5, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
            
            if (!isPast)
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (meetingUrl != null && meetingUrl.isNotEmpty) {
                      final uri = Uri.parse(meetingUrl);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('No se pudo abrir el enlace.')),
                          );
                        }
                      }
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('El psicólogo aún no ha asignado un link.')),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.videocam_rounded, color: Colors.white),
                  label: const Text('Unirse a la sesión', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: _primary, size: 20),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: _textSub, fontSize: 13)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(color: _textMain, fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }
}
