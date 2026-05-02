import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterScreen extends StatefulWidget {
  final FirebaseAuth? auth;
  final FirebaseFirestore? firestore;

  const RegisterScreen({super.key, this.auth, this.firestore});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // ── COLORES ────────────────────────────────────────────────────────────────
  static const Color _primary    = Color(0xFF2563EB);
  static const Color _background = Color(0xFFF0F2F5);
  static const Color _textMain   = Color(0xFF111827);
  static const Color _textSub    = Color(0xFF9E9E9E);

  // ── FORM ──────────────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  final _birthCtrl    = TextEditingController();
  final _yearsCtrl    = TextEditingController();
  final _descCtrl     = TextEditingController();

  bool _isLoading      = false;
  bool _obscurePass    = true;
  bool _acceptedTerms  = false;

  // Rol y campos por rol
  String  _selectedRole     = 'Paciente';
  String? _selectedGender;
  String? _selectedSpecialty;
  String? _selectedModality;

  static const List<String> _genders = [
    'Masculino', 'Femenino', 'No binario', 'Prefiero no decirlo',
  ];
  static const List<String> _specialties = [
    'Psicología Clínica', 'Psicología Infantil', 'Psicología Familiar',
    'Psicología Cognitivo-Conductual', 'Psicología Humanista',
    'Neuropsicología', 'Otra',
  ];
  static const List<String> _modalities = [
    'Presencial', 'Virtual', 'Híbrida',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose(); _passwordCtrl.dispose();
    _phoneCtrl.dispose(); _birthCtrl.dispose();
    _yearsCtrl.dispose(); _descCtrl.dispose();
    super.dispose();
  }

  // ── REGISTRO ───────────────────────────────────────────────────────────────
  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedTerms) {
      _showError('Debes aceptar los Términos y Condiciones para continuar.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final auth      = widget.auth      ?? FirebaseAuth.instance;
      final firestore = widget.firestore ?? FirebaseFirestore.instance;
      final isPsi     = _selectedRole == 'Psicólogo';

      final cred = await auth.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
      );
      await cred.user!.updateDisplayName(_nameCtrl.text.trim());

      final Map<String, dynamic> userData = {
        'name'      : _nameCtrl.text.trim(),
        'email'     : cred.user!.email,
        'role'      : _selectedRole,
        'status'    : isPsi ? 'pendiente' : 'activo',
        'createdAt' : FieldValue.serverTimestamp(),
      };

      if (!isPsi) {
        // Datos paciente
        if (_selectedGender != null) userData['gender']    = _selectedGender;
        if (_phoneCtrl.text.isNotEmpty) userData['phone']  = _phoneCtrl.text.trim();
        if (_birthCtrl.text.isNotEmpty) userData['birthDate'] = _birthCtrl.text.trim();
      } else {
        // Datos psicólogo
        if (_selectedSpecialty != null) userData['specialty'] = _selectedSpecialty;
        if (_yearsCtrl.text.isNotEmpty) userData['experienceYears'] = int.tryParse(_yearsCtrl.text.trim());
        if (_selectedModality != null)  userData['modality']  = _selectedModality;
        if (_descCtrl.text.isNotEmpty)  userData['description'] = _descCtrl.text.trim();
      }

      await firestore.collection('users').doc(cred.user!.uid).set(userData);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Cuenta creada! Bienvenido a CalmSpace'), backgroundColor: _primary),
      );
      Navigator.pushReplacementNamed(context, isPsi ? '/pending' : '/home');

    } on FirebaseAuthException catch (e) {
      final msg = switch (e.code) {
        'weak-password'       => 'La contraseña es muy débil (mínimo 6 caracteres).',
        'email-already-in-use'=> 'Ya existe una cuenta con este correo.',
        'invalid-email'       => 'El formato del correo no es válido.',
        'too-many-requests'   => 'Demasiados intentos. Intenta más tarde.',
        _                     => 'Ocurrió un error inesperado.',
      };
      _showError(msg);
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 20),
      firstDate: DateTime(1940),
      lastDate: DateTime(now.year - 10),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      _birthCtrl.text =
          '${picked.day.toString().padLeft(2, '0')} / ${picked.month.toString().padLeft(2, '0')} / ${picked.year}';
    }
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isPsi = _selectedRole == 'Psicólogo';

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: _textMain),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Crear cuenta',
          style: TextStyle(color: _textMain, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── SELECTOR DE ROL ────────────────────────────────
              const Text(
                '¿Cómo quieres usar CalmSpace?',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _textMain),
              ),
              const SizedBox(height: 10),
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

              if (isPsi) ...[
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
              _sectionLabel('Información básica'),

              // ── CAMPOS COMUNES ─────────────────────────────────
              _CardField(
                label: 'Nombre completo',
                controller: _nameCtrl,
                prefixIcon: Icons.person_outline,
                validator: (v) => v!.trim().isEmpty ? 'Requerido' : null,
              ),
              _CardField(
                label: 'Correo electrónico',
                controller: _emailCtrl,
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v!.trim().isEmpty) return 'Requerido';
                  if (!v.contains('@')) return 'Correo inválido';
                  return null;
                },
              ),
              _CardField(
                label: 'Contraseña',
                controller: _passwordCtrl,
                prefixIcon: Icons.lock_outline,
                obscureText: _obscurePass,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: _textSub, size: 20,
                  ),
                  onPressed: () => setState(() => _obscurePass = !_obscurePass),
                ),
                validator: (v) {
                  if (v!.isEmpty) return 'Requerido';
                  if (v.length < 6) return 'Mínimo 6 caracteres';
                  return null;
                },
              ),

              const SizedBox(height: 8),

              // ── CAMPOS PACIENTE ────────────────────────────────
              if (!isPsi) ...[
                _sectionLabel('Sobre ti'),
                _DropdownField(
                  label: 'Género',
                  value: _selectedGender,
                  items: _genders,
                  onChanged: (v) => setState(() => _selectedGender = v),
                ),
                _CardField(
                  label: 'Fecha de nacimiento',
                  controller: _birthCtrl,
                  prefixIcon: Icons.calendar_today_outlined,
                  readOnly: true,
                  hint: 'DD / MM / AAAA',
                  suffixIcon: const Icon(Icons.chevron_right, color: _textSub, size: 20),
                  onTap: _pickDate,
                ),
                _CardField(
                  label: 'Teléfono (opcional)',
                  controller: _phoneCtrl,
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  hint: '(55) 1234 5678',
                ),
              ],

              // ── CAMPOS PSICÓLOGO ───────────────────────────────
              if (isPsi) ...[
                _sectionLabel('Información profesional'),
                _DropdownField(
                  label: 'Especialidad *',
                  value: _selectedSpecialty,
                  items: _specialties,
                  onChanged: (v) => setState(() => _selectedSpecialty = v),
                  validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                ),
                _CardField(
                  label: 'Años de experiencia *',
                  controller: _yearsCtrl,
                  prefixIcon: Icons.work_outline,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v!.isEmpty) return 'Requerido';
                    if (int.tryParse(v) == null) return 'Debe ser un número';
                    return null;
                  },
                ),
                _DropdownField(
                  label: 'Modalidad de atención *',
                  value: _selectedModality,
                  items: _modalities,
                  onChanged: (v) => setState(() => _selectedModality = v),
                  validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                ),
                _CardField(
                  label: 'Descripción profesional (opcional)',
                  controller: _descCtrl,
                  prefixIcon: Icons.description_outlined,
                  maxLines: 3,
                  maxLength: 300,
                  hint: 'Cuéntanos sobre tu enfoque terapéutico...',
                ),
              ],

              const SizedBox(height: 8),

              // ── TÉRMINOS Y CONDICIONES ─────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24, height: 24,
                    child: Checkbox(
                      value: _acceptedTerms,
                      onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
                      activeColor: _primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _acceptedTerms = !_acceptedTerms),
                      child: const Text.rich(
                        TextSpan(
                          text: 'Acepto los ',
                          style: TextStyle(fontSize: 13, color: _textSub),
                          children: [
                            TextSpan(
                              text: 'Términos y Condiciones',
                              style: TextStyle(color: _primary, fontWeight: FontWeight.w600),
                            ),
                            TextSpan(text: ' y la '),
                            TextSpan(
                              text: 'Política de Privacidad',
                              style: TextStyle(color: _primary, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ── BOTÓN REGISTRAR ────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Text(
                          'Crear cuenta',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // ── YA TENGO CUENTA ────────────────────────────────
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.pushReplacementNamed(context, '/login'),
                  child: const Text.rich(
                    TextSpan(
                      text: '¿Ya tienes cuenta? ',
                      style: TextStyle(color: _textSub, fontSize: 14),
                      children: [
                        TextSpan(
                          text: 'Inicia sesión',
                          style: TextStyle(color: _primary, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              if (isPsi) ...[
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    '(*) Campo obligatorio',
                    style: TextStyle(color: _textSub, fontSize: 12),
                  ),
                ),
              ],

              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: _textSub,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ── TARJETA DE ROL ────────────────────────────────────────────────────────────
class _RoleCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  static const Color _primary = Color(0xFF2563EB);

  const _RoleCard({
    required this.label, required this.icon,
    required this.selected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEEF3FF) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? _primary : Colors.grey.shade300,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 28, color: selected ? _primary : Colors.grey),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? _primary : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── CAMPO TIPO TARJETA ─────────────────────────────────────────────────────────
class _CardField extends StatelessWidget {
  final String label;
  final TextEditingController? controller;
  final bool readOnly;
  final bool obscureText;
  final TextInputType? keyboardType;
  final int? maxLines;
  final int? maxLength;
  final String? hint;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final VoidCallback? onTap;
  final String? Function(String?)? validator;

  static const Color _primary = Color(0xFF2563EB);
  static const Color _textSub = Color(0xFF9E9E9E);

  const _CardField({
    required this.label,
    this.controller,
    this.readOnly = false,
    this.obscureText = false,
    this.keyboardType,
    this.maxLines = 1,
    this.maxLength,
    this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.onTap,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        obscureText: obscureText,
        keyboardType: keyboardType,
        maxLines: obscureText ? 1 : maxLines,
        maxLength: maxLength,
        onTap: onTap,
        validator: validator,
        style: const TextStyle(fontSize: 15, color: Color(0xFF111827), fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: _textSub, fontSize: 12),
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFFCCCCCC), fontSize: 15),
          prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: _primary, size: 20) : null,
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          counterText: '',
        ),
      ),
    );
  }
}

// ── DROPDOWN TIPO TARJETA ──────────────────────────────────────────────────────
class _DropdownField extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final String? Function(String?)? validator;

  static const Color _primary = Color(0xFF2563EB);
  static const Color _textSub = Color(0xFF9E9E9E);

  const _DropdownField({
    required this.label, required this.value,
    required this.items, required this.onChanged, this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: _primary, fontSize: 12),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
        icon: const Icon(Icons.keyboard_arrow_down, color: _textSub),
        items: items
            .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 15))))
            .toList(),
        onChanged: onChanged,
        validator: validator,
      ),
    );
  }
}