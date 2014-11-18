use Mojo::Base -strict;
use Test::Mojo;
use Test::More;

plan skip_all => 'TEST_REACT=1' unless $ENV{TEST_REACT};

{
  cleanup();
  use Mojolicious::Lite;
  plugin "Browserify" =>
    {browserify_args => [-g => 'reactify'], environment => "development", extensions => [qw( js jsx )],};
  app->asset("app.js" => "/js/react-complex.js");

  get "/app" => "app_js_inlined";
}

my $t = Test::Mojo->new;

$t->get_ok('/app.js')->status_is(200)->content_like(qr{var React}, 'var React')
  ->content_like(qr{module\.exports = React\.createClass}, 'module.exports = React.createClass')
  ->content_like(qr{var Progressbar2},                     'react-complex.js')
  ->content_like(qr{progressbar-container},                'react-progressbar.js');

#cleanup();
done_testing;

sub cleanup {
  my $p = File::Spec->catdir(qw( t public packed ));
  opendir(my $DH, $p) or return;
  unlink File::Spec->catfile($p, $_) for grep {/react-complex/} readdir $DH;
}

__DATA__
@@ app_js_inlined.js.ep
%= asset "app.js" => {inline => 1}
