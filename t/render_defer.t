
use strict;
use Test::More qw/no_plan/;
use Module::Build;
use File::Spec::Functions;
use File::Path qw/remove_tree make_path/;
#use Carp::Always;
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
	remove_tree ('/tmp/gbrowse_testing/',  {keep_root => 1});
}

my $req
    = PlackBuilder->mock_request(
    'name=ctgA:1..20000;label=CleavageSites-Alignments-Motifs-BindingSites-Clones'
    );

# standard initialization incantation
use_ok('Bio::Graphics::Browser2');
use_ok('Bio::Graphics::Browser2::Render::HTML');
my $globals = Bio::Graphics::Browser2->new($conf_file);
$globals->req($req);
my $session = $globals->session;
my $source  = $globals->create_data_source('volvox');
my $render  = Bio::Graphics::Browser2::Render::HTML->new( $source, $session );
$render->req($req);
$render->default_state();
$render->init_database;
$render->init_plugins;
$render->update_state;
$render->segment;    # this sets the segment

my $requests = $render->render_deferred();
my ( %cumulative_status, $probe_count );
push @{ $cumulative_status{$_} }, $requests->{$_}->status
    foreach keys %$requests;

my $time = time();

while ( time() - $time < 10 ) {
    $probe_count++;
    my %status_counts;
    for my $label ( keys %$requests ) {
        my $status = $requests->{$label}->status;
        push @{ $cumulative_status{$label} }, $status;
        $status_counts{ $requests->{$label}->status }++;
    }
    last if ( $status_counts{AVAILABLE} || 0 ) == 5;
}

# each track should start with either EMPTY or PENDING and end with AVAILABLE
for my $label ( keys %cumulative_status ) {
    like( $cumulative_status{$label}[0], qr/^(EMPTY|PENDING|AVAILABLE)$/ );
    is( $cumulative_status{$label}[-1], 'AVAILABLE' );
}

# test caching
$requests = $render->render_deferred();
my @cached = map { $requests->{$_}->status } keys %$requests;
is( "@cached", 'AVAILABLE AVAILABLE AVAILABLE AVAILABLE AVAILABLE' );

# test the render_deferred_track() call
my $track_name1 = 'CleavageSites';
my $key1        = $requests->{$track_name1}->key;
like($key1,  qr/\w+/);

my $view = $render->render_deferred_track(
    cache_key => $key1,
    track_id  => $track_name1,
);
my @images = $view =~ m!src=\"(/gbrowse/i/volvox/[a-z0-9]+\.png)\"!g;
is( scalar @images, 2 );    # one for the main image, and one for the pad

foreach (@images) {
    s!/gbrowse/i!/tmp/gbrowse_testing/images!;
}
is( -e $images[0], 1 );

# does cache expire?
$requests->{$track_name1}->cache_time(-1);
is( $requests->{$track_name1}->status, 'EXPIRED' );

$render->data_source->cache_time(-1);

is( substr(
        $render->render_deferred_track(
            cache_key => $key1,
            track_id  => $track_name1,
        ),
        0, 16
    ),
    "<!-- EXPIRED -->"
);


sub usleep {
    my $fractional_seconds = shift;
    select( undef, undef, undef, $fractional_seconds );
}

END {
	TestUtil->remove_config(builder => $current);
}

