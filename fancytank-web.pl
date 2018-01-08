#!/usr/bin/env perl
use Mojolicious::Lite;

# Documentation browser under "/perldoc"
plugin 'PODRenderer';

get '/' => sub {
  my $c = shift;
  $c->render(template => 'index');
};

get '/dashboard' => sub {
  my $c = shift;
  $c->render(template => 'dashboard');
};

app->start;
