import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../repositories/chat_repository.dart';
import 'chat_screen.dart';

/// Lists all conversations (active appointments with a chat) for the
/// logged-in user, regardless of role.
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  static const Color _primary  = Color(0xFF2B5BFF);
  static const Color _bg       = Color(0xFFF4F6FB);
  static const Color _textMain = Color(0xFF0D1B3E);
  static const Color _textSub  = Color(0xFF8A94A6);

  final _repo = ChatRepository();
  String _role = 'Paciente';
  String _userName = '';
  bool _loadingRole = true;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _loadingRole = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (mounted && doc.exists) {
        final data = doc.data()!;
        setState(() {
          _role = data['role'] as String? ?? 'Paciente';
          _userName = data['name'] as String? ??
              data['fullName'] as String? ??
              user.displayName ??
              'Usuario';
          _loadingRole = false;
        });
      } else {
        setState(() {
          _userName = user.displayName ?? 'Usuario';
          _loadingRole = false;
        });
      }
    } catch (_) {
      setState(() => _loadingRole = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (_loadingRole || user == null) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(child: CircularProgressIndicator(color: _primary)),
      );
    }

    final isPsi = _role == 'Psicólogo';

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text(
          'Mensajes',
          style: TextStyle(
              color: _textMain, fontWeight: FontWeight.bold, fontSize: 24),
        ),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade200, height: 1),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _repo.conversationsStream(
          userId: user.uid,
          isPsychologist: isPsi,
        ),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: _primary));
          }
          if (snap.hasError) {
            return Center(
              child: Text(
                'Error al cargar mensajes.\n${snap.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: _textSub),
              ),
            );
          }

          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return _EmptyConversations(isPsychologist: isPsi);
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final data = docs[i].data();
              final appointmentId = docs[i].id;
              final otherName = isPsi
                  ? (data['patientName'] as String? ?? 'Paciente')
                  : (data['psychologistName'] as String? ?? 'Psicólogo');
              final lastMsg =
                  data['lastMessage'] as String? ?? 'Sin mensajes aún';
              final lastMsgAt =
                  (data['lastMessageAt'] as Timestamp?)?.toDate();
              final date = data['date'] as String? ?? '';
              final time = data['startTime'] as String? ?? '';

              return _ConversationTile(
                appointmentId: appointmentId,
                otherPersonName: otherName,
                currentUserName: _userName,
                lastMessage: lastMsg,
                lastMessageAt: lastMsgAt,
                appointmentDate: date,
                appointmentTime: time,
              );
            },
          );
        },
      ),
    );
  }
}

// ── Conversation tile ─────────────────────────────────────────────────────────

class _ConversationTile extends StatelessWidget {
  final String appointmentId;
  final String otherPersonName;
  final String currentUserName;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final String appointmentDate;
  final String appointmentTime;

  static const Color _primary  = Color(0xFF2B5BFF);
  static const Color _textMain = Color(0xFF0D1B3E);
  static const Color _textSub  = Color(0xFF8A94A6);

  const _ConversationTile({
    required this.appointmentId,
    required this.otherPersonName,
    required this.currentUserName,
    required this.lastMessage,
    this.lastMessageAt,
    required this.appointmentDate,
    required this.appointmentTime,
  });

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return DateFormat('HH:mm').format(dt);
    }
    return DateFormat('d MMM', 'es').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final initial = otherPersonName.isNotEmpty
        ? otherPersonName[0].toUpperCase()
        : '?';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            appointmentId: appointmentId,
            otherPersonName: otherPersonName,
            currentUserName: currentUserName,
            appointmentDate: appointmentDate,
            appointmentTime: appointmentTime,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
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
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: _primary.withOpacity(0.12),
                  child: Text(initial,
                      style: const TextStyle(
                          color: _primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 20)),
                ),
                Positioned(
                  bottom: 1,
                  right: 1,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(otherPersonName,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: _textMain)),
                  const SizedBox(height: 3),
                  Text(
                    lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(fontSize: 13, color: _textSub),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Time + date chip
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (lastMessageAt != null)
                  Text(
                    _formatTime(lastMessageAt!),
                    style: const TextStyle(
                        fontSize: 11,
                        color: _textSub,
                        fontWeight: FontWeight.w500),
                  ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    appointmentDate,
                    style: const TextStyle(
                        fontSize: 10,
                        color: _primary,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyConversations extends StatelessWidget {
  final bool isPsychologist;
  const _EmptyConversations({required this.isPsychologist});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: const BoxDecoration(
                  color: Color(0xFFEEF2FF), shape: BoxShape.circle),
              child: const Icon(Icons.forum_rounded,
                  size: 56, color: Color(0xFF2B5BFF)),
            ),
            const SizedBox(height: 24),
            const Text(
              'Sin conversaciones',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D1B3E)),
            ),
            const SizedBox(height: 10),
            Text(
              isPsychologist
                  ? 'Cuando un paciente te escriba\naparecerá aquí.'
                  : 'Agenda una cita para poder chatear\ncon tu psicólogo.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF8A94A6),
                  height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}
