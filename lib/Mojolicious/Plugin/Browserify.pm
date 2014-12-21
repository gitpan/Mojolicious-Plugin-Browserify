package Mojolicious::Plugin::Browserify;

=head1 NAME

Mojolicious::Plugin::Browserify - An Mojolicious plugin for assetpack+browserify

=head1 VERSION

0.06

=head1 DESCRIPTION

L<Mojolicious::Plugin::Browserify> is a plugin that will register
L<Mojolicious::Plugin::Browserify::Processor> in
L<Mojolicious::Plugin::AssetPack>.

L<browserify|http://browserify.org/> is a JavaScript preprocessor which will
allow you to use L<commonjs|http://nodejs.org/docs/latest/api/modules.html#modules_modules>'s
C<require()> in your JavaScript files. Here is an example JavaScript file,
that use C<require()> to pull in L<React|http://facebook.github.io/react>:

  var React = require('react');

  module.exports = React.createClass({
    render: function() {
      return <div className="Bio"><p className="Bio-text">{this.props.text}</p></div>;
    }
  });

=head1 SYNOPSIS

  use Mojolicious::Lite;
  plugin "Browserify" => {
    browserify_args => [-g => "reactify"],
    environment => app->mode, # default
    extensions => [qw( js jsx )], # default is "js"
  };
  app->asset("app.js" => "/js/main.js");

  get "/app" => "app_js_inlined";
  app->start;

  __DATA__
  @@ app_js_inlined.js.ep
  %= asset "app.js" => {inline => 1}

Note! The L<SYNOPSIS> require both "react" and "reactify" to be installed:

  $ cd /home/projects/my-project
  $ mojo browserify install react
  $ mojo browserify install reactify

=head1 DEPENDENCIES

=over 4

=item * browserify

This module require L<browserify|http://browserify.org/> to be installed. The
node based application can either be installed system wide or locally to
your project. To install it locally, you can use the
L<browserify|Mojolicious::Command::browserify> Mojolicious command:

  # same as "npm install browserify"
  $ mojo browserify install

It is also possible to check installed versions using this command:

  $ mojo browserify version

=item * uglifyjs

L<uglifyjs|https://github.com/mishoo/UglifyJS2> is a really good minifier.
The test C<react.t> used to create a bundle that took 324K with
L<JavaScript::Minifier::XS>. With C<uglifyjs> the same code takes C<156K>.

What is the drawback? It takes a lot longer to run C<uglifyjs>, but it's
worth it, since it will only be called in production mode. Get it with
this command:

  $ mojo browserify install uglify-js

=back

=cut

use Mojo::Base 'Mojolicious::Plugin';
use Mojolicious::Plugin::Browserify::Processor;

our $VERSION = '0.06';

=head1 METHODS

=head2 register

Used to register L<Mojolicious::Plugin::Browserify::Processor> in the
C<Mojolicious> application.

=cut

sub register {
  my ($self, $app, $config) = @_;
  my $browserify = Mojolicious::Plugin::Browserify::Processor->new($config);

  $app->plugin("AssetPack") unless eval { $app->asset };
  $browserify->environment($app->mode) unless $config->{environment};

  for my $ext (@{$browserify->extensions}) {
    $app->asset->preprocessors->remove($ext);
    $app->asset->preprocessors->add($ext => $browserify);
  }
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
