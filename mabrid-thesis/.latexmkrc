# Use biber for biblatex bibliographies
$biber = 'biber';

# Run makeglossaries when .glo / .acn files change
add_cus_dep('glo', 'gls', 0, 'run_makeglossaries');
add_cus_dep('acn', 'acr', 0, 'run_makeglossaries');

sub run_makeglossaries {
    my ($base_name) = @_;
    system('makeglossaries', '-q', $base_name);
}

# Force multi-pass builds for TOC and references
$pdflatex = 'pdflatex -interaction=nonstopmode %O %S';
