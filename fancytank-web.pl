#!/usr/bin/env perl
use Mojolicious::Lite;

use FancyTank::Schema;

app->defaults(
    %{
        plugin 'Config' => {
            default => {
                site_name => "FancyTank",
            },
        },
    }
);

helper schema => sub {
    my $self = shift;

    my $schema = FancyTank::Schema->connect(
        {
            dsn      => $self->app->config->{database}{dsn},
            user     => $self->app->config->{database}{user},
            password => $self->app->config->{database}{pass},
            %{ $self->app->config->{database}{opts} },
        }
    );

    return $schema;
};

helper rs => sub {
    my ( $self, $table ) = @_;

    return unless $table;

    my $schema = $self->app->schema;
    my $rs = $schema->resultset($table);

    return $rs;
};

get '/' => sub {
    my $c = shift;
    $c->redirect_to("/dashboard");
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

get '/logout' => sub {
    my $c = shift;
    $c->render(template => 'login');
};

get '/register' => sub {
    my $c = shift;
    $c->render(template => 'register');
};

get '/account' => sub {
    my $c = shift;
    $c->render(template => 'account');
};

get '/setting' => sub {
    my $c = shift;
    $c->render(template => 'setting');
};

get '/files' => sub {
    my $c = shift;
    $c->render(template => 'files');
};

app->start;
