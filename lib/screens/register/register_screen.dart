import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // IMPORTANTE: Importar Firebase
import 'package:cloud_firestore/cloud_firestore.dart';

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

  // Variable para mostrar un indicador de carga
  bool _isLoading = false;

  // Función asíncrona para conectar con Firebase
  Future<void> _register() async {
    // 1. Validar el formulario localmente
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true; // Empezamos a cargar
      });

      try {
        final authInstance = widget.auth ?? FirebaseAuth.instance;
        final firestoreInstance = widget.firestore ?? FirebaseFirestore.instance;

        // 2. Intentar crear el usuario en Firebase
        UserCredential userCredential = await authInstance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        // Guardar nombre en Authentication
        await userCredential.user!.updateDisplayName(_nameController.text.trim());

        // Guardar el rol e información adicional en Firestore
        await firestoreInstance.collection('users').doc(userCredential.user!.uid).set({
          'name': _nameController.text.trim(),
          'email': userCredential.user!.email,
          'role': 'User',
          'createdAt': FieldValue.serverTimestamp(),
        });

        // 3. Si tiene éxito, mostramos mensaje y limpiamos (o navegamos)
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Cuenta creada con éxito! Bienvenido a CalmSpace'),
              backgroundColor: Colors.green,
            ),
          );
          // Aquí podrías usar Navigator.pushReplacement para ir al Home
        }
      } on FirebaseAuthException catch (e) {
        // 4. Manejo de errores específicos de Firebase
        String errorMsg = 'Ocurrió un error inesperado';

        if (e.code == 'weak-password') {
          errorMsg = 'La contraseña es muy débil.';
        } else if (e.code == 'email-already-in-use') {
          errorMsg = 'Ya existe una cuenta con este correo.';
        } else if (e.code == 'invalid-email') {
          errorMsg = 'El formato del correo no es válido.';
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
          );
        }
      } catch (e) {
        // Errores generales
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.toString())));
        }
      } finally {
        // 5. Quitamos el estado de carga pase lo que pase
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
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
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(title: const Text('Crear Cuenta'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            // Añadido para evitar error de overflow con el teclado
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                const Text(
                  'Regístrate en CalmSpace',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 50),

                // Campo de Nombre
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Nombre Completo',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'El nombre es obligatorio';
                    }
                    if (value.trim().length < 3) {
                      return 'Ingresa un nombre válido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 30),

                // Campo de Email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Correo Electrónico',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.email),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'El correo es obligatorio';
                    }
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                      return 'Ingresa un correo válido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 30),

                // Campo de Contraseña
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.lock),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'La contraseña es obligatoria';
                    }
                    if (value.length < 6) {
                      return 'Debe tener mínimo 6 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 50),

                // Botón de Registro dinámico
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : _register, // Desactiva el botón si está cargando
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      shape: const StadiumBorder(),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(
                            color: Colors.white,
                          ) // Spinner si carga
                        : const Text(
                            'Registrarse',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
