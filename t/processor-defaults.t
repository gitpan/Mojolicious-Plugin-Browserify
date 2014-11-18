use Mojo::Base -strict;
use Test::More;
use Mojolicious::Plugin::Browserify::Processor;

my $p = Mojolicious::Plugin::Browserify::Processor->new;

plan skip_all => 'browserify was not found' if $p->executable eq 'browserify';

is $p->environment, 'development', 'default environment';
is_deeply($p->extensions, ['js'], 'default extensions');
ok $p->can_process, 'can_process';

done_testing;
