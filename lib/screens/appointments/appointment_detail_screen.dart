import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/psychologist_model.dart';
import '../../repositories/appointment_repository.dart';
import 'schedule_appointment_screen.dart';

class AppointmentDetailScreen extends StatefulWidget {
  final String appointmentId;
  final Map<String, dynamic> appointmentData;
  final bool isPast;

  const AppointmentDetailScreen({
    super.key, 
    required this.appointmentId,
    required this.appointmentData,
    required this.isPast,
  });

  @override
  State<AppointmentDetailScreen> createState() => _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends State<AppointmentDetailScreen> {
  static const Color _primary = Color(0xFF2B5BFF);
  static const Color _bg = Color(0xFFF4F6FB);
  static const Color _textMain = Color(0xFF0D1B3E);
  static const Color _textSub = Color(0xFF8A94A6);

  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final psychName = widget.appointmentData['psychologistName'] ?? 'Psicólogo';
    final date = widget.appointmentData['date'] ?? '';
    final time = widget.appointmentData['startTime'] ?? '';
    final endTime = widget.appointmentData['endTime'] ?? '';
    final meetingUrl = widget.appointmentData['meetingUrl'] as String?;
    final status = widget.appointmentData['status'] as String? ?? 'scheduled';
    final isCancelled = status == 'cancelled';

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
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2B5BFF), Color(0xFF5E81FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Center(
                      child: Text(
                        psychName.isNotEmpty ? psychName[0].toUpperCase() : 'P',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                    ),
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
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isCancelled 
                                ? Colors.red.shade50 
                                : (widget.isPast ? Colors.grey.shade100 : const Color(0xFFDCFCE7)),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isCancelled 
                                ? 'Cita cancelada'
                                : (widget.isPast ? 'Cita finalizada' : 'Cita confirmada'),
                            style: TextStyle(
                              fontSize: 12,
                              color: isCancelled 
                                  ? Colors.red.shade700 
                                  : (widget.isPast ? _textSub : const Color(0xFF16A34A)),
                              fontWeight: FontWeight.w700,
                            ),
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
            
            // Info card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                children: [
                  _infoRow(Icons.calendar_month_rounded, 'Fecha', date),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Divider(height: 1, color: Color(0xFFF1F5F9))),
                  _infoRow(Icons.access_time_rounded, 'Horario', '$time - $endTime'),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Divider(height: 1, color: Color(0xFFF1F5F9))),
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
                color: isCancelled ? const Color(0xFFFEF2F2) : const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(16),
                border: Border(
                  left: BorderSide(
                    color: isCancelled ? const Color(0xFFEF4444) : const Color(0xFFF97316),
                    width: 4,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isCancelled ? Colors.red : Colors.orange).withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isCancelled ? Icons.cancel_rounded : Icons.info_rounded, 
                    color: isCancelled ? const Color(0xFFEF4444) : const Color(0xFFF97316),
                    size: 24,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      isCancelled
                        ? 'Esta sesión ha sido cancelada.'
                        : (widget.isPast 
                          ? 'Esta sesión ya concluyó. Puedes reservar una nueva sesión desde el catálogo.'
                          : 'Por favor, conéctate 5 minutos antes de la hora acordada. Asegúrate de estar en un lugar tranquilo y con buena conexión a internet.'),
                      style: TextStyle(
                        color: isCancelled ? const Color(0xFF991B1B) : const Color(0xFF9A3412), 
                        height: 1.5, 
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
            
              if (!widget.isPast && !isCancelled)
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2B5BFF), Color(0xFF5E81FF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: _primary.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            if (meetingUrl != null && meetingUrl.isNotEmpty) {
                              final uri = Uri.parse(meetingUrl);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              } else {
                                if (context.mounted) {
                                  _showEnhancedSnackbar('No se pudo abrir el enlace.', Colors.red);
                                }
                              }
                            } else {
                              if (context.mounted) {
                                _showEnhancedSnackbar('El psicólogo aún no ha asignado un link.', Colors.orange);
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          icon: const Icon(Icons.videocam_rounded, color: Colors.white, size: 22),
                          label: const Text('Unirse a la sesión', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            height: 54,
                            child: OutlinedButton(
                              onPressed: _isProcessing ? null : _cancelAppointment,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: BorderSide(color: Colors.red.shade300, width: 1.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: _isProcessing 
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
                                : const Text('Cancelar Cita', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            height: 54,
                            child: ElevatedButton(
                              onPressed: _isProcessing ? null : _rescheduleAppointment,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: _textMain,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                                elevation: 0,
                              ),
                              child: _isProcessing 
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _primary))
                                : const Text('Reprogramar', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
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

  void _showEnhancedSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == Colors.red ? Icons.error_outline_rounded : 
              color == Colors.green ? Icons.check_circle_outline_rounded : 
              Icons.info_outline_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        elevation: 6,
      ),
    );
  }

  Future<void> _cancelAppointment() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar Cita'),
        content: const Text('¿Estás seguro de que deseas cancelar esta cita?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, cancelar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);
    try {
      await AppointmentRepository().cancelAppointment(widget.appointmentId);
      if (mounted) {
        _showEnhancedSnackbar('Cita cancelada exitosamente.', Colors.green);
        Navigator.pop(context); // Go back to agenda
      }
    } catch (e) {
      if (mounted) {
        _showEnhancedSnackbar('Error al cancelar: $e', Colors.red);
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _rescheduleAppointment() async {
    setState(() => _isProcessing = true);
    try {
      final psychId = widget.appointmentData['psychologistId'];
      final doc = await FirebaseFirestore.instance.collection('users').doc(psychId).get();
      if (doc.exists && mounted) {
        final psych = PsychologistModel.fromFirestore(doc.data()!, doc.id);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ScheduleAppointmentScreen(
              psychologist: psych,
              appointmentIdToReschedule: widget.appointmentId,
            ),
          ),
        ).then((_) {
          // If returned, we can pop back to agenda because it might have been rescheduled
          if (mounted) Navigator.pop(context);
        });
      } else {
        throw Exception("Psicólogo no encontrado en la base de datos.");
      }
    } catch (e) {
      if (mounted) {
        _showEnhancedSnackbar('Error al reprogramar: $e', Colors.red);
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}
