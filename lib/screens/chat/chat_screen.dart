import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/message_model.dart';
import '../../providers/chat_provider.dart';

/// Full-screen chat UI — HU-12.
///
/// T1  – Polished UI matching project design system.
/// T2  – Messages driven by a real-time Firestore stream (via [ChatProvider]).
/// T4  – Failed messages stay visible with a retry button; pending messages
///        show a clock icon.
class ChatScreen extends StatefulWidget {
  final String appointmentId;
  final String otherPersonName;
  final String currentUserName;
  final String appointmentDate;
  final String appointmentTime;

  const ChatScreen({
    super.key,
    required this.appointmentId,
    required this.otherPersonName,
    required this.currentUserName,
    required this.appointmentDate,
    required this.appointmentTime,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const Color _bg       = Color(0xFFF0F2F8);
  static const Color _textMain = Color(0xFF0D1B3E);
  static const Color _textSub  = Color(0xFF8A94A6);

  late final ChatProvider _chatProvider;
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _chatProvider = ChatProvider.forCurrentUser(
      appointmentId: widget.appointmentId,
      displayName: widget.currentUserName,
    );
    _chatProvider.addListener(_scrollToBottom);
    // Scroll to bottom after first frame when history loads.
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _disposed = true;
    _chatProvider.removeListener(_scrollToBottom);
    _chatProvider.dispose();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_disposed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _inputCtrl.clear();
    await _chatProvider.sendMessage(text);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ChatProvider>.value(
      value: _chatProvider,
      child: Scaffold(
        backgroundColor: _bg,
        // T1: keyboard pushes input bar up correctly
        resizeToAvoidBottomInset: true,
        appBar: _buildAppBar(),
        body: Column(
          children: [
            // ── Offline banner (T4) ───────────────────────────────────────────
            Consumer<ChatProvider>(
              builder: (_, prov, _) => prov.isOffline
                  ? _OfflineBanner(onDismiss: prov.clearOfflineFlag)
                  : const SizedBox.shrink(),
            ),

            // ── Appointment chip ──────────────────────────────────────────────
            _AppointmentChip(
              date: widget.appointmentDate,
              time: widget.appointmentTime,
            ),

            // ── Message list (T2 real-time stream) ────────────────────────────
            Expanded(
              child: Consumer<ChatProvider>(
                builder: (_, prov, _) {
                  if (prov.error != null && prov.messages.isEmpty) {
                    return _ErrorState(error: prov.error!);
                  }
                  if (prov.messages.isEmpty) {
                    return _EmptyChat(name: widget.otherPersonName);
                  }
                  return ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    itemCount: prov.messages.length,
                    itemBuilder: (_, i) {
                      final msg = prov.messages[i];
                      final isMine = msg.senderId == _chatProvider.currentUserId;
                      final showDate = i == 0 ||
                          !_sameDay(prov.messages[i - 1].sentAt, msg.sentAt);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (showDate) _DateDivider(date: msg.sentAt),
                          _MessageBubble(
                            message: msg,
                            isMine: isMine,
                            onRetry: msg.isFailed
                                ? () => prov.retryMessage(msg.id)
                                : null,
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),

            // ── Input bar ────────────────────────────────────────────────────
            _InputBar(controller: _inputCtrl, onSend: _send),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final initial = widget.otherPersonName.isNotEmpty
        ? widget.otherPersonName[0].toUpperCase()
        : '?';
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: _textMain, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          // Avatar with gradient background
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2B5BFF), Color(0xFF5E81FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.otherPersonName,
                  style: const TextStyle(
                    color: _textMain,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Consumer<ChatProvider>(
                  builder: (_, prov, _) {
                    final label = prov.isSending
                        ? 'Enviando...'
                        : prov.isOffline
                            ? 'Sin conexión'
                            : 'En línea';
                    final color = prov.isSending
                        ? _textSub
                        : prov.isOffline
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF22C55E);
                    return Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      titleSpacing: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: const Color(0xFFF1F5F9), height: 1),
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyChat extends StatelessWidget {
  final String name;
  const _EmptyChat({required this.name});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
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
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.chat_bubble_rounded,
                  size: 52, color: Color(0xFF2B5BFF)),
            ),
            const SizedBox(height: 24),
            const Text(
              '¡Comienza la conversación!',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D1B3E),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Envía tu primer mensaje a ${name.split(' ').first}.\nSolo puedes chatear si tienes una cita agendada.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF8A94A6),
                height: 1.6,
              ),
            ),
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
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 48, color: Color(0xFF8A94A6)),
            const SizedBox(height: 16),
            const Text(
              'No se pudieron cargar los mensajes',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D1B3E)),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Color(0xFF8A94A6)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Appointment chip ──────────────────────────────────────────────────────────

class _AppointmentChip extends StatelessWidget {
  final String date;
  final String time;
  const _AppointmentChip({required this.date, required this.time});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.event_available_rounded,
              size: 14, color: Color(0xFF2B5BFF)),
          const SizedBox(width: 6),
          Text(
            'Cita: $date  ·  $time',
            style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF2B5BFF),
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Confirmada',
              style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFF16A34A),
                  fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Offline banner (T4) ───────────────────────────────────────────────────────

class _OfflineBanner extends StatelessWidget {
  final VoidCallback onDismiss;
  const _OfflineBanner({required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFF7ED),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.wifi_off_rounded,
                  size: 18, color: Color(0xFFF59E0B)),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Sin conexión — tus mensajes fallidos pueden reintentarse.',
                  style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF92400E),
                      fontWeight: FontWeight.w600),
                ),
              ),
              GestureDetector(
                onTap: onDismiss,
                child: const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.close_rounded,
                      size: 18, color: Color(0xFFF59E0B)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Date divider ──────────────────────────────────────────────────────────────

class _DateDivider extends StatelessWidget {
  final DateTime date;
  const _DateDivider({required this.date});

  String _label() {
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Hoy';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day) {
      return 'Ayer';
    }
    return DateFormat('d MMM yyyy', 'es').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(children: [
        const Expanded(child: Divider(color: Color(0xFFDDE3EE), thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFDDE3EE)),
            ),
            child: Text(
              _label(),
              style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF8A94A6),
                  fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const Expanded(child: Divider(color: Color(0xFFDDE3EE), thickness: 1)),
      ]),
    );
  }
}

// ── Message bubble (T4 pending / failed states) ───────────────────────────────

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMine;

  /// Non-null only for failed messages — triggers a retry.
  final VoidCallback? onRetry;

  static const Color _primary  = Color(0xFF2B5BFF);
  static const Color _textMain = Color(0xFF0D1B3E);
  static const Color _textSub  = Color(0xFF8A94A6);

  const _MessageBubble({
    required this.message,
    required this.isMine,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('HH:mm').format(message.sentAt);

    return Padding(
      padding: EdgeInsets.only(
        top: 3,
        bottom: 3,
        left: isMine ? 56 : 0,
        right: isMine ? 0 : 56,
      ),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Other-user avatar
          if (!isMine) ...[
            CircleAvatar(
              radius: 15,
              backgroundColor: _primary.withOpacity(0.12),
              child: Text(
                message.senderName.isNotEmpty
                    ? message.senderName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    color: _primary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Bubble
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: isMine && !message.isFailed
                        ? const LinearGradient(
                            colors: [Color(0xFF2B5BFF), Color(0xFF5E81FF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: message.isFailed
                        ? const Color(0xFFFEF2F2)
                        : (isMine ? null : Colors.white),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isMine ? 18 : 4),
                      bottomRight: Radius.circular(isMine ? 4 : 18),
                    ),
                    border: message.isFailed
                        ? Border.all(color: const Color(0xFFFCA5A5), width: 1)
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: message.isFailed
                            ? Colors.red.withOpacity(0.08)
                            : (isMine
                                ? _primary.withOpacity(0.22)
                                : Colors.black.withOpacity(0.06)),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: isMine
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.text,
                        style: TextStyle(
                          fontSize: 15,
                          color: message.isFailed
                              ? const Color(0xFF991B1B)
                              : (isMine ? Colors.white : _textMain),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Time + status icon row
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            time,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: message.isFailed
                                  ? const Color(0xFFEF4444)
                                  : (isMine
                                      ? Colors.white.withOpacity(0.7)
                                      : _textSub),
                            ),
                          ),
                          if (isMine) ...[
                            const SizedBox(width: 4),
                            _StatusIcon(
                                isPending: message.isPending,
                                isFailed: message.isFailed),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // T4: Retry button for failed messages
                if (message.isFailed && onRetry != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, right: 2),
                    child: GestureDetector(
                      onTap: onRetry,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: const Color(0xFFFCA5A5), width: 1),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.refresh_rounded,
                                size: 12, color: Color(0xFFEF4444)),
                            SizedBox(width: 4),
                            Text(
                              'Reintentar',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFFEF4444),
                                  fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (isMine) const SizedBox(width: 4),
        ],
      ),
    );
  }
}

// ── Status icon (pending clock / failed X / sent checkmark) ──────────────────

class _StatusIcon extends StatelessWidget {
  final bool isPending;
  final bool isFailed;
  const _StatusIcon({required this.isPending, required this.isFailed});

  @override
  Widget build(BuildContext context) {
    if (isFailed) {
      return const Icon(Icons.error_outline_rounded,
          size: 12, color: Color(0xFFEF4444));
    }
    if (isPending) {
      return Icon(Icons.schedule_rounded,
          size: 12, color: Colors.white.withOpacity(0.65));
    }
    return Icon(Icons.done_all_rounded,
        size: 13, color: Colors.white.withOpacity(0.85));
  }
}

// ── Input bar ─────────────────────────────────────────────────────────────────

class _InputBar extends StatefulWidget {
  final TextEditingController controller;
  final Future<void> Function() onSend;
  const _InputBar({required this.controller, required this.onSend});

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  static const Color _primary = Color(0xFF2B5BFF);
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onText);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onText);
    super.dispose();
  }

  void _onText() {
    final v = widget.controller.text.trim().isNotEmpty;
    if (v != _hasText) setState(() => _hasText = v);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 14,
              offset: const Offset(0, -4)),
        ],
      ),
      padding: EdgeInsets.only(
        left: 14,
        right: 10,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Text field
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 130),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F2F8),
                borderRadius: BorderRadius.circular(26),
                border:
                    Border.all(color: const Color(0xFFDDE3EE), width: 1),
              ),
              child: TextField(
                controller: widget.controller,
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(
                    fontSize: 15, color: Color(0xFF0D1B3E)),
                decoration: const InputDecoration(
                  hintText: 'Escribe un mensaje...',
                  hintStyle:
                      TextStyle(color: Color(0xFF8A94A6), fontSize: 15),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 18, vertical: 11),
                ),
                onSubmitted: (_) => widget.onSend(),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Send button
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: _hasText
                  ? const LinearGradient(
                      colors: [Color(0xFF2B5BFF), Color(0xFF5E81FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: _hasText ? null : const Color(0xFFE9EBF0),
              shape: BoxShape.circle,
              boxShadow: _hasText
                  ? [
                      BoxShadow(
                          color: _primary.withOpacity(0.38),
                          blurRadius: 10,
                          offset: const Offset(0, 4))
                    ]
                  : [],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: _hasText ? widget.onSend : null,
                child: Center(
                  child: Icon(
                    Icons.send_rounded,
                    size: 22,
                    color: _hasText
                        ? Colors.white
                        : const Color(0xFFB0B8C9),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
