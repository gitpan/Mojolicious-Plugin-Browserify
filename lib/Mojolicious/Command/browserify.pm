package Mojolicious::Command::browserify;

=head1 NAME

Mojolicious::Command::browserify - A Mojolicious command for browserify

=head1 DESCRIPTION

L<Mojolicious::Command::browserify> is a L<Mojolicious> command which handle
C<browserify> dependencies and installation.

=head1 SYNOPSIS

  $ mojo browserify install
  $ mojo browserify version

=cut

use Mojo::Base 'Mojolicious::Command';

my $NPM = $ENV{NODE_NPM_BIN} || 'npm';

=head1 ATTRIBUTES

=head2 description

Short description of command, used for the command list.

=head2 usage

Usage information for command, used for the help screen.

=cut

has description => "Manage browserify.";
has usage       => "mojo browserify {install|version}\n";

=head1 METHODS

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
  return print $self->usage unless $action =~ /^(install|version)$/;
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
  $self->_npm_version($_) for qw( react reactify );
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
  exec $NPM => @cmd;
  die "Could not exec $NPM: $! (Is npm installed?)\n";
}

sub _npm_version {
  my ($self, $module) = @_;
  my $format = "  %-40s %-14s (%s)\n";
  my ($installed, $latest);

  $self->_npm(qw( --json list ), $module, sub { $installed = $1 if /"version"\D+([\d\.]+)/ });
  $self->_npm(view => $module => 'version', sub { $latest = $1 if /([\d\.]+)/ });
  $self->_printf($format, $module, $installed || 'Not installed', $latest || 'Unknown');
}

sub _printf { shift; printf shift, @_; }

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
