import 'package:flutter/material.dart';

import '../messages/messages_inbox_screen.dart';

/// Seller shell tab — same inbox as `/messages`, embedded in bottom navigation.
class SellerMessagesTab extends StatelessWidget {
  const SellerMessagesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const MessagesInboxScreen(embeddedInShell: true);
  }
}
