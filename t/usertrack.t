use strict;
use Test::More qw/no_plan/;
use Module::Build;
use File::Spec::Functions;
use Bio::Graphics::FeatureFile;
use lib 't';
use TestUtil;
use PlackBuilder;

my $current = Module::Build->current;
my $conf_file
    = catfile( $current->base_dir, 't', 'testdata', 'conf', 'GBrowse.conf' );
TestUtil->template2conf( builder => $current );

use_ok('Bio::Graphics::Browser2');
use_ok('Bio::Graphics::Browser2::Render::HTML');

my $req = PlackBuilder->mock_request();
isa_ok( $req, 'Plack::Request' );
my $browser2 = Bio::Graphics::Browser2->new($conf_file);
my $session  = $browser2->session;
my $source   = $browser2->create_data_source( $session->source );
my $render = Bio::Graphics::Browser2::Render::HTML->new( $source, $session );
$render->req($req);
$render->init_database;
$render->init_plugins;
$render->update_coordinates;
$render->update_state;

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

my $f = Bio::Graphics::FeatureFile->new( -file => $conf );
my $configured_types = ( $f->configured_types )[0];
is( $configured_types, $escaped_url,
    'the configured type matched is identical to url' );
is( $f->setting( $escaped_url => 'remote feature' ), $url );
is( $f->setting( $escaped_url => 'category' ), 'My Tracks:Remote Tracks' );
is( $usertracks->filename($file),           $escaped_url );
is( $usertracks->get_file_id($escaped_url), $file );
is( $usertracks->title($file),              $escaped_url );
is( $usertracks->file_type($file), "imported" );
like( $usertracks->created($file),   qr/\d+/, 'the imported file has a created datestamp' );
like( $usertracks->modified($file),  qr/\d+/, 'the imported file has a modified datestamp' );
$usertracks->delete_file($file);
isnt( -e $conf,  1,  'conf file should not be present' );
is( $usertracks->tracks + 0, 0 );

