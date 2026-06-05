import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/message_model.dart';
import '../../providers/chat_provider.dart';

/// Full-screen chat UI (HU-12).
///
/// Required params:
///  [appointmentId]    – the Firestore appointment doc ID (used as chat room).
///  [otherPersonName]  – the display name of the other participant.
///  [currentUserName]  – the display name of the logged-in user.
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
  static const Color _primary   = Color(0xFF2B5BFF);
  static const Color _bg        = Color(0xFFF4F6FB);
  static const Color _textMain  = Color(0xFF0D1B3E);
  static const Color _textSub   = Color(0xFF8A94A6);

  late final ChatProvider _chatProvider;
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _providerDisposed = false;

  @override
  void initState() {
    super.initState();
    _chatProvider = ChatProvider.forCurrentUser(
      appointmentId: widget.appointmentId,
      displayName: widget.currentUserName,
    );
    _chatProvider.addListener(_onMessages);
  }

  @override
  void dispose() {
    _providerDisposed = true;
    _chatProvider.removeListener(_onMessages);
    _chatProvider.dispose();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onMessages() {
    if (_providerDisposed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
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
        appBar: _buildAppBar(),
        body: Column(
          children: [
            // ── Offline banner ────────────────────────────────────────────────
            Consumer<ChatProvider>(
              builder: (_, prov, __) => prov.isOffline
                  ? _OfflineBanner(onDismiss: prov.clearOfflineFlag)
                  : const SizedBox.shrink(),
            ),

            // ── Appointment info chip ─────────────────────────────────────────
            _AppointmentChip(
              date: widget.appointmentDate,
              time: widget.appointmentTime,
            ),

            // ── Message list ─────────────────────────────────────────────────
            Expanded(
              child: Consumer<ChatProvider>(
                builder: (_, prov, __) {
                  if (prov.error != null) {
                    return Center(
                      child: Text(
                        'Error al cargar mensajes.\n${prov.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: _textSub),
                      ),
                    );
                  }
                  if (prov.messages.isEmpty) {
                    return _EmptyChat(name: widget.otherPersonName);
                  }
                  return ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    itemCount: prov.messages.length,
                    itemBuilder: (_, i) {
                      final msg = prov.messages[i];
                      final isMine = msg.senderId ==
                          _chatProvider.currentUserId;
                      final showDate = i == 0 ||
                          !_sameDay(
                              prov.messages[i - 1].sentAt, msg.sentAt);
                      return Column(
                        children: [
                          if (showDate) _DateDivider(date: msg.sentAt),
                          _MessageBubble(
                            message: msg,
                            isMine: isMine,
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),

            // ── Input bar ────────────────────────────────────────────────────
            _InputBar(
              controller: _inputCtrl,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    final initial = widget.otherPersonName.isNotEmpty
        ? widget.otherPersonName[0].toUpperCase()
        : '?';
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: _textMain, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: _primary.withOpacity(0.15),
            child: Text(initial,
                style: const TextStyle(
                    color: _primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.otherPersonName,
                    style: const TextStyle(
                        color: _textMain,
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                    overflow: TextOverflow.ellipsis),
                Consumer<ChatProvider>(
                  builder: (_, prov, __) => Text(
                    prov.isSending ? 'Enviando...' : 'En línea',
                    style: TextStyle(
                      fontSize: 11,
                      color: prov.isSending
                          ? _textSub
                          : const Color(0xFF22C55E),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      titleSpacing: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: Colors.grey.shade100, height: 1),
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
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chat_bubble_outline_rounded,
                  size: 48, color: Color(0xFF2B5BFF)),
            ),
            const SizedBox(height: 20),
            Text(
              '¡Comienza la conversación!',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D1B3E)),
            ),
            const SizedBox(height: 8),
            Text(
              'Envía tu primer mensaje a $name.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14, color: Color(0xFF8A94A6), height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Appointment info chip ─────────────────────────────────────────────────────

class _AppointmentChip extends StatelessWidget {
  final String date;
  final String time;
  const _AppointmentChip({required this.date, required this.time});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.calendar_month_rounded,
              size: 14, color: Color(0xFF2B5BFF)),
          const SizedBox(width: 6),
          Text(
            'Cita: $date  ·  $time',
            style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF2B5BFF),
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('Confirmada',
                style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFF16A34A),
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ── Offline banner ────────────────────────────────────────────────────────────

class _OfflineBanner extends StatelessWidget {
  final VoidCallback onDismiss;
  const _OfflineBanner({required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFF7ED),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded,
              size: 18, color: Color(0xFFF59E0B)),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Esperando conexión · el mensaje no fue enviado',
              style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF92400E),
                  fontWeight: FontWeight.w500),
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(Icons.close_rounded,
                size: 18, color: Color(0xFFF59E0B)),
          ),
        ],
      ),
    );
  }
}

// ── Date divider ──────────────────────────────────────────────────────────────

class _DateDivider extends StatelessWidget {
  final DateTime date;
  const _DateDivider({required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    String label;
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      label = 'Hoy';
    } else if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1) {
      label = 'Ayer';
    } else {
      label = DateFormat('d MMM yyyy', 'es').format(date);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(children: [
        const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF8A94A6),
                  fontWeight: FontWeight.w600)),
        ),
        const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
      ]),
    );
  }
}

// ── Message bubble ────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMine;

  static const Color _primary  = Color(0xFF2B5BFF);
  static const Color _textMain = Color(0xFF0D1B3E);
  static const Color _textSub  = Color(0xFF8A94A6);

  const _MessageBubble({required this.message, required this.isMine});

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('HH:mm').format(message.sentAt);

    return Padding(
      padding: EdgeInsets.only(
        top: 4,
        bottom: 4,
        left: isMine ? 60 : 0,
        right: isMine ? 0 : 60,
      ),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[
            CircleAvatar(
              radius: 14,
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
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: isMine
                    ? const LinearGradient(
                        colors: [Color(0xFF2B5BFF), Color(0xFF5E81FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isMine ? null : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMine ? 18 : 4),
                  bottomRight: Radius.circular(isMine ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isMine
                        ? _primary.withOpacity(0.25)
                        : Colors.black.withOpacity(0.06),
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
                      color: isMine ? Colors.white : _textMain,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 10,
                          color: isMine
                              ? Colors.white.withOpacity(0.7)
                              : _textSub,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (isMine) ...[
                        const SizedBox(width: 4),
                        if (message.isPending)
                          Icon(Icons.schedule_rounded,
                              size: 12,
                              color: Colors.white.withOpacity(0.6))
                        else
                          Icon(Icons.done_all_rounded,
                              size: 12,
                              color: Colors.white.withOpacity(0.8)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isMine) const SizedBox(width: 4),
        ],
      ),
    );
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
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, -4)),
        ],
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 12,
        top: 12,
        bottom: 12 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Text field
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F6FB),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: TextField(
                  controller: widget.controller,
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(
                      fontSize: 15, color: Color(0xFF0D1B3E)),
                  decoration: const InputDecoration(
                    hintText: 'Escribe un mensaje...',
                    hintStyle: TextStyle(
                        color: Color(0xFF8A94A6), fontSize: 15),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                  ),
                  onSubmitted: (_) => widget.onSend(),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Send button
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
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
                color: _hasText ? null : Colors.grey.shade200,
                shape: BoxShape.circle,
                boxShadow: _hasText
                    ? [
                        BoxShadow(
                            color: _primary.withOpacity(0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 3))
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
                      color: _hasText ? Colors.white : Colors.grey.shade400,
                      size: 22,
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
