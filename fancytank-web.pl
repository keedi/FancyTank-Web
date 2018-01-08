#!/usr/bin/env perl
use Mojolicious::Lite;

app->defaults(
    %{
        plugin 'Config' => {
            default => {
                site_name => "FancyTank",
            },
        },
    }
);

get '/' => sub {
  my $c = shift;
  $c->render(template => 'index');
};

get '/dashboard' => sub {
  my $c = shift;
  $c->render(template => 'dashboard');
};

get '/tables' => sub {
  my $c = shift;
  $c->render(template => 'tables');
};

get '/forms' => sub {
  my $c = shift;
  $c->render(template => 'forms');
};

get '/buttons' => sub {
  my $c = shift;
  $c->render(template => 'buttons');
};

get '/login' => sub {
  my $c = shift;
  $c->render(template => 'login');
};

get '/register' => sub {
  my $c = shift;
  $c->render(template => 'register');
};

app->start;
