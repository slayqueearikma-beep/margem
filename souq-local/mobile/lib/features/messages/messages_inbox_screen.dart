import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../../core/services/app_storage.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_context.dart';
import '../../core/widgets/async_error_view.dart';
import '../../core/widgets/buyer_ui_components.dart';
import '../../core/widgets/user_safety_sheet.dart';
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
  const MessagesInboxScreen({super.key, this.embeddedInShell = false});

  final bool embeddedInShell;

  @override
  ConsumerState<MessagesInboxScreen> createState() =>
      _MessagesInboxScreenState();
}

class _MessagesInboxScreenState extends ConsumerState<MessagesInboxScreen>
    with WidgetsBindingObserver {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshInbox());
  }

  void _refreshInbox() {
    ref.invalidate(conversationsProvider);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshInbox();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
          if (!widget.embeddedInShell)
            BuyerScreenTitle(title: l10n.navMessages),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.screenHorizontal,
            ),
            child: BuyerSearchBar(
              hint: l10n.searchConversations,
              controller: _searchController,
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
            ),
          ),
          SizedBox(height: AppSpacing.sm),
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
                    loading: () => Center(
                      child: CircularProgressIndicator(
                        color: context.colors.primary,
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
                        color: context.colors.primary,
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
                              onTap: () async {
                                await context.push(
                                  '/messages/${conversation.id}',
                                  extra: conversation,
                                );
                                if (mounted) _refreshInbox();
                              },
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
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: context.colors.primaryMuted,
                  child: Text(
                    initial,
                    style: TextStyle(
                      color: context.colors.primary,
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
                      color: context.colors.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(width: AppSpacing.md),
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
                              ? context.colors.primary
                              : context.colors.textSecondary,
                          fontWeight: conversation.hasUnread
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  if (conversation.sellerId.isNotEmpty) ...[
                    SizedBox(height: 4),
                    Text(
                      l10n.inquiries,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: context.colors.primary,
                      ),
                    ),
                  ],
                  SizedBox(height: 4),
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
                                ? context.colors.textPrimary
                                : context.colors.textSecondary,
                            fontWeight: conversation.hasUnread
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (conversation.hasUnread) ...[
                        SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: context.colors.primary,
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
    extends ConsumerState<ConversationThreadScreen> with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _inputFocusNode = FocusNode();
  final _scrollController = ScrollController();
  List<ChatMessageModel> _messages = [];
  bool _loading = true;
  Object? _loadError;
  bool _sending = false;
  bool _pollInFlight = false;
  Timer? _pollTimer;
  static const _pollInterval = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadMessages();
    _startPolling();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_inputFocusNode.canRequestFocus) {
        _inputFocusNode.requestFocus();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadMessages();
      _startPolling();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _loadMessages(silent: true));
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (_pollInFlight) return;
    _pollInFlight = true;
    if (!silent && mounted) {
      setState(() {
        _loading = _messages.isEmpty;
        _loadError = null;
      });
    }
    try {
      final fetched = await apiServiceProvider
          .fetchConversationMessages(widget.conversationId);
      if (!mounted) return;
      setState(() {
        _messages = fetched;
        _loading = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      if (!silent || _messages.isEmpty) {
        setState(() {
          _loading = false;
          _loadError = error;
        });
      }
    } finally {
      _pollInFlight = false;
    }
  }

  @override
  void dispose() {
    ref.invalidate(conversationsProvider);
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    if (_inputFocusNode.hasFocus) {
      _inputFocusNode.unfocus();
    }
    _inputFocusNode.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await apiServiceProvider.replyToConversation(widget.conversationId, body);
      _controller.clear();
      await _loadMessages(silent: true);
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

  String _formatMessageTime(String raw) {
    if (raw.isEmpty) return '';
    final parsed = DateTime.tryParse(raw)?.toLocal();
    if (parsed == null) return '';
    final hour = parsed.hour.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = ref.watch(userSessionProvider);
    final authSession = ref.watch(authSessionProvider);
    final title = widget.conversation?.peerName.isNotEmpty == true
        ? widget.conversation!.peerName
        : l10n.navMessages;
    final peerUserId = widget.conversation?.peerUserId ?? '';
    final myUserId = authSession?.user.id ?? '';
    final canModerate = session != null &&
        !session.isGuest &&
        peerUserId.isNotEmpty &&
        myUserId.isNotEmpty &&
        peerUserId != myUserId;

    return BuyerScreenScaffold(
      appBar: BuyerAppBar(
        title: title,
        actions: [
          if (canModerate)
            UserSafetyMenuButton(
              userId: peerUserId,
              displayName: title,
              onBlocked: () => context.pop(),
            ),
        ],
      ),
      body: Column(
        children: [
          if (widget.conversation?.sellerId.isNotEmpty == true)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenHorizontal,
                vertical: AppSpacing.sm,
              ),
              color: context.colors.primaryMuted,
              child: Text(
                l10n.inquiriesSub,
                style: TextStyle(
                  fontSize: 12,
                  color: context.colors.textSecondary,
                ),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _loadError != null
                    ? AsyncErrorView.fromError(
                        _loadError!,
                        onRetry: () => _loadMessages(),
                      )
                    : _messages.isEmpty
                        ? Center(child: Text(l10n.noMessagesYet))
                        : RefreshIndicator(
                            color: context.colors.primary,
                            onRefresh: () => _loadMessages(),
                            child: ListView.builder(
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(AppSpacing.md),
                              itemCount: _messages.length,
                              itemBuilder: (_, index) {
                                final message = _messages[index];
                                final mine = myUserId.isNotEmpty &&
                                    message.senderId.isNotEmpty &&
                                    message.senderId == myUserId;
                                return Align(
                                  alignment: mine
                                      ? AlignmentDirectional.centerEnd
                                      : AlignmentDirectional.centerStart,
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    constraints: BoxConstraints(
                                      maxWidth:
                                          MediaQuery.sizeOf(context).width * 0.78,
                                    ),
                                    decoration: BoxDecoration(
                                      color: mine
                                          ? context.colors.primary
                                              .withValues(alpha: 0.12)
                                          : context.colors.surfaceVariant,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: mine
                                          ? CrossAxisAlignment.end
                                          : CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          message.body,
                                          style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface,
                                          ),
                                        ),
                                        if (message.createdAt.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            _formatMessageTime(message.createdAt),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: context.colors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
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
                      focusNode: _inputFocusNode,
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
