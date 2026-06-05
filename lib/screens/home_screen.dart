import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:calm_space/screens/profile/patient_detail_screen.dart';
import '../services/notification_service.dart';
import '../services/micro_intervention_service.dart';
import 'mood/mood_history_screen.dart';
import 'profile/view_profile_screen.dart';
import 'psychologists/psychologist_catalog_screen.dart';
import 'appointments/agenda_screen.dart';
import 'availability/manage_availability_screen.dart';

class HomeScreen extends StatefulWidget {
  final bool firestoreReady;
  const HomeScreen({super.key, this.firestoreReady = true});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  static const Color _primary  = Color(0xFF2B5BFF);
  static const Color _bg       = Color(0xFFF4F6FB);

  int    _navIndex      = 0;
  int?   _moodIndex;
  String _nombre        = '';
  String _email         = '';
  String _role          = 'Paciente';
  bool   _loading       = true;
  bool   _savingMood    = false;
  int    _todayCount    = 0;
  double? _todayAverage;

  String _moodReminderTime = '20:00'; // Default 8:00 PM
  
  bool _microInterventionsEnabled = false;
  List<String> _preferredInterventionTimes = [];
  String? _supportCategory;

  // Animación del check de confirmación
  late AnimationController _checkAnimCtrl;
  late Animation<double> _checkAnim;
  bool _showCheck = false;



  @override
  void initState() {
    super.initState();
    _checkAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _checkAnim = CurvedAnimation(parent: _checkAnimCtrl, curve: Curves.elasticOut);
    _loadUser();
    _loadTodayMood();
  }

  @override
  void dispose() {
    _checkAnimCtrl.dispose();
    super.dispose();
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
          _moodReminderTime = d['moodReminderTime'] ?? '20:00';
          _microInterventionsEnabled = d['microInterventionsEnabled'] ?? false;
          _preferredInterventionTimes = List<String>.from(d['preferredInterventionTimes'] ?? []);
          _supportCategory = d['supportCategory'];
          _loading = false;
        });

        // Programar recordatorio diario solo para pacientes
        if ((_role == 'Paciente') && mounted) {
          if (d['moodReminderTime'] == null) {
            // No tiene hora configurada, preguntarle en un Dialog bonito
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showReminderSetupDialog();
            });
          } else {
            final timeParts = _moodReminderTime.split(':');
            final hour = int.tryParse(timeParts.isNotEmpty ? timeParts[0] : '20') ?? 20;
            final minute = int.tryParse(timeParts.length > 1 ? timeParts[1] : '0') ?? 0;

            await NotificationService.instance.requestPermissions();
            await NotificationService.instance.scheduleDailyMoodReminder(
              hour: hour,
              minute: minute,
              skipToday: _todayCount > 0, // Si ya registró hoy, saltar
            );
          }
          
          MicroInterventionService.instance.syncInterventions();
        }
      }
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _showReminderSetupDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.notifications_active, color: Color(0xFF2563EB)),
            SizedBox(width: 10),
            Text('Tu bienestar diario', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Para ayudarte a llevar un mejor registro de tus emociones, ¿a qué hora te gustaría que te recordemos hacer tu check-in de ánimo?',
          style: TextStyle(fontSize: 15, color: Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Más tarde', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Elegir hora'),
          ),
        ],
      ),
    );

    if (result == true) {
      final picked = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 20, minute: 0),
        helpText: 'Selecciona la hora de tu recordatorio',
        builder: (ctx, child) => Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF2563EB)),
          ),
          child: child!,
        ),
      );

      if (picked != null) {
        final newTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
        setState(() => _moodReminderTime = newTime);
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          await FirebaseFirestore.instance.collection('users').doc(uid).set(
            {'moodReminderTime': newTime},
            SetOptions(merge: true),
          );
        }
        
        await NotificationService.instance.requestPermissions();
        await NotificationService.instance.scheduleDailyMoodReminder(
          hour: picked.hour,
          minute: picked.minute,
          skipToday: _todayCount > 0,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Recordatorio configurado para las $newTime ⏰'),
              backgroundColor: const Color(0xFF6BAE8E),
            ),
          );
        }
      } else {
        // Canceló el picker, guardamos un default para que no le siga preguntando siempre
        _saveDefaultTime();
      }
    } else {
      // Eligió "Más tarde", guardamos un default a las 20:00
      _saveDefaultTime();
    }
  }

  Future<void> _saveDefaultTime() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {'moodReminderTime': '20:00'},
        SetOptions(merge: true),
      );
    }
    // Programamos el default silenciosamente
    await NotificationService.instance.requestPermissions();
    await NotificationService.instance.scheduleDailyMoodReminder(
      hour: 20,
      minute: 0,
      skipToday: _todayCount > 0,
    );
  }

  Future<void> _loadTodayMood() async {
    try {
      final entries = await MoodData.getTodayEntries();
      if (mounted && entries.isNotEmpty) {
        final values = entries.map((e) => e['value'] as int).toList();
        final avg = values.fold(0, (a, b) => a + b) / values.length;
        setState(() {
          _todayCount = entries.length;
          _todayAverage = avg;
          _moodIndex = avg.round().clamp(0, 4);
        });
      }
    } catch (_) {}
  }

  /// Guarda automáticamente al seleccionar — sin botón de enviar
  Future<void> _autoSaveMood(int index) async {
    if (_savingMood) return;
    setState(() {
      _moodIndex = index;
      _savingMood = true;
      _showCheck = false;
    });

    try {
      await MoodData.save(index);
      if (mounted) {
        // Recargar datos del día
        final entries = await MoodData.getTodayEntries();
        final values = entries.map((e) => e['value'] as int).toList();
        final avg = values.fold(0, (a, b) => a + b) / values.length;

        setState(() {
          _savingMood = false;
          _showCheck = true;
          _todayCount = entries.length;
          _todayAverage = avg;
          _moodIndex = avg.round().clamp(0, 4);
        });

        _checkAnimCtrl.forward(from: 0);

        // Ocultar el check después de 2 segundos
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _showCheck = false);
        });

        // Re-programar el recordatorio para MAÑANA ya que ya registró hoy
        final timeParts = _moodReminderTime.split(':');
        final hour = int.tryParse(timeParts.isNotEmpty ? timeParts[0] : '20') ?? 20;
        final minute = int.tryParse(timeParts.length > 1 ? timeParts[1] : '0') ?? 0;
        NotificationService.instance.scheduleDailyMoodReminder(
          hour: hour,
          minute: minute,
          skipToday: true,
        );

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            Icon(MoodData.moods[index].icon, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Text(
              '${MoodData.moods[index].label} registrado',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (_todayCount > 1) ...[
              const SizedBox(width: 8),
              Text(
                '· Registro #$_todayCount hoy',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ]),
          backgroundColor: MoodData.moods[index].color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          duration: const Duration(seconds: 2),
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

  void _showMicroInterventionsBottomSheet() {
    bool tempEnabled = _microInterventionsEnabled;
    String? tempCategory = _supportCategory;
    List<String> tempTimes = List.from(_preferredInterventionTimes);

    final List<String> categories = ['Ansiedad', 'Depresión', 'Estrés', 'Autoestima', 'Duelo', 'General'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40, height: 4,
                          decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Row(
                        children: [
                          Icon(Icons.self_improvement, color: Color(0xFF2B5BFF), size: 28),
                          SizedBox(width: 12),
                          Text('Apoyo Diario', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text('Recibe mensajes motivacionales diseñados para mejorar tu estado de ánimo.',
                        style: TextStyle(fontSize: 14, color: Color(0xFF64748B))),
                      const SizedBox(height: 20),
                      
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Activar mensajes de apoyo', style: TextStyle(fontWeight: FontWeight.w600)),
                        value: tempEnabled,
                        activeColor: const Color(0xFF2B5BFF),
                        onChanged: (val) => setModalState(() => tempEnabled = val),
                      ),
                      
                      if (tempEnabled) ...[
                        const SizedBox(height: 16),
                        const Text('¿En qué área necesitas apoyo?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4F6FB),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: tempCategory,
                              isExpanded: true,
                              hint: const Text('Selecciona una categoría'),
                              icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF2B5BFF)),
                              items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                              onChanged: (v) => setModalState(() => tempCategory = v),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        const Text('¿En qué momentos del día?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          children: ['Mañana', 'Tarde', 'Noche'].map((t) => FilterChip(
                            label: Text(t),
                            selected: tempTimes.contains(t),
                            selectedColor: const Color(0xFF2B5BFF).withOpacity(0.15),
                            checkmarkColor: const Color(0xFF2B5BFF),
                            onSelected: (selected) {
                              setModalState(() {
                                if (selected) tempTimes.add(t);
                                else tempTimes.remove(t);
                              });
                            },
                          )).toList(),
                        ),
                      ],
                      const SizedBox(height: 32),
                      
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2B5BFF),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () async {
                            final uid = FirebaseAuth.instance.currentUser?.uid;
                            if (uid != null) {
                              await FirebaseFirestore.instance.collection('users').doc(uid).set({
                                'microInterventionsEnabled': tempEnabled,
                                'supportCategory': tempCategory,
                                'preferredInterventionTimes': tempTimes,
                              }, SetOptions(merge: true));
                              
                              if (mounted) {
                                setState(() {
                                  _microInterventionsEnabled = tempEnabled;
                                  _supportCategory = tempCategory;
                                  _preferredInterventionTimes = List.from(tempTimes);
                                });
                              }
                              
                              MicroInterventionService.instance.syncInterventions();
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          child: const Text('Guardar configuración', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(backgroundColor: _bg,
          body: Center(child: CircularProgressIndicator(color: _primary)));
    }

    final isPsi = _role == 'Psicólogo';
    final uid   = FirebaseAuth.instance.currentUser?.uid ?? '';

    // ── Tabs para cada rol ──────────────────────────────────────────────────
    final List<Widget> psiTabs = [
      _PsychologistHomeTab(nombre: _nombre, uid: uid, firestoreReady: widget.firestoreReady),
      ManageAvailabilityScreen(firestoreReady: widget.firestoreReady, psychologistId: uid),
      const AgendaScreen(),
      ViewProfileScreen(uid: uid, isOwnProfile: true),
    ];
    final List<Widget> pacienteTabs = [
      _HomeTab(
        nombre: _nombre, role: _role,
        moodIndex: _moodIndex,
        todayCount: _todayCount,
        todayAverage: _todayAverage,
        savingMood: _savingMood,
        showCheck: _showCheck,
        checkAnim: _checkAnim,
        onMoodTap: _autoSaveMood,
        onLogout: _logout,
        onViewAllPsychologists: () => setState(() => _navIndex = 1),
        moodReminderTime: _moodReminderTime,
        onChangeReminderTime: (time) => setState(() => _moodReminderTime = time),
        microInterventionsEnabled: _microInterventionsEnabled,
        supportCategory: _supportCategory ?? 'General',
        onMicroInterventionsTap: _showMicroInterventionsBottomSheet,
      ),
      const PsychologistCatalogScreen(),
      const AgendaScreen(),
      ViewProfileScreen(uid: uid, isOwnProfile: true),
    ];

    final tabs = isPsi ? psiTabs : pacienteTabs;

    return Scaffold(
      backgroundColor: _bg,
      bottomNavigationBar: _BottomNav(
        current: _navIndex,
        onTap: (i) => setState(() => _navIndex = i),
        isPsychologist: isPsi,
      ),
      body: IndexedStack(index: _navIndex, children: tabs),
    );
  }
}

// ── BOTTOM NAV ────────────────────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int current;
  final ValueChanged<int> onTap;
  final bool isPsychologist;
  static const Color _p = Color(0xFF2B5BFF);

  static const _patientItems = [
    (Icons.home_rounded,'Home'), (Icons.search_rounded,'Buscar'),
    (Icons.calendar_today_rounded,'Agenda'), (Icons.person_outline_rounded,'Perfil'),
  ];
  static const _psiItems = [
    (Icons.home_rounded,'Home'), (Icons.schedule_rounded,'Horarios'),
    (Icons.calendar_today_rounded,'Citas'), (Icons.person_outline_rounded,'Perfil'),
  ];

  const _BottomNav({required this.current, required this.onTap, this.isPsychologist = false});

  @override
  Widget build(BuildContext context) {
    final items = isPsychologist ? _psiItems : _patientItems;
    return Container(
    decoration: BoxDecoration(
      color: _p,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      boxShadow: [BoxShadow(color: _p.withOpacity(0.4), blurRadius: 20, offset: const Offset(0,-4))]),
    child: SafeArea(top: false,
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(items.length, (i) {
            final a = current == i;
            return GestureDetector(onTap: () => onTap(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: a ? Colors.white.withOpacity(0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(16)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(items[i].$1, color: a ? Colors.white : Colors.white54, size: 24),
                  const SizedBox(height: 4),
                  Text(items[i].$2, style: TextStyle(fontSize: 11,
                    color: a ? Colors.white : Colors.white54,
                    fontWeight: a ? FontWeight.w700 : FontWeight.normal)),
                  if (a) ...[const SizedBox(height:4), Container(width:4,height:4,
                    decoration: const BoxDecoration(color:Colors.white,shape:BoxShape.circle))],
                ]),
              ),
            );
          }),
        ),
      ),
    ),
  );
  }
}

// ── HOME TAB ──────────────────────────────────────────────────────────────────
class _HomeTab extends StatelessWidget {
  final String nombre, role;
  final int? moodIndex;
  final int todayCount;
  final double? todayAverage;
  final bool savingMood, showCheck;
  final Animation<double> checkAnim;
  final ValueChanged<int> onMoodTap;
  final VoidCallback onLogout;
  final VoidCallback onViewAllPsychologists;
  final String moodReminderTime;
  final ValueChanged<String> onChangeReminderTime;
  final bool microInterventionsEnabled;
  final String supportCategory;
  final VoidCallback onMicroInterventionsTap;

  static const Color _primary  = Color(0xFF2B5BFF);
  static const Color _textMain = Color(0xFF0D1B3E);
  static const Color _textSub  = Color(0xFF8A94A6);

  const _HomeTab({
    required this.nombre, required this.role,
    this.moodIndex, required this.todayCount,
    this.todayAverage, required this.savingMood,
    required this.showCheck, required this.checkAnim,
    required this.onMoodTap, required this.onLogout,
    required this.onViewAllPsychologists,
    required this.moodReminderTime,
    required this.onChangeReminderTime,
    required this.microInterventionsEnabled,
    required this.supportCategory,
    required this.onMicroInterventionsTap,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final first = nombre.split(' ').first.isNotEmpty ? nombre.split(' ').first : 'Usuario';
    final inicial = first[0].toUpperCase();
    final moods = MoodData.moods;
    const Color verdeBase = Color(0xFF2B5BFF);

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
            StreamBuilder<DocumentSnapshot>(
              stream: user != null 
                  ? FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots() 
                  : const Stream.empty(),
              builder: (context, snapshot) {
                String? photoUrl;
                if (snapshot.hasData && snapshot.data!.exists) {
                  final data = snapshot.data!.data() as Map<String, dynamic>;
                  photoUrl = data['photoUrl'];
                }
                
                return CircleAvatar(
                  radius: 26,
                  backgroundColor: verdeBase,
                  backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                      ? (photoUrl.startsWith('http')
                          ? NetworkImage(photoUrl)
                          : MemoryImage(base64Decode(photoUrl.split(',').last)) as ImageProvider)
                      : null,
                  child: (photoUrl == null || photoUrl.isEmpty) 
                      ? Text(
                          inicial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                );
              }
            ),
          ]),

          const SizedBox(height: 24),

          // ── SELECTOR DE ÁNIMO (REDISEÑADO) ──
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Header
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2B5BFF), Color(0xFF6B8FFF)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('¿Cómo te sientes?',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _textMain)),
                    Text(
                      todayCount > 0
                          ? '$todayCount registro${todayCount > 1 ? "s" : ""} hoy'
                          : 'Toca para registrar',
                      style: TextStyle(fontSize: 11, color: _textSub),
                    ),
                  ]),
                ]),
                // Ver historial
                GestureDetector(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const MoodHistoryScreen())),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_primary.withOpacity(0.12), _primary.withOpacity(0.06)],
                      ),
                      borderRadius: BorderRadius.circular(24)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.bar_chart_rounded, color: _primary, size: 15),
                      SizedBox(width: 5),
                      Text('Historial', style: TextStyle(
                          fontSize: 12, color: _primary, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ]),

              const SizedBox(height: 20),

              // ── Íconos de ánimo — SIEMPRE CON COLOR ──
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(moods.length, (i) {
                  final m = moods[i];
                  final isAvg = todayAverage != null && todayAverage!.round() == i;
                  return GestureDetector(
                    onTap: savingMood ? null : () => onMoodTap(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutBack,
                      width: 60,
                      height: 95, // Altura fija para que todos midan lo mismo
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                      decoration: BoxDecoration(
                        gradient: isAvg ? LinearGradient(
                          colors: [m.color.withOpacity(0.18), m.light.withOpacity(0.35)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ) : null,
                        color: isAvg ? null : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(18),
                        border: isAvg
                            ? Border.all(color: m.color.withOpacity(0.5), width: 2.5)
                            : Border.all(color: Colors.grey.shade200, width: 1),
                        boxShadow: isAvg ? [
                          BoxShadow(
                            color: m.color.withOpacity(0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ] : [],
                      ),
                      child: Column(children: [
                        // Ícono con fondo circular coloreado
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: isAvg ? 42 : 38,
                          height: isAvg ? 42 : 38,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isAvg
                                  ? [m.color, m.color.withOpacity(0.7)]
                                  : [m.color.withOpacity(0.12), m.light.withOpacity(0.25)],
                              begin: Alignment.topLeft, end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: isAvg ? [
                              BoxShadow(
                                color: m.color.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ] : [],
                          ),
                          child: Icon(m.icon,
                            color: isAvg ? Colors.white : m.color,
                            size: isAvg ? 24 : 20),
                        ),
                        const SizedBox(height: 6),
                        Text(m.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: isAvg ? FontWeight.w800 : FontWeight.w500,
                            color: isAvg ? m.color : _textSub),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      ]),
                    ),
                  );
                }),
              ),

              // ── Guardando... con indicador bonito ──
              if (savingMood) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2, color: _primary.withOpacity(0.6)),
                    ),
                    const SizedBox(width: 10),
                    Text('Guardando tu estado...',
                      style: TextStyle(fontSize: 12, color: _primary.withOpacity(0.7),
                          fontWeight: FontWeight.w600)),
                  ]),
                ),
              ],

              // ── Confirmación: ¡Registrado! ──
              if (showCheck && !savingMood && todayCount > 0) ...[
                const SizedBox(height: 16),
                ScaleTransition(
                  scale: checkAnim,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          MoodData.moods[todayAverage!.round().clamp(0, 4)].color.withOpacity(0.12),
                          MoodData.moods[todayAverage!.round().clamp(0, 4)].light.withOpacity(0.2),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: MoodData.moods[todayAverage!.round().clamp(0, 4)].color.withOpacity(0.25),
                      ),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Container(
                        width: 24, height: 24,
                        decoration: BoxDecoration(
                          color: MoodData.moods[todayAverage!.round().clamp(0, 4)].color,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                      ),
                      const SizedBox(width: 10),
                      Text('¡Registrado!',
                        style: TextStyle(fontSize: 13,
                          color: MoodData.moods[todayAverage!.round().clamp(0, 4)].color,
                          fontWeight: FontWeight.w700)),
                      const SizedBox(width: 6),
                      Text(
                        '${MoodData.moods[todayAverage!.round().clamp(0, 4)].label}',
                        style: TextStyle(fontSize: 12,
                          color: MoodData.moods[todayAverage!.round().clamp(0, 4)].color.withOpacity(0.7),
                          fontWeight: FontWeight.w500),
                      ),
                    ]),
                  ),
                ),
              ],

              // ── Resumen del día (cuando NO se acaba de registrar) ──
              if (todayCount > 0 && !savingMood && !showCheck) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        MoodData.moods[todayAverage!.round().clamp(0, 4)].light.withOpacity(0.25),
                        MoodData.moods[todayAverage!.round().clamp(0, 4)].color.withOpacity(0.06),
                      ],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: MoodData.moods[todayAverage!.round().clamp(0, 4)].color.withOpacity(0.15),
                    ),
                  ),
                  child: Row(children: [
                    Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            MoodData.moods[todayAverage!.round().clamp(0, 4)].color,
                            MoodData.moods[todayAverage!.round().clamp(0, 4)].color.withOpacity(0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(13),
                        boxShadow: [BoxShadow(
                          color: MoodData.moods[todayAverage!.round().clamp(0, 4)].color.withOpacity(0.3),
                          blurRadius: 8, offset: const Offset(0, 3),
                        )],
                      ),
                      child: Icon(
                        MoodData.moods[todayAverage!.round().clamp(0, 4)].icon,
                        color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          todayCount == 1
                              ? 'Tu estado de hoy'
                              : 'Promedio de hoy · $todayCount registros',
                          style: const TextStyle(fontSize: 10, color: _textSub, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          MoodData.moods[todayAverage!.round().clamp(0, 4)].label,
                          style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold,
                            color: MoodData.moods[todayAverage!.round().clamp(0, 4)].color),
                        ),
                      ],
                    )),
                    Icon(Icons.check_circle_rounded,
                        color: MoodData.moods[todayAverage!.round().clamp(0, 4)].color.withOpacity(0.4),
                        size: 22),
                  ]),
                ),
              ],
              
              // ── Botón para cambiar hora de recordatorio ──
              const SizedBox(height: 12),
              Center(
                child: TextButton.icon(
                  onPressed: () async {
                    final timeParts = moodReminderTime.split(':');
                    final initialHour = int.tryParse(timeParts.isNotEmpty ? timeParts[0] : '20') ?? 20;
                    final initialMin = int.tryParse(timeParts.length > 1 ? timeParts[1] : '0') ?? 0;
                    
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(hour: initialHour, minute: initialMin),
                      helpText: 'Cambiar hora de recordatorio',
                      builder: (ctx, child) => Theme(
                        data: Theme.of(ctx).copyWith(
                          colorScheme: const ColorScheme.light(primary: Color(0xFF2563EB)),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) {
                      final newTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                      onChangeReminderTime(newTime);
                      final uid = FirebaseAuth.instance.currentUser?.uid;
                      if (uid != null) {
                        await FirebaseFirestore.instance.collection('users').doc(uid).set(
                          {'moodReminderTime': newTime},
                          SetOptions(merge: true),
                        );
                      }
                      await NotificationService.instance.scheduleDailyMoodReminder(
                        hour: picked.hour,
                        minute: picked.minute,
                        skipToday: todayCount > 0,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Recordatorio actualizado a las $newTime ⏰'),
                            backgroundColor: const Color(0xFF6BAE8E),
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.notifications_active_outlined, size: 16, color: Color(0xFF9E9E9E)),
                  label: Text('Recordatorio: $moodReminderTime', 
                    style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E), fontWeight: FontWeight.w500)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: Colors.grey.shade50,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ]),
          ),

          const SizedBox(height: 24),

          // BANNER DE MICRO-INTERVENCIONES
          GestureDetector(
            onTap: onMicroInterventionsTap,
            child: Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2B5BFF), Color(0xFF1E40AF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF2B5BFF).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.favorite, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Apoyo Diario', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(
                          microInterventionsEnabled ? 'Apoyo activado · $supportCategory' : 'Toca aquí para recibir apoyo diario',
                          style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white),
                ],
              ),
            ),
          ),

          // CAROUSEL DE MENSAJES MOTIVACIONALES (REDISEÑADO)
          const _MotivationalCarousel(),

          const SizedBox(height: 24),

          // PRÓXIMAS CITAS
          const Text('Próximas Citas',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _textMain)),
          const SizedBox(height: 14),
          const _AppointmentsCarousel(),

          const SizedBox(height: 24),

          // PSICÓLOGOS DISPONIBLES — Firestore en tiempo real
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Psicólogos Disponibles',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _textMain)),
            GestureDetector(
              onTap: onViewAllPsychologists,
              child: const Text('Ver todos',
                style: TextStyle(fontSize: 13, color: _primary, fontWeight: FontWeight.w600)),
            ),
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
                    name: d['fullName'] ?? d['name'] ?? 'Sin nombre',
                    specialty: d['specialty'] ?? 'Psicólogo',
                    rating: (d['rating'] as num?)?.toDouble(),
                    photoUrl: d['photoUrl'],
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
  final String? photoUrl;
  static const Color _primary  = Color(0xFF2B5BFF);
  static const Color _textMain = Color(0xFF0D1B3E);
  static const Color _textSub  = Color(0xFF8A94A6);
  const _PsychCard({required this.name, required this.specialty, this.rating, this.photoUrl});

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
                borderRadius: BorderRadius.circular(14),
                image: photoUrl != null && photoUrl!.isNotEmpty
                    ? DecorationImage(image: NetworkImage(photoUrl!), fit: BoxFit.cover)
                    : null),
            child: photoUrl == null || photoUrl!.isEmpty
                ? Center(child: Text(inicial,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                        color: _primary)))
                : null),
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


class _MotivationalMessage {
  final String text;
  final String category;
  final String imageUrl;
  final Color accentColor;

  const _MotivationalMessage({
    required this.text,
    required this.category,
    required this.imageUrl,
    required this.accentColor,
  });
}

const List<_MotivationalMessage> _messages = [
  _MotivationalMessage(
    text: "El primer paso no te lleva a donde quieres ir, pero te saca de donde estás.",
    category: "Motivación",
    imageUrl: "https://images.unsplash.com/photo-1470246973918-29a93221c455?w=800&q=80",
    accentColor: Color(0xFF10B981),
  ),
  _MotivationalMessage(
    text: "Respira hondo. Es solo un mal día, no una mala vida.",
    category: "Paz Interior",
    imageUrl: "https://images.unsplash.com/photo-1518241353330-0f7941c2d9b5?w=800&q=80",
    accentColor: Color(0xFF6366F1),
  ),
  _MotivationalMessage(
    text: "Tu bienestar emocional no es un destino, es un camino que recorres día a día.",
    category: "Bienestar",
    imageUrl: "https://images.unsplash.com/photo-1544367567-0f2fcb009e0b?w=800&q=80",
    accentColor: Color(0xFFEC4899),
  ),
  _MotivationalMessage(
    text: "Dedicar tiempo para ti mismo no es egoísmo, es amor propio y salud mental.",
    category: "Auto-cuidado",
    imageUrl: "https://images.unsplash.com/photo-1506126613408-eca07ce68773?w=800&q=80",
    accentColor: Color(0xFFF59E0B),
  ),
  _MotivationalMessage(
    text: "La calma es el superpoder que te permite ver las cosas con claridad en medio de la tormenta.",
    category: "Mindfulness",
    imageUrl: "https://images.unsplash.com/photo-1447752875215-b2761acb3c5d?w=800&q=80",
    accentColor: Color(0xFF3B82F6),
  ),
];

class _MotivationalCarousel extends StatefulWidget {
  const _MotivationalCarousel();

  @override
  State<_MotivationalCarousel> createState() => _MotivationalCarouselState();
}

class _MotivationalCarouselState extends State<_MotivationalCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 8), (timer) {
      if (mounted) {
        final nextPage = (_currentPage + 1) % _messages.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
  }

  void _nextPage() {
    _startTimer();
    final nextPage = (_currentPage + 1) % _messages.length;
    _pageController.animateToPage(
      nextPage,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 240,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      msg.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [msg.accentColor.withOpacity(0.8), msg.accentColor.withOpacity(0.4)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withOpacity(0.75),
                            Colors.black.withOpacity(0.3),
                            Colors.black.withOpacity(0.1),
                          ],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.25),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  msg.category.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.format_quote_rounded,
                                color: Colors.white.withOpacity(0.4),
                                size: 32,
                              ),
                            ],
                          ),
                          const Spacer(),
                          Padding(
                            padding: const EdgeInsets.only(right: 16.0),
                            child: Text(
                              msg.text,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                                shadows: [
                                  Shadow(
                                    color: Colors.black38,
                                    offset: Offset(0, 2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 36),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Positioned(
            bottom: 16,
            left: 24,
            right: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: List.generate(_messages.length, (index) {
                    final isSelected = _currentPage == index;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      height: 6,
                      width: isSelected ? 20 : 6,
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : Colors.white.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _nextPage,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── PRÓXIMAS CITAS CAROUSEL ────────────────────────────────────────────────
class _AppointmentsCarousel extends StatelessWidget {
  const _AppointmentsCarousel();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('patientId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'scheduled')
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF2B5BFF)));
        }
        var docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Column(
              children: [
                Icon(Icons.event_busy_rounded, color: Color(0xFFCBD5E1), size: 36),
                SizedBox(height: 8),
                Text('No tienes citas programadas',
                  style: TextStyle(color: Color(0xFF8A94A6), fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
          );
        }

        final now = DateTime.now();
        // Sort in memory by appointment date and time
        docs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final dateStr = data['date'] as String? ?? '';
          final timeStr = data['startTime'] as String? ?? '';
          final dt = DateTime.tryParse('$dateStr $timeStr:00');
          // Optionally filter past appointments
          if (dt != null && dt.isBefore(now.subtract(const Duration(hours: 1)))) return false;
          return true;
        }).toList()..sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          
          final aDateStr = aData['date'] as String? ?? '';
          final aTimeStr = aData['startTime'] as String? ?? '';
          final bDateStr = bData['date'] as String? ?? '';
          final bTimeStr = bData['startTime'] as String? ?? '';

          final aDateTime = DateTime.tryParse('$aDateStr $aTimeStr:00') ?? DateTime.now();
          final bDateTime = DateTime.tryParse('$bDateStr $bTimeStr:00') ?? DateTime.now();
          
          return aDateTime.compareTo(bDateTime);
        });
        
        // Limit to 3 in memory
        if (docs.length > 3) docs = docs.sublist(0, 3);

        return SizedBox(
          height: 110,
          child: PageView.builder(
            controller: PageController(viewportFraction: 0.9),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final d = docs[index].data() as Map<String, dynamic>;
              return Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2B5BFF), Color(0xFF5E81FF)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF2B5BFF).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Cita confirmada', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12)),
                          const SizedBox(height: 4),
                          Text('${d['date']} • ${d['startTime']}', 
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ── DASHBOARD DEL PSICÓLOGO ───────────────────────────────────────────────────
class _PsychologistHomeTab extends StatelessWidget {
  final String nombre;
  final String uid;
  final bool firestoreReady;

  static const Color _primary  = Color(0xFF2B5BFF);
  static const Color _bg       = Color(0xFFF4F6FB);
  static const Color _textMain = Color(0xFF0D1B3E);
  static const Color _textSub  = Color(0xFF8A94A6);

  const _PsychologistHomeTab({
    required this.nombre,
    required this.uid,
    required this.firestoreReady,
  });

  @override
  Widget build(BuildContext context) {
    final first = nombre.split(' ').first.isNotEmpty ? nombre.split(' ').first : 'Doctor';
    final inicial = first[0].toUpperCase();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── HEADER ──────────────────────────────────────────────────────────
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('¡Hola, $first!',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900,
                    color: _textMain, letterSpacing: -0.5)),
              const SizedBox(height: 2),
              const Text('Panel del psicólogo',
                style: TextStyle(fontSize: 13, color: _textSub)),
            ]),
            // Avatar
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
              builder: (context, snapshot) {
                String? photoUrl;
                if (snapshot.hasData && snapshot.data!.exists) {
                  final data = snapshot.data!.data() as Map<String, dynamic>;
                  photoUrl = data['photoUrl'];
                }
                return CircleAvatar(
                  radius: 26,
                  backgroundColor: _primary,
                  backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                      ? (photoUrl.startsWith('http')
                          ? NetworkImage(photoUrl)
                          : MemoryImage(base64Decode(photoUrl.split(',').last)) as ImageProvider)
                      : null,
                  child: (photoUrl == null || photoUrl.isEmpty)
                      ? Text(inicial, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))
                      : null,
                );
              },
            ),
          ]),

          const SizedBox(height: 28),

          // ── TARJETAS RESUMEN ─────────────────────────────────────────────────
          StreamBuilder<QuerySnapshot>(
            stream: firestoreReady
                ? FirebaseFirestore.instance
                    .collection('appointments')
                    .where('psychologistId', isEqualTo: uid)
                    .where('status', isEqualTo: 'scheduled')
                    .snapshots()
                : const Stream.empty(),
            builder: (context, snap) {
              final total = snap.data?.docs.length ?? 0;
              final now = DateTime.now();
              final todayStr = '${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}';
              final todayCount = snap.data?.docs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                return data['date'] == todayStr;
              }).length ?? 0;

              return Row(children: [
                Expanded(child: _StatCard(
                  icon: Icons.calendar_month_rounded,
                  label: 'Citas hoy',
                  value: '$todayCount',
                  color: const Color(0xFF2B5BFF),
                  light: const Color(0xFFEEF2FF),
                )),
                const SizedBox(width: 12),
                Expanded(child: _StatCard(
                  icon: Icons.people_rounded,
                  label: 'Total pendientes',
                  value: '$total',
                  color: const Color(0xFF7C3AED),
                  light: const Color(0xFFF5F3FF),
                )),
              ]);
            },
          ),

          const SizedBox(height: 24),

          // ── PRÓXIMAS CITAS DEL PSICÓLOGO ────────────────────────────────────
          const Text('Próximas Citas',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _textMain)),
          const SizedBox(height: 14),

          StreamBuilder<QuerySnapshot>(
            stream: firestoreReady
                ? FirebaseFirestore.instance
                    .collection('appointments')
                    .where('psychologistId', isEqualTo: uid)
                    .where('status', isEqualTo: 'scheduled')
                    .snapshots()
                : const Stream.empty(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: _primary));
              }
              var docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: const Column(children: [
                    Icon(Icons.event_busy_rounded, color: Color(0xFFCBD5E1), size: 40),
                    SizedBox(height: 10),
                    Text('No tienes citas programadas',
                      style: TextStyle(color: Color(0xFF8A94A6), fontSize: 13, fontWeight: FontWeight.w500)),
                  ]),
                );
              }

              // Ordenar por fecha
              final sorted = List.from(docs)..sort((a, b) {
                final ad = (a.data() as Map<String, dynamic>);
                final bd = (b.data() as Map<String, dynamic>);
                final aStr = '${ad['date']} ${ad['startTime']}:00';
                final bStr = '${bd['date']} ${bd['startTime']}:00';
                final aDt = DateTime.tryParse(aStr) ?? DateTime.now();
                final bDt = DateTime.tryParse(bStr) ?? DateTime.now();
                return aDt.compareTo(bDt);
              });

              return Column(
                children: sorted.take(5).map((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  final patientId = d['patientId'] as String? ?? '';
                  final patientName = d['patientName'] as String? ?? 'Paciente';
                  
                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('users').doc(patientId).get(),
                    builder: (context, userSnap) {
                      String resolvedName = patientName;
                      if (userSnap.hasData && userSnap.data!.exists) {
                        final userData = userSnap.data!.data() as Map<String, dynamic>?;
                        if (userData != null) {
                          final realName = userData['name'] as String? ?? '';
                          if (realName.isNotEmpty && (patientName == 'Paciente' || patientName.isEmpty)) {
                            resolvedName = realName;
                          }
                        }
                      }

                      return GestureDetector(
                        onTap: () {
                          if (patientId.isNotEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PatientDetailScreen(
                                  patientId: patientId,
                                  patientName: resolvedName,
                                ),
                              ),
                            );
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))],
                          ),
                          child: Row(children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.calendar_month_rounded, color: _primary, size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(resolvedName,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _textMain)),
                                const SizedBox(height: 4),
                                Text('${d['date'] ?? ''} · ${d['startTime'] ?? ''} - ${d['endTime'] ?? ''}',
                                  style: const TextStyle(fontSize: 12, color: _textSub)),
                              ],
                            )),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('Confirmada',
                            style: TextStyle(fontSize: 11, color: Color(0xFF16A34A), fontWeight: FontWeight.w600)),
                        ),
                      ]),
                    ),
                  );
                 },
                );
              }).toList(),
            );
          },
          ),

          const SizedBox(height: 24),

          // ── ACCESOS RÁPIDOS ──────────────────────────────────────────────────
          const Text('Accesos Rápidos',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _textMain)),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _QuickAction(
              icon: Icons.schedule_rounded,
              label: 'Gestionar\nHorarios',
              color: const Color(0xFF2B5BFF),
              onTap: () {
                // Navigate to tab 1 (Horarios)
                final homeState = context.findAncestorStateOfType<_HomeScreenState>();
                homeState?.setState(() => homeState._navIndex = 1);
              },
            )),
            const SizedBox(width: 12),
            Expanded(child: _QuickAction(
              icon: Icons.calendar_today_rounded,
              label: 'Ver todas\nlas citas',
              color: const Color(0xFF7C3AED),
              onTap: () {
                final homeState = context.findAncestorStateOfType<_HomeScreenState>();
                homeState?.setState(() => homeState._navIndex = 2);
              },
            )),
            const SizedBox(width: 12),
            Expanded(child: _QuickAction(
              icon: Icons.person_outline_rounded,
              label: 'Mi\nPerfil',
              color: const Color(0xFF0891B2),
              onTap: () {
                final homeState = context.findAncestorStateOfType<_HomeScreenState>();
                homeState?.setState(() => homeState._navIndex = 3);
              },
            )),
          ]),

          const SizedBox(height: 32),
        ]),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color, light;
  const _StatCard({required this.icon, required this.label, required this.value, required this.color, required this.light});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: light, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 12),
        Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF8A94A6), fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
        ),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 10),
          Text(label, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0D1B3E)), maxLines: 2),
        ]),
      ),
    );
  }
}