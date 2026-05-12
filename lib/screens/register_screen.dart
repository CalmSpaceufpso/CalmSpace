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
  final _licenseCtrl  = TextEditingController();
  final _phoneCtrl    = TextEditingController();

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
    final isPsi = _role == 'Psicólogo';

    return Scaffold(
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
                        color: const Color(0xFF0F172A).withOpacity(0.06),
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
                    Expanded(child: Divider(color: _textSub.withOpacity(0.2))),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('o continúa con', style: TextStyle(fontSize: 12, color: _textSub))),
                    Expanded(child: Divider(color: _textSub.withOpacity(0.2))),
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
                          color: Colors.black.withOpacity(0.04),
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
              color: Colors.black.withOpacity(0.06),
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
      prefixIcon: Icon(icon, color: _primary.withOpacity(0.5), size: 18),
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
}
