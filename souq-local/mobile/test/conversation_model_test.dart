import 'package:flutter_test/flutter_test.dart';
import 'package:souq_local/core/models/models.dart';

void main() {
  test('ConversationModel parses open-conversation API payload', () {
    final model = ConversationModel.fromJson({
      'id': '550e8400-e29b-41d4-a716-446655440000',
      'buyer_id': '6ba7b810-9dad-11d1-80b4-00c04fd430c8',
      'seller_id': '6ba7b811-9dad-11d1-80b4-00c04fd430c8',
      'peer_user_id': '6ba7b810-9dad-11d1-80b4-00c04fd430c8',
      'last_message_at': '2026-08-09T10:00:00Z',
      'peer_name': 'Demo Store',
      'unread_count': 0,
      'last_message_preview': '',
    });

    expect(model.id, '550e8400-e29b-41d4-a716-446655440000');
    expect(model.peerName, 'Demo Store');
    expect(model.unreadCount, 0);
  });
}
