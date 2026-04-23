import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/models/person_item.dart';

class FakeChatView extends StatefulWidget {
  const FakeChatView({super.key, required this.person});

  final PersonItem person;

  @override
  State<FakeChatView> createState() => _FakeChatViewState();
}

class _FakeChatViewState extends State<FakeChatView> {
  final TextEditingController _controller = TextEditingController();
  final List<_FakeMessage> _messages = List<_FakeMessage>.from(
    const [
      _FakeMessage('omg, this is amazing', false),
      _FakeMessage('perfect! ✅', false),
      _FakeMessage('Wow, this is really epic', false),
      _FakeMessage('How are you?', true),
      _FakeMessage('just ideas for next time', false),
      _FakeMessage("I'll be there in 2 mins ⏰", false),
      _FakeMessage('woohoooo', true),
      _FakeMessage('Haha oh man', true),
      _FakeMessage("Haha that's terrifying 😂", true),
      _FakeMessage('aww', false),
      _FakeMessage('omg, this is amazing', false),
      _FakeMessage('woohoooo 🔥', false),
    ],
  );
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(_FakeMessage(text, true));
    });
    _controller.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 60,
        duration: const Duration(milliseconds: 220),
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
                  );
                },
              ),
            ),
            _Composer(
              controller: _controller,
              onSend: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({required this.person});

  final PersonItem person;

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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFEDE6FB),
              borderRadius: BorderRadius.circular(10),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => Get.toNamed(
                AppRoutes.audioCall,
                arguments: {'person': person},
              ),
              child: Row(
                children: [
                  const Icon(Icons.call_rounded, color: AppColors.primaryColor),
                  const SizedBox(width: 6),
                  Text(
                    'fake_chat_call'.tr,
                    style: const TextStyle(
                      color: AppColors.primaryColor,
                      fontWeight: FontWeight.w700,
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
  });

  final PersonItem person;
  final String text;
  final bool fromMe;

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
      child: Text(
        text,
        style: TextStyle(
          fontSize: 17,
          color: fromMe ? AppColors.white : AppColors.black.withValues(alpha: 0.88),
          fontWeight: FontWeight.w500,
        ),
      ),
    );

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

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Row(
        children: [
          const Icon(Icons.attach_file_rounded, size: 24, color: AppColors.black),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.black.withValues(alpha: 0.10)),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      onSubmitted: (_) => onSend(),
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
                      onTap: onSend,
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
                errorWidget: (_, __, ___) => const ColoredBox(
                  color: Color(0xFFE1E1E1),
                ),
              )
            : const ColoredBox(color: Color(0xFFE1E1E1)),
      ),
    );
  }
}

class _FakeMessage {
  const _FakeMessage(this.text, this.fromMe);

  final String text;
  final bool fromMe;
}
