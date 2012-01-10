#-*-Perl-*-

use strict;
use Test::More qw/no_plan/;
use Module::Build;
use File::Spec::Functions;
use lib 't';
use TestUtil;
use PlackBuilder;

my $current = Module::Build->current;

## -- generate all configuration files
TestUtil->template2conf( builder => $current );

my $base_dir = catdir($current->base_dir, 't');
my $conf_file = catfile( $base_dir, 'testdata', 'conf', 'GBrowse.conf' );
use_ok('Bio::Graphics::Browser2');

my $globals = Bio::Graphics::Browser2->new($conf_file);
isa_ok( $globals, 'Bio::Graphics::Browser2' );

# exercise globals a bit
is( $globals->config_base, catdir( $base_dir, 'testdata', 'conf' ) );
is( $globals->htdocs_base,
    catdir( $base_dir, 'testdata', 'htdocs', 'gbrowse' ) );
is( $globals->url_base, '/gbrowse' );

is( $globals->plugin_path,
    catdir( $base_dir, '/testdata/conf/../../../conf/plugins' ) );
is( $globals->language_path,
    catdir( $base_dir, 'testdata', 'conf', 'languages' ) );
is( $globals->templates_path,
    catdir( $base_dir, 'testdata', 'conf', 'templates' ) );
is( $globals->moby_path,
    catdir( $base_dir, 'testdata', 'conf', 'MobyServices' ) );

is( $globals->js_url,       '/gbrowse/js' );
is( $globals->button_url,   '/gbrowse/images/buttons' );
is( $globals->tmpimage_dir, '/tmp/gbrowse_testing/images' );
is( $globals->image_url,    '/gbrowse/i' );
is( $globals->help_url,     '/gbrowse/.' );

# does setting the environment variable change things?
$ENV{GBROWSE_CONF} = '/etc/gbrowse';
is( $globals->config_base, '/etc/gbrowse' );

is( $globals->plugin_path,    '/etc/gbrowse/../../../conf/plugins' );
is( $globals->language_path,  '/etc/gbrowse/languages' );
is( $globals->templates_path, '/etc/gbrowse/templates' );
is( $globals->moby_path,      '/etc/gbrowse/MobyServices' );

is( $globals->js_url,     '/gbrowse/js' );
is( $globals->button_url, '/gbrowse/images/buttons' );
is( $globals->help_url,   '/gbrowse/.' );

delete $ENV{$_} foreach qw(GBROWSE_CONF GBROWSE_DOCS GBROWSE_ROOT);

#$ENV{GBROWSE_DOCS} = $Bin;

# exercise tmpdir a bit
#rmtree( '/tmp/gbrowse_testing/images', 0, 0 );    # in case it was left over
my $path = $globals->tmpdir('test1/test2');
is( $path, '/tmp/gbrowse_testing/test1/test2' );

# test the data sources
my @sources = $globals->data_sources;
is( @sources,                                    2 );
is( $sources[0],                                 'volvox' );
is( $globals->data_source_description('volvox'), 'Volvox Example Database' );
is( $globals->data_source_path('yeast_chr1'),
    catdir( $base_dir, 'testdata', 'conf', 'yeast.conf' ) );
is( $globals->valid_source('volvox') ,  1);

# try to create a session
my $session = $globals->session;

# test default data source
is( $session->source,  $globals->default_source );
is( $session->source ,  'volvox' );

# change data source
$session->source('yeast_chr1');

# remember id and see if we get the same session back again
my $id = $session->id;
$session->flush;
undef $session;
$session = $globals->session($id);
is( $session->id ,  $id );
is( $session->source ,  'yeast_chr1' );

## -- this piece needed to be worked with Plack
my $req = PlackBuilder->mock_request('source=volvox');
$globals->req($req);
is( $globals->update_data_source($session) ,  'volvox');
is( $session->source ,  'volvox' );

is( $globals->update_data_source( $session, 'yeast_chr1' ), 'yeast_chr1' );
is( $session->source ,  'yeast_chr1' );

$req = PlackBuilder->mock_request_from_path('/yeast_chr1');
$globals->req($req);
is( $globals->update_data_source($session), 'yeast_chr1' );

$req = PlackBuilder->mock_request_from_path('/invalid');
$globals->req($req);
is( $globals->update_data_source($session), 'yeast_chr1' );
is( $globals->update_data_source( $session, 'volvox' ), 'volvox' );


# see whether the singleton caching system is working
is( Bio::Graphics::Browser2->new($conf_file), $globals );

#my $time = time;
#utime( $time, $time, $conf_file );    # equivalent to "touch"
#isnt( Bio::Graphics::Browser2->new($conf_file) ,  $globals );

