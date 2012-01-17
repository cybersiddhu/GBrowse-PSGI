use strict;
use Test::More qw/no_plan/;
use Module::Build;
use File::Spec::Functions;
use File::Path qw/remove_tree/;
use lib 't';
use TestUtil;
use PlackBuilder;
use Carp::Always;


my $current;
my $conf_file;

BEGIN {
    $current = Module::Build->current;
    $conf_file = catfile( $current->base_dir, 't', 'testdata', 'conf',
        'GBrowse.conf' );
    TestUtil->template2conf( builder => $current );
}

use_ok('Bio::Graphics::Browser2');
use_ok('Bio::Graphics::Browser2::Render::HTML');

my $req      = PlackBuilder->mock_request();
my $browser2 = Bio::Graphics::Browser2->new($conf_file);
$browser2->req($req);
my $session  = $browser2->session;
my $source   = $browser2->create_data_source( $session->source );
my $render = Bio::Graphics::Browser2::Render::HTML->new( $source, $session );
$render->req($req);
$render->init_database;
$render->init_plugins;
$render->default_state;
is( $render->state->{width}, 800, 'it has the initial width' );

$req = PlackBuilder->mock_request('ref=ctgA;start=1;end=1000');
$render->req($req);
$render->update_coordinates;
is( $render->state->{name},  'ctgA:1..1,000', 'it gets the name' );
is( $render->state->{ref},   'ctgA',          'it gets the ref argument' );
is( $render->state->{start}, 1,               'it gets the start argument' );
is( $render->state->{stop},  1000,            'it gets the stop argument' );

# lie a little bit to test things
$render->state->{seg_min} = 1;
$render->state->{seg_max} = 5000;

# now we pretend that we've pressed the right button
$req = PlackBuilder->mock_request('right+500.x=yes;navigate=1');
$render->req($req);
$render->update_coordinates;
is( $render->state->{name}, 'ctgA:501..1,500', 'it gets the updated name' );

# pretend we want to zoom in 50%
$req = PlackBuilder->mock_request('zoom+in+50%.x=yes;navigate=1');
$render->req($req);
$render->update_coordinates;
is( $render->state->{name}, 'ctgA:751..1,250', 'it gets the name' );
my $segment = $render->segment;
is( $segment->start, 751,  'it gets start of the segment' );
is( $segment->end,   1250, 'it gets end of the segment' );

# pretend that we've selected the popup menu to go to 100 bp
$req = PlackBuilder->mock_request('span=100;navigate=1');
$render->req($req);
$render->update_coordinates;
is( $render->state->{name}, 'ctgA:951..1,050', 'it gets the name' );

# Do we clip properly? If I scroll right 5000 bp, then we should stick at 4901..5000
$req = PlackBuilder->mock_request('right+5000+bp.x=yes;navigate=1');
$render->req($req);
$render->update_coordinates;
is( $render->state->{name},
    'ctgA:4,901..5,000', 'it gets the name with correct coordinates' );

# Is the asynchronous rendering working
my ( $render_object, $retrieve_object, $status, $mime );
$req = PlackBuilder->mock_request('action=navigate;navigate=right+5000+bp');
$render->req($req);
( $status, $mime, $render_object ) = $render->asynchronous_event();
is( ref $render_object, 'HASH', 'render object is a hash reference' );
is( ref $render_object->{track_keys},
    'HASH', 'track_keys is a hash reference' );
like( $_, qr/^[a-z,A-Z,:]+$/,
    "track_keys key $_ is alphanumeric with or without colon" )
    for keys %{ $render_object->{track_keys} };

# Check the retrieve_multiple option for asynch render
my $query_str = TestUtil->renderhash2query( $render_object, 'track_keys',
    'action=retrieve_multiple' );
$req = PlackBuilder->mock_request($query_str);
$render->req($req);
( $status, $mime, $retrieve_object ) = $render->asynchronous_event;
is( ref $retrieve_object, 'HASH', 'render object is a hash reference' );
is( ref $retrieve_object->{track_html},
    'HASH', 'track_html is a hash reference' );

# Check Add Track
$req = PlackBuilder->mock_request('track_names=Motifs;action=add_tracks');
$render->req($req);
my $render_object2;
( $status, $mime, $render_object2 ) = $render->asynchronous_event();
is( ref $render_object2, 'HASH', 'render object is a hash reference' );
is( ref $render_object2->{track_data},
    'HASH', 'track_data is a hash reference' );
like( $_, qr/^[a-z,A-Z,:]+$/,
    "track_data key $_ are alphanumeric with or without colon" )
    for keys %{ $render_object2->{track_data} };

$query_str = 'action=retrieve_multiple';
my $track_data = $render_object2->{track_data};
for my $key ( keys %{$track_data} ) {
    isnt( $track_data->{$key}, undef, "track_data $key has a value" );
    my $track_key = $track_data->{$key}{track_key};
    $query_str .= ";track_div_ids=$key;tk_$key=$track_key";
}

$req = PlackBuilder->mock_request($query_str);
$render->req($req);
my $retrieve_object2;
( $status, $mime, $retrieve_object2 ) = $render->asynchronous_event;
is( ref $retrieve_object2, 'HASH', 'render object is a hash reference' );
is( ref $retrieve_object2->{track_html},
    'HASH', 'track_html is a hash reference' );

# Check update sections
$req
    = PlackBuilder->mock_request( 'action=update_sections'
        . '&section_names=nonsense'
        . '&section_names=page_title'
        . '&section_names=span'
        . '&section_names=tracks_panel'
        . '&section_names=upload_tracks_panel' );
$render->req($req);
my $render_object3;
( $status, $mime, $render_object3 ) = $render->asynchronous_event();
is( ref $render_object3, 'HASH', 'render object is a hash reference' );
is( ref $render_object3->{section_html},
    'HASH', 'section_html is a hash reference' );

my $section_html = $render_object3->{section_html};
is( $section_html->{nonsense},
    'Unknown element: nonsense',
    'it matches the nonsense key'
);
like( $section_html->{page_title},
    qr/^Volvox/, 'it matches the page_title key' );
like( $section_html->{span}, qr/selected/, 'it matches the span key' );
like( $section_html->{tracks_panel},
    qr/Clones/, 'it matches the tracks_panel key' );

# Check update sections for plugin conifig
# Nonsense plugin
$req
    = PlackBuilder->mock_request( 'action=update_sections'
        . '&section_names=plugin_configure_div'
        . '&plugin_base=blah' );
$render->req($req);
undef $render_object;
( $status, $mime, $render_object ) = $render->asynchronous_event();
is( ref $render_object, 'HASH', 'render object is a hash reference' );
is( ref $render_object->{section_html},
    'HASH', 'section_html is a hash reference' );
is( $render_object->{section_html}->{plugin_configure_div},
    "blah is not a recognized plugin",
    'it matches the unrecognized plugin'
);

# No plugin
$req = PlackBuilder->mock_request(
    'action=update_sections' . '&section_names=plugin_configure_div' );
$render->req($req);
undef $render_object;
( $status, $mime, $render_object ) = $render->asynchronous_event();
is( ref $render_object, 'HASH', 'render object is a hash reference' );
is( ref $render_object->{section_html},
    'HASH', 'section_html is a hash reference' );
is( $render_object->{section_html}->{plugin_configure_div},
    "No plugin was specified.",
    'it has no plugin specified'
);

# Real plugin
$req
    = PlackBuilder->mock_request( 'action=update_sections'
        . '&section_names=plugin_configure_div'
        . '&plugin_base=RestrictionAnnotator' );
$render->req($req);
undef $render_object;
( $status, $mime, $render_object ) = $render->asynchronous_event();
is( ref $render_object, 'HASH', 'render object is a hash reference' );
is( ref $render_object->{section_html},
    'HASH', 'section_html is a hash reference' );
like(
    $render_object->{section_html}->{plugin_configure_div},
    qr/RestrictionAnnotator.enzyme/,
    'it matches the restriction enzyme plugin'
);

# Check setting visibility
$req = PlackBuilder->mock_request(
    'action=set_track_visibility;track_name=Motifs;visible=0');
$render->req($req);
undef $render_object;
( $status, $mime, $render_object ) = $render->asynchronous_event();
is( $status, 204, 'it has no content HTTP status' );
is( $render->state()->{features}{Motifs}{visible},
    undef, 'it has not visible feature defined' );

$req = PlackBuilder->mock_request(
    'action=set_track_visibility;track_name=Motifs;visible=1');
$render->req($req);
undef $render_object;
( $status, $mime, $render_object ) = $render->asynchronous_event();
is( $status, 204, 'it has no content HTTP status' );
is( $render->state()->{features}{'Motifs'}{'visible'},
    1, 'it has visible feature' );

END {
	TestUtil->remove_config(builder => $current);
	remove_tree ('/tmp/gbrowse_testing/',  {keep_root => 1});
}
