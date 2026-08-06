# Use biber for biblatex bibliographies
$biber = 'biber';

# Run makeglossaries when .glo / .acn files change
add_cus_dep('glo', 'gls', 0, 'makeglossaries %O %S');
add_cus_dep('acn', 'acr', 0, 'makeglossaries %O %S');

# Force multi-pass builds for TOC and references
$pdflatex = 'pdflatex -interaction=nonstopmode %O %S';
