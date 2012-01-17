use strict;
use Test::More qw/no_plan/;
use Module::Build;
use File::Spec::Functions;
use File::Path qw/remove_tree make_path/;
use lib 't';
use TestUtil;
use PlackBuilder;

my $current;
my $conf_file;

BEGIN {
    $current = Module::Build->current;
    $conf_file = catfile( $current->base_dir, 't', 'testdata', 'conf',
        'GBrowse.conf' );
    TestUtil->template2conf( builder => $current );
}

my $req = PlackBuilder->mock_request ;
use_ok('Bio::Graphics::Browser2');
my $browser2 = Bio::Graphics::Browser2->new($conf_file);
$browser2->req($req);
isa_ok( $browser2, 'Bio::Graphics::Browser2' );
my $session = $browser2->session;
isa_ok( $session, 'Bio::Graphics::Browser2::Session' );
my $id = $session->id;
like( $id, qr/\w+/, 'it has a session id' );
$session->flush;
undef $session;

$session = $browser2->session($id);
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


END {
	TestUtil->remove_config(builder => $current);
	remove_tree ('/tmp/gbrowse_testing/',  {keep_root => 1});
}
