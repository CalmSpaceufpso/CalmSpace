import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class RegisterScreen extends StatefulWidget {
  final FirebaseAuth? auth;
  final FirebaseFirestore? firestore;

  const RegisterScreen({super.key, this.auth, this.firestore});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

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
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color verdeBase = Color(0xFF6BAE8E);
    const Color beige = Color(0xFFF7F3EE);
    const Color textoPrimario = Color(0xFF2D3A32);

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
        ),
      ),
    );
  }
}
