#!/usr/bin/env python3
"""Generate localized legal HTML from modular markdown sources."""

from __future__ import annotations

import re
from pathlib import Path

try:
    import yaml
except ImportError:
    yaml = None  # type: ignore

WORKSPACE = Path(__file__).resolve().parents[3]
LEGAL = WORKSPACE / "legal"
CONTENT = LEGAL / "content"
CONFIG = LEGAL / "config" / "entity.yaml"
MANIFEST = LEGAL / "manifest.yaml"
OUTPUT = Path(__file__).resolve().parents[1] / "static" / "legal"

CSS = """
:root { --text:#1a1a2e; --muted:#5c5c7a; --border:#e8e8f0; --accent:#6b5ce7; --bg:#faf9f7; }
* { box-sizing: border-box; }
body { font-family: system-ui, -apple-system, "Segoe UI", Roboto, "Noto Sans Arabic", sans-serif;
  line-height: 1.65; color: var(--text); background: var(--bg); margin: 0; padding: 0; }
.wrap { max-width: 760px; margin: 0 auto; padding: 2rem 1.25rem 4rem; }
header { border-bottom: 1px solid var(--border); margin-bottom: 2rem; padding-bottom: 1rem; }
h1 { font-size: 1.75rem; margin: 0 0 .5rem; letter-spacing: -0.02em; }
.meta { color: var(--muted); font-size: .9rem; }
h2 { font-size: 1.15rem; margin: 2rem 0 .75rem; color: var(--text); }
p, li { font-size: .98rem; }
ul, ol { padding-inline-start: 1.25rem; }
table { width: 100%; border-collapse: collapse; font-size: .92rem; margin: 1rem 0; }
th, td { border: 1px solid var(--border); padding: .55rem .65rem; text-align: start; vertical-align: top; }
th { background: #f3f2ff; }
.note { background: #fff8e6; border: 1px solid #f0d78c; border-radius: 8px; padding: .85rem 1rem; font-size: .92rem; margin: 1rem 0; }
footer { margin-top: 3rem; padding-top: 1rem; border-top: 1px solid var(--border); color: var(--muted); font-size: .85rem; }
.lang-nav { margin-top: .75rem; font-size: .88rem; }
.lang-nav a { color: var(--accent); margin-inline-end: .75rem; }
.doc-nav a { color: var(--accent); margin-inline-end: .75rem; }
[dir="rtl"] body { text-align: right; }
"""


def _load_yaml(path: Path) -> dict:
    if yaml is None:
        raise SystemExit("PyYAML required: pip install pyyaml")
    return yaml.safe_load(path.read_text(encoding="utf-8")) or {}


def _build_vars(entity: dict) -> dict[str, str]:
    platform = entity.get("platform", {})
    ent = entity.get("entity", {})
    contacts = entity.get("contacts", {})
    urls = entity.get("urls", {})
    version = entity.get("version", {})
    targets = entity.get("response_targets", {})
    platforms = platform.get("platforms", [])

    return {
        "platform_name": platform.get("name", "Dribex"),
        "platform_description": platform.get("description", ""),
        "platform_list": ", ".join(platforms),
        "legal_name": ent.get("legal_name", ""),
        "trading_name": ent.get("trading_name", "Dribex"),
        "address_line_1": ent.get("address_line_1", ""),
        "city": ent.get("city", ""),
        "postal_code": ent.get("postal_code", ""),
        "country": ent.get("country", "Morocco"),
        "registration_number": ent.get("registration_number", ""),
        "cndp_status": ent.get("cndp_status", ""),
        "jurisdiction": platform.get("jurisdiction", "Kingdom of Morocco"),
        "governing_law": platform.get("governing_law", "laws of the Kingdom of Morocco"),
        "minimum_age": str(platform.get("minimum_age", 16)),
        "privacy_email": contacts.get("privacy", ""),
        "dpo_email": contacts.get("dpo", ""),
        "support_email": contacts.get("support", ""),
        "legal_email": contacts.get("legal", ""),
        "sellers_email": contacts.get("sellers", ""),
        "billing_email": contacts.get("billing", ""),
        "safety_email": contacts.get("safety", ""),
        "copyright_email": contacts.get("copyright", ""),
        "security_email": contacts.get("security", ""),
        "accessibility_email": contacts.get("accessibility", ""),
        "enterprise_email": contacts.get("enterprise", ""),
        "website_url": urls.get("website", ""),
        "app_url": urls.get("app", ""),
        "package_version": version.get("package", "2.0.0"),
        "effective_date": version.get("effective_date", ""),
        "last_updated": version.get("last_updated", ""),
        "support_response_days": str(targets.get("general_support_days", 2)),
        "privacy_response_days": str(targets.get("privacy_request_days", 30)),
        "security_response_days": str(targets.get("security_ack_days", 3)),
        "copyright_response_days": str(targets.get("copyright_days", 5)),
        "safety_response_min": str(targets.get("safety_hours_min", 24)),
        "safety_response_max": str(targets.get("safety_hours_max", 72)),
    }


def _substitute(text: str, variables: dict[str, str]) -> str:
    def repl(match: re.Match[str]) -> str:
        key = match.group(1)
        return variables.get(key, match.group(0))

    return re.sub(r"\{\{(\w+)\}\}", repl, text)


def _inline_md(text: str) -> str:
    text = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", text)
    text = re.sub(
        r"\[([^\]]+)\]\(([^)]+)\)",
        r'<a href="\2">\1</a>',
        text,
    )
    return text


def _markdown_to_html(md: str, variables: dict[str, str]) -> tuple[str, str]:
    md = _substitute(md, variables)
    title = "Dribex"
    if md.startswith("---"):
        _, front, rest = md.split("---", 2)
        for line in front.strip().splitlines():
            if line.startswith("title:"):
                title = line.split(":", 1)[1].strip()
        md = rest.strip()

    html_parts: list[str] = []
    lines = md.splitlines()
    i = 0
    in_table = False
    table_rows: list[str] = []

    def flush_table() -> None:
        nonlocal in_table, table_rows
        if not table_rows:
            return
        html_parts.append("<table>")
        for ri, row in enumerate(table_rows):
            cells = [c.strip() for c in row.strip("|").split("|")]
            tag = "th" if ri == 0 else "td"
            html_parts.append("<tr>" + "".join(f"<{tag}>{_inline_md(c)}</{tag}>" for c in cells) + "</tr>")
        html_parts.append("</table>")
        table_rows = []
        in_table = False

    while i < len(lines):
        line = lines[i].rstrip()
        if not line.strip():
            i += 1
            continue
        if line.startswith("|"):
            in_table = True
            table_rows.append(line)
            i += 1
            continue
        if in_table:
            flush_table()

        if line.startswith("## "):
            html_parts.append(f"<h2>{_inline_md(line[3:].strip())}</h2>")
        elif line.startswith("> "):
            note_lines = [line[2:]]
            i += 1
            while i < len(lines) and lines[i].startswith("> "):
                note_lines.append(lines[i][2:])
                i += 1
            html_parts.append(f'<div class="note">{_inline_md(" ".join(note_lines))}</div>')
            continue
        elif line.startswith("- "):
            html_parts.append("<ul>")
            while i < len(lines) and lines[i].startswith("- "):
                html_parts.append(f"<li>{_inline_md(lines[i][2:].strip())}</li>")
                i += 1
            html_parts.append("</ul>")
            continue
        elif re.match(r"^\d+\.\s", line):
            html_parts.append("<ol>")
            while i < len(lines) and re.match(r"^\d+\.\s", lines[i]):
                item = re.sub(r"^\d+\.\s*", "", lines[i]).strip()
                html_parts.append(f"<li>{_inline_md(item)}</li>")
                i += 1
            html_parts.append("</ol>")
            continue
        else:
            para = line
            i += 1
            while i < len(lines) and lines[i].strip() and not lines[i].startswith(("#", ">", "-", "|")) and not re.match(r"^\d+\.\s", lines[i]):
                para += " " + lines[i].strip()
                i += 1
            html_parts.append(f"<p>{_inline_md(para)}</p>")
            continue
        i += 1

    if in_table:
        flush_table()

    return title, "\n".join(html_parts)


def _page(
    lang: str,
    slug: str,
    title: str,
    body: str,
    variables: dict[str, str],
    related: list[tuple[str, str]],
) -> str:
    rtl = ' dir="rtl"' if lang == "ar" else ""
    lang_links = []
    for code, label in [("en", "English"), ("fr", "Français"), ("ar", "العربية")]:
        if code != lang:
            lang_links.append(f'<a href="/legal/{code}/{slug}">{label}</a>')
    doc_links = [f'<a href="/legal/{lang}/{s}">{label}</a>' for s, label in related]

    meta = (
        f'{variables["platform_name"]} · Version {variables["package_version"]} · '
        f'Effective {variables["effective_date"]} · Last updated {variables["last_updated"]}'
    )

    return f"""<!DOCTYPE html>
<html lang="{lang}"{rtl}>
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<title>{title} — {variables["platform_name"]}</title>
<style>{CSS}</style>
</head>
<body>
<div class="wrap">
<header>
<h1>{title}</h1>
<p class="meta">{meta}</p>
<p class="lang-nav">{" · ".join(lang_links)}</p>
</header>
<main>
{body}
</main>
<footer>
<p class="doc-nav">{" · ".join(doc_links)}</p>
<p>© {variables["platform_name"]} · <a href="mailto:{variables["privacy_email"]}">{variables["privacy_email"]}</a></p>
</footer>
</div>
</body>
</html>
"""


def main() -> None:
    entity = _load_yaml(CONFIG)
    manifest = _load_yaml(MANIFEST)
    variables = _build_vars(entity)
    languages = manifest.get("languages", ["en", "fr", "ar"])

    related_labels = {
        "privacy": "Privacy",
        "terms": "Terms",
        "cookies": "Cookies",
        "seller-terms": "Seller Terms",
        "community-guidelines": "Community",
        "account-deletion": "Account deletion",
        "subscription-terms": "Subscriptions",
        "legal-notice": "Legal notice",
        "open-source-licenses": "Open source",
    }

    public_manifest = {
        "package_version": manifest.get("package_version"),
        "effective_date": manifest.get("effective_date"),
        "last_updated": manifest.get("last_updated"),
        "languages": languages,
        "documents": [],
    }

    for doc in manifest.get("documents", []):
        slug = doc["slug"]
        content_dir = CONTENT / slug
        related = []
        for rel_slug in doc.get("related", []):
            label = related_labels.get(rel_slug, rel_slug.replace("-", " ").title())
            related.append((rel_slug, label))

        if doc.get("status") == "published":
            public_manifest["documents"].append(
                {
                    "id": doc.get("id"),
                    "slug": slug,
                    "version": doc.get("version"),
                    "effective_date": doc.get("effective_date"),
                    "title": doc.get("title", {}),
                    "summary": doc.get("summary"),
                    "consent_required": doc.get("consent_required"),
                    "related": doc.get("related", []),
                }
            )

        for lang in languages:
            src = content_dir / f"{lang}.md"
            if not src.is_file():
                src = content_dir / "en.md"
            if not src.is_file():
                print(f"skip missing {slug}/{lang}")
                continue
            title, body = _markdown_to_html(src.read_text(encoding="utf-8"), variables)
            out = OUTPUT / lang / f"{slug}.html"
            out.parent.mkdir(parents=True, exist_ok=True)
            out.write_text(_page(lang, slug, title, body, variables, related), encoding="utf-8")
            print(f"wrote {out}")

    manifest_out = OUTPUT / "manifest.json"
    import json

    manifest_out.write_text(json.dumps(public_manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"wrote {manifest_out}")


if __name__ == "__main__":
    main()
