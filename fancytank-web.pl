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
# CPAN: Mojolicious::Plugin::Authentication
# https://metacpan.org/pod/Mojolicious::Plugin::Authentication
#
plugin "authentication" => {
    autoload_user   => 1,
    session_key     => "fancytank",
    load_user       => sub {
        my ( $c, $uid ) = @_;

        my $user_obj = $c->app->rs("User")->find({ id => $uid });

        return $user_obj
    },
    validate_user => sub {
        my ( $c, $username, $password, $extradata ) = @_;

        my $user_obj = $c->rs("User")->find({ email => $username });
        unless ($user_obj) {
            my $msg = "$username: cannot find such user";
            $c->app->log->warn($msg);
            return;
        }

        unless ( $user_obj->check_password($password) ) {
            my $msg = "$username: invalid password";
            $c->app->log->warn($msg);
            return;
        }

        unless ( $user_obj->enable ) {
            my $msg = "$username: disabled user";
            $c->app->log->warn($msg);
            return;
        }

        return $user_obj->id;
    },
};

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
app->validator->add_check(
    password => sub {
        my ( $validation, $name, $value, @args ) = @_;
        my ( $user_obj ) = @args;
        my $ret = $user_obj->check_password($value);
        return !$ret;
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

under sub {
    my $c = shift;

    if ( $c->is_user_authenticated ) {
        my $cu = $c->current_user;
        $c->stash( cu => $cu );
        return 1;
    }

    return 1 if $c->req->url->path->to_abs_string eq "/login";
    return 1 if $c->req->url->path->to_abs_string eq "/register";

    $c->app->log->warn("only valid logged-in user can access");
    $c->redirect_to("/login");
    return;
};

get '/' => sub {
    my $c = shift;
    $c->redirect_to("/dashboard");
};

get '/dashboard' => sub {
    my $c = shift;

    my $count_users = $c->rs("User")->count;
    $c->stash( count_users => $count_users );

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

    #
    # redirect for logged in user
    #
    my $cu = $c->current_user;
    if ($cu) {
        $c->redirect_to("/");
        return;
    }

    $c->render(template => 'login');
};

post '/login' => sub {
    my $c = shift;

    #
    # redirect for logged in user
    #
    my $cu = $c->current_user;
    if ($cu) {
        $c->redirect_to("/");
        return;
    }

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

    if ( $c->authenticate( $email, $password ) ) {
        #
        # login success
        #
        my $redirect_url = "/";
        $c->redirect_to( $c->url_for($redirect_url) );
        return;
    }
    else {
        $c->app->log->warn("$email: failed to login");
        $c->render(
            "login",
            error_type    => "login_failed",
            error_message => "User does not exist or password is incorrect.",
        );
        return;
    }
};

get '/logout' => sub {
    my $c = shift;

    my $user = $c->current_user;
    $c->app->log->info( $user->email . ": try to logout");

    $c->logout;
    $c->redirect_to("/login");
};

get '/register' => sub {
    my $c = shift;

    #
    # redirect for logged in user
    #
    my $cu = $c->current_user;
    if ($cu) {
        $c->redirect_to("/");
        return;
    }

    $c->render(template => 'register');
};

post '/register' => sub {
    my $c = shift;

    #
    # redirect for logged in user
    #
    my $cu = $c->current_user;
    if ($cu) {
        $c->redirect_to("/");
        return;
    }

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

post '/account' => sub {
    my $c = shift;

    my $cu = $c->stash("cu");

    $c->app->log->debug( sprintf( "%s: update_type(%s)", $cu->email, $c->param("update_type") ) );

    # http://mojolicious.org/perldoc/Mojolicious/Guides/Rendering#Form-validation
    # Check if parameters have been submitted
    my $validation = $c->validation;
    return $c->render unless $validation->has_data;

    if ( $validation->required("update_type")->in( "basic", "password" )->is_valid ) {
        use experimental qw( smartmatch );
        given ( $validation->param("update_type") ) {
            when ("basic") {
                $validation->required("first_name")->size(1, 64);
                $validation->required("last_name")->size(1, 64);
                $validation->required("time_zone");
            }
            when ("password") {
                $validation->required("password")->size(8, 100)->password($cu);
                $validation->required("new_password")->size(8, 100);
                $validation->required("confirm_new_password")->equal_to("new_password");
            }
        }
    }

    if ( $validation->has_error ) {
        my $msg = "invalid parameters: " . join( ", ", @{ $validation->failed } );
        $c->app->log->debug($msg);
        $c->render("account", error_type => "parameter", error_message => $msg );
        return;
    }

    my $update_type = $c->param("update_type")  || q{};
    my $first_name  = $c->param("first_name")   || q{};
    my $last_name   = $c->param("last_name")    || q{};
    my $time_zone   = $c->param("time_zone")    || q{};
    my $password    = $c->param("new_password") || q{};

    my $log_message = "update_type($update_type): " . join( ",", $cu->email, $first_name, $last_name, $time_zone, $password );
    $c->app->log->debug($log_message);

    #
    # update a user
    #
    my ( $ret, $error ) = try {
        use experimental qw( smartmatch );
        my %params;
        given ($update_type) {
            when ("basic") {
                %params = (
                    first_name => $first_name,
                    last_name  => $last_name,
                    time_zone  => $time_zone,
                );
            }
            when ("password") {
                %params = (
                    password => $password,
                );
            }
        }
        $cu->update( \%params );
        ( 1, undef );
    }
    catch {
        ( undef, $_ );
    };
    unless ($ret) {
        my $msg = sprintf( "failed to update a user %s", $cu->email );
        $c->app->log->debug("$msg: $error");
        $c->render("account", error_type => "update_user", error_message => $msg );
        return;
    }

    $c->render(template => 'account');
};

get '/setting' => sub {
    my $c = shift;

    my $cu = $c->stash("cu");
    unless ( $cu->admin ) {
        $c->app->log->warn("only admin user can access: " . $cu->email);
        $c->reply->not_found;
        return;
    }

    $c->render(template => 'setting');
};

get '/files' => sub {
    my $c = shift;
    $c->render(template => 'files');
};

app->start;
