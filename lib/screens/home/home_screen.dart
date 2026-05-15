import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../profile/view_profile_screen.dart';
import '../availability/manage_availability_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  // ── Paleta ──────────────────────────────────────────────────────────────────
  static const Color _verde      = Color(0xFF5BA98B);
  static const Color _verdeDark  = Color(0xFF3D7A63);
  static const Color _lavanda    = Color(0xFF9B8EC4);
  static const Color _lavandaBg  = Color(0xFFF2EFF9);
  static const Color _beige      = Color(0xFFF8F5F0);
  static const Color _card       = Color(0xFFFFFFFF);
  static const Color _textDark   = Color(0xFF1E2D28);
  static const Color _textMid    = Color(0xFF6B7C74);
  static const Color _amber      = Color(0xFFE8A76C);

  // ── Estado ──────────────────────────────────────────────────────────────────
  int _selectedMood = -1;
  int _navIndex     = 0;
  String _role      = 'Paciente';
  bool   _loadingRole = true;

  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulseAnim;

  final List<Map<String, dynamic>> _moods = [
    {'emoji': '😔', 'label': 'Mal'},
    {'emoji': '😐', 'label': 'Regular'},
    {'emoji': '🙂', 'label': 'Bien'},
    {'emoji': '😊', 'label': 'Muy bien'},
    {'emoji': '😄', 'label': 'Genial'},
  ];

  static const List<String> _quotes = [
    '"La salud mental es tan importante como la salud física."',
    '"Pedir ayuda es un acto de valentía, no de debilidad."',
    '"Cuida tu mente como cuidas tu cuerpo."',
    '"Un día a la vez. Un paso a la vez."',
    '"Está bien no estar bien — lo importante es buscar apoyo."',
  ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _loadRole();
  }

  Future<void> _loadRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && mounted) {
        setState(() {
          _role = (doc.data()?['role'] ?? 'Paciente') as String;
          _loadingRole = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingRole = false);
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  // ── Frase del día (basada en fecha) ─────────────────────────────────────────
  String get _todayQuote {
    final idx = DateTime.now().day % _quotes.length;
    return _quotes[idx];
  }

  @override
  Widget build(BuildContext context) {
    final user   = FirebaseAuth.instance.currentUser;
    final nombre = user?.displayName ?? user?.email ?? 'Usuario';
    final initial = nombre.isNotEmpty ? nombre[0].toUpperCase() : 'U';
    final esPsicologo = _role == 'Psicólogo';

    return Scaffold(
      backgroundColor: _beige,
      body: IndexedStack(
        index: _navIndex,
        children: [
          _buildDashboard(context, nombre, initial, esPsicologo),
          if (esPsicologo)
            ManageAvailabilityScreen(
              firestoreReady: true,
              psychologistId: user?.uid ?? 'psicologo-demo',
            )
          else
            _buildPlaceholder('Mis Citas', Icons.calendar_month_rounded),
          _buildPlaceholder('Explorar', Icons.explore_rounded),
          _buildProfileTab(user),
        ],
      ),
      bottomNavigationBar: _buildNavBar(esPsicologo),
    );
  }

  // ── DASHBOARD ────────────────────────────────────────────────────────────────
  Widget _buildDashboard(
    BuildContext context,
    String nombre,
    String initial,
    bool esPsicologo,
  ) {
    return CustomScrollView(
      slivers: [
        // Header degradado
        SliverToBoxAdapter(child: _buildHeader(nombre, initial, esPsicologo)),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 24),
              _buildMoodCard(),
              const SizedBox(height: 28),
              _sectionTitle('Herramientas'),
              const SizedBox(height: 14),
              _buildToolGrid(esPsicologo),
              const SizedBox(height: 28),
              _buildQuoteCard(),
              if (esPsicologo) ...[
                const SizedBox(height: 28),
                _buildPsicoCard(),
              ],
              const SizedBox(height: 100),
            ]),
          ),
        ),
      ],
    );
  }

  // ── HEADER ───────────────────────────────────────────────────────────────────
  Widget _buildHeader(String nombre, String initial, bool esPsicologo) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_verdeDark, _verde],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hola, ${nombre.split(' ').first} 👋',
                      style: GoogleFonts.outfit(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      esPsicologo
                          ? 'Panel del psicólogo'
                          : '¿Cómo te sientes hoy?',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                    if (!_loadingRole) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _role,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Logout + Avatar
              Row(
                children: [
                  // Botón cerrar sesión
                  GestureDetector(
                    onTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          title: Text('Cerrar sesión',
                              style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold)),
                          content: Text(
                            '¿Estás seguro que deseas cerrar sesión?',
                            style: GoogleFonts.outfit(fontSize: 14),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text('Cancelar',
                                  style: GoogleFonts.outfit(color: _textMid)),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text('Salir',
                                  style: GoogleFonts.outfit(
                                      color: Colors.redAccent,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await FirebaseAuth.instance.signOut();
                      }
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.15),
                      ),
                      child: const Icon(
                        Icons.power_settings_new_rounded,
                        color: Colors.white70,
                        size: 20,
                      ),
                    ),
                  ),
                  // Avatar
                  GestureDetector(
                    onTap: () => setState(() => _navIndex = 3),
                    child: ScaleTransition(
                      scale: _pulseAnim,
                      child: Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.25),
                          border: Border.all(color: Colors.white60, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            initial,
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── TARJETA ESTADO ÁNIMO ─────────────────────────────────────────────────────
  Widget _buildMoodCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _verde.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _verde.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.favorite_rounded,
                    color: _verde, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                'Estado de ánimo',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _textDark,
                ),
              ),
              const Spacer(),
              if (_selectedMood >= 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _verde.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '✓ Registrado',
                    style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: _verde,
                        fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Toca cómo te sientes ahora',
            style: GoogleFonts.outfit(fontSize: 13, color: _textMid),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_moods.length, (i) {
              final selected = _selectedMood == i;
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedMood = i);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          '${_moods[i]['emoji']} ${_moods[i]['label']} registrado'),
                      backgroundColor: _verde,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? _verde.withOpacity(0.15)
                        : Colors.grey.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected ? _verde : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _moods[i]['emoji'] as String,
                        style: TextStyle(
                            fontSize: selected ? 26 : 22),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _moods[i]['label'] as String,
                        style: GoogleFonts.outfit(
                          fontSize: 9,
                          color: selected ? _verde : _textMid,
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ── HERRAMIENTAS ─────────────────────────────────────────────────────────────
  Widget _buildToolGrid(bool esPsicologo) {
    final tools = esPsicologo
        ? [
            {
              'icon': Icons.calendar_today_rounded,
              'label': 'Disponibilidad',
              'sub': 'Gestiona tus horarios',
              'color': _verde,
              'bg': const Color(0xFFEAF4EF),
              'route': 'disponibilidad',
            },
            {
              'icon': Icons.people_rounded,
              'label': 'Mis Pacientes',
              'sub': 'Ver lista completa',
              'color': _lavanda,
              'bg': _lavandaBg,
              'route': null,
            },
            {
              'icon': Icons.bar_chart_rounded,
              'label': 'Estadísticas',
              'sub': 'Actividad del mes',
              'color': _amber,
              'bg': const Color(0xFFFDF3E8),
              'route': null,
            },
            {
              'icon': Icons.chat_bubble_rounded,
              'label': 'Mensajes',
              'sub': 'Bandeja de entrada',
              'color': const Color(0xFF7BB5D4),
              'bg': const Color(0xFFEBF5FB),
              'route': null,
            },
          ]
        : [
            {
              'icon': Icons.self_improvement_rounded,
              'label': 'Respiración',
              'sub': 'Ejercicios guiados',
              'color': _verde,
              'bg': const Color(0xFFEAF4EF),
              'route': null,
            },
            {
              'icon': Icons.book_rounded,
              'label': 'Diario',
              'sub': 'Escribe tus pensamientos',
              'color': _lavanda,
              'bg': _lavandaBg,
              'route': null,
            },
            {
              'icon': Icons.headphones_rounded,
              'label': 'Meditación',
              'sub': 'Sesiones de calma',
              'color': const Color(0xFF9FC4B7),
              'bg': const Color(0xFFEDF5F2),
              'route': null,
            },
            {
              'icon': Icons.bar_chart_rounded,
              'label': 'Progreso',
              'sub': 'Tu historial emocional',
              'color': _amber,
              'bg': const Color(0xFFFDF3E8),
              'route': null,
            },
          ];

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      childAspectRatio: 1.45,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: tools.map((t) => _ToolTile(tool: t)).toList(),
    );
  }

  // ── FRASE DEL DÍA ────────────────────────────────────────────────────────────
  Widget _buildQuoteCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _lavanda.withOpacity(0.15),
            _lavanda.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _lavanda.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _lavanda.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.format_quote_rounded,
                color: _lavanda, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Frase del día',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _lavanda,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _todayQuote,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: _textDark,
                    height: 1.6,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── TARJETA PSICÓLOGO ────────────────────────────────────────────────────────
  Widget _buildPsicoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_verdeDark, _verde],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gestiona tu disponibilidad',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Configura los horarios en que\natiendes a tus pacientes.',
                  style: GoogleFonts.outfit(
                      fontSize: 13, color: Colors.white70, height: 1.5),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () => setState(() => _navIndex = 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Ir a disponibilidad →',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: _verdeDark,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.calendar_month_rounded,
              size: 60, color: Colors.white24),
        ],
      ),
    );
  }

  // ── TAB PERFIL ───────────────────────────────────────────────────────────────
  Widget _buildProfileTab(User? user) {
    if (user == null) return const SizedBox();
    return ViewProfileScreen(uid: user.uid, isOwnProfile: true);
  }

  // ── PLACEHOLDER ──────────────────────────────────────────────────────────────
  Widget _buildPlaceholder(String label, IconData icon) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: _verde.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text(
            label,
            style: GoogleFonts.outfit(
                fontSize: 20, fontWeight: FontWeight.bold, color: _textMid),
          ),
          const SizedBox(height: 8),
          Text(
            'Próximamente disponible',
            style: GoogleFonts.outfit(fontSize: 14, color: _textMid),
          ),
        ],
      ),
    );
  }

  // ── NAV BAR ──────────────────────────────────────────────────────────────────
  Widget _buildNavBar(bool esPsicologo) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                label: 'Inicio',
                selected: _navIndex == 0,
                onTap: () => setState(() => _navIndex = 0),
              ),
              _NavItem(
                icon: esPsicologo
                    ? Icons.calendar_month_rounded
                    : Icons.event_available_rounded,
                label: esPsicologo ? 'Horarios' : 'Citas',
                selected: _navIndex == 1,
                onTap: () => setState(() => _navIndex = 1),
              ),
              _NavItem(
                icon: Icons.explore_rounded,
                label: 'Explorar',
                selected: _navIndex == 2,
                onTap: () => setState(() => _navIndex = 2),
              ),
              _NavItem(
                icon: Icons.person_rounded,
                label: 'Perfil',
                selected: _navIndex == 3,
                onTap: () => setState(() => _navIndex = 3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── SECTION TITLE ────────────────────────────────────────────────────────────
  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: GoogleFonts.outfit(
        fontSize: 17,
        fontWeight: FontWeight.bold,
        color: _textDark,
      ),
    );
  }
}

// ── TOOL TILE ─────────────────────────────────────────────────────────────────
class _ToolTile extends StatelessWidget {
  final Map<String, dynamic> tool;
  const _ToolTile({required this.tool});

  @override
  Widget build(BuildContext context) {
    final color  = tool['color'] as Color;
    final bg     = tool['bg'] as Color;

    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Próximamente: ${tool['label']}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: color,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(tool['icon'] as IconData, color: color, size: 20),
            ),
            const Spacer(),
            Text(
              tool['label'] as String,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E2D28),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              tool['sub'] as String,
              style: GoogleFonts.outfit(
                  fontSize: 10, color: const Color(0xFF6B7C74)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── NAV ITEM ──────────────────────────────────────────────────────────────────
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String   label;
  final bool     selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  static const Color _verde = Color(0xFF5BA98B);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _verde.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: selected ? _verde : const Color(0xFFB0BDB8),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 10,
                color: selected ? _verde : const Color(0xFFB0BDB8),
                fontWeight:
                    selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
