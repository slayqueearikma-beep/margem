# MABRID Academic Report — Build Instructions

## Requirements

- LaTeX distribution (TeX Live 2023+ recommended)
- `biber` for bibliography
- `latexmk` (optional, recommended)

## Compile

```bash
cd mabrid-thesis
latexmk -pdf -interaction=nonstopmode -bibtex- main.tex
```

Or manually:

```bash
pdflatex main.tex
biber main
pdflatex main.tex
pdflatex main.tex
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
