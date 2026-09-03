#!/usr/bin/env python3
"""Generate Figure — Business Model Canvas de DRIBEX (Osterwalder & Pigneur)."""

from __future__ import annotations

from pathlib import Path

import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch

ROOT = Path(__file__).resolve().parent
FIG = ROOT

BLUE = "#1E3A5F"
ACCENT = "#4A6FA5"
LIGHT = "#EEF2F8"
WHITE = "#FFFFFF"
MUTED = "#5C6B7A"
TITLE_BG = "#F7F9FC"

plt.rcParams.update(
    {
        "font.family": "DejaVu Sans",
        "font.size": 9,
        "axes.unicode_minus": False,
    }
)


def box(ax, x, y, w, h, title, bullets, fc=WHITE, title_fc=LIGHT):
    patch = FancyBboxPatch(
        (x, y),
        w,
        h,
        boxstyle="round,pad=0.012,rounding_size=0.06",
        linewidth=1.2,
        edgecolor=BLUE,
        facecolor=fc,
    )
    ax.add_patch(patch)

    title_h = 0.38
    title_patch = FancyBboxPatch(
        (x + 0.04, y + h - title_h - 0.04),
        w - 0.08,
        title_h,
        boxstyle="round,pad=0.01,rounding_size=0.04",
        linewidth=0,
        facecolor=title_fc,
    )
    ax.add_patch(title_patch)
    ax.text(
        x + w / 2,
        y + h - title_h / 2 - 0.04,
        title,
        ha="center",
        va="center",
        fontsize=9.5,
        weight="bold",
        color=BLUE,
    )

    text_y = y + h - title_h - 0.22
    line_h = min(0.26, (h - title_h - 0.35) / max(len(bullets), 1))
    fs = 7.8 if len(bullets) >= 5 else 8.2
    for i, bullet in enumerate(bullets):
        ax.text(
            x + 0.12,
            text_y - i * line_h,
            f"• {bullet}",
            ha="left",
            va="top",
            fontsize=fs,
            color=MUTED,
            linespacing=1.1,
        )


def save(fig, name: str) -> None:
    path = FIG / name
    fig.savefig(path, bbox_inches="tight", dpi=220)
    if name.endswith(".png"):
        pdf_path = path.with_suffix(".pdf")
        fig.savefig(pdf_path, bbox_inches="tight")
        print(f"wrote {pdf_path}")
    print(f"wrote {path}")


def dribex_business_model_canvas() -> None:
    fig, ax = plt.subplots(figsize=(12.5, 7.2))
    ax.set_xlim(0, 12.5)
    ax.set_ylim(0, 7.2)
    ax.axis("off")

    # Figure caption / title
    ax.text(
        6.25,
        6.95,
        "Figure X.X — Business Model Canvas de DRIBEX",
        ha="center",
        va="center",
        fontsize=13,
        weight="bold",
        color=BLUE,
    )
    ax.text(
        6.25,
        6.55,
        "Modèle Osterwalder & Pigneur — place de marché DRIBEX",
        ha="center",
        va="center",
        fontsize=9,
        color=MUTED,
        style="italic",
    )

    # Classic BMC grid coordinates (x, y, w, h)
    # Top row height ~3.5, bottom row ~2.0
    top_y = 2.55
    top_h = 3.55
    bot_y = 0.35
    bot_h = 2.0

    # Left column
    box(
        ax,
        0.25,
        top_y,
        2.15,
        top_h,
        "Partenaires clés",
        [
            "Fournisseur cloud",
            "Processeur de paiement (futur)",
            "Agences de vérification",
            "Associations",
        ],
    )
    box(
        ax,
        2.55,
        top_y + 2.05,
        2.15,
        top_h - 2.05,
        "Activités clés",
        [
            "Sélection",
            "Modération",
            "Marketing",
            "Conformité",
            "Opérations de sécurité",
        ],
    )
    box(
        ax,
        2.55,
        top_y,
        2.15,
        1.9,
        "Ressources clés",
        [
            "Marque",
            "Corpus de politiques",
            "Équipe de modération",
            "Infrastructure cloud",
            "Actifs de données gouvernés",
        ],
        title_fc="#E8EDF5",
    )

    # Center
    box(
        ax,
        4.85,
        top_y,
        2.55,
        top_h,
        "Propositions de valeur",
        [
            "Découverte de confiance",
            "Vérification",
            "Communauté",
            "Analyses pour vendeurs",
        ],
        fc="#F4F7FB",
        title_fc=ACCENT + "33",
    )

    # Right column
    box(
        ax,
        7.55,
        top_y + 2.05,
        2.15,
        top_h - 2.05,
        "Relations clients",
        [
            "Libre-service",
            "Support communautaire",
            "Gestion de compte dédiée pour entreprises",
        ],
    )
    box(
        ax,
        7.55,
        top_y,
        2.15,
        1.9,
        "Canaux",
        [
            "Applications mobiles",
            "Présence web",
            "Partenariats",
            "Vente terrain pour l'entreprise",
        ],
        title_fc="#E8EDF5",
    )
    box(
        ax,
        9.85,
        top_y,
        2.4,
        top_h,
        "Segments clients",
        [
            "Acheteurs",
            "Vendeurs",
            "Entreprises multi-sites",
            "Partenaires",
        ],
    )

    # Bottom row
    box(
        ax,
        2.55,
        bot_y,
        4.85,
        bot_h,
        "Structure de coûts",
        [
            "Cloud",
            "Personnel",
            "Marketing",
            "Juridique",
            "Outils de sécurité",
            "Modération",
        ],
        fc=LIGHT,
        title_fc=WHITE,
    )
    box(
        ax,
        7.55,
        bot_y,
        4.7,
        bot_h,
        "Flux de revenus",
        [
            "Abonnements vendeurs",
            "Premium acheteur",
            "Frais de vérification",
            "Contrats d'entreprise",
        ],
        fc=LIGHT,
        title_fc=WHITE,
    )

    # Subtle outer frame
    frame = FancyBboxPatch(
        (0.15, 0.25),
        12.2,
        6.15,
        boxstyle="round,pad=0.01,rounding_size=0.08",
        linewidth=1.0,
        edgecolor="#CBD5E1",
        facecolor="none",
        linestyle="-",
    )
    ax.add_patch(frame)

    save(fig, "dribex-business-model-canvas.png")
    plt.close()


if __name__ == "__main__":
    dribex_business_model_canvas()
