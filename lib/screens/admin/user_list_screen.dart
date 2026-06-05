import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../models/user_profile.dart';
import '../../providers/user_list_provider.dart';
import '../../repositories/user_repository.dart';

/// Admin screen — HU-16: Ver lista de usuarios registrados.
///
/// T1 – Polished list UI with search bar, role filter chips,
///      loading / empty / error states.
/// T2 – Data driven by [UserListProvider] which subscribes to a real-time
///      Firestore stream via [UserRepository].
/// T3 – [AdminGuard] verifies the caller has role == 'Admin' before
///      rendering this screen; non-admins see a locked dialog.
class UserListScreen extends StatelessWidget {
  const UserListScreen({super.key});

  /// Navigate to this screen with a built-in admin guard.
  ///
  /// Call this from any entry point instead of pushing [UserListScreen]
  /// directly — it enforces T3 without duplicating the check.
  static Future<void> openGuarded(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final isAdmin = await UserRepository().isAdmin(user.uid);
    if (!context.mounted) return;

    if (!isAdmin) {
      _showLockedDialog(context);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => UserListProvider(),
          child: const UserListScreen(),
        ),
      ),
    );
  }

  static void _showLockedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.admin_panel_settings_rounded,
              color: Color(0xFF2B5BFF), size: 24),
          SizedBox(width: 10),
          Text('Acceso restringido',
              style:
                  TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        ]),
        content: const Text(
          'Solo los administradores pueden acceder a la lista de usuarios registrados.',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido',
                style: TextStyle(
                    color: Color(0xFF2B5BFF),
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const _UserListView();
  }
}

// ── Main view ─────────────────────────────────────────────────────────────────

class _UserListView extends StatefulWidget {
  const _UserListView();

  @override
  State<_UserListView> createState() => _UserListViewState();
}

class _UserListViewState extends State<_UserListView> {
  static const Color _primary  = Color(0xFF2B5BFF);
  static const Color _bg       = Color(0xFFF4F6FB);
  static const Color _textMain = Color(0xFF0D1B3E);
  static const Color _textSub  = Color(0xFF8A94A6);

  final TextEditingController _searchCtrl = TextEditingController();

  static const _roles = ['Todos', 'Paciente', 'Psicólogo', 'Admin'];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearch);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch() {
    context.read<UserListProvider>().setSearchQuery(_searchCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(context),
      body: Column(
        children: [
          // ── Search bar ───────────────────────────────────────────────────
          _SearchBar(controller: _searchCtrl),

          // ── Role filter chips ────────────────────────────────────────────
          _RoleFilterRow(roles: _roles),

          // ── Summary bar ──────────────────────────────────────────────────
          Consumer<UserListProvider>(
            builder: (_, prov, __) {
              if (prov.isLoading || prov.error != null) {
                return const SizedBox.shrink();
              }
              return _SummaryBar(users: prov.users);
            },
          ),

          // ── List ─────────────────────────────────────────────────────────
          Expanded(
            child: Consumer<UserListProvider>(
              builder: (_, prov, __) {
                if (prov.isLoading) return _LoadingState();
                if (prov.error != null) return _ErrorState(error: prov.error!);
                if (prov.filteredUsers.isEmpty) {
                  return _EmptyState(hasFilters: prov.roleFilter.isNotEmpty ||
                      prov.searchQuery.isNotEmpty);
                }
                return _UserList(users: prov.filteredUsers);
              },
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.white,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 2)),
          ],
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _textMain, size: 16),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Usuarios Registrados',
            style: TextStyle(
                color: _textMain,
                fontWeight: FontWeight.bold,
                fontSize: 18),
          ),
          Consumer<UserListProvider>(
            builder: (_, prov, __) => Text(
              prov.isLoading ? 'Cargando...' : '${prov.users.length} usuarios en total',
              style: const TextStyle(
                  color: _textSub,
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
      actions: [
        Consumer<UserListProvider>(
          builder: (_, prov, __) {
            final hasFilters = prov.roleFilter.isNotEmpty ||
                prov.searchQuery.isNotEmpty;
            if (!hasFilters) return const SizedBox.shrink();
            return IconButton(
              tooltip: 'Limpiar filtros',
              icon: const Icon(Icons.filter_alt_off_rounded,
                  color: _primary),
              onPressed: () {
                prov.clearFilters();
                _searchCtrl.clear();
              },
            );
          },
        ),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: const Color(0xFFF1F5F9), height: 1),
      ),
    );
  }
}

// ── Search bar ────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  const _SearchBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: controller,
        style: const TextStyle(fontSize: 14, color: Color(0xFF0D1B3E)),
        decoration: InputDecoration(
          hintText: 'Buscar por nombre...',
          hintStyle:
              const TextStyle(color: Color(0xFF8A94A6), fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded,
              color: Color(0xFF8A94A6), size: 20),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, val, __) => val.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded,
                        size: 18, color: Color(0xFF8A94A6)),
                    onPressed: () {
                      controller.clear();
                      context.read<UserListProvider>().setSearchQuery('');
                    },
                  )
                : const SizedBox.shrink(),
          ),
          filled: true,
          fillColor: const Color(0xFFF4F6FB),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}

// ── Role filter chips ─────────────────────────────────────────────────────────

class _RoleFilterRow extends StatelessWidget {
  final List<String> roles;
  const _RoleFilterRow({required this.roles});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
      child: Consumer<UserListProvider>(
        builder: (_, prov, __) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: roles.map((role) {
                final isSelected = role == 'Todos'
                    ? prov.roleFilter.isEmpty
                    : prov.roleFilter == role;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => prov.setRoleFilter(
                        role == 'Todos' ? '' : role),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF2B5BFF)
                            : const Color(0xFFF4F6FB),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF2B5BFF)
                              : const Color(0xFFDDE3EE),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _iconFor(role),
                            size: 14,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF8A94A6),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            role,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF8A94A6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }

  IconData _iconFor(String role) {
    switch (role) {
      case 'Psicólogo':
        return Icons.psychology_rounded;
      case 'Admin':
        return Icons.admin_panel_settings_rounded;
      case 'Paciente':
        return Icons.person_rounded;
      default:
        return Icons.people_rounded;
    }
  }
}

// ── Summary bar ───────────────────────────────────────────────────────────────

class _SummaryBar extends StatelessWidget {
  final List<UserProfile> users;
  const _SummaryBar({required this.users});

  @override
  Widget build(BuildContext context) {
    final patients = users.where((u) => u.role == 'Paciente').length;
    final psychs   = users.where((u) => u.role == 'Psicólogo').length;
    final admins   = users.where((u) => u.role == 'Admin').length;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          _SummaryChip(
              label: 'Pacientes',
              count: patients,
              color: const Color(0xFF2B5BFF),
              bg: const Color(0xFFEEF2FF)),
          const SizedBox(width: 8),
          _SummaryChip(
              label: 'Psicólogos',
              count: psychs,
              color: const Color(0xFF7C3AED),
              bg: const Color(0xFFF5F3FF)),
          if (admins > 0) ...[
            const SizedBox(width: 8),
            _SummaryChip(
                label: 'Admins',
                count: admins,
                color: const Color(0xFF0891B2),
                bg: const Color(0xFFE0F2FE)),
          ],
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final Color bg;
  const _SummaryChip(
      {required this.label,
      required this.count,
      required this.color,
      required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        '$count $label',
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

// ── User list ─────────────────────────────────────────────────────────────────

class _UserList extends StatelessWidget {
  final List<UserProfile> users;
  const _UserList({required this.users});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: users.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _UserCard(user: users[i]),
    );
  }
}

// ── User card ─────────────────────────────────────────────────────────────────

class _UserCard extends StatelessWidget {
  final UserProfile user;

  static const Color _primary  = Color(0xFF2B5BFF);
  static const Color _textMain = Color(0xFF0D1B3E);

  const _UserCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final initial = user.fullName.isNotEmpty
        ? user.fullName[0].toUpperCase()
        : '?';

    final roleColor  = _roleColor(user.role);
    final roleBg     = _roleBg(user.role);
    final roleIcon   = _roleIcon(user.role);
    final statusColor = _statusColor(user.status);
    final statusLabel = _statusLabel(user.status);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: _Avatar(
            photoUrl: user.photoUrl,
            initial: initial,
            color: roleColor),
        title: Text(
          user.fullName.isNotEmpty ? user.fullName : 'Sin nombre',
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: _textMain),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 3),
            Row(children: [
              Icon(roleIcon, size: 12, color: roleColor),
              const SizedBox(width: 4),
              Text(user.role,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: roleColor)),
              if (user.role == 'Psicólogo' &&
                  user.specialty != null &&
                  user.specialty!.isNotEmpty) ...[
                const Text(' · ',
                    style: TextStyle(
                        fontSize: 11, color: Color(0xFF8A94A6))),
                Flexible(
                  child: Text(user.specialty!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF8A94A6))),
                ),
              ],
            ]),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Role badge
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: roleBg,
                  borderRadius: BorderRadius.circular(20)),
              child: Text(user.role,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: roleColor)),
            ),
            const SizedBox(height: 5),
            // Status badge
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20)),
              child: Text(statusLabel,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: statusColor)),
            ),
          ],
        ),
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'Psicólogo':
        return const Color(0xFF7C3AED);
      case 'Admin':
        return const Color(0xFF0891B2);
      default:
        return const Color(0xFF2B5BFF);
    }
  }

  Color _roleBg(String role) {
    switch (role) {
      case 'Psicólogo':
        return const Color(0xFFF5F3FF);
      case 'Admin':
        return const Color(0xFFE0F2FE);
      default:
        return const Color(0xFFEEF2FF);
    }
  }

  IconData _roleIcon(String role) {
    switch (role) {
      case 'Psicólogo':
        return Icons.psychology_rounded;
      case 'Admin':
        return Icons.admin_panel_settings_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'aprobado':
      case 'activo':
        return const Color(0xFF16A34A);
      case 'pendiente':
        return const Color(0xFFF59E0B);
      case 'rechazado':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF8A94A6);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'aprobado':
        return 'Aprobado';
      case 'activo':
        return 'Activo';
      case 'pendiente':
        return 'Pendiente';
      case 'rechazado':
        return 'Rechazado';
      default:
        return status;
    }
  }
}

// ── Avatar ────────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String? photoUrl;
  final String initial;
  final Color color;
  const _Avatar(
      {required this.photoUrl,
      required this.initial,
      required this.color});

  @override
  Widget build(BuildContext context) {
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      ImageProvider? img;
      try {
        img = photoUrl!.startsWith('http')
            ? NetworkImage(photoUrl!)
            : MemoryImage(base64Decode(photoUrl!.split(',').last));
      } catch (_) {
        img = null;
      }
      if (img != null) {
        return CircleAvatar(radius: 24, backgroundImage: img);
      }
    }
    return CircleAvatar(
      radius: 24,
      backgroundColor: color.withOpacity(0.15),
      child: Text(
        initial,
        style: TextStyle(
            color: color, fontWeight: FontWeight.bold, fontSize: 18),
      ),
    );
  }
}

// ── Loading state ─────────────────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Color(0xFF2B5BFF)),
          SizedBox(height: 16),
          Text('Cargando usuarios...',
              style: TextStyle(
                  color: Color(0xFF8A94A6),
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool hasFilters;
  const _EmptyState({required this.hasFilters});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEEF2FF), Color(0xFFE0E7FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFF2B5BFF).withOpacity(0.12),
                      blurRadius: 18,
                      offset: const Offset(0, 6)),
                ],
              ),
              child: Icon(
                hasFilters
                    ? Icons.search_off_rounded
                    : Icons.people_outline_rounded,
                size: 52,
                color: const Color(0xFF2B5BFF),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              hasFilters
                  ? 'Sin resultados'
                  : 'Sin usuarios registrados',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D1B3E)),
            ),
            const SizedBox(height: 10),
            Text(
              hasFilters
                  ? 'Intenta cambiar los filtros o la búsqueda.'
                  : 'Aún no hay usuarios en la base de datos.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF8A94A6),
                  height: 1.6),
            ),
            if (hasFilters) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () {
                  context.read<UserListProvider>().clearFilters();
                },
                icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
                label: const Text('Limpiar filtros',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2B5BFF),
                  side: const BorderSide(
                      color: Color(0xFF2B5BFF), width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String error;
  const _ErrorState({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: Colors.red.withOpacity(0.12),
                      blurRadius: 18,
                      offset: const Offset(0, 6)),
                ],
              ),
              child: const Icon(Icons.cloud_off_rounded,
                  size: 48, color: Color(0xFFEF4444)),
            ),
            const SizedBox(height: 22),
            const Text(
              'Error al cargar usuarios',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D1B3E)),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF8A94A6), height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
