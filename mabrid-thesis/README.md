# MABRID — Rapport académique (français)

## Prérequis

- Distribution LaTeX (TeX Live 2023+ recommandé)
- `biber` pour la bibliographie
- `latexmk` (recommandé)
- `texlive-lang-french` pour le support français (babel)

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
```

## Compilation

```bash
cd mabrid-thesis
latexmk -C
latexmk -pdf -interaction=nonstopmode main.tex
```

Le fichier généré est **`main.pdf`** (environ 103--106 pages).

## Structure du rapport

| Chapitre | Contenu |
|----------|---------|
| 1 | Vision commerciale MABRID |
| 2 | Entrepreneuriat et stratégie de lancement (~15 p.) |
| 3 | Gouvernance d'entreprise |
| 4 | Architecture de sécurité entreprise |
| 5 | Sécurisation technique de l'application MarGem (~15 p.) |
| 6--9 | Cloud, juridique, feuille de route, marketing |
| 10 | Conclusion |

## Figures

Placer les images dans `figures/` (voir les noms dans les chapitres). Des emplacements gris s'affichent tant que les fichiers sont absents.

## Dépannage

| Erreur | Solution |
|--------|----------|
| `Unknown option 'french' for package babel` | `sudo apt install texlive-lang-french` |
| `Bibliography string 'andothers' untranslated` | Installer `texlive-lang-french`, puis `latexmk -C && latexmk -pdf main.tex` |
| Références `undefined` après clean | Normal au 1er passage ; relancer `latexmk` (ou `latexmk -C` puis rebuild complet) |
| `makeglossaries` manquant | `sudo apt install texlive-latex-extra` |
| PDF incomplet (~96 p.) | Build interrompu ; relancer le cycle complet ci-dessus |
