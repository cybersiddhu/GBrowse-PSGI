#!/usr/bin/perl -w
use strict;
use Bio::Graphics::Browser2;
use Bio::Graphics::Browser2::Render::HTML;
use PlackBuilder;
use Data::Dump qw/pp/;

die "no conf file given\n" if !$ARGV[0];
my $req
    = PlackBuilder->mock_request(
    'action=navigate&navigate=left 0&view_start=NaN&view_stop=NaN&snapshot=false'
    );
my $globals = Bio::Graphics::Browser2->new( $ARGV[0] );
$globals->req($req);
my $session = $globals->session;
my $source  = $globals->create_data_source( $session->source );
my $render  = Bio::Graphics::Browser2::Render::HTML->new( $source, $session );
$render->req($req);
my ($status, $mime, $render_obj) = $render->asynchronous_event;
pp $render_obj;

