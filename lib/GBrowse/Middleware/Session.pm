package GBrowse::Middleware::Session;

use strict;
use parent qw/Plack::Middleware/;
use Plack::Util::Accessor qw/conf state store/;
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
    my %opt;
    for my $param (qw/store state/) {
        $opt{$param} = $self->$param if $self->$param;
    }
    my $app = $self->app;
    if ( !$self->conf )
    {    ## -- without the GBrowe.conf it tries the default option
        my $app = Plack::Middleware::Session->wrap( $app, %opt );
        return $app->($env);
    }

    my $conf_file = catfile( $self->conf, 'GBrowse.conf' );
    my $data = Bio::Graphics::FeatureFile->new( -file => $conf_file );

    my $session_val = $self->session_args($data);
    my ( $driver, $args ) = @$session_val ? @$session_val : ( 'default', {} );
    my $expires = $self->session_expires_args($data) || 2 * 3600;

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
    ## -- unless provided it always default to cookie state
    if ( not defined $opt{state} ) {
        $opt{state} = Plack::Session::State::Cookie->new(
            expires     => $expires,
            session_key => 'sid'
        );
    }
    $app = Plack::Middleware::Session->wrap( $app, %opt );
    return $app->($env);
}

sub session_args {
    my ( $self, $config ) = @_;
    my $value = $config->setting( 'general' => 'session driver' );
    return if !$value;

    my @session_data;
    my ( $driver_str, $serial_str ) = split /\;/, $value;
    my ($name) = ( ( split /\:/, $driver_str ) )[1];
    push @session_data, ucfirst $name;

    my $args_str = $config->setting( 'general' => 'session args' );
    if ($args_str) {
        my ( $arg, $param ) = split /\s+/, $args_str;
        $arg = 'dir' if $arg eq 'Directory';
        if ( $name eq 'db_file' ) {
            $arg   = 'root_dir';
            $param = dirname $param;
        }
        push @session_data, { $arg => $param };
    }
    else {
        push @session_data, {};
    }
    return \@session_data;
}

sub session_expires_args {
    my ( $self, $config ) = @_;
    my $expires_str = $config->setting( 'general' => 'expire session' );
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

