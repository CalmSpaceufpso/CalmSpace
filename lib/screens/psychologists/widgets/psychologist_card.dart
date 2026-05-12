// lib/screens/psychologists/widgets/psychologist_card.dart

import 'package:flutter/material.dart';
import '../../../models/psychologist_model.dart';

class PsychologistCard extends StatelessWidget {
  final PsychologistModel psychologist;
  final VoidCallback onTap;

  const PsychologistCard({
    super.key,
    required this.psychologist,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAvatar(),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              psychologist.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1A2E),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (psychologist.isAvailable)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF4CAF50),
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        psychologist.specialty,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6C63FF),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded,
                              color: Color(0xFFFFC107), size: 16),
                          const SizedBox(width: 4),
                          Text(
                            psychologist.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '(${psychologist.reviewCount})',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade500),
                          ),
                          const Spacer(),
                          _ModalidadBadge(modalidad: psychologist.modalidad),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.work_outline_rounded,
                              size: 13, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(
                            '${psychologist.yearsOfExperience} años exp.',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600),
                          ),
                          const Spacer(),
                          Text(
                            '\$${_formatPrice(psychologist.pricePerSession)} / sesión',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF00BFA5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded,
                    color: Colors.grey.shade400, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    final initials = _getInitials(psychologist.name);
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: _getAvatarGradient(psychologist.name),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: psychologist.photoUrl.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                psychologist.photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _initialsWidget(initials),
              ),
            )
          : _initialsWidget(initials),
    );
  }

  Widget _initialsWidget(String initials) {
    return Center(
      child: Text(
        initials,
        style: const TextStyle(
            color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.substring(0, 2).toUpperCase();
  }

  List<Color> _getAvatarGradient(String name) {
    final gradients = [
      [const Color(0xFF6C63FF), const Color(0xFF9C94FF)],
      [const Color(0xFF00BFA5), const Color(0xFF1DE9B6)],
      [const Color(0xFFF57C00), const Color(0xFFFFB74D)],
      [const Color(0xFF1565C0), const Color(0xFF42A5F5)],
      [const Color(0xFF6A1B9A), const Color(0xFFBA68C8)],
    ];
    final index = name.codeUnitAt(0) % gradients.length;
    return gradients[index];
  }

  String _formatPrice(double price) {
    if (price >= 1000) return '${(price / 1000).toStringAsFixed(0)}k';
    return price.toStringAsFixed(0);
  }
}

class _ModalidadBadge extends StatelessWidget {
  final String modalidad;
  const _ModalidadBadge({required this.modalidad});

  @override
  Widget build(BuildContext context) {
    final config = _getConfig();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (config['color'] as Color).withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config['icon'] as IconData,
              size: 11, color: config['color'] as Color),
          const SizedBox(width: 3),
          Text(
            modalidad,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: config['color'] as Color,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getConfig() {
    switch (modalidad) {
      case 'Virtual':
        return {'color': const Color(0xFF6C63FF), 'icon': Icons.videocam_outlined};
      case 'Presencial':
        return {'color': const Color(0xFF00BFA5), 'icon': Icons.location_on_outlined};
      default:
        return {'color': const Color(0xFFF57C00), 'icon': Icons.swap_horiz_rounded};
    }
  }
}