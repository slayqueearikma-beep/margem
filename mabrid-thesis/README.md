# MABRID Academic Report — Build Instructions

## Requirements

- LaTeX distribution (TeX Live 2023+ recommended)
- `biber` for bibliography
- `latexmk` (optional, recommended)

### Debian / Ubuntu (recommended one-liner)

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
  texlive-fonts-recommended
```

`texlive-latex-extra` provides `microtype`, `titlesec`, `enumitem`, `glossaries`, and `pgfgantt`. The project still builds **without** `microtype` and `pgfgantt` (fallbacks are included).

### Minimal install

If you only install `texlive-latex-base`, you will hit more missing-package errors. Use the full package list above for a smooth build.

## Compile

```bash
cd mabrid-thesis
latexmk -pdf -interaction=nonstopmode main.tex
```

Or manually:

```bash
pdflatex main.tex
biber main
pdflatex main.tex
pdflatex main.tex
```

Clean rebuild:

```bash
latexmk -C
latexmk -pdf -interaction=nonstopmode main.tex
```

## Figures

Place your images in `figures/` using filenames referenced in chapters, for example:

- `figures/mabrid-logo.pdf`
- `figures/ch01-platform-ecosystem.pdf`
- `figures/ch03-network-segmentation.pdf`
- `figures/ch07-brand-guidelines.pdf`

Until files exist, the report renders grey placeholder boxes with captions.

## Customisation

Edit `frontmatter/titlepage.tex` for author, supervisor, and institution names.

## Page count

Target length is 100–120 pages with `oneside` A4 and `onehalfspacing`. Actual page count depends on figure density and institution formatting requirements.

## Troubleshooting

| Error | Fix |
|-------|-----|
| `microtype.sty not found` | Install `texlive-latex-extra`, or ignore (optional package) |
| `biblatex.sty not found` | `sudo apt install texlive-bibtex-extra biber` |
| `glossaries.sty not found` | `sudo apt install texlive-latex-extra` |
| Empty bibliography | Run `biber main` between `pdflatex` passes |
| Undefined citations | Run full `latexmk` cycle twice after `biber` |
