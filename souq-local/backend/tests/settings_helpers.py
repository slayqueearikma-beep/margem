"""Shared Settings kwargs for production configuration tests."""

_PROD_NAPS = {
    "payment_provider": "naps",
    "naps_merchant_id": "test-merchant",
    "naps_secret_key": "test-secret-key-32chars-minimum",
    "naps_epay_payment_init_url": "https://naps.example.com/init",
    "naps_webhook_secret": "test-webhook-secret-32chars-min",
}

_PROD_BREVO = {
    "brevo_api_key": "x" * 32,
    "brevo_sender_email": "noreply@dribex.ma",
    "brevo_sender_name": "Dribex",
}
