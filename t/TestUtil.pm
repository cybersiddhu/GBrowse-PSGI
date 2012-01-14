package TestUtil;

use strict;

# Other modules:
use Template;
use Module::Build;
use File::Spec::Functions;

# Module implementation
#
my %conf = (
    'Gbrowse.tt' => 'GBrowse.conf',
    'volvox.tt'  => 'volvox.conf',
    'yeast.tt'   => 'yeast.conf'
);

sub template2conf {
    my ( $class, %arg ) = @_;
    my $builder = $arg{builder} || Module::Build->current;
    my $output_folder = $arg{output_folder}
        || catdir( $builder->base_dir, 't', 'testdata', 'conf' );
    my $template_folder = $arg{template_folder}
        || catdir( $builder->base_dir, 't', 'testdata', 'conf', 'templates' );

    my $var = {
        'gbrowse_conf' => $arg{gbrowse_conf}
            || catdir( $builder->base_dir, 't', 'testdata' ),
        'gbrowse_docs' => $arg{gbrowse_conf}
            || catdir( $builder->base_dir, 't' )
    };

    my $tt = Template->new(
        {   OUTPUT_PATH  => $output_folder,
            INCLUDE_PATH => $template_folder
        }
    );
    for my $template ( keys %conf ) {
        $tt->process( $template, $var, $conf{$template} ) || croak $tt->error;
    }

}

sub renderhash2query {
    my ($class, $render_hash, $name, $prepend) = @_;
    my $query_str;
    $query_str = $prepend if $prepend;
    for my $key ( keys %{ $render_hash->{$name} } ) {
        $query_str .= ";track_div_ids=$key;tk_$key=";
        $query_str .= $render_hash->{$name}{$key};
    }
    return $query_str;
}

sub remove_config {
    my ( $class, %arg ) = @_;
    my $builder = $arg{builder} || Module::Build->current;
    my $output_folder = $arg{output_folder}
        || catdir( $builder->base_dir, 't', 'testdata', 'conf' );
	unlink catfile($output_folder, $conf{$_}) for keys %conf;
}

1;    # Magic true value required at end of module

