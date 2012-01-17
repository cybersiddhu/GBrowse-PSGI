use strict;
use Test::More qw/no_plan/;
use Module::Build;
use File::Spec::Functions;
use File::Path qw/remove_tree/;
use lib 't';
use PlackBuilder;
use TestUtil;

my $current;
my $conf_file;

BEGIN {
    $current = Module::Build->current;
    $conf_file = catfile( $current->base_dir, 't', 'testdata', 'conf',
        'GBrowse.conf' );
    TestUtil->template2conf( builder => $current );
}

use_ok('Bio::Graphics::Browser2');
use_ok('Bio::Graphics::Browser2::Region');

my $req = PlackBuilder->mock_request;
my $browser2 = Bio::Graphics::Browser2->new($conf_file);
$browser2->req($req);
my $session  = $browser2->session;
my $source   = $browser2->create_data_source('volvox');
my $state    = $session->page_settings;

# first test that the region search is working
my $region = Bio::Graphics::Browser2::Region->new(
    {   source => $source,
        state  => $state,
        db => $source->open_database()   # this will open the default database
    }
);

isa_ok( $region, 'Bio::Graphics::Browser2::Region' );
my $features = $region->search_features( { -search_term => 'Contig:ctgA' } );
is( ref $features,     'ARRAY', 'feature is an array reference' );
is( scalar @$features, 1,       'it should have a single feature' );
is( $features->[0]->method,
    'chromosome', 'it should give chromosome as method name' );
is( $features->[0]->start, 1,     'it should give the start coordinate' );
is( $features->[0]->end,   50000, 'it should give back the end coordinate' );

$features = $region->search_features(
    { -search_term => 'Contig:ctgA:10001..20000' } );
is( $features->[0]->length, 10000, 'it should return the length of feature' );

$features = $region->search_features( { -search_term => 'HOX' } );
is( scalar @$features, 4, 'search with term HOX should return 4 features' );

$features = $region->search_features( { -search_term => 'Match:seg*' } );
is( scalar @$features, 2, 'search with Match:seg* should return 2 features' );

$features = $region->search_features( { -search_term => 'My_feature:f12' } );
is( scalar @$features, 1, 'search with f12 returns a single feature' );

$region = Bio::Graphics::Browser2::Region->new(
    {   source => $source,
        state  => $state,
        db     => $source->open_database('CleavageSites'),
    }
);
isa_ok( $region, 'Bio::Graphics::Browser2::Region' );
$features = $region->search_features( { -search_term => 'Cleavage*' } );
is( scalar @$features,
    15, 'it should return 15 features with Clevage wild card search' );

$features = $region->search_features( { -search_term => 'Cleavage11' } );
is( scalar @$features,
    1, 'it should return a single feature with Cleavage11 search' );

$region = Bio::Graphics::Browser2::Region->new(
    {   source => $source,
        state  => $state,
        db     => $source->open_database('Alignments'),
    }
);

isa_ok( $region, 'Bio::Graphics::Browser2::Region' );
$features = $region->search_features( { -search_term => 'Cleavage11' } );
is( scalar @$features,
    0, 'it should not match any feature with Cleavage11 search' );

$features = $region->search_features( { -search_term => 'Heterodox14' } );
is( scalar @$features,
    1, 'it should return a single feature with search term Heterodox14' );

# now try the local multidatabase functionality
use_ok('Bio::Graphics::Browser2::RegionSearch');
my $search = Bio::Graphics::Browser2::RegionSearch->new(
    {   source => $source,
        state  => $state,
    }
);
isa_ok( $search, 'Bio::Graphics::Browser2::RegionSearch' );
$search->init_databases();
$features = $search->search_features_locally( { -search_term => 'HOX' } );
is( scalar @$features, 4, 'it should 4 features with search term HOX' );

$features = $search->search_features_locally(
    { -search_term => 'Binding_site:B07' } )
    ;    # test removal of duplicate features
is( scalar @$features,
    1, 'it should return a single feature with search term Binding_site' );

$features = $search->search_features_locally(
    { -search_term => 'My_feature:f12' } );
is( scalar @$features,
    1, 'it should return a single feature with search term f12' );

$features = $search->search_features_locally(
    { -search_term => 'My_feature:f12', -shortcircuit => 0 } );
is( scalar @$features,
    3, 'it should return a 3 features with search term f12 along with no shortcircuit option' );
my @dbids = sort map { $_->gbrowse_dbid } @$features;
is( join('|', @dbids), 'CleavageSites|general|volvox2:database' );

my @seqid = sort map { $_->seq_id } @$features;
is( join('|', @seqid), 'ctgA|ctgB|ctgB' );


END {
	TestUtil->remove_config(builder => $current);
	remove_tree ('/tmp/gbrowse_testing/',  {keep_root => 1});
}

#$features
#    = $search->search_features_remotely( { -search_term => 'Heterodox14' } )
#    ;    # this will appear in volvox4
#is( scalar @$features,
#    1, 'it should return a single feature with search term Heterodox14' );

#$features
#    = $search->search_features_remotely( { -search_term => 'Cleavage11' } )
#    ;    # this will appear in volvox3
#is( scalar @$features,
#    1, 'it should return a single feature with search term Cleavage11' );
#
#$features
#    = $search->search_features_remotely( { -search_term => 'Cleavage*' } )
#    ;    # this will appear in volvox3
#is( scalar @$features,
#    15, 'it should return 15 features with search term Cleavage' );
#
