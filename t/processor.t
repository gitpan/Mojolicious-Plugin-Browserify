use Mojo::Base -strict;
use Test::More;
use Mojolicious::Plugin::Browserify::Processor;

my $p = Mojolicious::Plugin::Browserify::Processor->new;

plan skip_all => 'browserify was not found' if $p->executable eq 'browserify';
plan skip_all => "Cannot chdir t/public/js: $!" unless chdir 't/public/js';

is int(@{$p->_node_module_path}), 1, 'found a node_modules directory';
is_deeply([$p->_find_node_modules(\'', 'foo')], [], 'no modules found');

my $text = Mojo::Util::slurp('react-simple.js');
my $data = {};
is_deeply([$p->_find_node_modules(\$text, 'react-simple.js')], ['react'], 'depends on react');

$text = Mojo::Util::slurp('react-complex.js');
is_deeply(
  [sort $p->_find_node_modules(\$text, 'react-complex.js', $data)],
  ['./react-progressbar.js', 'react'],
  'depends on ./react-progressbar'
);

done_testing;
