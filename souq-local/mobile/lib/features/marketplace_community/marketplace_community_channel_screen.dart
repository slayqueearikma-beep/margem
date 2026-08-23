import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/marketplace_community_models.dart';
import '../../core/services/api_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_context.dart';
import '../../core/widgets/async_error_view.dart';
import '../../core/widgets/buyer_ui_components.dart';
import '../../l10n/app_localizations.dart';

final marketplaceCommunityMessagesProvider = FutureProvider.autoDispose
    .family<List<MarketplaceCommunityMessageModel>, String>((ref, channelId) {
  return apiServiceProvider.fetchMarketplaceCommunityMessages(channelId);
});

class MarketplaceCommunityChannelScreen extends ConsumerStatefulWidget {
  const MarketplaceCommunityChannelScreen({
    super.key,
    required this.channelId,
    required this.channelName,
    required this.marketplaceSlug,
    this.defaultPostType = 'general',
  });

  final String channelId;
  final String channelName;
  final String marketplaceSlug;
  final String defaultPostType;

  @override
  ConsumerState<MarketplaceCommunityChannelScreen> createState() =>
      _MarketplaceCommunityChannelScreenState();
}

class _MarketplaceCommunityChannelScreenState
    extends ConsumerState<MarketplaceCommunityChannelScreen> {
  final _controller = TextEditingController();
  String _postType = 'general';
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _postType = widget.defaultPostType;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await apiServiceProvider.postMarketplaceCommunityMessage(
        channelId: widget.channelId,
        body: body,
        postType: _postType,
      );
      _controller.clear();
      ref.invalidate(marketplaceCommunityMessagesProvider(widget.channelId));
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final messagesAsync = ref.watch(marketplaceCommunityMessagesProvider(widget.channelId));

    return BuyerScreenScaffold(
      appBar: BuyerAppBar(title: widget.channelName),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              data: (messages) => ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
                itemCount: messages.length,
                itemBuilder: (_, index) {
                  final message = messages[index];
                  return _MessageBubble(message: message);
                },
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => AsyncErrorView(
                message: error.toString(),
                onRetry: () =>
                    ref.invalidate(marketplaceCommunityMessagesProvider(widget.channelId)),
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal),
              child: Text(_error!, style: TextStyle(color: context.colors.error)),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.sm,
              AppSpacing.screenHorizontal,
              AppSpacing.md,
            ),
            child: Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _PostTypeChip(
                        label: l10n.marketplaceCommunityPostQuestion,
                        value: 'question',
                        groupValue: _postType,
                        onSelected: (v) => setState(() => _postType = v),
                      ),
                      _PostTypeChip(
                        label: l10n.marketplaceCommunityPostDeal,
                        value: 'deal',
                        groupValue: _postType,
                        onSelected: (v) => setState(() => _postType = v),
                      ),
                      _PostTypeChip(
                        label: l10n.marketplaceCommunityPostRecommend,
                        value: 'seller_recommendation',
                        groupValue: _postType,
                        onSelected: (v) => setState(() => _postType = v),
                      ),
                      _PostTypeChip(
                        label: l10n.marketplaceCommunityPostScam,
                        value: 'scam_report',
                        groupValue: _postType,
                        onSelected: (v) => setState(() => _postType = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: l10n.communityNewMessage,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PostTypeChip extends StatelessWidget {
  const _PostTypeChip({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onSelected,
  });

  final String label;
  final String value;
  final String groupValue;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: groupValue == value,
        onSelected: (_) => onSelected(value),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final MarketplaceCommunityMessageModel message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.colors.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message.senderName, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(message.body),
          ],
        ),
      ),
    );
  }
}
