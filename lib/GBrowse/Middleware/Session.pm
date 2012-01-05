package GBrowse::Middleware::Session;

use strict;
use parent qw/Plack::Middleware/;
use Plack::Util::Accessor qw/conf/;
use File::Spec::Functions;
use Bio::Graphics::FeatureFile;
use Plack::Middleware::Session;
use Plack::Session::State::Cookie;
use Plack::Session::Store;
use Module::Load;
use File::Basename;

# Other modules:

# Module implementation
#

sub call {
    my ( $self, $env ) = @_;
    my $conf_file = catfile( $self->conf, 'GBrowse.conf' );
    my $data = Bio::Graphics::FeatureFile->new( -file => $conf_file );

    my $app = $self->app;
    my ( $driver, $args ) = $self->session_args($data) || ( 'default', {} );
    my $expires = $self->session_expires_args($data) || 2 * 3600;
    my %opt = (
        state => Plack::Session::State::Cookie->new( expires => $expires ) );
    if ( $driver eq 'default' ) {
        $opt{store} = Plack::Session::Store->new;
    }
    elsif ( $driver eq 'Db_file' ) {
        load 'Plack::Session::Store::Cache';
        load 'CHI';
        $opt{store} = Plack::Session::Store::Cache->new(
            cache => CHI->new( driver => 'BerkleyDB', %$args ) );
    }
    else {
        my $module = 'Plack::Session::Store::' . $driver;
        load $module;
        $opt{store} = $module->new(%$args);
    }
    $app = Plack::Middleware::Session->wrap( $app, %opt );
    $app->($env);
}

sub session_args {
    my ( $self, $config ) = @_;
    my $value = $config->setting( 'GENERAL' => 'session driver' );
    return if !$driver;

    my @session_data;
    my ( $driver_str, $serial_str ) = split /\;/, $value;
    my ($name) = ( ( split /\:/, $driver_str ) )[1];
    push @session_data, ucfirst $name;

    my $args_str = $config->setting( 'GENERAL' => 'session args' );
    if ($args_str) {
        my ( $arg, $param ) = split /\s+/, $args_str;
        $arg = 'dir' if $arg eq 'Directory';
        if ( $name eq 'db_file' ) {
            $arg   = 'root_dir';
            $param = dirname $param;
        }
        push @session_data, { $arg => $param };
    }
    return @session_data;
}

sub session_expires_args {
    my ( $self, $config ) = @_;
    my $expires_str = $config->setting( 'GENERAL' => 'expire session' );
    return if !$expires_str;

    my $value;
    if ( $expires_str =~ /^(\d+)([a-z,A-Z]+)$/ ) {
        if ( $2 eq 's' ) {
            $value = $1;
        }
        elsif ( $2 eq 'm' ) {
            $value = $1 * 60;
        }
        elsif ( $2 eq 'h' ) {
            $value = $1 * 3600;
        }
        elsif ( $2 eq 'd' ) {
            $value = $1 * 3600 * 24;
        }
        elsif ( $2 eq 'w' ) {
            $value = $1 * 3600 * 24 * 7;
        }
        else {
            $value = $1 * 3600 * 24 * 30;
        }
        return $value;
    }
}

1;    # Magic true value required at end of module

