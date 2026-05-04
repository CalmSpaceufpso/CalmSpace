import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
 feature/HU-01-registro-email
import 'package:flutter_svg/flutter_svg.dart';

class RegisterScreen extends StatefulWidget {
  final FirebaseAuth? auth;
  final FirebaseFirestore? firestore;
  const RegisterScreen({super.key, this.auth, this.firestore});

import 'package:google_sign_in/google_sign_in.dart';

class RegisterScreen extends StatefulWidget {
 feature/HU-01-registro-email
  const RegisterScreen({super.key});
 main

  final FirebaseAuth? auth;
  final FirebaseFirestore? firestore;

  const RegisterScreen({super.key, this.auth, this.firestore});
 main

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // ── PALETA ───────────────────────────────────────────────────────────────────
  static const Color _primary  = Color(0xFF1D35B4);
  static const Color _bg       = Color(0xFFF4F6FB);
  static const Color _textMain = Color(0xFF1E293B);
  static const Color _textSub  = Color(0xFF64748B);
  static const Color _fieldBg  = Color(0xFFF1F4FC);
  static const Color _fieldBdr = Color(0xFFDDE3F5);

  // ── FORM ──────────────────────────────────────────────────────────────────────
  final _formKey      = GlobalKey<FormState>();
  final _nameCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _licenseCtrl  = TextEditingController(); // Cédula profesional
  final _phoneCtrl    = TextEditingController(); // Teléfono psicólogo

 feature/HU-01-registro-email
  bool    _isLoading = false;
  bool    _obscure   = true;
  bool    _terms     = false;
  String  _role      = 'Paciente';

  @override
  void dispose() {
    for (final c in [_nameCtrl, _emailCtrl, _passwordCtrl, _licenseCtrl, _phoneCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_terms) { _err('Debes aceptar los Términos y Condiciones.'); return; }
    setState(() => _isLoading = true);
    try {
      final auth  = widget.auth      ?? FirebaseAuth.instance;
      final db    = widget.firestore ?? FirebaseFirestore.instance;
      final isPsi = _role == 'Psicólogo';

      final cred = await auth.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(), password: _passwordCtrl.text.trim());
      await cred.user!.updateDisplayName(_nameCtrl.text.trim());

      await db.collection('users').doc(cred.user!.uid).set({
        'name'     : _nameCtrl.text.trim(),
        'email'    : cred.user!.email,
        'role'     : _role,
        'status'   : isPsi ? 'pendiente' : 'activo',
        'createdAt': FieldValue.serverTimestamp(),
        if (isPsi) ...{
          // Especialidad y datos adicionales se completan en el perfil profesional (Paso 2)
          if (_licenseCtrl.text.isNotEmpty) 'license': _licenseCtrl.text.trim(),
          if (_phoneCtrl.text.isNotEmpty)   'phone'  : _phoneCtrl.text.trim(),
        },
      });

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, isPsi ? '/pending' : '/home');
    } on FirebaseAuthException catch (e) {
      _err(switch (e.code) {
        'weak-password'        => 'Contraseña muy débil (mín. 6 caracteres).',
        'email-already-in-use' => 'Ya existe una cuenta con este correo.',
        'invalid-email'        => 'El formato del correo no es válido.',
        _                      => 'Ocurrió un error inesperado.',
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);

  bool _isLoading = false;
  String _selectedRole = 'Paciente'; // 'Paciente' o 'Psicólogo'

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authInstance = FirebaseAuth.instance;
      final firestoreInstance = FirebaseFirestore.instance;

      // 1. Crear usuario en Firebase Auth
      UserCredential userCredential = await authInstance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      // 2. Guardar nombre en Authentication
      await userCredential.user!.updateDisplayName(_nameController.text.trim());

      // 3. Guardar datos adicionales en Firestore
      final isPsicologo = _selectedRole == 'Psicólogo';
      await firestoreInstance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
            'name': _nameController.text.trim(),
            'email': userCredential.user!.email,
            'role': _selectedRole,
            // Pacientes se activan de inmediato; psicólogos quedan pendientes
            'status': isPsicologo ? 'pendiente' : 'activo',
            'createdAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Cuenta creada con éxito! Bienvenido a CalmSpace'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pushReplacementNamed(context, '/home');
    } on FirebaseAuthException catch (e) {
      String errorMsg = 'Ocurrió un error inesperado';

      if (e.code == 'weak-password') {
        errorMsg = 'La contraseña es muy débil.';
      } else if (e.code == 'email-already-in-use') {
        errorMsg = 'Ya existe una cuenta con este correo.';
      } else if (e.code == 'invalid-email') {
        errorMsg = 'El formato del correo no es válido.';
      } else if (e.code == 'too-many-requests') {
        errorMsg = 'Demasiados intentos. Intenta más tarde.';
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // GOOGLE SIGN-IN
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await FirebaseAuth.instance.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      debugPrint("Error: ${e.message}");
      return null;
 main
    }
  }

  void _err(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(m, style: const TextStyle(fontWeight: FontWeight.w500)),
    backgroundColor: Colors.redAccent,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));

  // ── BUILD ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
 feature/HU-01-registro-email
    final isPsi = _role == 'Psicólogo';

    return Scaffold(
 feature/HU-01-registro-email
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Form(
              key: _formKey,
              child: Column(
                children: [

                  // ── LOGO + TÍTULO ─────────────────────────────────────────
                  Image.network(
                    'https://i.postimg.cc/sgPdPjqB/LOGO-AZUL.png',
                    height: 60, fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                      const Icon(Icons.spa_rounded, color: _primary, size: 52)),
                  const SizedBox(height: 12),
                  const Text('Crear cuenta', style: TextStyle(
                    fontSize: 28, fontWeight: FontWeight.w800,
                    color: _primary, letterSpacing: -0.5)),
                  const SizedBox(height: 4),
                  const Text('Tu espacio de bienestar emocional',
                    style: TextStyle(fontSize: 13, color: _textSub)),
                  const SizedBox(height: 28),

                  // ── TARJETA ───────────────────────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                        blurRadius: 24, offset: const Offset(0, 8))],
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    child: Column(
                      children: [

                        // ── ROL SELECTOR ───────────────────────────────────
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(16)),
                          child: Row(children: [
                            _rolePill('Paciente', Icons.self_improvement_rounded),
                            _rolePill('Psicólogo', Icons.psychology_rounded),
                          ]),
                        ),
                        const SizedBox(height: 24),

                        // ── CAMPOS COMUNES ─────────────────────────────────
                        _field(ctrl: _nameCtrl, hint: 'Nombre completo',
                          icon: Icons.person_outline_rounded,
                          validator: (v) => v!.trim().isEmpty ? 'Requerido' : null),
                        _field(ctrl: _emailCtrl, hint: 'Correo electrónico',
                          icon: Icons.alternate_email_rounded,
                          type: TextInputType.emailAddress,
                          validator: (v) {
                            if (v!.trim().isEmpty) return 'Requerido';
                            if (!v.contains('@')) return 'Correo inválido';
                            return null;
                          }),
                        _field(ctrl: _passwordCtrl, hint: 'Contraseña',
                          icon: Icons.lock_outline_rounded, obscure: _obscure,
                          action: IconButton(
                            icon: Icon(
                              _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              color: _textSub, size: 18),
                            onPressed: () => setState(() => _obscure = !_obscure)),
                          validator: (v) => v!.length < 6 ? 'Mínimo 6 caracteres' : null),

                        // ── CAMPOS EXTRA PSICÓLOGO ─────────────────────────
                        if (isPsi) ...[
                          const SizedBox(height: 4),
                          // Aviso de verificación
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFC7D2FE))),
                            child: const Row(children: [
                              Icon(Icons.verified_user_outlined, color: _primary, size: 18),
                              SizedBox(width: 10),
                              Expanded(child: Text(
                                'Necesitamos verificar tu identidad como profesional antes de activar tu perfil.',
                                style: TextStyle(fontSize: 12, color: _primary, height: 1.4))),
                            ]),
                          ),
                          const SizedBox(height: 16),

                          _field(ctrl: _licenseCtrl, hint: 'Número de tarjeta profesional *',
                            icon: Icons.badge_outlined,
                            type: TextInputType.number,
                            validator: (v) => v!.trim().isEmpty ? 'Requerido para verificación' : null),
                          _field(ctrl: _phoneCtrl, hint: 'Teléfono de contacto *',
                            icon: Icons.phone_iphone_rounded,
                            type: TextInputType.phone,
                            validator: (v) => v!.trim().isEmpty ? 'Requerido para verificación' : null),
                        ],

                        const SizedBox(height: 8),

                        // ── TÉRMINOS ───────────────────────────────────────
                        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                          SizedBox(width: 20, height: 20,
                            child: Checkbox(
                              value: _terms,
                              onChanged: (v) => setState(() => _terms = v ?? false),
                              activeColor: _primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5))),
                          const SizedBox(width: 10),
                          const Expanded(child: Text.rich(TextSpan(
                            text: 'Acepto los ', style: TextStyle(fontSize: 12, color: _textSub),
                            children: [
                              TextSpan(text: 'Términos', style: TextStyle(color: _primary, fontWeight: FontWeight.w600)),
                              TextSpan(text: ' y '),
                              TextSpan(text: 'Privacidad', style: TextStyle(color: _primary, fontWeight: FontWeight.w600)),
                            ],
                          ))),
                        ]),

                        const SizedBox(height: 20),

                        // ── BOTÓN ──────────────────────────────────────────
                        SizedBox(
                          width: double.infinity, height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _register,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primary, elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                            child: _isLoading
                              ? const SizedBox(width: 20, height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                              : const Text('Regístrate', style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── LOGIN LINK ────────────────────────────────────────────
                  GestureDetector(
                    onTap: () => Navigator.pushReplacementNamed(context, '/login'),
                    child: const Text.rich(TextSpan(
                      text: '¿Ya tienes cuenta? ', style: TextStyle(fontSize: 14, color: _textSub),
                      children: [TextSpan(text: 'Inicia sesión',
                        style: TextStyle(color: _primary, fontWeight: FontWeight.w700))],
                    )),
                  ),

                  const SizedBox(height: 20),

                  // ── SOCIAL ────────────────────────────────────────────────
                  Row(children: [
                    Expanded(child: Divider(color: _textSub.withValues(alpha: 0.2))),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('o continúa con', style: TextStyle(fontSize: 12, color: _textSub))),
                    Expanded(child: Divider(color: _textSub.withValues(alpha: 0.2))),
                  ]),
                  const SizedBox(height: 14),

                  GestureDetector(
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Próximamente'))),
                    child: Container(
                      width: 56, height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _fieldBdr),
                        boxShadow: [BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8, offset: const Offset(0, 3))]),
                      child: Center(
                        child: SvgPicture.network(
                          'https://www.vectorlogo.zone/logos/google/google-icon.svg',
                          width: 22, height: 22)),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────────

  Widget _rolePill(String label, IconData icon) {
    final isSel = _role == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _role = label),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: isSel ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSel ? [BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6, offset: const Offset(0, 2))] : []),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 16, color: isSel ? _primary : _textSub),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(
              fontSize: 13,
              fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
              color: isSel ? _primary : _textSub)),
          ]),
        ),
      ),
    );
  }

  InputDecoration _deco({required String hint, required IconData icon}) =>
    InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFADB5C9), fontSize: 14),
      prefixIcon: Icon(icon, color: _primary.withValues(alpha: 0.5), size: 18),
      filled: true, fillColor: _fieldBg,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _fieldBdr)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _fieldBdr)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _primary, width: 1.8)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent, width: 1.8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      isDense: true,
    );

  Widget _field({
    required TextEditingController ctrl, required String hint, required IconData icon,
    bool obscure = false, bool readOnly = false, TextInputType? type,
    Widget? action, VoidCallback? onTap, String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: ctrl, obscureText: obscure, readOnly: readOnly,
        keyboardType: type, onTap: onTap, validator: validator,
        style: const TextStyle(fontSize: 14, color: _textMain, fontWeight: FontWeight.w500),
        decoration: _deco(hint: hint, icon: icon).copyWith(suffixIcon: action),
      ),
    );
  }

  // ── PICKER (Bottom Sheet en lugar de dropdown nativo) ──────────────────────
  Future<void> _showPicker({
    required String title,
    required List<String> items,
    required String? current,
    required ValueChanged<String?> onSelected,
  }) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFDDE3F5),
                borderRadius: BorderRadius.circular(2))),
            // Title
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 20, right: 20),
              child: Text(title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _textMain)),
            ),
            const Divider(height: 1, color: Color(0xFFEEF2FF)),
            const SizedBox(height: 4),
            // Items
            ...items.map((item) {
              final isSel = item == current;
              return InkWell(
                onTap: () {
                  onSelected(item);
                  Navigator.pop(ctx);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isSel ? _primary.withValues(alpha: 0.06) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Text(item,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
                          color: isSel ? _primary : _textMain)),
                    ),
                    if (isSel)
                      const Icon(Icons.check_circle_rounded, color: _primary, size: 20),
                  ]),
                ),
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // Campo que abre el picker al tocarse (sustituye al dropdown nativo)
  Widget _pickerField({
    required String? value,
    required String hint,
    required IconData icon,
    required List<String> items,
    required String title,
    required ValueChanged<String?> onChanged,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: FormField<String>(
        initialValue: value,
        validator: validator,
        builder: (state) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () async {
                await _showPicker(
                  title: title, items: items,
                  current: value, onSelected: (v) {
                    onChanged(v);
                    state.didChange(v);
                  });
              },
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: _fieldBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: state.hasError ? Colors.redAccent : _fieldBdr,
                    width: state.hasError ? 1.8 : 1),
                ),
                child: Row(children: [
                  Icon(icon, color: _primary.withValues(alpha: 0.5), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      value ?? hint,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: value != null ? FontWeight.w500 : FontWeight.w400,
                        color: value != null ? _textMain : const Color(0xFFADB5C9)),
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFFADB5C9), size: 20),
                ]),
              ),

      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        title: const Text('Crear Cuenta'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 40),
                const Text(
                  'Regístrate en CalmSpace',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 40),

 feature/HU-03-login
                // Campo Nombre

                // NOMBRE
 main
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) =>
                      value!.isEmpty ? 'Ingresa tu nombre' : null,
                ),

    const Color verdeBase = Color(0xFF6BAE8E);
    const Color beige = Color(0xFFF7F3EE);
    const Color textoPrimario = Color(0xFF2D3A32);
 main

    return Scaffold(
      backgroundColor: beige,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header Gradient
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 40,
                ),
                decoration: const BoxDecoration(
                  color: verdeBase,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(40),
                    bottomRight: Radius.circular(40),
                  ),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Únete a\nCalmSpace',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Tu espacio seguro comienza aquí',
                      style: TextStyle(fontSize: 16, color: Colors.white70),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const SizedBox(height: 10),

                      // Selector de Rol
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '¿Cómo quieres usar CalmSpace?',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textoPrimario,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _RoleCard(
                            label: 'Soy Paciente',
                            icon: Icons.self_improvement_rounded,
                            selected: _selectedRole == 'Paciente',
                            onTap: () => setState(() => _selectedRole = 'Paciente'),
                          ),
                          const SizedBox(width: 12),
                          _RoleCard(
                            label: 'Soy Psicólogo',
                            icon: Icons.psychology_outlined,
                            selected: _selectedRole == 'Psicólogo',
                            onTap: () => setState(() => _selectedRole = 'Psicólogo'),
                          ),
                        ],
                      ),
                      if (_selectedRole == 'Psicólogo') ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF8E1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFFCC02)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline, color: Color(0xFFE65100), size: 18),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Tu perfil será revisado por un administrador antes de activarse.',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF5D4037)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),

                      // Campo Nombre

                      TextFormField(
                        controller: _nameController,
                        style: const TextStyle(color: textoPrimario),
                        decoration: InputDecoration(
                          labelText: 'Nombre completo',
                          labelStyle: const TextStyle(color: Colors.black54),
                          prefixIcon: const Icon(
                            Icons.person_outline,
                            color: verdeBase,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: verdeBase,
                              width: 2,
                            ),
                          ),
                        ),
                        validator: (value) =>
                            value!.isEmpty ? 'Ingresa tu nombre' : null,
                      ),

                      const SizedBox(height: 20),

                      // Campo Email
                      TextFormField(
                        controller: _emailController,
                        style: const TextStyle(color: textoPrimario),
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Correo electrónico',
                          labelStyle: const TextStyle(color: Colors.black54),
                          prefixIcon: const Icon(
                            Icons.email_outlined,
                            color: verdeBase,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: verdeBase,
                              width: 2,
                            ),
                          ),
                        ),
                        validator: (value) =>
                            value!.isEmpty ? 'Ingresa tu correo' : null,
                      ),

                      const SizedBox(height: 20),

                      // Campo Contraseña
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        style: const TextStyle(color: textoPrimario),
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          labelStyle: const TextStyle(color: Colors.black54),
                          prefixIcon: const Icon(
                            Icons.lock_outline,
                            color: verdeBase,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: verdeBase,
                              width: 2,
                            ),
                          ),
                        ),
                        validator: (value) =>
                            value!.length < 6 ? 'Mínimo 6 caracteres' : null,
                      ),

                      const SizedBox(height: 40),

                      // Botón Registrarse
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _register,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: verdeBase,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 3,
                                  ),
                                )
                              : const Text(
                                  'Crear Cuenta',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Separador
                      Row(
                        children: [
                          Expanded(child: Divider(color: Colors.grey.shade300)),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'O regístrate con',
                              style: TextStyle(color: Colors.black54),
                            ),
                          ),
                          Expanded(child: Divider(color: Colors.grey.shade300)),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // GOOGLE SIGN-IN
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await signInWithGoogle();
                          },
                          icon: Image.network(
                            'https://cdn-icons-png.flaticon.com/512/3002/3002211.png',
                            height: 24,
                          ),
                          label: const Text(
                            "Continuar con Google",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: textoPrimario,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Enlace a login
                      TextButton(
                        onPressed: () =>
                            Navigator.pushReplacementNamed(context, '/login'),
                        child: RichText(
                          text: const TextSpan(
                            text: '¿Ya tienes cuenta? ',
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 15,
                            ),
                            children: [
                              TextSpan(
                                text: 'Inicia sesión',
                                style: TextStyle(
                                  color: verdeBase,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                     ],
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

// ── WIDGET TARJETA DE ROL ─────────────────────────────────────────────────────
class _RoleCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

 feature/HU-01-registro-email
                // GOOGLE SIGN-IN
                ElevatedButton.icon(
                  onPressed: () async {
                    await signInWithGoogle();
                  },
                  icon: Image.network(
                    'https://cdn-icons-png.flaticon.com/512/281/281764.png',
                    height: 24,
                  ),
                  label: const Text("Continuar con Google"),
          main
                ),
              ],
 main
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 12),
                child: Text(state.errorText!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
          ],

  @override
  Widget build(BuildContext context) {
    const Color verdeBase = Color(0xFF6BAE8E);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFE8F5EE) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? verdeBase : Colors.grey.shade300,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 28,
                color: selected ? verdeBase : Colors.grey,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? verdeBase : Colors.grey,
                ),
              ),
            ],
          ),
 main
        ),
      ),
    );
  }
}
