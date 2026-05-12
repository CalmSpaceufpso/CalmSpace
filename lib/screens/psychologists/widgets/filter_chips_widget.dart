// lib/screens/psychologists/widgets/filter_chips_widget.dart

import 'package:flutter/material.dart';

class FilterChipsWidget extends StatelessWidget {
  final List<String> specialties;
  final String? selectedSpecialty;
  final String? selectedModalidad;
  final bool hasActiveFilters;
  final ValueChanged<String?> onSpecialtySelected;
  final ValueChanged<String?> onModalidadSelected;
  final VoidCallback onClearFilters;

  static const _modalidades = ['Virtual', 'Presencial', 'Ambas'];

  const FilterChipsWidget({
    super.key,
    required this.specialties,
    required this.selectedSpecialty,
    required this.selectedModalidad,
    required this.hasActiveFilters,
    required this.onSpecialtySelected,
    required this.onModalidadSelected,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    if (specialties.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _FilterChip(
                  label: 'Todos',
                  isSelected: selectedSpecialty == null && selectedModalidad == null,
                  color: const Color(0xFF6C63FF),
                  onTap: onClearFilters,
                ),
              ),
              ...specialties.map((specialty) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _FilterChip(
                      label: specialty,
                      isSelected: selectedSpecialty == specialty,
                      color: const Color(0xFF00BFA5),
                      onTap: () => onSpecialtySelected(
                        selectedSpecialty == specialty ? null : specialty,
                      ),
                    ),
                  )),
            ],
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: _modalidades
                .map((m) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _FilterChip(
                        label: m,
                        isSelected: selectedModalidad == m,
                        color: const Color(0xFFF57C00),
                        onTap: () => onModalidadSelected(
                          selectedModalidad == m ? null : m,
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? color : Colors.grey.shade300),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 3))]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}