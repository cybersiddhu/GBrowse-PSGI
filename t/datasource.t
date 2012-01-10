use strict;
use Test::More qw/no_plan/;
use Module::Build;
use File::Spec::Functions;
use IO::String;
use Carp::Always;
use lib 't';
use TestUtil;
use PlackBuilder;

my $current = Module::Build->current;

## -- generate all configuration files
TestUtil->template2conf( builder => $current );
my $conf_file
    = catfile( $current->base_dir, 't', 'testdata', 'conf', 'GBrowse.conf' );

use_ok('Bio::Graphics::Browser2');
my $req     = PlackBuilder->mock_request;
my $globals = Bio::Graphics::Browser2->new($conf_file);
$globals->req($req);
my $session = $globals->session;

# test data source creation
my $source = $globals->create_data_source( $session->source );
isa_ok( $source, 'Bio::Graphics::Browser2::DataSource' );
is( $source->name,        'volvox' );
is( $source->description, 'Volvox Example Database' );

# is it cached correctly?
# we should get exactly the same object each time we call create_data_source....
is( $globals->create_data_source( $session->source ), $source );

# ... unless the config file has been updated more recently
#$time = time();
#utime( $time, $time, $globals->data_source_path( $session->source ) );
#isnt( $globals->create_data_source( $session->source ) ,  $source );

# Is data inherited?
is( $source->html1, 'This is inherited' );
is( $source->html2, 'This is overridden' );

# does the timeout calculation work?
is( $source->global_time('expire cache'), 7200 );

# Do semantic settings work?
is( $source->safe, 1, 'source should be safe' );
is( $source->setting( general => 'plugins' ),
    'Aligner RestrictionAnnotator ProteinDumper TestFinder' );
is( $source->setting('plugins'),
    'Aligner RestrictionAnnotator ProteinDumper TestFinder' );
is( $source->semantic_setting( Alignments => 'glyph' ), 'segments' );
is( $source->semantic_setting( Alignments => 'glyph', 30000 ), 'box' );
is( $source->type2label( 'alignment', 0, 'Alignments' ), 'Alignments' );

# Do callbacks work (or at least, do we get a CODE reference back)?
is( ref( $source->code_setting( EST => 'bgcolor' ) ), 'CODE' );

# Test other modifiers
my @types = sort $source->overview_tracks;
is( "@types", "Motifs:overview Transcripts:overview" );

# Test that :database sections do not come through in labels
my %tracks = map { $_ => 1 } $source->labels;
isnt( exists $tracks{'volvox2:database'}, 1 );

# Test that we retrieve four database labels
my @dbs = sort $source->databases;
is( scalar @dbs, 4 );
is( $dbs[0],     'volvox1' );

my ( $dbid, $adapter, @args ) = $source->db_settings;
is( $dbid, 'general', 'it returs the default database section' );
my $db = $source->open_database;
isa_ok( $db, $adapter );

# Test that we can get db args from "volvox2"
( $dbid, $adapter, @args ) = $source->db2args('volvox2');
is( $adapter,     'Bio::DB::GFF' );
is( "@args[0,1]", '-adaptor memory' );

# Test that we get the same args from the binding sites track
my ( $dbid2, $adapter2, @args2 ) = $source->db_settings('BindingSites');
is( $adapter,      $adapter2 );
is( "@args[0..3]", "@args2[0..3]" );

# Test that we get the same database from two tracks
my $db1 = $source->open_database('Linkage2');
my $db2 = $source->open_database('Linkage2');
my $db3 = $source->open_database('BindingSites');
is( $db1, $db2 );
is( $db1, $db3 );

# Test reverse mapping
is( scalar $source->db2id($db1), 'volvox2:database' );
is( join( ' ', sort $source->db2id($db1) ), 'volvox2:database' );

# Test that anonymous databases that use the same open
# arguments get mapped onto a single database
my $db4 = $source->open_database('Linkage');
is( $db1,                        $db4 );
is( scalar $source->db2id($db4), 'volvox2:database' );
is( join( ' ', $source->db2id($db1) ), 'volvox2:database' );

# Test restrictions/authorization
%tracks = map { $_ => 1 } $source->labels;
isnt( exists $tracks{Variation}, 1 );

$req = PlackBuilder->mock_request_with_remote(remote_host => 'foo.cshl.edu');
$globals->req($req);
$source = $globals->create_data_source($session->source);
%tracks = map { $_ => 1 } $source->labels;
is( exists $tracks{Variation},  1 );

$req = PlackBuilder->mock_request_with_remote(remote_user => 'lstein');
$globals->req($req);
$source = $globals->create_data_source($session->source);
%tracks = map { $_ => 1 } $source->labels;
ok( exists $tracks{Variation},  1 );

# test that make_link should produce a fatal error
#ok( !eval { $source->make_link(); 1 } );

# test that environment variable interpolation is working in dbargs
#$ENV{GBROWSE_DOCS} = '/foo/bar';
$source = $globals->create_data_source('yeast_chr1');
#( undef, $adapter, @args ) = $source->db_settings;
#like( $args[3], qr!^/foo/bar! );
#
#$ENV{GBROWSE_DOCS} = '/buzz/buzz';
#( undef, $adapter, @args ) = $source->db_settings;
#like( $args[3], qr!^/foo/bar! );    # old value cached

#$source->clear_cache;
#( undef, $adapter, @args ) = $source->db_settings;
#like( $args[3] ,   qr!^/buzz/buzz! );    # old value cached

# Test the data_source_to_label() and track_source_to_label() functions
my @labels = sort $source->track_source_to_label('foobar');
is( scalar @labels, 0,  'it has no label named foobar' );
@labels = sort $source->track_source_to_label('modENCODE');
is( "@labels", "CDS Genes ORFs" ,  'it has CDS Genes ORFs as the labels for modENCODE track source');
@labels = sort $source->track_source_to_label( 'marc perry', 'nicole washington' );
is( "@labels", "CDS ORFs" );
@labels = sort $source->data_source_to_label('SGD');
is( "@labels", "CDS Genes ORFs" );
@labels = sort $source->data_source_to_label('flybase');
is( "@labels", "CDS" );

# Test whether user data can be added to the data source
@labels = $source->labels;
{
    local $source->{_user_tracks};
    $source->add_user_type(
        'fred',
        {   glyph   => 'segments',
            feature => 'genes',
            color   => sub { return 'blue' },
        }
    );
    my @new_labels = $source->labels;
    is( @new_labels, @labels + 1 );
    my $setting = $source->setting( fred => 'glyph' );
    is( $setting, 'segments' );
    is( $source->code_setting( fred => 'color' )->() , 'blue');

    my $fh = IO::String->new(<<END);
[tester]
glyph = test
feature = test
bgcolor = orange
END
    $source->parse_user_fh($fh);
    is( $source->labels + 0, @labels + 2 );
    is( 'orange', $source->setting( tester => 'bgcolor' ) );
}

is( @labels + 0, $source->labels + 0 );
is( $source->setting( fred => 'glyph' ), undef );

