use strict;
use Test::More qw/no_plan/;
use Module::Build;
use File::Spec::Functions;
use lib 't';
use TestUtil;
use PlackBuilder;
use Carp::Always;

my $current = Module::Build->current;
my $conf_file
    = catfile( $current->base_dir, 't', 'testdata', 'conf', 'GBrowse.conf' );
TestUtil->template2conf( builder => $current );

use_ok('Bio::Graphics::Browser2');
use_ok('Bio::Graphics::Browser2::Render::HTML');

my $req = PlackBuilder->mock_request(
    'name=ctgA:1..20000;label=Clones-Transcripts-Motifs');
isa_ok( $req, 'Plack::Request' );
my $browser2 = Bio::Graphics::Browser2->new($conf_file);
$browser2->req($req);
my $session  = $browser2->session;
my $source   = $browser2->create_data_source( $session->source );
my $render = Bio::Graphics::Browser2::Render::HTML->new( $source, $session );
$render->req($req);
$render->init_database;
$render->init_plugins;
$render->update_coordinates;
$render->update_state;
my $s = $render->region->segments;
is( @$s, 1, 'it should have one segment' );
my @labels = $render->detail_tracks;
is( join( ' ', sort @labels ),
    'Clones Motifs Transcripts',
    'it should failed to update tracks properly'
);
my $panel_renderer = $render->get_panel_renderer( $s->[0] );
isa_ok( $panel_renderer, 'Bio::Graphics::Browser2::RenderPanels' );

my $panels = $panel_renderer->render_panels( { labels => \@labels } );
is( join( ' ', ( sort keys %$panels ) ),
    'Clones Motifs Transcripts',
    'it should have incorrect panels keys'
);
my ($png) = grep m!/gbrowse/i/!, $panels->{Motifs} =~ /src="([^"]+\.png)"/g;
like( $png, qr/\w+\.png$/,
    'it should be a png image file with alphanumeric name' );

#diag($png);
$png =~ s!/gbrowse/i!/tmp/gbrowse_testing/images!;
is( -e $png, 1, 'the file should be present in the filesystem' );

$req
    = PlackBuilder->mock_request(
    'name=ctgA:1..20000;label=Clones-Transcripts-Motifs-BindingSites-TransChip'
    );
$browser2->req($req);
$render->req($req);
$render->update_state;
$s              = $render->region->segments;
$panel_renderer = $render->get_panel_renderer( $s->[0] );
$panels         = $panel_renderer->render_panels(
    { labels => [ $render->detail_tracks ] } );
isnt(
    join( ' ', sort keys %$panels ),
    'BindingSites TransChip Clones Motifs Transcripts',
    'it should have incorrect keys'
);
($png) = grep m!/gbrowse/i/!,
    $panels->{BindingSites} =~ /src="([^"]+\.png)"/g;
like( $png, qr/\w+\.png$/,
    'it should be a png image file with alphanumeric name' );
$png =~ s!/gbrowse/i!/tmp/gbrowse_testing/images!;
is( -e $png, 1, 'the file should be present in the filesystem' );

# test different ways of splitting labels
$req = PlackBuilder->mock_request(
    'name=ctgA:1..20000;l=Clones%1EMotifs%1EBindingSites%1ETransChip');
$render->req($req);
$render->update_state;
is( join( ' ', sort $render->detail_tracks ),
    "BindingSites Clones Motifs TransChip",
    'it should have correct keys'
);

$req = PlackBuilder->mock_request(
    'name=ctgA:1..20000;label=Clones-Motifs-BindingSites');
$render->req($req);
$render->update_state;
is( join( ' ', sort $render->detail_tracks ),
    "BindingSites Clones Motifs",
    'it should have correct keys'
);

# -- user tracks
my $usertracks = $render->user_tracks;
isa_ok( $usertracks, 'Bio::Graphics::Browser2::UserTracks::Filesystem' );
like(
    $usertracks,
    qr /(database|filesystem)/i,
    'it should match either of database or filesystem'
);
isa_ok( $usertracks->{config},  'Bio::Graphics::Browser2::DataSource' );
isa_ok( $usertracks->{globals}, 'Bio::Graphics::Browser2' );

my $url         = 'http://www.foo.bar/this/is/a/remotetrack';
my $escaped_url = $usertracks->escape_url($url);
like(
    $usertracks->path,
    qr!/gbrowse_testing/userdata/volvox/[0-9a-h]{32}$!,
    'it should match the usertrack path'
);

my $file   = $usertracks->import_url($url);
my @tracks = $usertracks->tracks;
is( @tracks, 1, 'it should have one track' );
is( $tracks[0], $file,
    'the first track should be identical to the file name' );
is( $usertracks->is_imported($file), 1, 'it should have imported the file' );
my $conf = $usertracks->track_conf( $tracks[0] );
is( -e $conf, 1, 'the usertrack configuration is present in the filesystem' );

