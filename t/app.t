use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use Mojolicious::Plugin::Browserify::Processor;

my $p = Mojolicious::Plugin::Browserify::Processor->new;
plan skip_all => 'browserify was not found' if $p->executable eq 'browserify';

{
  cleanup();
  use Mojolicious::Lite;
  plugin "Browserify" => {environment => "development", extensions => [qw( js jsx )],};
  app->asset("app.js" => "/js/boop.js");

  get "/app" => "app_js_inlined";
}

my $t = Test::Mojo->new;

$t->get_ok('/app.js')->status_is(200)->content_like(qr{s\.toUpperCase\(.*'\!'}, 'robot.js')
  ->content_like(qr{console\.log\(robot\('boop'\)\);}, 'boop.js');

cleanup();
done_testing;

sub cleanup {
  my $p = File::Spec->catdir(qw( t public packed ));
  opendir(my $DH, $p) or return;
  unlink File::Spec->catfile($p, $_) for grep {/boop/} readdir $DH;
}

__DATA__
@@ app_js_inlined.js.ep
%= asset "app.js" => {inline => 1}
