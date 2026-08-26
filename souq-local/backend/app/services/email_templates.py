"""Branded HTML + plain-text transactional email templates."""

from __future__ import annotations

from dataclasses import dataclass
from html import escape

from app.config import settings


@dataclass(frozen=True)
class RenderedEmail:
    subject: str
    text_body: str
    html_body: str


def _support_contact() -> str:
    reply = settings.effective_email_reply_to
    if reply:
        return reply
    from_header = settings.effective_from_header
    if "<" in from_header and ">" in from_header:
        return from_header.split("<", 1)[1].rsplit(">", 1)[0].strip()
    return from_header


def _render_layout(
    *,
    subject: str,
    heading: str,
    intro: str,
    body_lines: list[str],
    action_label: str | None = None,
    action_url: str | None = None,
    footer_note: str | None = None,
) -> RenderedEmail:
    support = _support_contact()
    app_name = settings.email_from_name.strip() or "Dribex"
    safe_heading = escape(heading)
    safe_intro = escape(intro)
    safe_lines = [escape(line) for line in body_lines]
    text_lines = [intro, "", *body_lines]
    if action_label and action_url:
        text_lines.extend(["", f"{action_label}: {action_url}"])
    if footer_note:
        text_lines.extend(["", footer_note])
    text_lines.extend(["", f"Questions? Contact us at {support}."])
    text_body = "\n".join(text_lines)

    body_html = "".join(f"<p style=\"margin:0 0 16px;color:#3d3a36;line-height:1.6;\">{line}</p>" for line in safe_lines)
    action_html = ""
    if action_label and action_url:
        action_html = (
            "<table role=\"presentation\" cellspacing=\"0\" cellpadding=\"0\" style=\"margin:24px 0;\">"
            "<tr><td align=\"center\" bgcolor=\"#8b6914\" style=\"border-radius:10px;\">"
            f"<a href=\"{escape(action_url, quote=True)}\" "
            "style=\"display:inline-block;padding:14px 28px;color:#ffffff;text-decoration:none;"
            f"font-weight:700;font-size:16px;\">{escape(action_label)}</a>"
            "</td></tr></table>"
        )
    footer_html = ""
    if footer_note:
        footer_html = (
            f"<p style=\"margin:24px 0 0;color:#6b645b;font-size:14px;line-height:1.5;\">{escape(footer_note)}</p>"
        )

    html_body = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{escape(subject)}</title>
</head>
<body style="margin:0;padding:0;background:#f5f0e8;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Arial,sans-serif;">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#f5f0e8;padding:24px 12px;">
    <tr>
      <td align="center">
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:600px;background:#ffffff;border-radius:16px;overflow:hidden;border:1px solid #e8dfd0;">
          <tr>
            <td style="padding:28px 28px 12px;text-align:center;background:#faf6ef;">
              <div style="font-size:28px;font-weight:800;color:#8b6914;letter-spacing:-0.5px;">{escape(app_name)}</div>
            </td>
          </tr>
          <tr>
            <td style="padding:8px 28px 32px;">
              <h1 style="margin:0 0 12px;font-size:24px;line-height:1.3;color:#1f1b16;">{safe_heading}</h1>
              <p style="margin:0 0 16px;color:#3d3a36;line-height:1.6;">{safe_intro}</p>
              {body_html}
              {action_html}
              {footer_html}
            </td>
          </tr>
          <tr>
            <td style="padding:18px 28px;background:#faf6ef;color:#6b645b;font-size:13px;line-height:1.5;text-align:center;">
              {escape(app_name)} · {escape(support)}
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>"""
    return RenderedEmail(subject=subject, text_body=text_body, html_body=html_body)


def render_password_reset(*, web_url: str, deep_url: str, expires_hours: int) -> RenderedEmail:
    return _render_layout(
        subject="Reset your Dribex password",
        heading="Reset your password",
        intro="We received a request to reset the password for your Dribex account.",
        body_lines=[
            f"This link expires in {expires_hours} hour(s) and can only be used once.",
            f"You can also open the Dribex app directly: {deep_url}",
        ],
        action_label="Reset password",
        action_url=web_url,
        footer_note=(
            "If you did not request a password reset, you can ignore this email. "
            "Your password will not change unless you use the link above."
        ),
    )


def render_email_verification(*, web_url: str, deep_url: str, code: str, expires_minutes: int) -> RenderedEmail:
    return _render_layout(
        subject="Verify your Dribex email",
        heading="Verify your email address",
        intro="Welcome to Dribex. Verify your email to secure your account.",
        body_lines=[
            f"Your verification code is: {code}",
            f"This code expires in {expires_minutes} minutes.",
            f"Open in the Dribex app: {deep_url}",
        ],
        action_label="Verify email",
        action_url=web_url,
        footer_note="If you did not create a Dribex account, you can ignore this email.",
    )


def render_signup_otp(*, code: str, expires_minutes: int) -> RenderedEmail:
    return _render_layout(
        subject="Your Dribex verification code",
        heading="Confirm your signup",
        intro="Use this verification code to continue creating your Dribex account.",
        body_lines=[
            f"Your verification code is: {code}",
            f"This code expires in {expires_minutes} minutes.",
        ],
        footer_note="If you did not request this code, you can ignore this email.",
    )


def render_welcome(*, display_name: str | None = None) -> RenderedEmail:
    greeting = display_name.strip() if display_name and display_name.strip() else "there"
    return _render_layout(
        subject="Welcome to Dribex",
        heading="Welcome to Dribex",
        intro=f"Hi {greeting}, your Dribex account is ready.",
        body_lines=[
            "Discover local sellers, save favorites, and connect with your community.",
        ],
        action_label="Open Dribex",
        action_url=settings.public_app_url.rstrip("/"),
    )


def render_security_alert(*, alert_type: str, message: str, detail_lines: list[str] | None = None) -> RenderedEmail:
    titles = {
        "password_changed": "Your password was changed",
        "email_changed": "Your account email was changed",
        "mfa_enabled": "MFA was enabled on your account",
        "mfa_disabled": "MFA was disabled on your account",
        "suspicious_login": "Unusual sign-in activity detected",
        "account_locked": "Your account was temporarily locked",
    }
    heading = titles.get(alert_type, "Security notice for your Dribex account")
    subject = f"Dribex security alert: {heading}"
    lines = [message, *(detail_lines or [])]
    return _render_layout(
        subject=subject,
        heading=heading,
        intro="We are letting you know about an important security event on your Dribex account.",
        body_lines=lines,
        footer_note=(
            "If you did not perform this action, reset your password immediately and contact support."
        ),
    )


def render_notification(*, subject: str, message: str) -> RenderedEmail:
    return _render_layout(
        subject=subject,
        heading=subject,
        intro=message,
        body_lines=[],
    )
