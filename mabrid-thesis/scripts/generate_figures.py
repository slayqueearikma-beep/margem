#!/usr/bin/env python3
"""Generate professional figures for the MABRID French academic report."""

from __future__ import annotations

from pathlib import Path

import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch, Circle
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
FIG = ROOT / "figures"
BLUE = "#1E3A5F"
ACCENT = "#8A7CC6"
LIGHT = "#EEF2F8"
MUTED = "#5C6B7A"

plt.rcParams.update(
    {
        "font.family": "DejaVu Sans",
        "font.size": 10,
        "axes.unicode_minus": False,
    }
)


def save(name: str) -> None:
    path = FIG / name
    path.parent.mkdir(parents=True, exist_ok=True)
    if name.endswith(".pdf"):
        plt.savefig(path, bbox_inches="tight", dpi=200)
    else:
        plt.savefig(path, bbox_inches="tight", dpi=180)
    plt.close()
    print(f"wrote {path}")


def box(ax, x, y, w, h, text, fc=LIGHT, ec=BLUE, fs=9, bold=False):
    patch = FancyBboxPatch(
        (x, y),
        w,
        h,
        boxstyle="round,pad=0.02,rounding_size=0.08",
        linewidth=1.4,
        edgecolor=ec,
        facecolor=fc,
    )
    ax.add_patch(patch)
    weight = "bold" if bold else "normal"
    ax.text(x + w / 2, y + h / 2, text, ha="center", va="center", fontsize=fs, weight=weight, color=BLUE)


def arrow(ax, x1, y1, x2, y2, dashed=False):
    style = "dashed" if dashed else "solid"
    ax.add_patch(
        FancyArrowPatch(
            (x1, y1),
            (x2, y2),
            arrowstyle="-|>",
            mutation_scale=12,
            linewidth=1.2,
            color=BLUE,
            linestyle=style,
        )
    )


def logo():
    fig, ax = plt.subplots(figsize=(4, 1.6))
    ax.set_xlim(0, 10)
    ax.set_ylim(0, 4)
    ax.axis("off")
    box(ax, 0.2, 0.8, 9.6, 2.4, "", fc=BLUE, ec=BLUE)
    ax.text(5, 2, "MABRID", ha="center", va="center", fontsize=28, weight="bold", color="white")
    ax.text(5, 1.1, "Place de marché numérique de confiance", ha="center", va="center", fontsize=9, color="#D8E4F5")
    save("mabrid-logo.png")


def platform_ecosystem():
    fig, ax = plt.subplots(figsize=(10, 6))
    ax.set_xlim(0, 10)
    ax.set_ylim(0, 6)
    ax.axis("off")
    ax.set_title("Écosystème multi-acteurs MABRID", fontsize=13, weight="bold", color=BLUE, pad=12)
    box(ax, 0.5, 4.2, 2.2, 1.0, "Acheteurs", fc="#FFFFFF")
    box(ax, 3.9, 4.2, 2.2, 1.0, "Vendeurs / PME", fc="#FFFFFF")
    box(ax, 7.3, 4.2, 2.2, 1.0, "Partenaires\n(institutions)", fc="#FFFFFF")
    box(ax, 2.8, 2.2, 4.4, 1.2, "Plateforme MABRID\n(gouvernance, confiance, modération)", fc=ACCENT + "33", ec=ACCENT, bold=True)
    box(ax, 0.8, 0.5, 2.5, 1.0, "Paiements\nhors plateforme", fc=LIGHT)
    box(ax, 3.7, 0.5, 2.5, 1.0, "Services\njuridiques", fc=LIGHT)
    box(ax, 6.6, 0.5, 2.5, 1.0, "Observabilité\n& sécurité", fc=LIGHT)
    for x in [1.6, 5.0, 8.4]:
        arrow(ax, x, 4.2, 5.0, 3.4)
    for x, y in [(2.05, 1.5), (4.95, 1.5), (7.85, 1.5)]:
        arrow(ax, 5.0, 2.2, x, y + 1.0, dashed=True)
    save("ch01-platform-ecosystem.pdf")


def morocco_map():
    fig, ax = plt.subplots(figsize=(8, 7))
    ax.set_title("Déploiement national par phases", fontsize=13, weight="bold", color=BLUE)
    cities = {
        "Casablanca": (1, 2.2, 1),
        "Rabat": (0.6, 2.8, 1),
        "Marrakech": (-0.8, 1.0, 2),
        "Tanger": (-1.2, 4.0, 2),
        "Fès": (0.2, 3.4, 2),
        "Agadir": (-1.0, -0.5, 3),
        "Meknès": (0.0, 3.0, 3),
        "Oujda": (2.0, 3.8, 3),
    }
    ax.plot([-1.5, 2.3, 1.8, -1.2, -1.5], [-1, -0.8, 4.5, 4.3, -1], color=BLUE, lw=1.5)
    ax.fill([-1.5, 2.3, 1.8, -1.2, -1.5], [-1, -0.8, 4.5, 4.3, -1], color=LIGHT, alpha=0.6)
    colors = {1: BLUE, 2: ACCENT, 3: MUTED}
    for name, (x, y, phase) in cities.items():
        ax.scatter(x, y, s=180, c=colors[phase], edgecolors="white", linewidth=1.2, zorder=3)
        ax.text(x, y + 0.18, name, ha="center", fontsize=8, color=BLUE)
    legend = [
        mpatches.Patch(color=BLUE, label="Phase 1 — villes d'ancrage"),
        mpatches.Patch(color=ACCENT, label="Phase 2 — expansion régionale"),
        mpatches.Patch(color=MUTED, label="Phase 3 — couverture nationale"),
    ]
    ax.legend(handles=legend, loc="lower right", frameon=True, fontsize=8)
    ax.set_xlim(-2, 2.8)
    ax.set_ylim(-1.5, 5)
    ax.axis("off")
    save("ch01-morocco-map.pdf")


def stakeholder_map():
    fig, ax = plt.subplots(figsize=(9, 6))
    ax.set_xlim(0, 10)
    ax.set_ylim(0, 6)
    ax.axis("off")
    ax.set_title("Carte des parties prenantes", fontsize=13, weight="bold", color=BLUE)
    center = Circle((5, 3), 1.1, facecolor=ACCENT + "44", edgecolor=ACCENT, linewidth=1.5)
    ax.add_patch(center)
    ax.text(5, 3, "MABRID", ha="center", va="center", weight="bold", color=BLUE)
    nodes = [
        (1.2, 4.8, "Acheteurs"),
        (8.8, 4.8, "Vendeurs"),
        (1.0, 1.2, "Régulateurs"),
        (5.0, 0.6, "Investisseurs"),
        (9.0, 1.2, "Communautés\nlocales"),
        (5.0, 5.3, "Partenaires\ntechnologiques"),
    ]
    for x, y, label in nodes:
        box(ax, x - 1.0, y - 0.45, 2.0, 0.9, label, fc="#FFFFFF", fs=8)
        arrow(ax, x, y, 5, 3, dashed=(y > 4.5))
    save("ch01-stakeholder-map.pdf")


def entrepreneur_journey():
    fig, ax = plt.subplots(figsize=(10, 3.2))
    ax.set_xlim(0, 10)
    ax.set_ylim(0, 2)
    ax.axis("off")
    ax.set_title("Parcours entrepreneurial MABRID", fontsize=13, weight="bold", color=BLUE)
    steps = ["Idée", "Validation\nmarché", "MVP", "Lancement\npilote", "Scale\nnational"]
    xs = np.linspace(1, 9, len(steps))
    for i, (x, label) in enumerate(zip(xs, steps)):
        box(ax, x - 0.75, 0.55, 1.5, 0.9, label, fc="#FFFFFF" if i % 2 else LIGHT)
        if i < len(steps) - 1:
            arrow(ax, x + 0.75, 1.0, xs[i + 1] - 0.75, 1.0)
    save("ch02-entrepreneur-journey.pdf")


def business_model_canvas():
    fig, ax = plt.subplots(figsize=(11, 6.5))
    ax.set_xlim(0, 11)
    ax.set_ylim(0, 6.5)
    ax.axis("off")
    ax.set_title("Business Model Canvas — MABRID", fontsize=13, weight="bold", color=BLUE)
    blocks = [
        (0.2, 3.4, 2.0, 2.8, "Partenaires\nclés"),
        (2.4, 3.4, 2.0, 1.3, "Activités\nclés"),
        (2.4, 4.9, 2.0, 1.3, "Ressources\nclés"),
        (4.6, 3.4, 2.2, 2.8, "Proposition\nde valeur\n(confiance locale)"),
        (6.9, 3.4, 2.0, 1.3, "Relation\nclient"),
        (6.9, 4.9, 2.0, 1.3, "Canaux\n(app, web)"),
        (9.1, 3.4, 1.7, 2.8, "Segments\nclients"),
        (2.4, 0.4, 4.4, 2.6, "Structure\nde coûts"),
        (6.9, 0.4, 3.9, 2.6, "Sources\nde revenus\n(abonnements)"),
    ]
    for x, y, w, h, text in blocks:
        box(ax, x, y, w, h, text, fs=8)
    save("ch02-bmc.pdf")


def org_chart():
    fig, ax = plt.subplots(figsize=(9, 5.5))
    ax.set_xlim(0, 9)
    ax.set_ylim(0, 5.5)
    ax.axis("off")
    ax.set_title("Gouvernance organisationnelle (illustrative)", fontsize=13, weight="bold", color=BLUE)
    box(ax, 3.2, 4.3, 2.6, 0.9, "Direction générale", bold=True)
    roles = ["Produit", "Technologie", "Sécurité", "Juridique", "Marketing"]
    xs = np.linspace(0.6, 7.0, len(roles))
    for x, role in zip(xs, roles):
        box(ax, x, 2.5, 1.5, 0.8, role, fs=8)
        arrow(ax, 4.5, 4.3, x + 0.75, 3.3)
    box(ax, 3.0, 0.8, 3.0, 0.9, "Comité sécurité & conformité", fc=ACCENT + "33", ec=ACCENT)
    for x in xs:
        arrow(ax, x + 0.75, 2.5, 4.5, 1.7, dashed=True)
    save("ch02-org-chart.pdf")


def entrepreneur_timeline():
    fig, ax = plt.subplots(figsize=(10, 3.5))
    ax.set_title("Chronologie entrepreneuriale (36 mois)", fontsize=13, weight="bold", color=BLUE)
    months = [0, 6, 12, 18, 24, 30, 36]
    labels = ["Étude", "MVP", "Pilote\n3 villes", "Monétisation", "Expansion", "Série A?", "Maturité"]
    ax.plot(months, [1] * len(months), color=BLUE, lw=2)
    ax.scatter(months, [1] * len(months), s=120, c=ACCENT, zorder=3, edgecolors="white")
    for m, lab in zip(months, labels):
        ax.text(m, 1.08, lab, ha="center", fontsize=8, color=BLUE)
    ax.set_yticks([])
    ax.set_xlabel("Mois")
    ax.set_xlim(-2, 38)
    ax.set_ylim(0.8, 1.25)
    ax.spines[["left", "top", "right"]].set_visible(False)
    save("ch02-entrepreneur-timeline.pdf")


def security_governance():
    fig, ax = plt.subplots(figsize=(9, 5))
    ax.set_xlim(0, 9)
    ax.set_ylim(0, 5)
    ax.axis("off")
    ax.set_title("Gouvernance de la sécurité", fontsize=13, weight="bold", color=BLUE)
    layers = [
        (1.0, 3.8, "Politiques & normes"),
        (1.0, 2.7, "Contrôles techniques"),
        (1.0, 1.6, "Opérations SOC"),
        (1.0, 0.5, "Amélioration continue"),
    ]
    for i, (x, y, text) in enumerate(layers):
        box(ax, x, y, 7.0, 0.85, text, fc="#FFFFFF" if i % 2 else LIGHT)
    save("ch03-security-governance.pdf")


def network_segmentation():
    fig, ax = plt.subplots(figsize=(10, 5))
    ax.set_xlim(0, 10)
    ax.set_ylim(0, 5)
    ax.axis("off")
    ax.set_title("Segmentation réseau logique (Azure)", fontsize=13, weight="bold", color=BLUE)
    zones = [
        (0.4, 3.2, 9.2, 1.2, "DMZ — WAF / API Gateway / TLS"),
        (0.4, 1.8, 4.3, 1.1, "Sous-réseau applicatif\n(Container Apps)"),
        (5.1, 1.8, 4.5, 1.1, "Sous-réseau admin\n(IP allowlist)"),
        (0.4, 0.4, 9.2, 1.1, "Données — PostgreSQL, Blob (Private Endpoints)"),
    ]
    for x, y, w, h, text in zones:
        box(ax, x, y, w, h, text, fs=8)
    save("ch03-network-segmentation.pdf")


def soc_dashboard():
    fig, ax = plt.subplots(figsize=(10, 4.5))
    ax.set_title("Indicateurs SOC (vue synthétique)", fontsize=13, weight="bold", color=BLUE)
    metrics = ["Alertes ouvertes", "Temps moyen\n de réponse", "Incidents\n critiques", "Couverture\n journaux"]
    values = [12, 18, 2, 96]
    colors = [ACCENT, BLUE, "#C45C5C", "#3E8E5A"]
    bars = ax.bar(metrics, values, color=colors, edgecolor="white", linewidth=0.8)
    ax.set_ylabel("Valeur (indicative)")
    ax.set_ylim(0, 110)
    for bar, val in zip(bars, values):
        ax.text(bar.get_x() + bar.get_width() / 2, bar.get_height() + 2, str(val), ha="center", fontsize=9)
    ax.spines[["top", "right"]].set_visible(False)
    save("ch03-soc-dashboard.pdf")


def app_architecture():
    fig, ax = plt.subplots(figsize=(10, 5.5))
    ax.set_xlim(0, 10)
    ax.set_ylim(0, 5.5)
    ax.axis("off")
    ax.set_title("Architecture applicative MarGem / MABRID", fontsize=13, weight="bold", color=BLUE)
    box(ax, 0.8, 4.0, 2.0, 1.0, "Flutter\nMobile")
    box(ax, 3.3, 4.0, 2.0, 1.0, "Admin Web")
    box(ax, 6.0, 4.0, 3.0, 1.0, "Utilisateurs\n(acheteurs / vendeurs)")
    box(ax, 2.5, 2.3, 5.0, 1.0, "API FastAPI\n(auth, catalogue, communauté)", bold=True)
    box(ax, 0.8, 0.6, 2.2, 1.0, "PostgreSQL")
    box(ax, 3.5, 0.6, 2.2, 1.0, "Stockage\nmédias")
    box(ax, 6.2, 0.6, 2.8, 1.0, "SMTP / Maps\n(optionnel)")
    arrow(ax, 1.8, 4.0, 4.0, 3.3)
    arrow(ax, 4.3, 4.0, 5.0, 3.3)
    arrow(ax, 7.5, 4.0, 5.0, 3.3, dashed=True)
    arrow(ax, 4.0, 2.3, 1.9, 1.6)
    arrow(ax, 5.0, 2.3, 4.6, 1.6)
    arrow(ax, 6.0, 2.3, 7.6, 1.6, dashed=True)
    save("ch03b-app-architecture.pdf")


def middleware_stack():
    fig, ax = plt.subplots(figsize=(8, 6))
    ax.set_xlim(0, 8)
    ax.set_ylim(0, 6)
    ax.axis("off")
    ax.set_title("Pile middleware sécurité (backend)", fontsize=13, weight="bold", color=BLUE)
    layers = [
        "TLS / HTTPS",
        "Rate limiting",
        "Admin IP & Origin guards",
        "JWT + MFA",
        "Validation & audit",
        "Handlers métier",
    ]
    h = 0.75
    for i, layer in enumerate(layers):
        y = 5.0 - i * (h + 0.15)
        fc = ACCENT + "33" if i < 3 else LIGHT
        box(ax, 1.0, y, 6.0, h, layer, fc=fc, fs=9)
    save("ch03b-middleware-stack.pdf")


def mobile_security():
    fig, ax = plt.subplots(figsize=(7, 6))
    ax.set_xlim(0, 7)
    ax.set_ylim(0, 6)
    ax.axis("off")
    ax.set_title("Sécurité client mobile Flutter", fontsize=13, weight="bold", color=BLUE)
    layers = [
        "UI & navigation",
        "Gestion erreurs\n(production)",
        "Stockage sécurisé\n(tokens)",
        "Certificate pinning\n(optionnel)",
        "Transport HTTPS",
    ]
    for i, layer in enumerate(layers):
        y = 4.8 - i * 0.95
        box(ax, 1.0, y, 5.0, 0.75, layer, fc="#FFFFFF" if i % 2 else LIGHT, fs=8)
    save("ch03b-mobile-security.pdf")


def data_flow_map():
    fig, ax = plt.subplots(figsize=(9, 5))
    ax.set_xlim(0, 9)
    ax.set_ylim(0, 5)
    ax.axis("off")
    ax.set_title("Gouvernance des données et transferts", fontsize=13, weight="bold", color=BLUE)
    box(ax, 0.5, 3.5, 2.0, 1.0, "Collecte\n(compte, contenu)")
    box(ax, 3.2, 3.5, 2.3, 1.0, "Traitement\n(Maroc / cloud)")
    box(ax, 6.3, 3.5, 2.2, 1.0, "Conservation\n& suppression")
    box(ax, 1.5, 1.0, 2.5, 1.0, "Loi 09-08\n(CNDP)")
    box(ax, 4.8, 1.0, 2.5, 1.0, "Droits\nutilisateurs")
    arrow(ax, 2.5, 4.0, 3.2, 4.0)
    arrow(ax, 5.5, 4.0, 6.3, 4.0)
    arrow(ax, 4.35, 3.5, 2.75, 2.0, dashed=True)
    arrow(ax, 4.35, 3.5, 6.05, 2.0, dashed=True)
    save("ch05-data-flow-map.pdf")


def compliance_cycle():
    fig, ax = plt.subplots(figsize=(6, 6))
    ax.set_xlim(-1.6, 1.6)
    ax.set_ylim(-1.6, 1.6)
    ax.axis("off")
    ax.set_title("Cycle de conformité", fontsize=13, weight="bold", color=BLUE)
    steps = ["Identifier", "Mettre en\nœuvre", "Surveiller", "Améliorer"]
    angles = np.linspace(90, 90 - 360, 5)[:-1]
    for ang, step in zip(angles, steps):
        rad = np.deg2rad(ang)
        x, y = 1.1 * np.cos(rad), 1.1 * np.sin(rad)
        circle = Circle((x, y), 0.42, facecolor=LIGHT, edgecolor=BLUE, linewidth=1.3)
        ax.add_patch(circle)
        ax.text(x, y, step, ha="center", va="center", fontsize=8, color=BLUE)
    for i in range(len(steps)):
        a1 = np.deg2rad(angles[i])
        a2 = np.deg2rad(angles[(i + 1) % len(steps)])
        ax.annotate(
            "",
            xy=(1.1 * np.cos(a2), 1.1 * np.sin(a2)),
            xytext=(1.1 * np.cos(a1), 1.1 * np.sin(a1)),
            arrowprops=dict(arrowstyle="-|>", color=ACCENT, lw=1.5),
        )
    save("ch05-compliance-cycle.pdf")


def expansion_map():
    fig, ax = plt.subplots(figsize=(8, 7))
    ax.set_title("Feuille de route d'expansion géographique", fontsize=13, weight="bold", color=BLUE)
    cities = {
        "Casablanca": (1, 2.2, 1),
        "Rabat": (0.6, 2.8, 1),
        "Marrakech": (-0.8, 1.0, 2),
        "Tanger": (-1.2, 4.0, 2),
        "Fès": (0.2, 3.4, 2),
        "Agadir": (-1.0, -0.5, 3),
    }
    ax.plot([-1.5, 2.3, 1.8, -1.2, -1.5], [-1, -0.8, 4.5, 4.3, -1], color=BLUE, lw=1.5)
    ax.fill([-1.5, 2.3, 1.8, -1.2, -1.5], [-1, -0.8, 4.5, 4.3, -1], color=LIGHT, alpha=0.6)
    colors = {1: BLUE, 2: ACCENT, 3: MUTED}
    for name, (x, y, phase) in cities.items():
        ax.scatter(x, y, s=180, c=colors[phase], edgecolors="white", linewidth=1.2, zorder=3)
        ax.text(x, y + 0.18, name, ha="center", fontsize=8, color=BLUE)
    legend = [
        mpatches.Patch(color=BLUE, label="Phase 1"),
        mpatches.Patch(color=ACCENT, label="Phase 2"),
        mpatches.Patch(color=MUTED, label="Phase 3"),
    ]
    ax.legend(handles=legend, loc="lower right", frameon=True, fontsize=8)
    ax.set_xlim(-2, 2.8)
    ax.set_ylim(-1.5, 5)
    ax.axis("off")
    save("ch06-expansion-map.pdf")


def brand_guidelines():
    fig, ax = plt.subplots(figsize=(8, 4.5))
    ax.set_xlim(0, 8)
    ax.set_ylim(0, 4.5)
    ax.axis("off")
    ax.set_title("Directives de marque MABRID", fontsize=13, weight="bold", color=BLUE)
    swatches = [(BLUE, "Bleu institutionnel"), (ACCENT, "Accent violet"), (LIGHT, "Fond clair"), ("#FAF9F7", "Neutre")]
    for i, (color, label) in enumerate(swatches):
        x = 0.5 + i * 1.9
        patch = FancyBboxPatch((x, 2.0), 1.4, 1.2, boxstyle="round,pad=0.02", facecolor=color, edgecolor=BLUE)
        ax.add_patch(patch)
        ax.text(x + 0.7, 1.5, label, ha="center", fontsize=8, color=BLUE)
    ax.text(4, 0.7, "Typographie : sans-serif moderne · Ton : confiance, clarté, proximité locale", ha="center", fontsize=9, color=MUTED)
    save("ch07-brand-guidelines.pdf")


def marketing_funnel():
    fig, ax = plt.subplots(figsize=(8, 5))
    ax.set_title("Entonnoir d'acquisition", fontsize=13, weight="bold", color=BLUE)
    stages = ["Notoriété", "Téléchargement", "Inscription", "Première\ninteraction", "Rétention"]
    widths = [100, 78, 58, 42, 28]
    y = np.arange(len(stages))
    ax.barh(y, widths, color=[BLUE, ACCENT, BLUE, ACCENT, MUTED], edgecolor="white")
    ax.set_yticks(y, stages)
    ax.set_xlabel("Volume relatif (%)")
    ax.invert_yaxis()
    ax.spines[["top", "right"]].set_visible(False)
    save("ch07-marketing-funnel.pdf")


def azure_architecture():
    fig, ax = plt.subplots(figsize=(11, 6))
    ax.set_xlim(0, 11)
    ax.set_ylim(0, 6)
    ax.axis("off")
    ax.set_title("Architecture Azure — production MABRID / MarGem", fontsize=13, weight="bold", color=BLUE)
    box(ax, 0.3, 4.7, 10.4, 0.9, "Internet — TLS — WAF / Front Door", fc=LIGHT)
    box(ax, 0.5, 3.2, 3.0, 1.2, "Container Apps\nAPI FastAPI")
    box(ax, 4.0, 3.2, 3.0, 1.2, "Admin Web\nnginx")
    box(ax, 7.5, 3.2, 3.0, 1.2, "Azure AD\nIdentité")
    box(ax, 0.5, 1.5, 4.8, 1.2, "PostgreSQL Flexible\n(Private Endpoint)")
    box(ax, 5.8, 1.5, 4.7, 1.2, "Blob Storage\n+ Key Vault")
    box(ax, 0.5, 0.2, 10.0, 0.9, "Application Insights · Log Analytics · Alertes", fc=ACCENT + "22", ec=ACCENT)
    save("architecture-azure-prod.png")


def onprem_architecture():
    fig, ax = plt.subplots(figsize=(11, 6))
    ax.set_xlim(0, 11)
    ax.set_ylim(0, 6)
    ax.axis("off")
    ax.set_title("Architecture Ubuntu on-premise — pilote / labo", fontsize=13, weight="bold", color=BLUE)
    box(ax, 0.3, 4.7, 10.4, 0.9, "Nginx / Traefik — Let's Encrypt — UFW", fc=LIGHT)
    box(ax, 0.5, 3.0, 3.2, 1.3, "Docker Compose\nAPI + Admin")
    box(ax, 4.2, 3.0, 3.0, 1.3, "PostgreSQL\n16")
    box(ax, 7.5, 3.0, 3.0, 1.3, "MinIO / disque\nlocal médias")
    box(ax, 0.5, 1.2, 5.0, 1.2, "Prometheus · Grafana · Loki", fc=ACCENT + "22", ec=ACCENT)
    box(ax, 5.8, 1.2, 4.7, 1.2, "Sauvegardes\n+ Fail2Ban")
    box(ax, 0.5, 0.1, 10.0, 0.8, "Réseau local / Tailscale pour accès admin", fc=LIGHT)
    save("architecture-onprem-ubuntu.png")


def main() -> None:
    logo()
    platform_ecosystem()
    morocco_map()
    stakeholder_map()
    entrepreneur_journey()
    business_model_canvas()
    org_chart()
    entrepreneur_timeline()
    security_governance()
    network_segmentation()
    soc_dashboard()
    app_architecture()
    middleware_stack()
    mobile_security()
    data_flow_map()
    compliance_cycle()
    expansion_map()
    brand_guidelines()
    marketing_funnel()
    azure_architecture()
    onprem_architecture()


if __name__ == "__main__":
    main()
