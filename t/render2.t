use strict;
use Test::More qw/no_plan/;
use Module::Build;
use File::Spec::Functions;
use lib 't';
use TestUtil;
use PlackBuilder;

my $current = Module::Build->current;
my $conf_file = catfile(
    $current->base_dir, 't',
    'testdata',                       'conf',
    'GBrowse.conf'
);
my $req = PlackBuilder->mock_request();
TestUtil->template2conf(builder => $current);

use_ok('Bio::Graphics::Browser2');
use_ok('Bio::Graphics::Browser2::Render');

my $browser2 = Bio::Graphics::Browser2->new($conf_file);
$browser2->req($req);
my $session  = $browser2->session;
my $source   = $browser2->create_data_source( $session->source );
my $render   = Bio::Graphics::Browser2::Render->new( $source, $session );
$render->req($req);

isa_ok( $render,           'Bio::Graphics::Browser2::Render' );
isa_ok( $render->globals,  'Bio::Graphics::Browser2' );
isa_ok( $render->response, 'Plack::Response' );
is( ( $render->language->language )[0],
    'posix', 'it has the default language' );
is( $render->tr( 'IMAGE_LINK', 'Link to Image' ),
    '...low-res PNG image',
    'it sets the low range png image'
);

$req->header( 'Accept-Language' => 'fr' );
$render = Bio::Graphics::Browser2::Render->new( $source, $session, $req );
is( ( $render->language->language )[0], 'fr',
    'it sets the correct language' );
is( $render->tr( 'IMAGE_LINK', 'Link to Image' ),
    'Lien vers une image de cet affichage',
    'it sets the low range png image in the correct language'
);

isa_ok($render->data_source,  'Bio::Graphics::Browser2::DataSource');
isnt($render->db, 1,  'it have not set the db yet');
my $db = $render->init_database;
isa_ok($db,  'Bio::DB::GFF::Adaptor::memory');
is($db, $render->db,  'it has a data adaptor after initialization');
is(scalar $db->features,  53,  'it has 53 features');


my $plugin = $render->init_plugins;
isa_ok($plugin, 'Bio::Graphics::Browser2::PluginSet');
my @plugins    = $plugin->plugins;
is(scalar @plugins,4,  'it has 4 plugins');

#
############### testing update code #############
is($render->default_state, 0,  'it sets the default state');
is($render->state->{width},800,  'it returns the default width');
is($render->state->{grid},1,  'it returns the default grid value');

## -- new mock request
$req = PlackBuilder->mock_request_from_query('width=1024;grid=0');
$render->req($req);
$render->update_options;
is($render->state->{width},1024,  'it returns the new value of the width');
is($render->state->{grid},0,  'it returns the new grid value');

# Session management
# (Need to undef the renderer in order to call session's destroy method)
my $id = $session->id;
$session->flush;
undef $session;

$session = $browser2->session($id);
is($session->id,$id,  'it got back the session id');
use_ok('Bio::Graphics::Browser2::Render::HTML');
$render  = Bio::Graphics::Browser2::Render::HTML->new($source,$session);
my $req2 = PlackBuilder->mock_request;
$render->req($req2);
isa_ok($render->init_database,  'Bio::DB::GFF::Adaptor::memory');
isa_ok($render->init_plugins, 'Bio::Graphics::Browser2::PluginSet');
is($render->state->{width},1024,  'it got back the previous width setting');
