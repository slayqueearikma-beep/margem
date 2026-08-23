import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/community_models.dart';
import '../../core/services/api_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/community_websocket_service.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_context.dart';
import '../../core/widgets/async_error_view.dart';
import '../../core/widgets/design_system_components.dart';
import '../../core/widgets/margem_background.dart';
import '../../core/widgets/network_image_view.dart';
import '../../l10n/app_localizations.dart';
import 'community_providers.dart';

class CommunityChannelScreen extends ConsumerStatefulWidget {
  const CommunityChannelScreen({
    super.key,
    required this.channelId,
    this.channelName = '',
    this.citySlug = '',
  });

  final String channelId;
  final String channelName;
  final String citySlug;

  @override
  ConsumerState<CommunityChannelScreen> createState() =>
      _CommunityChannelScreenState();
}

class _CommunityChannelScreenState extends ConsumerState<CommunityChannelScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _ws = CommunityWebSocketService();
  final List<CommunityMessageModel> _optimistic = [];
  CommunityMessageModel? _replyTo;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _connectWs());
  }

  void _connectWs() {
    final token = apiServiceProvider.tokenProvider?.call();
    if (token == null || token.isEmpty) return;
    _ws.connect(
      channelId: widget.channelId,
      token: token,
      citySlug: widget.citySlug,
      onEvent: _handleWsEvent,
    );
  }

  void _handleWsEvent(Map<String, dynamic> event) {
    final type = event['type'] as String? ?? '';
    if (type == 'message.new') {
      final msg = parseWsMessage(event);
      if (msg != null && mounted) {
        setState(() {
          _optimistic.removeWhere((m) => m.body == msg.body && m.id.startsWith('temp-'));
        });
        ref.invalidate(communityMessagesProvider(widget.channelId));
      }
    } else if (type == 'typing') {
      final payload = event['payload'] as Map<String, dynamic>?;
      final name = payload?['display_name'] as String? ?? '';
      if (name.isNotEmpty) {
        ref.read(communityTypingUsersProvider.notifier).state = {name};
        Future<void>.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            ref.read(communityTypingUsersProvider.notifier).state = {};
          }
        });
      }
    } else if (type == 'message.deleted' || type == 'message.edited') {
      ref.invalidate(communityMessagesProvider(widget.channelId));
    }
  }

  @override
  void dispose() {
    _ws.disconnect();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty || _sending) return;

    final auth = ref.read(authSessionProvider);
    final tempId = 'temp-${DateTime.now().millisecondsSinceEpoch}';
    final optimistic = CommunityMessageModel(
      id: tempId,
      channelId: widget.channelId,
      sender: CommunitySenderModel(
        id: auth?.user.id ?? '',
        displayName: auth?.user.displayName ?? 'You',
      ),
      body: body,
      replyToId: _replyTo?.id,
      createdAt: DateTime.now(),
    );

    setState(() {
      _sending = true;
      _optimistic.insert(0, optimistic);
      _controller.clear();
      _replyTo = null;
    });

    try {
      await apiServiceProvider.postCommunityMessage(
        channelId: widget.channelId,
        body: body,
        replyToId: optimistic.replyToId,
      );
      ref.invalidate(communityMessagesProvider(widget.channelId));
      setState(() => _optimistic.removeWhere((m) => m.id == tempId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
        setState(() => _optimistic.removeWhere((m) => m.id == tempId));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final messagesAsync = ref.watch(communityMessagesProvider(widget.channelId));
    final typing = ref.watch(communityTypingUsersProvider);
    final myId = ref.watch(authSessionProvider)?.user.id;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Column(
          children: [
            Text(widget.channelName),
            if (widget.citySlug.isNotEmpty)
              Text(
                widget.citySlug,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.colors.textSecondary,
                    ),
              ),
          ],
        ),
      ),
      body: MargemBackground(
        showBlobs: false,
        child: Column(
          children: [
            Expanded(
              child: messagesAsync.when(
                data: (messages) {
                  final merged = [
                    ..._optimistic,
                    ...messages.where(
                      (m) => !_optimistic.any((o) => o.body == m.body),
                    ),
                  ];
                  if (merged.isEmpty) {
                    return AppEmptyState(
                      title: l10n.communityEmptyChannel,
                      subtitle: l10n.communityEmptyChannelSubtitle,
                      icon: Icons.chat_outlined,
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(communityMessagesProvider(widget.channelId));
                    },
                    child: ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenHorizontal,
                        vertical: AppSpacing.md,
                      ),
                      itemCount: merged.length,
                      itemBuilder: (_, index) {
                        final message = merged[index];
                        final isMine = message.sender.id == myId;
                        return _MessageBubble(
                          message: message,
                          isMine: isMine,
                          onReply: () => setState(() => _replyTo = message),
                          onReact: (emoji) => _react(message.id, emoji),
                          onReport: () => _report(message.id),
                          onCopy: () {
                            Clipboard.setData(ClipboardData(text: message.body));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l10n.communityCopied)),
                            );
                          },
                          onDelete: isMine
                              ? () => _delete(message.id)
                              : null,
                        );
                      },
                    ),
                  );
                },
                loading: () =>
                    Center(child: CircularProgressIndicator()),
                error: (e, _) => AsyncErrorView.fromError(
                  e,
                  onRetry: () =>
                      ref.invalidate(communityMessagesProvider(widget.channelId)),
                ),
              ),
            ),
            if (typing.isNotEmpty)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.communityTyping(typing.first),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.colors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                  ),
                ),
              ),
            if (_replyTo != null)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.xs,
                ),
                color: context.colors.primaryMuted,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${l10n.communityReplyingTo} ${_replyTo!.sender.displayName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() => _replyTo = null),
                    ),
                  ],
                ),
              ),
            _Composer(
              controller: _controller,
              sending: _sending,
              onSend: _send,
              onChanged: (_) => _ws.sendTyping(),
              hint: l10n.writeYourMessage,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _react(String messageId, String emoji) async {
    await apiServiceProvider.reactCommunityMessage(messageId, emoji);
    ref.invalidate(communityMessagesProvider(widget.channelId));
  }

  Future<void> _report(String messageId) async {
    await apiServiceProvider.reportCommunityMessage(
      messageId,
      reason: 'inappropriate',
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.communityReported)),
      );
    }
  }

  Future<void> _delete(String messageId) async {
    await apiServiceProvider.deleteCommunityMessage(messageId);
    ref.invalidate(communityMessagesProvider(widget.channelId));
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.onReply,
    required this.onReact,
    required this.onReport,
    required this.onCopy,
    this.onDelete,
  });

  final CommunityMessageModel message;
  final bool isMine;
  final VoidCallback onReply;
  final ValueChanged<String> onReact;
  final VoidCallback onReport;
  final VoidCallback onCopy;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bubbleColor = isMine
        ? context.colors.primary.withValues(alpha: 0.18)
        : Colors.white.withValues(alpha: 0.9);

    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMine) ...[
            _Avatar(sender: message.sender),
            SizedBox(width: AppSpacing.sm),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () => _showActions(context),
              child: Container(
                padding: EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                  border: Border.all(
                    color: isMine
                        ? context.colors.primary.withValues(alpha: 0.3)
                        : context.colors.divider,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isMine)
                      Row(
                        children: [
                          Text(
                            message.sender.displayName,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(width: 6),
                          _TrustBadge(score: message.sender.trustScore),
                          if (message.sender.isVerified)
                            Padding(
                              padding: EdgeInsetsDirectional.only(start: 4),
                              child: Icon(
                                Icons.verified_rounded,
                                size: 14,
                                color: context.colors.primary,
                              ),
                            ),
                          if (message.sender.isPremium)
                            Padding(
                              padding: EdgeInsetsDirectional.only(start: 4),
                              child: Icon(
                                Icons.workspace_premium_rounded,
                                size: 14,
                                color: context.colors.secondary,
                              ),
                            ),
                        ],
                      ),
                    if (message.isPinned)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.push_pin_rounded, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              l10n.communityPinned,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    Text(message.body),
                    if (message.reactions.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        spacing: 4,
                        children: message.reactions
                            .map(
                              (r) => ActionChip(
                                label: Text('${r.emoji} ${r.count}'),
                                onPressed: () => onReact(r.emoji),
                                visualDensity: VisualDensity.compact,
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(message.createdAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showActions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply_rounded),
              title: Text(context.l10n.communityReply),
              onTap: () {
                Navigator.pop(ctx);
                onReply();
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: Text(context.l10n.communityCopy),
              onTap: () {
                Navigator.pop(ctx);
                onCopy();
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_reaction_outlined),
              title: const Text('👍'),
              onTap: () {
                Navigator.pop(ctx);
                onReact('👍');
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: Text(context.l10n.communityReport),
              onTap: () {
                Navigator.pop(ctx);
                onReport();
              },
            ),
            if (onDelete != null)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: Text(context.l10n.remove),
                onTap: () {
                  Navigator.pop(ctx);
                  onDelete!();
                },
              ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.sender});

  final CommunitySenderModel sender;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 18,
      backgroundColor: context.colors.primaryMuted,
      child: sender.avatarUrl.isNotEmpty
          ? ClipOval(
              child: SizedBox(
                width: 36,
                height: 36,
                child: NetworkImageView(
                  url: sender.avatarUrl,
                  fit: BoxFit.cover,
                ),
              ),
            )
          : Text(
              sender.displayName.isNotEmpty
                  ? sender.displayName[0].toUpperCase()
                  : '?',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: context.colors.primary,
              ),
            ),
    );
  }
}

class _TrustBadge extends StatelessWidget {
  const _TrustBadge({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: context.colors.primaryMuted,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$score',
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.onChanged,
    required this.hint,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final ValueChanged<String> onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: hint,
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton.filled(
              onPressed: sending ? null : onSend,
              icon: sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
