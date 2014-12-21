BEGIN { $ENV{MOJO_MODE} //= 'development' }
use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use Mojolicious::Plugin::Browserify::Processor;

my $p = Mojolicious::Plugin::Browserify::Processor->new;
plan skip_all => 'browserify was not found' if $p->executable eq 'browserify';
plan skip_all => 'npm install react'    unless -d 'node_modules/react';
plan skip_all => 'npm install reactify' unless -d 'node_modules/reactify';

{
  cleanup();
  use Mojolicious::Lite;
  plugin "Browserify" => {browserify_args => [-t => 'reactify'], extensions => [qw( js jsx )]};
  app->asset("app-complex.js" => "/js/react-complex.js");

  get "/app" => "app_js_inlined";
}

my $t = Test::Mojo->new;

$t->get_ok('/app.js')->status_is(200)->content_like(qr{fb\.me/react-devtools})->content_like(qr{createClass})
  ->content_like(qr{progressbar-container}, 'react-progressbar.js');

cleanup();
done_testing;

sub cleanup {
  my $p = File::Spec->catdir(qw( t public packed ));
  opendir(my $DH, $p) or return;
  unlink File::Spec->catfile($p, $_) for grep {/(app|react)-complex/} readdir $DH;
}

__DATA__
@@ app_js_inlined.js.ep
%= asset "app-complex.js" => {inline => 1}
