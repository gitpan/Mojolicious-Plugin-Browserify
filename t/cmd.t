use Mojo::Base -strict;
use Mojolicious::Command::browserify;
use Mojolicious::Plugin::Browserify;
use Cwd;
use File::Spec;
use Test::More;

chdir File::Spec->tmpdir or plan skip_all => "Could not chdir to temp: $!";
my $cmd = Mojolicious::Command::browserify->new;

isa_ok($cmd, 'Mojolicious::Command');

my @print;
no warnings 'redefine';
*Mojolicious::Command::browserify::_printf = sub { shift; push @print, @_; };

@print = ();
eval { $cmd->install('adskjnadsksajndlksandnsakdnaslkdnad') };
like $@, qr{(failed:|Could not exec)}, 'could not install adskjnadsksajndlksandnsakdnaslkdnad';

@print = ();
$cmd->version;
like "@print", qr{REQUIRED}, 'REQUIRED';
like "@print", qr{OPTIONAL}, 'OPTIONAL';
is $print[3], Mojolicious::Plugin::Browserify->VERSION, 'VERSION';
is int(grep { $_ eq 'Not installed' } @print), 4, 'Not installed';
is int(grep { $_ =~ /  %-40s.*\n/ } @print), 5, 'sprintf';

done_testing;
