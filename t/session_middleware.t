use strict;
use Test::More qw/no_plan/;
use Module::Build;
use File::Spec::Functions;
use Plack::Builder;
use Plack::Request;
use Plack::Session;
use Plack::Test;
use HTTP::Request::Common qw/GET POST DELETE/;
use Plack::Middleware::Session;
use Plack::Session::Store::File;
use Plack::Session::State::Cookie;
use Plack::Session::State;
use lib 't';
use TestUtil;

my $current = Module::Build->current;

## -- generate all configuration files
TestUtil->template2conf( builder => $current );

my $session_id;
my $conf_dir = catdir( $current->base_dir, 't', 'testdata', 'conf' );
my $app1 = sub {
    my $env = shift;
    my $req = Plack::Request->new($env);
    my $session;

    my $method = $req->method;
    if ( $method eq 'GET' ) {
        $session = Plack::Session->new( $req->env );
        my @keys = $session->keys;
        my $resp = $req->new_response;
        if (@keys) {
            $resp->status(200);
            my @body;
            push @body, $session->get($_) for @keys;
            $resp->body( join( ':', @body ) );
        }
        else {
            $resp->status(204);
        }
        $resp->finalize;
    }
    elsif ( $method eq 'POST' ) {
        my $resp = $req->new_response;
        $session    = Plack::Session->new( $req->env );
        $session_id = $session->id;
        my $hash = $req->parameters;
        $session->set( $_, $hash->get($_) ) for $hash->keys;
        $resp->status(204);
        $resp->location('/');
        $resp->finalize;
    }
    elsif ( $method eq 'DELETE' ) {
        my $resp = $req->new_response;
        $session = Plack::Session->new( $req->env );
        $session->expire;
        $resp->status(204);
        $resp->finalize;
    }
};

use_ok('GBrowse::Middleware::Session');
my $builder = Plack::Builder->new;
$builder->add_middleware(
    '+GBrowse::Middleware::Session',
    conf  => $conf_dir,
    state => Plack::Session::State->new
);
my $app3 = $builder->mount( '/gbapp' => $app1 );
$app3 = $builder->to_app($app3);

#$app3 = $builder->to_app($app3);

test_psgi $app3, sub {
    my $cb  = shift;
    my $res = $cb->(
        POST '/gbapp',
        [   plack     => 'works',
            gbsession => 'okay'
        ]
    );
    is $res->code, 204;

    $res = $cb->( GET '/gbapp?plack_session=' . $session_id );
    is $res->code,    200;
    is $res->content, 'works:okay';

    $res = $cb->( DELETE '/gbapp?plack_session=' . $session_id );
    is $res->code, 204;

    $res = $cb->( GET '/gbapp?plack_session=' . $session_id );
    is $res->code, 204;
};
