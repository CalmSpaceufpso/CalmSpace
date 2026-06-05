import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // ── PALETA (idéntica al RegisterScreen) ──────────────────────────────────────
  static const Color _primary  = Color(0xFF1D35B4);
  static const Color _bg       = Color(0xFFF4F6FB);
  static const Color _textMain = Color(0xFF1E293B);
  static const Color _textSub  = Color(0xFF64748B);
  static const Color _fieldBg  = Color(0xFFF1F4FC);
  static const Color _fieldBdr = Color(0xFFDDE3F5);

  // ── FORM ─────────────────────────────────────────────────────────────────────
  final _formKey      = GlobalKey<FormState>();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _isLoading = false;
  bool _obscure   = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email:    _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
      );
      // El StreamBuilder en main.dart redirige automáticamente al Home
    } on FirebaseAuthException catch (e) {
      // ignore: avoid_print
      print('[LoginScreen] FirebaseAuthException: code=${e.code} msg=${e.message}');
      _err(switch (e.code) {
        'user-not-found'      => 'Usuario no encontrado.',
        'wrong-password'      => 'Contraseña incorrecta.',
        'invalid-email'       => 'El formato del correo no es válido.',
        'too-many-requests'   => 'Demasiados intentos. Intenta más tarde.',
        'invalid-credential'  => 'Correo o contraseña incorrectos.',
        'user-disabled'       => 'Esta cuenta ha sido deshabilitada.',
        'network-request-failed' => 'Sin conexión a internet.',
        _                     => 'Error: ${e.code}',
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
                  const Text('Bienvenido', style: TextStyle(
                    fontSize: 28, fontWeight: FontWeight.w800,
                    color: _primary, letterSpacing: -0.5)),
                  const SizedBox(height: 4),
                  const Text('Inicia sesión en tu espacio de bienestar',
                    style: TextStyle(fontSize: 13, color: _textSub),
                    textAlign: TextAlign.center),
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
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // ── CAMPOS ─────────────────────────────────────────
                        _field(
                          ctrl: _emailCtrl,
                          hint: 'Correo electrónico',
                          icon: Icons.alternate_email_rounded,
                          type: TextInputType.emailAddress,
                          validator: (v) {
                            if (v!.trim().isEmpty) return 'Requerido';
                            if (!v.contains('@')) return 'Correo inválido';
                            return null;
                          },
                        ),
                        _field(
                          ctrl: _passwordCtrl,
                          hint: 'Contraseña',
                          icon: Icons.lock_outline_rounded,
                          obscure: _obscure,
                          action: IconButton(
                            icon: Icon(
                              _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                              color: _textSub, size: 18),
                            onPressed: () =>
                              setState(() => _obscure = !_obscure)),
                          validator: (v) =>
                            v!.length < 6 ? 'Mínimo 6 caracteres' : null,
                        ),

                        const SizedBox(height: 8),

                        // ── BOTÓN INGRESAR ─────────────────────────────────
                        SizedBox(
                          width: double.infinity, height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primary, elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14))),
                            child: _isLoading
                              ? const SizedBox(width: 20, height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5, color: Colors.white))
                              : const Text('Ingresar', style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── REGISTRO LINK ─────────────────────────────────────────
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/register'),
                    child: const Text.rich(TextSpan(
                      text: '¿No tienes cuenta? ',
                      style: TextStyle(fontSize: 14, color: _textSub),
                      children: [
                        TextSpan(
                          text: 'Regístrate',
                          style: TextStyle(
                            color: _primary,
                            fontWeight: FontWeight.w700)),
                      ],
                    )),
                  ),

                  const SizedBox(height: 20),

                  // ── SEPARADOR ─────────────────────────────────────────────
                  Row(children: [
                    Expanded(child: Divider(
                      color: _textSub.withOpacity(0.2))),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('o continúa con',
                        style: TextStyle(fontSize: 12, color: _textSub))),
                    Expanded(child: Divider(
                      color: _textSub.withOpacity(0.2))),
                  ]),
                  const SizedBox(height: 14),

                  // ── GOOGLE ────────────────────────────────────────────────
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

  InputDecoration _deco({required String hint, required IconData icon}) =>
    InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFADB5C9), fontSize: 14),
      prefixIcon: Icon(icon, color: _primary.withOpacity(0.5), size: 18),
      filled: true, fillColor: _fieldBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _fieldBdr)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _fieldBdr)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _primary, width: 1.8)),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent)),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.8)),
      contentPadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      isDense: true,
    );

  Widget _field({
    required TextEditingController ctrl,
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputType? type,
    Widget? action,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: ctrl,
        obscureText: obscure,
        keyboardType: type,
        validator: validator,
        style: const TextStyle(
          fontSize: 14, color: _textMain, fontWeight: FontWeight.w500),
        decoration: _deco(hint: hint, icon: icon).copyWith(suffixIcon: action),
      ),
    );
  }
}
