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

my $req      = PlackBuilder->mock_request('name=ctgA');
my $browser2 = Bio::Graphics::Browser2->new($conf_file);
$browser2->req($req);
my $session = $browser2->session;
my $source  = $browser2->create_data_source( $session->source );
my $render  = Bio::Graphics::Browser2::Render::HTML->new( $source, $session );
$render->req($req);
$render->init_database;
$render->init_plugins;
$render->update_coordinates;
my $r = $render->region;
isa_ok( $r, 'Bio::Graphics::Browser2::Region' );
my $seg = $r->segments;
is( ref $seg,          'ARRAY', 'it is an arrayref' );
is( scalar @$seg,      1,       'it is an arrayref of one element' );
is( $seg->[0]->seq_id, 'ctgA',  'it returns the seq id' );
is( $seg->[0]->start,  1,       'it returns the start coordinate' );
is( $seg->[0]->end,    50000,   'it returns the end coordinate' );

# now try to fetch a nonexistent feature
$req = PlackBuilder->mock_request('name=foobar');
$render->req($req);
$render->update_coordinates;
is( $render->state->{name},
    'foobar', 'it returns the state of the feature name' );
$r = $render->region;
is( @{ $r->segments }, 0, 'its segment is not defined' );

# try fetching a feature by name
$req = PlackBuilder->mock_request('name=My_feature:f13');
$render->req($req);
$render->update_coordinates;
is( $render->state->{name},
    'My_feature:f13', 'it returns the state of the name' );
$seg = $render->region->segments;
is( $seg->[0]->seq_id, 'ctgA', 'it gets the name of the feature' );
is( $seg->[0]->start,  19157,  'it gets the start coordinate' );
is( $seg->[0]->end,    22915,  'it gets the end coordinate' );

# try fetching something that shouldn't match
$req = PlackBuilder->mock_request('name=Foo:f13');
$render->req($req);
$render->update_coordinates;
is( @{ $render->region->segments },
    0, "it should return 0 result for searching with Foo:f13" );

# try fetching something that  matches more than once
# m02 is interesting because there are four entries, but one is a duplicate
# and should be weeded out
$req = PlackBuilder->mock_request('name=Motif:m02');
$render->req($req);
$render->update_coordinates;
is( scalar @{ $render->region->features },
    3, "Motif:m02 should have matched three times" );

# try the * match
$req = PlackBuilder->mock_request('name=Motif:m0*');
$render->req($req);
$render->update_coordinates;
is( @{ $render->region->segments },
    7, "Motif:m0* should have matched  seven times" );

# try keyword search
$req = PlackBuilder->mock_request('name=kinase');
$render->req($req);
$render->update_coordinates;
is( @{ $render->region->segments },
    4, "'kinase' should have matched 4 times" );

# Exercise the plugin "find" interface.
# The "TestFinder" plugin treats the name as a feature type and returns all instances
$req = PlackBuilder->mock_request(
    'name=motif;plugin_action=Find;plugin=TestFinder');
$render->req($req);
$render->update_coordinates;
is( scalar @{ $render->region->features },
    11, "Finder plugin should have found 11 motifs" );
is( @{ $render->region->segments },
    11, "Finder plugin should have found 11 unique motif segments" );

# The finder plugin creates a "My Tracks" track, which then interferes with
# other tests.
$render->delete_uploads;

# something funny with getting render settings
isnt( $render->setting('mag icon height'),
    0, 'its mag icon height should be more than zero' );
isnt( $render->setting('fine zoom'), '',
    'its fine zoom should not be empty' );

END {
    TestUtil->remove_config( builder => $current );
    remove_tree( '/tmp/gbrowse_testing/', { keep_root => 1 } );
}
