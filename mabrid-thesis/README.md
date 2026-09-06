# MABRID — Rapport académique (français)

## Prérequis

- Distribution LaTeX (TeX Live 2023+ recommandé)
- `biber` pour la bibliographie
- `latexmk` (recommandé)
- `texlive-lang-french` pour le support français (babel)
- Python 3 + `matplotlib` pour régénérer les figures

### Debian / Ubuntu

```bash
sudo apt update
sudo apt install -y \
  latexmk \
  biber \
  texlive-latex-base \
  texlive-latex-recommended \
  texlive-latex-extra \
  texlive-bibtex-extra \
  texlive-pictures \
  texlive-fonts-recommended \
  texlive-lang-french
pip install matplotlib
```

## Figures

Générer ou mettre à jour toutes les illustrations professionnelles :

```bash
python3 scripts/generate_figures.py
```

Les fichiers sont écrits dans `figures/` (PDF vectoriel + PNG pour les architectures). Le rapport utilise `\figureplaceholder` : si un fichier est absent, un cadre gris s'affiche à la place.

## Compilation

```bash
cd mabrid-thesis
python3 scripts/generate_figures.py   # recommandé avant build
latexmk -C
latexmk -pdf -interaction=nonstopmode main.tex
```

Le fichier généré est **`main.pdf`** (environ **118 pages**, limite cible ≤ 120).

## Structure du rapport

| Chapitre | Contenu |
|----------|---------|
| 1 | Vision commerciale MABRID |
| 2 | Entrepreneuriat et stratégie de lancement |
| 3 | Gouvernance d'entreprise |
| 4 | Architecture de sécurité entreprise |
| 5 | Sécurisation technique de l'application MarGem |
| 6 | Flux d'information et déploiement Azure / on-premise |
| 7–10 | Cloud, juridique, feuille de route, marketing |
| 11 | Conclusion |

## Dépannage

| Erreur | Solution |
|--------|----------|
| `Unknown option 'french' for package babel` | `sudo apt install texlive-lang-french` |
| `Bibliography string 'andothers' untranslated` | Installer `texlive-lang-french`, puis `latexmk -C && latexmk -pdf main.tex` |
| Références `undefined` après clean | Normal au 1er passage ; relancer `latexmk` |
| `makeglossaries` manquant | `sudo apt install texlive-latex-extra` |
| PDF > 120 pages | Réduire les annexes ou condenser un chapitre ; vérifier les figures surdimensionnées |
