import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  // Constantes
  static const int _moodReminderId = 1001;
  static const int _reminderHour   = 20; // 8:00 PM
  static const int _reminderMinute = 0;

  Future<void> initialize() async {
    // Inicializar zonas horarias
    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );
  }

  /// Solicita permisos en Android 13+
  Future<bool> requestPermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }
    return true; // iOS pide permisos en initialize()
  }

  /// Programa un recordatorio diario a la hora especificada.
  /// [skipToday]: Si es true, el recordatorio comenzará a partir de mañana, útil si el usuario ya registró su ánimo hoy.
  Future<void> scheduleDailyMoodReminder({
    int hour = 20,
    int minute = 0,
    bool skipToday = false,
  }) async {
    // Cancelar cualquier recordatorio previo antes de reprogramar
    await _plugin.cancel(_moodReminderId);

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // Si la hora de hoy ya pasó o si queremos saltarnos el día de hoy
    if (scheduled.isBefore(now) || skipToday) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      _moodReminderId,
      '¿Cómo te sientes hoy? 💙',
      'Recuerda registrar tu estado de ánimo en CalmSpace. '
          '¡Solo toma unos segundos!',
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'calm_space_mood_channel',
          'Recordatorio de Bienestar',
          channelDescription: 'Recordatorio diario para registrar tu estado de ánimo',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: Color(0xFF2B5BFF),
          playSound: true,
          enableVibration: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // Repetir cada día a la misma hora
    );
  }

  /// Cancela el recordatorio diario (si el usuario cierra sesión)
  Future<void> cancelMoodReminder() async {
    await _plugin.cancel(_moodReminderId);
  }

  /// Cancela todas las micro-intervenciones programadas previamente
  Future<void> cancelMicroInterventions() async {
    // Usamos el rango 2000-2100 para IDs de micro intervenciones
    for (int i = 2000; i < 2100; i++) {
      await _plugin.cancel(i);
    }
  }

  /// Programa una lista de mensajes en diferentes días y horas
  Future<void> scheduleMicroInterventions(List<String> messages, List<String> times) async {
    await cancelMicroInterventions(); // Limpiar previas
    if (messages.isEmpty || times.isEmpty) return;

    final now = tz.TZDateTime.now(tz.local);
    int currentId = 2000; // ID inicial
    int messageIndex = 0;

    // Iterar para programar hasta 14 días (para no llegar al límite de iOS de 64 notificaciones si hay muchas horas)
    for (int dayOffset = 0; dayOffset < 14; dayOffset++) {
      final targetDate = now.add(Duration(days: dayOffset));
      
      for (String timeStr in times) {
        if (messageIndex >= messages.length) {
          messageIndex = 0; // Reciclar mensajes si tenemos pocos
        }

        final timeParts = timeStr.split(':');
        final hour = int.tryParse(timeParts.isNotEmpty ? timeParts[0] : '9') ?? 9;
        final minute = int.tryParse(timeParts.length > 1 ? timeParts[1] : '0') ?? 0;

        var scheduledDate = tz.TZDateTime(
          tz.local,
          targetDate.year,
          targetDate.month,
          targetDate.day,
          hour,
          minute,
        );

        // Solo programar si la hora está en el futuro
        if (scheduledDate.isAfter(now)) {
          await _plugin.zonedSchedule(
            currentId++,
            'Mensaje para ti ✨',
            messages[messageIndex],
            scheduledDate,
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'calm_space_micro_interventions',
                'Micro-intervenciones',
                channelDescription: 'Mensajes diarios de apoyo psicológico',
                importance: Importance.defaultImportance,
                priority: Priority.defaultPriority,
                icon: '@mipmap/ic_launcher',
                color: Color(0xFF6BAE8E),
                playSound: true,
              ),
              iOS: DarwinNotificationDetails(
                presentAlert: true,
                presentBadge: true,
                presentSound: true,
              ),
            ),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          );
          messageIndex++;
          if (currentId >= 2064) return; // Limite de seguridad de iOS
        }
      }
    }
  }

  /// Dispara una notificación inmediata para pruebas (Debug)
  Future<void> showTestNotification(String message) async {
    await _plugin.show(
      9999,
      'Mensaje para ti ✨',
      message,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'calm_space_micro_interventions',
          'Micro-intervenciones',
          channelDescription: 'Mensajes diarios de apoyo psicológico',
          importance: Importance.max,
          priority: Priority.max,
          icon: '@mipmap/ic_launcher',
          color: Color(0xFF2B5BFF),
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}
