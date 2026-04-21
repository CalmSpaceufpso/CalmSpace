import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_fonts/google_fonts.dart';

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
  bool _acceptedTerms = false; // NUEVO: Estado para el checkbox de términos
  bool _obscurePassword = true;

  // Colores extraídos del mockup para mantener consistencia
  final Color _primaryBlue = const Color(0xFF1D3DB6); // Azul principal (títulos, botones)
  final Color _lightBgColor = const Color(0xFFF3F5FC); // Fondo claro de los inputs
  final Color _textColor = const Color(0xFF1E1E1E); // Texto oscuro

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    // Validación del checkbox de términos y condiciones
    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes aceptar los Términos y Condiciones para continuar.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authInstance = widget.auth ?? FirebaseAuth.instance;
      final firestoreInstance = widget.firestore ?? FirebaseFirestore.instance;

      // 1. Crear usuario en Firebase Auth
      UserCredential userCredential = await authInstance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 2. Guardar nombre en Authentication
      await userCredential.user!.updateDisplayName(_nameController.text.trim());

      // 3. Guardar datos adicionales en Firestore
      await firestoreInstance.collection('users').doc(userCredential.user!.uid).set({
        'name': _nameController.text.trim(),
        'email': userCredential.user!.email,
        'role': 'User',
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
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

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final authInstance = widget.auth ?? FirebaseAuth.instance;
      return await authInstance.signInWithCredential(credential);
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

  // Widget reutilizable para los campos de texto según el diseño del mockup
  // Esto evita tener código repetitivo (código espagueti) en el método build.
  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    bool isPassword = false,
    String? Function(String?)? validator,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        validator: validator,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.grey.shade600),
          filled: true,
          fillColor: _lightBgColor,
          suffixIcon: suffixIcon,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none, // Sin borde por defecto, igual al mockup
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none, // Aseguramos que no haya borde en reposo
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: _primaryBlue, width: 1.5), // Borde azul al enfocar
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.red, width: 1.5),
          ),
        ),
      ),
    );
  }

  // Widget reutilizable para los botones sociales (Google, Facebook)
  Widget _buildSocialButton({
    String? iconPath,
    IconData? iconData,
    Color? bgColor,
    Color? iconColor,
    double iconSize = 30,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: bgColor ?? const Color(0xFFEBEBEB), // Fondo gris claro del mockup
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: iconData != null
              ? Icon(iconData, color: iconColor ?? Colors.black, size: iconSize)
              : Image.network(
                  iconPath!,
                  width: iconSize,
                  height: iconSize,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.error),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
      ),
      child: Scaffold(
        backgroundColor: Colors.white, // Fondo blanco según el mockup
      body: Stack(
        children: [
          // FONDO DECORATIVO
          Positioned.fill(
            child: CustomPaint(
              painter: BackgroundPainter(),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // TÍTULO
                      Text(
                        'Crear cuenta',
                        style: TextStyle(
                          fontSize: 36, // Ajustado a 36 según mockup
                          fontWeight: FontWeight.w900,
                          color: _primaryBlue,
                        ),
                      ),
                      const SizedBox(height: 8), // Ajustado a 8 según mockup
                      
                      // SUBTÍTULO
                      Text(
                        'Crea una cuenta y da el primer paso para\nsentirte mejor',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: _textColor,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 50), // Ajustado a 50 según mockup

                  // CAMPO: NOMBRE COMPLETO
                  _buildTextField(
                    controller: _nameController,
                    hintText: 'Nombre Completo',
                    validator: (value) => value!.isEmpty ? 'Ingresa tu nombre' : null,
                  ),
                  const SizedBox(height: 20),

                  // CAMPO: CORREO ELECTRÓNICO
                  _buildTextField(
                    controller: _emailController,
                    hintText: 'Correo Electrónico',
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Ingresa tu correo';
                      if (!value.contains('@')) return 'Correo inválido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // CAMPO: CONTRASEÑA
                  _buildTextField(
                    controller: _passwordController,
                    hintText: 'Contraseña',
                    isPassword: _obscurePassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    validator: (value) => value!.length < 6 ? 'Mínimo 6 caracteres' : null,
                  ),
                  const SizedBox(height: 15),

                  // CHECKBOX TÉRMINOS Y CONDICIONES
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: _acceptedTerms,
                          activeColor: _primaryBlue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          onChanged: (value) {
                            setState(() {
                              _acceptedTerms = value ?? false;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            text: 'Al marcar esta casilla, aceptas nuestros ',
                            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                            children: [
                              TextSpan(
                                text: 'Términos',
                                style: TextStyle(color: _primaryBlue, fontWeight: FontWeight.bold),
                              ),
                              const TextSpan(text: ' y '),
                              TextSpan(
                                text: 'Condiciones',
                                style: TextStyle(color: _primaryBlue, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // BOTÓN REGÍSTRATE
                  SizedBox(
                    width: double.infinity,
                    height: 55, // Altura prominente como en el mockup
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Regístrate',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 25),

                  // ENLACE: ¿YA TIENES UNA CUENTA?
                  GestureDetector(
                    onTap: () => Navigator.pushReplacementNamed(context, '/login'),
                    child: Text(
                      '¿Ya tienes una cuenta?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // DIVISOR: O BIEN, CONTINÚA CON
                  Text(
                    'O bien, continúa con',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // BOTONES SOCIALES (Google y Facebook)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildSocialButton(
                        // Ícono de Google
                        iconPath: 'https://cdn-icons-png.flaticon.com/512/2991/2991148.png', 
                        onPressed: signInWithGoogle,
                      ),
                      const SizedBox(width: 20),
                      _buildSocialButton(
                        // Ícono de Facebook oficial
                        iconData: Icons.facebook,
                        bgColor: const Color(0xFF1877F2),
                        iconColor: Colors.white,
                        iconSize: 28,
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Login con Facebook próximamente')),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
        ),
      ),
    );
  }
}

// CustomPainter para el fondo con líneas curvas suaves y abstractas
class BackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE8EAF6) // Gris muy claro
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path1 = Path();
    // Línea curva superior izquierda
    path1.moveTo(0, size.height * 0.15);
    path1.quadraticBezierTo(size.width * 0.1, size.height * 0.3, size.width * 0.3, 0);

    final path2 = Path();
    // Línea cruzando sutilmente la izquierda
    path2.moveTo(0, size.height * 0.4);
    path2.quadraticBezierTo(size.width * 0.2, size.height * 0.5, size.width * 0.4, size.height);

    final path3 = Path();
    // Línea inferior izquierda sutil
    path3.moveTo(0, size.height * 0.7);
    path3.quadraticBezierTo(size.width * 0.15, size.height * 0.8, size.width * 0.3, size.height);

    final path4 = Path();
    // Línea sutil cruzando hacia la derecha
    path4.moveTo(size.width * 0.8, 0);
    path4.quadraticBezierTo(size.width, size.height * 0.2, size.width * 0.9, size.height * 0.4);

    canvas.drawPath(path1, paint);
    canvas.drawPath(path2, paint);
    canvas.drawPath(path3, paint);
    canvas.drawPath(path4, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}