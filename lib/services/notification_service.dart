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
}
