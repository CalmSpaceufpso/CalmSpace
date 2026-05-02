import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/flutter_svg.dart';

class RegisterScreen extends StatefulWidget {
  final FirebaseAuth? auth;
  final FirebaseFirestore? firestore;

  const RegisterScreen({super.key, this.auth, this.firestore});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // ── PALETA DEFINITIVA (Contraste y Elegancia) ───────────────────────────
  static const Color _primary    = Color(0xFF1D35B4); // Azul fuerte del mockup
  static const Color _primaryLgt = Color(0xFF3B56E5); 
  static const Color _bg         = Color(0xFFF4F6FB); // Fondo base
  static const Color _cardBg     = Colors.white;      // Contraste puro para el form
  static const Color _textMain   = Color(0xFF1E293B);
  static const Color _textSub    = Color(0xFF64748B);
  static const Color _fieldBg    = Color(0xFFF8FAFC); // Fondo sutil para campos
  static const Color _fieldBdr   = Color(0xFFE2E8F0);

  // ── CONTROLADORES ──────────────────────────────────────────────────────────
  final _formKey      = GlobalKey<FormState>();
  final _nameCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  final _birthCtrl    = TextEditingController();
  final _yearsCtrl    = TextEditingController();
  final _descCtrl     = TextEditingController();

  bool    _isLoading     = false;
  bool    _obscurePass   = true;
  bool    _terms         = false;
  
  String  _role          = 'Paciente';
  String? _gender;
  String? _specialty;
  String? _modality;

  static const _genders = ['Masculino', 'Femenino', 'No binario', 'Prefiero no decirlo'];
  static const _specialties = [
    'Psicología Clínica', 'Psicología Infantil', 'Psicología Familiar',
    'Cognitivo-Conductual', 'Humanista', 'Neuropsicología', 'Otra',
  ];
  static const _modalities = ['Presencial', 'Virtual', 'Híbrida'];

  @override
  void dispose() {
    for (final c in [_nameCtrl, _emailCtrl, _passwordCtrl,
                     _phoneCtrl, _birthCtrl, _yearsCtrl, _descCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── REGISTRO ───────────────────────────────────────────────────────────────
  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_terms) {
      _showError('Debes aceptar los Términos y Condiciones para continuar.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final auth      = widget.auth      ?? FirebaseAuth.instance;
      final firestore = widget.firestore ?? FirebaseFirestore.instance;
      final isPsi     = _role == 'Psicólogo';

      final cred = await auth.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(), password: _passwordCtrl.text.trim());
      await cred.user!.updateDisplayName(_nameCtrl.text.trim());

      final data = <String, dynamic>{
        'name'     : _nameCtrl.text.trim(),
        'email'    : cred.user!.email,
        'role'     : _role,
        'status'   : isPsi ? 'pendiente' : 'activo',
        'createdAt': FieldValue.serverTimestamp(),
        if (!isPsi) ...{
          if (_gender != null)             'gender'   : _gender,
          if (_phoneCtrl.text.isNotEmpty)  'phone'    : _phoneCtrl.text.trim(),
          if (_birthCtrl.text.isNotEmpty)  'birthDate': _birthCtrl.text.trim(),
        },
        if (isPsi) ...{
          if (_specialty != null)          'specialty'      : _specialty,
          if (_yearsCtrl.text.isNotEmpty)  'experienceYears': int.tryParse(_yearsCtrl.text.trim()),
          if (_modality != null)           'modality'       : _modality,
          if (_descCtrl.text.isNotEmpty)   'description'    : _descCtrl.text.trim(),
        },
      };

      await firestore.collection('users').doc(cred.user!.uid).set(data);
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, isPsi ? '/pending' : '/home');
    } on FirebaseAuthException catch (e) {
      _showError(switch (e.code) {
        'weak-password'        => 'La contraseña es muy débil (mín. 6 caracteres).',
        'email-already-in-use' => 'Ya existe una cuenta con este correo.',
        'invalid-email'        => 'El formato del correo no es válido.',
        _                      => 'Ocurrió un error inesperado.',
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w500)), 
      backgroundColor: Colors.redAccent, 
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
    ));

  Future<void> _pickDate() async {
    final p = await showDatePicker(
      context: context,
      initialDate: DateTime(DateTime.now().year - 20),
      firstDate: DateTime(1940),
      lastDate: DateTime(DateTime.now().year - 10),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: _primary)),
        child: child!),
    );
    if (p != null) {
      _birthCtrl.text = '${p.day.toString().padLeft(2,'0')}/${p.month.toString().padLeft(2,'0')}/${p.year}';
    }
  }

  // ── BUILD ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isPsi = _role == 'Psicólogo';
    
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 10),
                
                // ── LOGO Y TÍTULO FUERA DE LA TARJETA (Para dar profundidad) ──
                const Icon(Icons.spa_rounded, color: _primary, size: 40),
                const SizedBox(height: 12),
                const Text('Crear cuenta',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: _primary, letterSpacing: -0.5)),
                const SizedBox(height: 8),
                const Text('Da el primer paso para sentirte mejor',
                  style: TextStyle(fontSize: 15, color: _textSub, fontWeight: FontWeight.w500)),
                
                const SizedBox(height: 32),

                // ── TARJETA DEL FORMULARIO (Alto Contraste) ───────────────────
                Container(
                  decoration: BoxDecoration(
                    color: _cardBg,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.06), blurRadius: 30, offset: const Offset(0, 10)),
                      BoxShadow(color: _primary.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      
                      // ── SELECTOR DE ROL ─────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(16)),
                        child: Row(
                          children: [
                            _rolePill('Paciente', Icons.self_improvement_rounded),
                            _rolePill('Psicólogo', Icons.psychology_rounded),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // ── CAMPOS BÁSICOS ──────────────────────────────────────
                      _inputField(
                        ctrl: _nameCtrl, label: 'Nombre completo', icon: Icons.person_rounded,
                        validator: (v) => v!.trim().isEmpty ? 'Requerido' : null),
                      
                      _inputField(
                        ctrl: _emailCtrl, label: 'Correo electrónico', icon: Icons.alternate_email_rounded,
                        type: TextInputType.emailAddress,
                        validator: (v) {
                          if (v!.trim().isEmpty) return 'Requerido';
                          if (!v.contains('@')) return 'Correo inválido';
                          return null;
                        }),

                      _inputField(
                        ctrl: _passwordCtrl, label: 'Contraseña', icon: Icons.lock_rounded, obscure: _obscurePass,
                        action: IconButton(
                          icon: Icon(_obscurePass ? Icons.visibility_rounded : Icons.visibility_off_rounded, color: _textSub),
                          onPressed: () => setState(() => _obscurePass = !_obscurePass),
                        ),
                        validator: (v) => v!.length < 6 ? 'Mínimo 6 caracteres' : null),

                      // ── CAMPOS DINÁMICOS ────────────────────────────────────
                      if (!isPsi) ...[
                        Row(
                          children: [
                            Expanded(child: _dropField(label: 'Género (Opcional)', value: _gender, items: _genders, icon: Icons.wc_rounded, onChanged: (v) => setState(() => _gender = v))),
                            const SizedBox(width: 16),
                            Expanded(child: _inputField(ctrl: _birthCtrl, label: 'Nacimiento', icon: Icons.calendar_month_rounded, readOnly: true, onTap: _pickDate)),
                          ],
                        ),
                        _inputField(ctrl: _phoneCtrl, label: 'Teléfono (Opcional)', icon: Icons.phone_rounded, type: TextInputType.phone),
                      ],

                      if (isPsi) ...[
                        Row(
                          children: [
                            Expanded(child: _dropField(label: 'Especialidad *', value: _specialty, items: _specialties, icon: Icons.workspace_premium_rounded, onChanged: (v) => setState(() => _specialty = v), validator: (v) => v == null ? 'Req' : null)),
                            const SizedBox(width: 16),
                            Expanded(child: _dropField(label: 'Modalidad *', value: _modality, items: _modalities, icon: Icons.laptop_mac_rounded, onChanged: (v) => setState(() => _modality = v), validator: (v) => v == null ? 'Req' : null)),
                          ],
                        ),
                        _inputField(ctrl: _yearsCtrl, label: 'Años experiencia *', icon: Icons.timeline_rounded, type: TextInputType.number, validator: (v) => v!.isEmpty ? 'Requerido' : null),
                      ],

                      const SizedBox(height: 8),

                      // ── TÉRMINOS ────────────────────────────────────────────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 24, height: 24,
                            child: Checkbox(
                              value: _terms, onChanged: (v) => setState(() => _terms = v ?? false),
                              activeColor: _primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text.rich(TextSpan(
                              text: 'Acepto los ', style: TextStyle(fontSize: 13, color: _textSub, height: 1.4),
                              children: [
                                TextSpan(text: 'Términos', style: TextStyle(color: _primary, fontWeight: FontWeight.w600)),
                                TextSpan(text: ' y '),
                                TextSpan(text: 'Privacidad', style: TextStyle(color: _primary, fontWeight: FontWeight.w600)),
                              ],
                            )),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // ── BOTÓN REGÍSTRATE ────────────────────────────────────
                      Container(
                        width: double.infinity, height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: _primary.withValues(alpha: 0.25), blurRadius: 20, offset: const Offset(0, 8))],
                        ),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _register,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: _isLoading
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                            : const Text('Regístrate', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5)),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // ── LOGIN LINK Y SOCIAL (Fuera de la tarjeta) ────────────────
                GestureDetector(
                  onTap: () => Navigator.pushReplacementNamed(context, '/login'),
                  child: const Text.rich(TextSpan(
                    text: '¿Ya tienes una cuenta? ', style: TextStyle(fontSize: 15, color: _textSub, fontWeight: FontWeight.w500),
                    children: [
                      TextSpan(text: 'Inicia sesión', style: TextStyle(color: _primary, fontWeight: FontWeight.w800)),
                    ],
                  )),
                ),
                
                const SizedBox(height: 32),

                Row(
                  children: [
                    Expanded(child: Divider(color: _textSub.withValues(alpha: 0.2))),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('o continúa con', style: TextStyle(fontSize: 13, color: _textSub, fontWeight: FontWeight.w600)),
                    ),
                    Expanded(child: Divider(color: _textSub.withValues(alpha: 0.2))),
                  ],
                ),

                const SizedBox(height: 24),

                // ── BOTONES SOCIALES DEFINITIVOS ──────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _socialBox(
                      child: SvgPicture.network('https://www.vectorlogo.zone/logos/google/google-icon.svg', width: 26, height: 26),
                    ),
                    const SizedBox(width: 20),
                    _socialBox(
                      child: const Icon(Icons.facebook_rounded, color: Color(0xFF1877F2), size: 30),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── HELPERS UI ──────────────────────────────────────────────────────────────

  Widget _rolePill(String label, IconData icon) {
    final isSel = _role == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _role = label),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSel ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSel ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))] : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: isSel ? _primary : _textSub),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 14, fontWeight: isSel ? FontWeight.w700 : FontWeight.w600, color: isSel ? _primary : _textSub)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inputField({
    required TextEditingController ctrl, required String label, required IconData icon,
    bool obscure = false, bool readOnly = false, TextInputType? type,
    Widget? action, VoidCallback? onTap, String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: ctrl, obscureText: obscure, readOnly: readOnly, keyboardType: type,
        onTap: onTap, validator: validator,
        style: const TextStyle(fontSize: 15, color: _textMain, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: _textSub, fontSize: 14, fontWeight: FontWeight.w400),
          floatingLabelStyle: const TextStyle(color: _primary, fontSize: 13, fontWeight: FontWeight.w700),
          prefixIcon: Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(right: 8, left: 4),
            child: Container(
              decoration: BoxDecoration(color: _primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.all(6),
              child: Icon(icon, color: _primary, size: 18),
            ),
          ),
          suffixIcon: action,
          filled: true, fillColor: _fieldBg,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _fieldBdr, width: 1.5)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _fieldBdr, width: 1)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _primary, width: 2)),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
          focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.redAccent, width: 2)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _dropField({
    required String? value, required List<String> items, required String label, required IconData icon,
    required ValueChanged<String?> onChanged, String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: value, isExpanded: true,
        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _textSub),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: _textSub, fontSize: 14, fontWeight: FontWeight.w400),
          floatingLabelStyle: const TextStyle(color: _primary, fontSize: 13, fontWeight: FontWeight.w700),
          prefixIcon: Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(right: 8, left: 4),
            child: Container(
              decoration: BoxDecoration(color: _primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.all(6),
              child: Icon(icon, color: _primary, size: 18),
            ),
          ),
          filled: true, fillColor: _fieldBg,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _fieldBdr, width: 1.5)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _fieldBdr, width: 1)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _primary, width: 2)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        items: items.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis))).toList(),
        onChanged: onChanged, validator: validator,
      ),
    );
  }

  Widget _socialBox({required Widget child}) {
    return GestureDetector(
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Próximamente'))),
      child: Container(
        width: 64, height: 64,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _fieldBdr),
          boxShadow: [BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.03), blurRadius: 15, offset: const Offset(0, 4))],
        ),
        child: Center(child: child),
      ),
    );
  }
}