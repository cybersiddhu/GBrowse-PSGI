package GBrowse::Handler::PSGI;

use strict;
use Plack::Util::Accessor qw/conf htdocs/;
use Plack::Request;
use File::Spec::Functions;

# Other modules:

# Module implementation
#

sub new {
    my ( $class, %arg ) = @_;
    $class = ref $class || $class;
    my $self = bless {}, $class;
    for my $p (qw/conf htdocs/) {
        $self->$p( $arg{$p} ) if defined $arp{$p};
    }
    return $self;
}

sub run {
    my ( $self, $env ) = @_;
    my $req     = Plack::Request->new($env);
    my $globals = Bio::Graphics::Browser2->new(
        catfile( $self->conf, 'GBrowse.conf' ) );
    my $session = $globals->session;
    my $source  = $globals->create_data_source( $session->source );
    my $render
        = Bio::Graphics::Browser2::Render::HTML->new( $source, $session );
    my $resp = $render->run($req);
    return $resp->finalize;

}

1;    # Magic true value required at end of module

