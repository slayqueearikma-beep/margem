    brevo = raw.get("BREVO_API_KEY", "").strip()
    insecure = raw.get("ALLOW_INSECURE_EMAIL_FALLBACK", "false").lower() == "true"
    if not brevo and not insecure:
        errors.append(
            "BREVO_API_KEY is empty and ALLOW_INSECURE_EMAIL_FALLBACK=false — "
            "API will not start in staging/production. For LAN home without outbound mail, set "
            "ALLOW_INSECURE_EMAIL_FALLBACK=true"
        )
    if insecure and not brevo:
        warnings.append(
            "ALLOW_INSECURE_EMAIL_FALLBACK=true — verification emails will be logged, not delivered"
        )
    if brevo and not raw.get("BREVO_SENDER_EMAIL", "").strip():
        warnings.append("BREVO_SENDER_EMAIL is empty — Brevo sends will fail until a verified sender is set")
