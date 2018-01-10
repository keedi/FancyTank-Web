#!/usr/bin/env perl

use Mojolicious::Lite;

use Email::Valid;
use Try::Tiny;

use FancyTank::Schema;

app->defaults(
    %{
        plugin 'Config' => {
            default => {
                error_message => q{},
                error_type    => q{},
                site_name     => "FancyTank",
            },
        },
    }
);

#
# https://stackoverflow.com/questions/2049502/what-characters-are-allowed-in-an-email-address
# http://tools.ietf.org/html/rfc5322
# http://tools.ietf.org/html/rfc5321
# http://tools.ietf.org/html/rfc822#section-6.1
#
# CPAN: Email::Valid
# https://metacpan.org/pod/Email::Valid
#
app->validator->add_check(
    email => sub {
        my ( $validation, $name, $value, @args ) = @_;
        my $email = Email::Valid->address($value);
        return !$email;
    },
);

helper schema => sub {
    my $c = shift;

    my $schema = FancyTank::Schema->connect(
        {
            dsn      => $c->app->config->{database}{dsn},
            user     => $c->app->config->{database}{user},
            password => $c->app->config->{database}{pass},
            %{ $c->app->config->{database}{opts} },
        }
    );

    return $schema;
};

helper rs => sub {
    my ( $c, $table ) = @_;

    return unless $table;

    my $schema = $c->app->schema;
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

post '/login' => sub {
    my $c = shift;

    # http://mojolicious.org/perldoc/Mojolicious/Guides/Rendering#Form-validation
    # Check if parameters have been submitted
    my $validation = $c->validation;
    return $c->render unless $validation->has_data;

    $validation->required("email")->size(5, 255)->email;
    $validation->required("password");

    if ( $validation->has_error ) {
        my $msg = "invalid parameters: " . join( ", ", @{ $validation->failed } );
        $c->app->log->debug($msg);
        $c->render("login", error_type => "parameter", error_message => $msg );
        return;
    }

    my $email    = $c->param("email")    || q{};
    my $password = $c->param("password") || q{};

    my $log_message = join( ",", $email, $password );
    $c->app->log->debug($log_message);

    my $user = $c->rs("User")->find( { email => $email } );
    unless ($user) {
        my $msg = "user does not exist";
        $c->app->log->debug($msg);
        $msg = "User does not exist or password is incorrect.";
        $c->render("login", error_type => "user_not_found", error_message => $msg );
        return;
    }
    unless ( $user->check_password($password) ) {
        my $msg = "password is incorrect";
        $c->app->log->debug($msg);
        $msg = "User does not exist or password is incorrect.";
        $c->render( "login", error_type => "user_incorrect_password", error_message => $msg );
        return;
    }

    # login success

    $c->redirect_to("/dashboard");
};

get '/logout' => sub {
    my $c = shift;
    $c->render(template => 'login');
};

get '/register' => sub {
    my $c = shift;
    $c->render(template => 'register');
};

post '/register' => sub {
    my $c = shift;

    # http://mojolicious.org/perldoc/Mojolicious/Guides/Rendering#Form-validation
    # Check if parameters have been submitted
    my $validation = $c->validation;
    return $c->render unless $validation->has_data;

    $validation->required("first_name")->size(1, 64);
    $validation->required("last_name")->size(1, 64);
    $validation->required("email")->size(5, 255)->email;
    $validation->required("password")->size(8, 100);
    $validation->required("password2")->equal_to("password");

    if ( $validation->has_error ) {
        my $msg = "invalid parameters: " . join( ", ", @{ $validation->failed } );
        $c->app->log->debug($msg);
        $c->render("register", error_type => "parameter", error_message => $msg );
        return;
    }

    my $first_name = $c->param("first_name") || q{};
    my $last_name  = $c->param("last_name")  || q{};
    my $email      = $c->param("email")      || q{};
    my $password   = $c->param("password")   || q{};
    my $password2  = $c->param("password2")  || q{};

    my $log_message = join( ",", $first_name, $last_name, $email, $password, $password2 );
    $c->app->log->debug($log_message);

    #
    # create a user
    #
    my ( $user, $error ) = try {
        my $_user = $c->rs("User")->create(
            {
                email      => $email,
                password   => $password,
                first_name => $first_name,
                last_name  => $last_name,
                time_zone  => $c->app->config->{time_zone},
            },
        );

        ( $_user, undef );
    }
    catch {
        ( undef, $_ );
    };
    unless ($user) {
        my $msg = "failed to create a user $email";
        $c->app->log->debug("$msg: $error");
        $c->render("register", error_type => "create_user", error_message => $msg );
        return;
    }

    $c->redirect_to("/login");
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
