package Mojolicious::Command::browserify;

=head1 NAME

Mojolicious::Command::browserify - A Mojolicious command for browserify

=head1 DESCRIPTION

L<Mojolicious::Command::browserify> is a L<Mojolicious> command which handle
C<browserify> dependencies and installation.

=head1 SYNOPSIS

  # Bundle an asset from command line
  \$ mojo browserify bundle input.js

  # Pass on "-t reactify" to browserify
  \$ mojo browserify bundle -t reactify input.js

  # Watch input files and write output to out.js
  \$ mojo browserify bundle -t reactify input.js -w -o out.js

  # Make a minified bundle
  \$ MOJO_MODE=production mojo browserify bundle -t reactify input.js

  # Install dependencies
  \$ mojo browserify install browserify
  \$ mojo browserify install reactify

  # Check installed versions
  \$ mojo browserify version

=cut

use Mojo::Base 'Mojolicious::Command';
use Cwd 'abs_path';
use File::Basename 'dirname';

my $NPM = $ENV{NODE_NPM_BIN} || 'npm';

$ENV{MOJO_LOG_LEVEL} ||= 'info';

=head1 ATTRIBUTES

=head2 description

Short description of command, used for the command list.

=head2 usage

Usage information for command, used for the help screen.

=cut

has description => "Manage browserify.";
has usage       => <<"HERE";
# Bundle an asset from command line
\$ mojo browserify bundle input.js

# Pass on "-t reactify" to browserify
\$ mojo browserify bundle -t reactify input.js

# Watch input files and write output to out.js
\$ mojo browserify bundle -t reactify input.js -w -o out.js

# Make a minified bundle
\$ MOJO_MODE=production mojo browserify bundle -t reactify input.js

# Install dependencies
\$ mojo browserify install browserify
\$ mojo browserify install reactify

# Check installed versions
\$ mojo browserify version

HERE

=head1 METHODS

=head2 bundle

This method will bundle a JavaScript file from the command line.

=cut

sub bundle {
  my $self = shift->_parse_bundle_args(@_);

  require Mojolicious::Plugin::AssetPack;
  require Mojolicious::Plugin::Browserify::Processor;
  require Mojolicious::Static;

  my $assetpack = Mojolicious::Plugin::AssetPack->new;
  my $processor = Mojolicious::Plugin::Browserify::Processor->new;

  $assetpack->out_dir(Cwd::getcwd)->{static} = Mojolicious::Static->new;
  $assetpack->minify(1) if $processor->environment eq 'production';
  $processor->browserify_args($self->{browserify_args} || []);
  chdir dirname $self->{in} or die "Could not chdir to $self->{in}: $!\n";

  do {
    my $javascript = Mojo::Util::slurp($self->{in});
    $processor->process($assetpack, \$javascript, $self->{in});
    if ($self->{out}) {
      Mojo::Util::spurt($javascript, $self->{out});
      $self->app->log->info("Wrote $self->{out}");
    }
    else {
      $self->_printf("%s\n", $javascript);
    }
  } while $self->{watch} and $self->_watch($processor);
}

=head2 install

This method will run C<npm install browserify>. It will die unless
browserify was installed.

=cut

sub install {
  my $self       = shift;
  my $module     = shift || 'browserify';
  my $exit_value = $self->_npm(install => $module, sub { shift->_printf('%s', shift); });
  die "'npm install browserify' failed: $exit_value\n" if $exit_value;
  $self->_printf("\nbrowserify was installed\n");
}

=head2 run

Run command and call L</install> or L</version>.

=cut

sub run {
  my $self = shift;
  my $action = shift || '';

  exec perldoc => __FILE__ if $action eq 'help';
  return print $self->usage unless $action =~ /^(bundle|install|version)$/;
  return $self->$action(@_);
}

=head2 version

Print version information.

=cut

sub version {
  my ($self, @args) = @_;

  require Mojolicious::Plugin::Browserify;
  $self->_printf("REQUIRED\n");
  $self->_printf("  %-40s %s\n", 'Mojolicious::Plugin::Browserify', Mojolicious::Plugin::Browserify->VERSION);
  $self->_npm_version($_) for qw( browserify );
  $self->_printf("\nOPTIONAL\n");
  $self->_npm_version($_) for qw( react reactify uglifyjs );
  $self->_printf("\n");
}

sub _npm {
  my $cb = pop;
  my ($self, @cmd) = @_;
  my $pid;

  pipe my $CHILD_READ, my $CHILD_WRITE or die "Unable to create pipe to npm: $!";
  $pid = fork // die "Could not fork npm: $!\n";

  if ($pid) {
    close $CHILD_WRITE;
    local $_;
    $self->$cb($_) while <$CHILD_READ>;
    waitpid $pid, 0;
    return $? >> 8;
  }

  close $CHILD_READ;
  close STDERR;
  open STDOUT, '>&', fileno($CHILD_WRITE);
  { exec $NPM => @cmd }
  my $err = $!;
  print "Could not exec $NPM: $err (Is npm installed?)\n";
  exit $err;
}

sub _npm_version {
  my ($self, $module) = @_;
  my $format = "  %-40s %-14s (%s)\n";
  my ($installed, $latest);

  $self->_npm(qw( --json list ), $module, sub { $installed = $1 if /"version"\D+([\d\.]+)/ });
  $self->_npm(view => $module => 'version', sub { $latest = $1 if /([\d\.]+)/ });
  $self->_printf($format, $module, $installed || 'Not installed', $latest || 'Unknown');
}

sub _parse_bundle_args {
  my ($self, @args) = @_;

  while (@args) {
    my $arg = shift @args // next;
    if ($arg =~ /^--?w/) { $self->{watch} = 1;                     next }
    if ($arg =~ /^--?o/) { $self->{out}   = abs_path(shift @args); next }
    if (-r $arg)         { $self->{in}    = abs_path($arg);        next }
    push @{$self->{browserify_args}}, $arg;
  }

  die "Usage: mojo browserify bundle <input.js>\n" unless $self->{in};
  die "-o <file> is required in watch mode (-w).\n" if $self->{watch} and !$self->{out};
  $self;
}

sub _printf { shift; printf shift, @_; }

sub _watch {
  my ($self, $processor) = @_;
  my @watch = ($self->{in}, values %{$processor->{node_modules}});
  my $cache = {};

  $self->app->log->debug("Watching @watch");

  while (1) {
    for my $file (@watch) {
      my $mtime = (stat $file)[9] or next;
      $cache->{$file} ||= $mtime;
      return 1 unless $cache->{$file} == $mtime;
    }
    sleep 1;
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
