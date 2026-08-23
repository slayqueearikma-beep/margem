import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../../core/services/app_storage.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/async_error_view.dart';
import '../../core/widgets/buyer_ui_components.dart';
import '../../l10n/app_localizations.dart';

final conversationsProvider =
    FutureProvider.autoDispose<List<ConversationModel>>((ref) async {
  final session = ref.watch(userSessionProvider);
  if (session == null || session.isGuest) return const [];
  return apiServiceProvider.fetchConversations();
});

final conversationsUnreadCountProvider = Provider.autoDispose<AsyncValue<int>>(
  (ref) {
    return ref.watch(conversationsProvider).whenData(
          (items) => items.fold<int>(0, (sum, c) => sum + c.unreadCount),
        );
  },
);

class MessagesInboxScreen extends ConsumerStatefulWidget {
  const MessagesInboxScreen({super.key});

  @override
  ConsumerState<MessagesInboxScreen> createState() =>
      _MessagesInboxScreenState();
}

class _MessagesInboxScreenState extends ConsumerState<MessagesInboxScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = ref.watch(userSessionProvider);
    final isGuest = session == null || session.isGuest;
    final conversationsAsync = ref.watch(conversationsProvider);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BuyerScreenTitle(title: l10n.navMessages),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenHorizontal,
            ),
            child: BuyerSearchBar(
              hint: l10n.searchConversations,
              controller: _searchController,
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: isGuest
                ? BuyerEmptyState(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: l10n.signInToMessage,
                    subtitle: l10n.signInToMessageSubtitle,
                    actionLabel: l10n.logIn,
                    onAction: () => context.push('/login'),
                  )
                : conversationsAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.lavender,
                      ),
                    ),
                    error: (e, _) => AsyncErrorView.fromError(
                      e,
                      onRetry: () => ref.invalidate(conversationsProvider),
                    ),
                    data: (conversations) {
                      final filtered = _query.isEmpty
                          ? conversations
                          : conversations
                              .where((c) =>
                                  c.peerName.toLowerCase().contains(_query) ||
                                  c.lastMessagePreview
                                      .toLowerCase()
                                      .contains(_query))
                              .toList();
                      if (filtered.isEmpty) {
                        return BuyerEmptyState(
                          icon: Icons.forum_outlined,
                          title: l10n.noConversationsYet,
                          actionLabel: l10n.findPeopleToMessage,
                          onAction: () => context.push('/search'),
                        );
                      }
                      return RefreshIndicator(
                        color: AppColors.lavender,
                        onRefresh: () async =>
                            ref.invalidate(conversationsProvider),
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.screenHorizontal,
                            vertical: AppSpacing.sm,
                          ),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (_, index) {
                            final conversation = filtered[index];
                            return _ConversationTile(
                              conversation: conversation,
                              onTap: () => context.push(
                                '/messages/${conversation.id}',
                                extra: conversation,
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.onTap,
  });

  final ConversationModel conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final initial = conversation.peerName.isNotEmpty
        ? conversation.peerName.substring(0, 1).toUpperCase()
        : '?';
    final timeLabel = _formatTimestamp(conversation.lastMessageAt);

    return BuyerSurfaceCard(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.lavenderMuted,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: AppColors.lavender,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.peerName.isEmpty
                              ? l10n.conversationDefault
                              : conversation.peerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: conversation.hasUnread
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        timeLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: conversation.hasUnread
                              ? AppColors.lavender
                              : AppColors.textSecondary,
                          fontWeight: conversation.hasUnread
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.lastMessagePreview.isEmpty
                              ? l10n.tapToOpenConversation
                              : conversation.lastMessagePreview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: conversation.hasUnread
                                ? AppColors.navy
                                : AppColors.textSecondary,
                            fontWeight: conversation.hasUnread
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (conversation.hasUnread) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.lavender,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            conversation.unreadCount > 99
                                ? '99+'
                                : '${conversation.unreadCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(String raw) {
    if (raw.isEmpty) return '';
    final parsed = DateTime.tryParse(raw)?.toLocal();
    if (parsed == null) return '';
    final now = DateTime.now();
    final sameDay = parsed.year == now.year &&
        parsed.month == now.month &&
        parsed.day == now.day;
    if (sameDay) {
      final hour = parsed.hour.toString().padLeft(2, '0');
      final minute = parsed.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }
    return '${parsed.day}/${parsed.month}';
  }
}

class ConversationThreadScreen extends ConsumerStatefulWidget {
  const ConversationThreadScreen({
    super.key,
    required this.conversationId,
    this.conversation,
  });

  final String conversationId;
  final ConversationModel? conversation;

  @override
  ConsumerState<ConversationThreadScreen> createState() =>
      _ConversationThreadScreenState();
}

class _ConversationThreadScreenState
    extends ConsumerState<ConversationThreadScreen> {
  final _controller = TextEditingController();
  late Future<List<ChatMessageModel>> _future;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _future = apiServiceProvider.fetchConversationMessages(widget.conversationId);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await apiServiceProvider.replyToConversation(widget.conversationId, body);
      _controller.clear();
      setState(() {
        _future =
            apiServiceProvider.fetchConversationMessages(widget.conversationId);
      });
      ref.invalidate(conversationsProvider);
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.somethingWentWrong)),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = widget.conversation?.peerName.isNotEmpty == true
        ? widget.conversation!.peerName
        : l10n.navMessages;

    return BuyerScreenScaffold(
      appBar: BuyerAppBar(title: title),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<ChatMessageModel>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return AsyncErrorView.fromError(
                    snapshot.error!,
                    onRetry: () => setState(() {
                      _future = apiServiceProvider
                          .fetchConversationMessages(widget.conversationId);
                    }),
                  );
                }
                final messages = snapshot.data ?? const [];
                if (messages.isEmpty) {
                  return Center(child: Text(l10n.noMessagesYet));
                }
                final myId = ref.watch(authSessionProvider)?.user.id;
                return ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: messages.length,
                  itemBuilder: (_, index) {
                    final message = messages[index];
                    final mine =
                        myId != null && message.senderId.isNotEmpty && message.senderId == myId;
                    return Align(
                      alignment:
                          mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
                        ),
                        decoration: BoxDecoration(
                          color: mine
                              ? AppColors.primary.withValues(alpha: 0.12)
                              : AppColors.cardSelected,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          message.body,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: l10n.writeYourMessage,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: _sending
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
          ),
        ],
      ),
    );
  }
}
