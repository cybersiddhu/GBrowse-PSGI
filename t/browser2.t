use strict;
use Test::More qw/no_plan/;
use Module::Build;
use File::Spec::Functions;
use lib 't';
use TestUtil;

my $current = Module::Build->current;

## -- generate all configuration files
TestUtil->template2conf( builder => $current );

my $conf_file
    = catfile( $current->base_dir, 't', 'testdata', 'conf', 'GBrowse.conf' );
use_ok('Bio::Graphics::Browser2');
my $browser2 = Bio::Graphics::Browser2->new($conf_file);
isa_ok( $browser2, 'Bio::Graphics::Browser2' );
my $session = $browser2->session;
isa_ok( $session, 'Bio::Graphics::Browser2::Session' );
my $id = $session->id;
like( $id, qr/\w+/, 'it has a session id' );

my $session2 = $browser2->session($id);
isa_ok( $session, 'Bio::Graphics::Browser2::Session' );
is( $id, $session->id, 'matches the session id' );

my $dsn = $session->source;
is( $dsn, 'volvox', 'it returns correct dsn' );
is( $browser2->data_source_path($dsn),
    catfile(
        $current->base_dir, 't', 'testdata', 'conf', 'volvox.conf'
    ),
    'it resolves the dsn to correct path'
);
is( $browser2->data_source_description($dsn),
    'Volvox Example Database',
    'it matches the correct datasource description'
);
my $source = $browser2->create_data_source($dsn);
isa_ok( $source, 'Bio::Graphics::Browser2::DataSource' );
is_deeply([$source->databases],  [qw/volvox1 volvox2 volvox3 volvox4/],  'it has configured four data sources');

my ($dbid, $adaptor, @argv) = $source->db_settings;
is($dbid, 'general',  'it returs the default database section');
my $db = $source->open_database;
isa_ok($db, $adaptor);

