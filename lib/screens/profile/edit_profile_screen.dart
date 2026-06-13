import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/user_profile.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  static const Color _primary = Color(0xFF2563EB);
  static const Color _background = Color(0xFFF0F2F5);
  static const Color _textMain = Color(0xFF111827);
  static const Color _textSub = Color(0xFF9E9E9E);

  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  String _role = 'Paciente';
  String? _photoUrl;

  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _birthCtrl;
  late TextEditingController _genderCtrl;
  late TextEditingController _reasonCtrl;
  late TextEditingController _specialtyCtrl;
  late TextEditingController _yearsCtrl;
  late TextEditingController _modalityCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _contactPhoneCtrl;
  late TextEditingController _priceCtrl;

  String? _emailFromAuth;

  // Especialidades para dropdown
  final List<String> _specialties = [
    'Psicología Clínica',
    'Psicología Infantil',
    'Psicología Familiar',
    'Psicología Cognitivo-Conductual',
    'Psicología Humanista',
    'Neuropsicología',
    'Otra',
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl        = TextEditingController();
    _phoneCtrl       = TextEditingController();
    _birthCtrl       = TextEditingController();
    _genderCtrl      = TextEditingController();
    _reasonCtrl      = TextEditingController();
    _specialtyCtrl   = TextEditingController();
    _yearsCtrl       = TextEditingController();
    _modalityCtrl    = TextEditingController();
    _descCtrl        = TextEditingController();
    _contactPhoneCtrl = TextEditingController();
    _priceCtrl       = TextEditingController();
    _emailFromAuth   = FirebaseAuth.instance.currentUser?.email;
    _loadProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _phoneCtrl.dispose(); _birthCtrl.dispose();
    _genderCtrl.dispose(); _reasonCtrl.dispose(); _specialtyCtrl.dispose();
    _yearsCtrl.dispose(); _modalityCtrl.dispose(); _descCtrl.dispose();
    _contactPhoneCtrl.dispose(); _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        final p = UserProfile.fromMap(uid, doc.data()!);
        setState(() {
          _role = p.role;
          _photoUrl = p.photoUrl;
          _nameCtrl.text        = p.fullName;
          _phoneCtrl.text       = p.phone ?? '';
          _birthCtrl.text       = p.birthDate ?? '';
          _genderCtrl.text      = p.gender ?? '';
          _reasonCtrl.text      = p.supportReason ?? '';
          _specialtyCtrl.text   = p.specialty ?? '';
          _yearsCtrl.text       = p.experienceYears?.toString() ?? '';
          _modalityCtrl.text    = p.modality ?? '';
          _descCtrl.text        = p.description ?? '';
          _contactPhoneCtrl.text = p.contactPhone ?? '';
          _priceCtrl.text       = p.pricePerSession?.toInt().toString() ?? '';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final isPsi = _role == 'Psicólogo';
      final profileData = {
        'fullName': _nameCtrl.text.trim(),
        'role': _role,
        'photoUrl': _photoUrl,
        'phone': isPsi ? null : _phoneCtrl.text.trim(),
        'birthDate': isPsi ? null : _birthCtrl.text.trim(),
        'gender': isPsi ? null : _genderCtrl.text.trim(),
        'supportReason': isPsi ? null : _reasonCtrl.text.trim(),
        'specialty': isPsi ? _specialtyCtrl.text.trim() : null,
        'experienceYears': isPsi ? int.tryParse(_yearsCtrl.text.trim()) : null,
        'modality': _modalityCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'contactPhone': _contactPhoneCtrl.text.trim(),
        'pricePerSession': double.tryParse(_priceCtrl.text.trim()),
      };
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set(profileData, SetOptions(merge: true));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white),
              SizedBox(width: 12),
              Text(
                'Perfil guardado exitosamente',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.white),
              ),
            ],
          ),
          backgroundColor: _primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.only(bottom: 90, left: 20, right: 20),
          elevation: 8,
          duration: const Duration(seconds: 3),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 300,
        maxHeight: 300,
        imageQuality: 40,
      );

      if (image != null) {
        final Uint8List imageBytes = await image.readAsBytes();
        final String base64String = base64Encode(imageBytes);
        
        setState(() {
          _photoUrl = 'data:image/jpeg;base64,$base64String';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al seleccionar imagen: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 25),
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: _background,
        body: Center(child: CircularProgressIndicator(color: _primary)),
      );
    }

    final isPsi = _role == 'Psicólogo';
    final inicial = _nameCtrl.text.isNotEmpty ? _nameCtrl.text[0].toUpperCase() : 'U';

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: _textMain),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditing ? 'Editar Perfil' : 'Datos de la cuenta',
          style: const TextStyle(color: _textMain, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        centerTitle: true,
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: _primary),
              onPressed: () => setState(() => _isEditing = true),
            )
          else
            TextButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _primary),
                    )
                  : const Text(
                      'Guardar',
                      style: TextStyle(
                        color: _primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            children: [
              // ── AVATAR ──────────────────────────────────────
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _isEditing ? _pickImage : null,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: _primary,
                      backgroundImage: _photoUrl != null
                          ? (_photoUrl!.startsWith('http')
                              ? NetworkImage(_photoUrl!)
                              : MemoryImage(base64Decode(_photoUrl!.split(',').last)) as ImageProvider)
                          : null,
                      child: _photoUrl == null
                          ? Text(
                              inicial,
                              style: const TextStyle(
                                fontSize: 48, color: Colors.white, fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    if (_isEditing)
                      Positioned(
                        bottom: 0, right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: _primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ── CAMPOS ──────────────────────────────────────
              _CardField(
                label: 'Nombre completo',
                controller: _nameCtrl,
                readOnly: !_isEditing,
                validator: (v) => v!.isEmpty ? 'Requerido' : null,
              ),

              if (!isPsi) ...[
                _CardField(
                  label: 'Correo electrónico',
                  initialValue: _emailFromAuth ?? '',
                  readOnly: true,
                ),
                _CardField(
                  label: 'Teléfono',
                  controller: _phoneCtrl,
                  readOnly: !_isEditing,
                  keyboardType: TextInputType.phone,
                  hint: '(55) 1234 5678',
                ),
                _CardField(
                  label: 'Fecha de Nacimiento',
                  controller: _birthCtrl,
                  readOnly: true,
                  hint: 'DD / MM / AAAA',
                  suffixIcon: const Icon(Icons.calendar_today_outlined, color: _textSub, size: 20),
                  onTap: _isEditing ? _pickDate : null,
                ),
              ],

              if (isPsi) ...[
                // Especialidad dropdown
                _DropdownField(
                  label: 'Especialidad *',
                  value: _specialtyCtrl.text.isEmpty ? null : _specialtyCtrl.text,
                  items: _specialties,
                  onChanged: _isEditing ? (v) => setState(() => _specialtyCtrl.text = v ?? '') : null,
                  validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                ),
                _CardField(
                  label: 'Años de experiencia',
                  controller: _yearsCtrl,
                  readOnly: !_isEditing,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v!.isEmpty) return 'Requerido';
                    if (int.tryParse(v) == null) return 'Debe ser un número';
                    return null;
                  },
                ),
                _CardField(
                  label: 'Cuéntanos sobre tu enfoque profesional...',
                  controller: _descCtrl,
                  readOnly: !_isEditing,
                  maxLines: 4,
                  maxLength: 500,
                  validator: (v) => v!.isEmpty ? 'Requerido' : null,
                ),
                _CardField(
                  label: 'Precio por sesión (COP)',
                  controller: _priceCtrl,
                  readOnly: !_isEditing,
                  keyboardType: TextInputType.number,
                  hint: 'Ej. 50000',
                  validator: (v) {
                    if (v == null || v.isEmpty) return null; // opcional
                    if (double.tryParse(v) == null) return 'Debe ser numérico';
                    return null;
                  },
                ),
              ],

              const SizedBox(height: 8),

              // ── CAMBIAR CONTRASEÑA ───────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Próximamente: Cambio de contraseña')),
                    );
                  },
                  icon: const Icon(Icons.lock_outline, size: 18),
                  label: const Text(
                    'Cambiar Contraseña',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primary,
                    side: const BorderSide(color: _primary, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                ),
              ),

              if (isPsi) ...[
                const SizedBox(height: 12),
                const Text(
                  '(*) Campo obligatorio',
                  style: TextStyle(color: _textSub, fontSize: 12),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ── WIDGET CAMPO TIPO TARJETA ────────────────────────────────────────────────
class _CardField extends StatelessWidget {
  final String label;
  final TextEditingController? controller;
  final String? initialValue;
  final bool readOnly;
  final TextInputType? keyboardType;
  final int? maxLines;
  final int? maxLength;
  final String? hint;
  final Widget? suffixIcon;
  final VoidCallback? onTap;
  final String? Function(String?)? validator;

  const _CardField({
    required this.label,
    this.controller,
    this.initialValue,
    this.readOnly = false,
    this.keyboardType,
    this.maxLines = 1,
    this.maxLength,
    this.hint,
    this.suffixIcon,
    this.onTap,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: TextFormField(
        controller: controller,
        initialValue: controller == null ? initialValue : null,
        readOnly: readOnly,
        keyboardType: keyboardType,
        maxLines: maxLines,
        maxLength: maxLength,
        onTap: onTap,
        validator: validator,
        style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A2E), fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 12),
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFFBBBBBB), fontSize: 15),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
          counterText: '',
        ),
      ),
    );
  }
}

// ── WIDGET DROPDOWN TIPO TARJETA ─────────────────────────────────────────────
class _DropdownField extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?>? onChanged;
  final String? Function(String?)? validator;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    this.onChanged,
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
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 12),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
        ),
        icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF9E9E9E)),
        items: items
            .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 15))))
            .toList(),
        onChanged: onChanged,
        validator: validator,
      ),
    );
  }
}
