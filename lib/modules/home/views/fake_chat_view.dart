import 'dart:async' show unawaited;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/ads/ads_remote_config_service.dart';
import '../../../core/models/person_item.dart';
import '../../../core/services/chatbot_service.dart';

class FakeChatView extends StatefulWidget {
  const FakeChatView({super.key, required this.person});

  final PersonItem person;

  @override
  State<FakeChatView> createState() => _FakeChatViewState();
}

class _FakeChatViewState extends State<FakeChatView> {
  final TextEditingController _controller = TextEditingController();
  final List<_FakeMessage> _messages = <_FakeMessage>[];
  final ScrollController _scrollController = ScrollController();
  late final ChatbotService _chatbot;
  bool _replyInProgress = false;

  @override
  void initState() {
    super.initState();
    final adsRc = Get.find<AdsRemoteConfigService>();
    _chatbot = ChatbotService(apiKey: adsRc.chatBotApiKey);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _replyInProgress) return;
    _replyInProgress = true;
    setState(() {
      _messages.add(_FakeMessage(text, true));
      _messages.add(_FakeMessage('fake_chat_typing'.tr, false, isTyping: true));
    });
    _controller.clear();
    _scrollToBottom();

    final history = _messages
        .where((m) => !m.isTyping)
        .map(
          (m) => <String, String>{
            'role': m.fromMe ? 'user' : 'assistant',
            'text': m.text,
          },
        )
        .toList();

    try {
      final reply = await _chatbot.getReply(
        userMessage: text,
        personaName: widget.person.name,
        history: history,
      );
      if (!mounted) return;
      setState(() {
        final typingIndex = _messages.lastIndexWhere((m) => m.isTyping);
        if (typingIndex != -1) {
          _messages[typingIndex] = _FakeMessage(reply, false);
        } else {
          _messages.add(_FakeMessage(reply, false));
        }
      });
      _scrollToBottom();
    } finally {
      _replyInProgress = false;
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 90,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _ChatHeader(person: widget.person),
            Expanded(
              child: ListView.separated(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                itemCount: _messages.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final m = _messages[index];
                  return _MessageRow(
                    person: widget.person,
                    text: m.text,
                    fromMe: m.fromMe,
                    isTyping: m.isTyping,
                  );
                },
              ),
            ),
            _Composer(controller: _controller, onSend: _sendMessage),
          ],
        ),
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({required this.person});

  final PersonItem person;
  bool get _hasAudio => (person.audioUrl?.trim().isNotEmpty ?? false);
  bool get _hasVideo => (person.videoUrl?.trim().isNotEmpty ?? false);
  bool get _canCall => _hasAudio || _hasVideo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Get.back(),
            icon: SvgPicture.asset(
              'assets/setting/ic_back.svg',
              matchTextDirection: true,
              width: 20,
              height: 20,
            ),
            color: AppColors.black,
            splashRadius: 20,
          ),
          const SizedBox(width: 2),
          _Avatar(url: person.imageUrl, size: 48),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  person.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.black,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        color: Color(0xFF51D58A),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'fake_chat_online'.tr,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.black.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_canCall)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFEDE6FB),
                borderRadius: BorderRadius.circular(10),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => Get.toNamed(
                  AppRoutes.scheduleCall,
                  arguments: {'person': person},
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.call_rounded,
                      color: AppColors.primaryColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'fake_chat_call'.tr,
                      style: const TextStyle(
                        color: AppColors.primaryColor,
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({
    required this.person,
    required this.text,
    required this.fromMe,
    this.isTyping = false,
  });

  final PersonItem person;
  final String text;
  final bool fromMe;
  final bool isTyping;

  @override
  Widget build(BuildContext context) {
    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.58,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: fromMe ? AppColors.primaryColor : const Color(0xFFF0F1F3),
        borderRadius: BorderRadius.circular(14),
      ),
      child: isTyping
          ? const _TypingDots()
          : Text(
              text,
              style: TextStyle(
                fontSize: 17,
                color: fromMe
                    ? AppColors.white
                    : AppColors.black.withValues(alpha: 0.88),
                fontWeight: FontWeight.w500,
              ),
            ),
    );

    if (isTyping) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _Avatar(url: person.imageUrl, size: 42),
          const SizedBox(width: 8),
          bubble,
        ],
      );
    }

    if (fromMe) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          bubble,
          const SizedBox(width: 8),
          _Avatar(url: person.imageUrl, size: 42),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _Avatar(url: person.imageUrl, size: 42),
        const SizedBox(width: 8),
        bubble,
      ],
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dotColor = AppColors.black.withValues(alpha: 0.62);
    return SizedBox(
      width: 34,
      height: 14,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) {
          final t = _controller.value;
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List<Widget>.generate(3, (i) {
              final phase = (t - (i * 0.16)).clamp(0.0, 1.0);
              final opacity = 0.28 + (0.72 * (1 - (phase - 0.5).abs() * 2));
              return Opacity(
                opacity: opacity.clamp(0.18, 1),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSend});

  final TextEditingController controller;
  final Future<void> Function() onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.black.withValues(alpha: 0.10),
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      onSubmitted: (_) => unawaited(onSend()),
                      textInputAction: TextInputAction.send,
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        hintText: 'fake_chat_type_message'.tr,
                        hintStyle: TextStyle(
                          color: AppColors.black.withValues(alpha: 0.38),
                          fontSize: 17,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: GestureDetector(
                      onTap: () => unawaited(onSend()),
                      child: const Icon(
                        Icons.send_rounded,
                        color: AppColors.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.size});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final u = url?.trim() ?? '';
    return ClipRRect(
      borderRadius: BorderRadius.circular(11),
      child: SizedBox(
        width: size,
        height: size,
        child: u.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: u,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const _AvatarFallback(),
              )
            : const _AvatarFallback(),
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFE1E1E1),
      child: Center(
        child: Icon(Icons.person_rounded, color: Color(0xFF9EA3AD), size: 20),
      ),
    );
  }
}

class _FakeMessage {
  const _FakeMessage(this.text, this.fromMe, {this.isTyping = false});

  final String text;
  final bool fromMe;
  final bool isTyping;
}
