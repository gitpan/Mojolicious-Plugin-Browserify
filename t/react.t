BEGIN { $ENV{MOJO_MODE} //= 'production' }
use Mojo::Base -strict;
use Test::Mojo;
use Test::More;

plan skip_all => 'TEST_REACT=1' unless $ENV{TEST_REACT};

{
  cleanup();
  use Mojolicious::Lite;
  plugin "Browserify" =>
    {browserify_args => [-t => 'reactify'], environment => "development", extensions => [qw( js jsx )]};
  app->asset("app-complex.js" => "/js/react-complex.js");

  get "/app" => "app_js_inlined";
}

my $t = Test::Mojo->new;

$t->get_ok('/app.js')->status_is(200)->content_like(qr{require})->content_like(qr{createClass})
  ->content_like(qr{progressbar-container}, 'react-progressbar.js')->header_is('Content-Length' => 159054);

#cleanup();
done_testing;

sub cleanup {
  my $p = File::Spec->catdir(qw( t public packed ));
  opendir(my $DH, $p) or return;
  unlink File::Spec->catfile($p, $_) for grep {/(app|react)-complex/} readdir $DH;
}

__DATA__
@@ app_js_inlined.js.ep
%= asset "app-complex.js" => {inline => 1}
