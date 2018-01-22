#!/usr/bin/env perl

use utf8;

use Mojolicious::Lite;

use Mojo::Util;

use DateTime;
use Email::Valid;
use File::stat;
use Path::Tiny;
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

plugin "RenderFile";

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

helper sorted_dirs_files => sub {
    my ( $c, $current_dir ) = @_;

    my $iter = $current_dir->iterator;
    my @dirs;
    my @files;
    while ( my $path = $iter->() ) {
        my $encoded_path = $current_dir->child( Mojo::Util::decode("UTF-8", $path->basename) );
        if ( $encoded_path->is_dir ) {
            push @dirs, $encoded_path;
        }
        else {
            push @files, $encoded_path;
        }
    }
    my @sorted_dirs  = sort @dirs;
    my @sorted_files = sort @files;

    return ( \@sorted_dirs, \@sorted_files );
};

helper recent_files => sub {
    my ( $c, $home_dir ) = @_;

    my @files = `find $home_dir -mtime -2`;
    chomp @files;

    my @encoded_files = map { Mojo::Util::decode("UTF-8", $_) } @files;
    my @result_files;
    for my $file (@encoded_files) {
        my $encoded_path = path($file);
        push @result_files, $encoded_path;
    }

    return \@result_files;
};

helper get_req_dir => sub {
    my ( $c, $base_dir, $remain_dir ) = @_;

    unless ( $base_dir ) {
        $c->app->log->warn("base_dir is needed");
        return;
    }

    my $current_dir;
    if ($remain_dir) {
        $current_dir = path($base_dir)->child($remain_dir);
    }
    else {
        $current_dir = path($base_dir);
    }
    unless ( $current_dir->is_dir ) {
        $c->app->log->warn("req_dir must be a valid directory: [$current_dir]");
        return;
    }

    return $current_dir;
};

helper get_req_file => sub {
    my ( $c, $base_dir, $remain_file ) = @_;

    unless ( $base_dir ) {
        $c->app->log->warn("base_dir is needed");
        return;
    }

    unless ($remain_file) {
        $c->app->log->warn("remain_file is needed");
        return;
    }

    my $current_file = path($base_dir)->child($remain_file);
    unless ( $current_file->is_file ) {
        $c->app->log->warn("req_file must be a valid file: [$current_file]");
        return;
    }

    return $current_file;
};

helper get_req_path => sub {
    my ( $c, $base_dir, $remain_path ) = @_;
    my %opts = (
        check_exists => 1,
        %{ $_[3] || +{} },
    );

    unless ( $base_dir ) {
        $c->app->log->warn("base_dir is needed");
        return;
    }

    unless ($remain_path) {
        $c->app->log->warn("remain_path is needed");
        return;
    }

    my $current_file = path($base_dir)->child($remain_path);
    if ( $opts{check_exists} ) {
        unless ( $current_file->exists ) {
            $c->app->log->warn("req_file must be existed: [$current_file]");
            return;
        }
    }

    return $current_file;
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
    return 1 if $c->req->url->path->to_abs_string =~ m{^/api/app/};

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

    my $cu = $c->stash("cu");
    my $home_dir = $cu->home_dir;

    my $count_recent = `find $home_dir -mtime -2 | wc -l`;

    my $count_files = `find $home_dir | wc -l`;
    chomp $count_files;
    $c->app->log->debug( sprintf( "%s: count_files(%d)", $cu->email, $count_files ) );

    my %storage;
    {
        my @lines = `df -h --output=source,size,used,avail $home_dir`;
        my ( undef, $sized, $used, $avail ) = split q{ }, $lines[1];
        $c->app->log->debug( sprintf( "%s: sized(%s), used(%s), avail(%s)", $cu->email, $sized, $used, $avail ) );
        %storage = (
            sized => $sized,
            used  => $used,
            avail => $avail,
        );
    }

    my $files = $c->recent_files($home_dir);

    my $count_users = $c->rs("User")->count;
    $c->stash(
        count_recent => $count_recent,
        count_users  => $count_users,
        count_files  => $count_files,
        storage      => \%storage,
        files        => $files,
        base_dir     => q{},
    );

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

    my $cu = $c->stash("cu");

    my $current_dir = $c->get_req_dir( $cu->home_dir );
    unless ($current_dir) {
        $c->reply->not_found;
        return;
    }
    my ( $dirs, $files ) = $c->sorted_dirs_files($current_dir);

    $c->stash(
        breadcrumbs => [],
        base_dir    => q{},
        dirs        => $dirs,
        files       => $files,
    );

    $c->render(template => 'files');
};

get '/files/*dir' => sub {
    my $c = shift;

    my $cu  = $c->stash("cu");
    my $dir = $c->param("dir");

    $c->app->log->debug( sprintf( "%s: opening dir: [%s]", $cu->email, $dir ) );

    my $current_dir = $c->get_req_dir( $cu->home_dir, $dir );
    unless ($current_dir) {
        $c->reply->not_found;
        return;
    }
    my ( $dirs, $files ) = $c->sorted_dirs_files($current_dir);

    my @breadcrumbs = split "/", $dir;

    $c->stash(
        breadcrumbs => \@breadcrumbs,
        base_dir    => $dir,
        dirs        => $dirs,
        files       => $files,
    );

    $c->render(template => 'files');
};

get '/preview/*file' => sub {
    my $c = shift;

    my $cu   = $c->stash("cu");
    my $file = $c->param("file");

    $c->app->log->debug( sprintf( "%s: preview file: [%s]", $cu->email, $file ) );

    my $current_file = $c->get_req_file( $cu->home_dir, $file );
    unless ($current_file) {
        $c->reply->not_found;
        return;
    }

    my @breadcrumbs = split "/", $file;

    my $basename = path("/files/$file")->basename;
    $c->stash(
        breadcrumbs => \@breadcrumbs,
        basename    => $basename,
        file        => $file,
        path_obj    => $current_file,
        file_stat   => stat($current_file),
    );

    $c->render(template => 'preview');
};

get '/download/*file' => sub {
    my $c = shift;

    my $cu   = $c->stash("cu");
    my $file = $c->param("file");

    $c->app->log->debug( sprintf( "%s: download file: [%s]", $cu->email, $file ) );

    my $current_file = $c->get_req_file( $cu->home_dir, $file );
    unless ($current_file) {
        $c->reply->not_found;
        return;
    }

    $c->render_file( filepath => "$current_file" );
};

del '/api/files/*file/delete' => sub {
    my $c = shift;

    my $cu   = $c->stash("cu");
    my $file = $c->param("file");

    $c->app->log->debug( sprintf( "%s: api.delete file: [%s]", $cu->email, $file ) );

    my $current_file = $c->get_req_path( $cu->home_dir, $file );
    unless ($current_file) {
        my $error_code = 400;
        my $error_msg  = "The requested resource is not valid";
        $c->render(
            status => $error_code,
            json   => {
                message   => $error_msg,
                errorCode => $error_code,
                created   => DateTime->now( time_zone => $cu->time_zone ),
                request   => sprintf( "%s %s", $c->req->method, $c->req->url->path->to_abs_string ),
            },
        );
        return;
    }

    $current_file->remove_tree;

    $c->render(
        json   => {
            message => "Success",
            created => DateTime->now( time_zone => $cu->time_zone ),
            request => sprintf( "%s %s", $c->req->method, $c->req->url->path->to_abs_string ),
        },
    );
};

put '/api/files/*file/rename' => sub {
    my $c = shift;

    my $cu       = $c->stash("cu");
    my $file     = $c->param("file");
    my $filename = $c->param("filename");

    $c->app->log->debug( sprintf( "%s: api.rename file: [%s] -> [%s]", $cu->email, $file, $filename ) );

    my $current_file = $c->get_req_path( $cu->home_dir, $file );
    unless ($current_file) {
        my $error_code = 400;
        my $error_msg  = "The requested resource is not valid";
        $c->render(
            status => $error_code,
            json   => {
                message   => $error_msg,
                errorCode => $error_code,
                created   => DateTime->now( time_zone => $cu->time_zone ),
                request   => sprintf( "%s %s", $c->req->method, $c->req->url->path->to_abs_string ),
            },
        );
        return;
    }

    my $is_same_dir = 0;
    my $dest = $current_file->parent->child($filename);
    {
        my $p1 = path( $cu->home_dir )->realpath;
        my ( $p2, $error ) = try {
            my $_path = $dest->realpath;
            ( $_path, undef );
        }
        catch {
            ( undef, $_ );
        };
        unless ($p2) {
            $c->app->log->warn("cannot resolve path: [$dest]");

            my $error_code = 400;
            my $error_msg  = "The requested new filename cannot be resolved";
            $c->render(
                status => $error_code,
                json   => {
                    message   => $error_msg,
                    errorCode => $error_code,
                    created   => DateTime->now( time_zone => $cu->time_zone ),
                    request   => sprintf( "%s %s", $c->req->method, $c->req->url->path->to_abs_string ),
                },
            );
            return;
        }
        unless ( $p1->subsumes($p2) ) {
            $c->app->log->warn("unallowed path: [$dest] [$p2]");

            my $error_code = 400;
            my $error_msg  = "The requested new filename is not valid";
            $c->render(
                status => $error_code,
                json   => {
                    message   => $error_msg,
                    errorCode => $error_code,
                    created   => DateTime->now( time_zone => $cu->time_zone ),
                    request   => sprintf( "%s %s", $c->req->method, $c->req->url->path->to_abs_string ),
                },
            );
            return;
        }
        $is_same_dir = 1 if $current_file->parent eq $p2->parent;

        $c->app->log->info(
            sprintf(
                "%s: move file: [%s] -> [%s]",
                $cu->email,
                $current_file,
                $p2,
            )
        );
    }

    # rename file
    $current_file->move($dest);

    $c->render(
        json   => {
            message      => "Success",
            isSameDir    => $is_same_dir,
            destFilename => $dest->basename,
            created      => DateTime->now( time_zone => $cu->time_zone ),
            request      => sprintf( "%s %s", $c->req->method, $c->req->url->path->to_abs_string ),
        },
    );
};

post '/api/dirs/*dir' => sub {
    my $c = shift;

    my $cu  = $c->stash("cu");
    my $dir = $c->param("dir");

    $c->app->log->debug( sprintf( "%s: api.create.dir: [%s]", $cu->email, $dir, ) );

    my $validation = $c->validation;
    # http://mojolicious.org/perldoc/Mojolicious/Validator/Validation#input
    $validation->input({ dir => $dir });
    return $c->render unless $validation->has_data;

    # deny: \ / : ? * " |
    $validation->required("dir")->size(1, 128)->like(qr{[^\\/:?*"|]+});

    if ( $validation->has_error ) {
        my $error_code = 400;
        my $error_msg  = "Invalid parameters: " . join( ", ", @{ $validation->failed } );
        $c->app->log->warn($error_msg);
        $c->render(
            status => $error_code,
            json   => {
                message   => $error_msg,
                errorCode => $error_code,
                created   => DateTime->now( time_zone => $cu->time_zone ),
                request   => sprintf( "%s %s", $c->req->method, $c->req->url->path->to_abs_string ),
            },
        );
        return;
    }

    my $current_dir = $c->get_req_path( $cu->home_dir, $dir, { check_exists => 0 } );
    unless ($current_dir) {
        my $error_code = 400;
        my $error_msg  = "The requested resource is not valid";
        $c->app->log->warn($error_msg);
        $c->render(
            status => $error_code,
            json   => {
                message   => $error_msg,
                errorCode => $error_code,
                created   => DateTime->now( time_zone => $cu->time_zone ),
                request   => sprintf( "%s %s", $c->req->method, $c->req->url->path->to_abs_string ),
            },
        );
        return;
    }
    if ( $current_dir->exists ) {
        my $error_code = 400;
        my $error_msg  = "The requested resource is already existed";
        $c->app->log->warn($error_msg);
        $c->render(
            status => $error_code,
            json   => {
                message   => $error_msg,
                errorCode => $error_code,
                created   => DateTime->now( time_zone => $cu->time_zone ),
                request   => sprintf( "%s %s", $c->req->method, $c->req->url->path->to_abs_string ),
            },
        );
        return;
    }

    # create path
    $current_dir->mkpath;
    if ( $current_dir->is_dir ) {
        $c->app->log->info( sprintf( "%s: created dir: [%s]", $cu->email, $current_dir ) );
    }

    $c->render(
        json   => {
            message     => "Success",
            destDirname => $current_dir->basename,
            created     => DateTime->now( time_zone => $cu->time_zone ),
            request     => sprintf( "%s %s", $c->req->method, $c->req->url->path->to_abs_string ),
        },
    );
};

post '/api/files/*file' => sub {
    my $c = shift;

    my $cu          = $c->stash("cu");
    my $file        = $c->param("file");
    my $upload_file = $c->param("upload_file");

    $c->app->log->debug( sprintf( "%s: api.create.file [%s]", $cu->email, $file ) );

    # Check file size
    if ( $c->req->is_limit_exceeded ) {
        my $error_code = 400;
        my $error_msg  = "File is too big.";
        $c->app->log->warn($error_msg);
        $c->render(
            status => $error_code,
            json   => {
                message   => $error_msg,
                errorCode => $error_code,
                created   => DateTime->now( time_zone => $cu->time_zone ),
                request   => sprintf( "%s %s", $c->req->method, $c->req->url->path->to_abs_string ),
            },
        );
        return;
    }

    my $current_file = $c->get_req_path( $cu->home_dir, $file, { check_exists => 0 } );
    unless ($current_file) {
        my $error_code = 400;
        my $error_msg  = "The requested resource is not valid";
        $c->app->log->warn($error_msg);
        $c->render(
            status => $error_code,
            json   => {
                message   => $error_msg,
                errorCode => $error_code,
                created   => DateTime->now( time_zone => $cu->time_zone ),
                request   => sprintf( "%s %s", $c->req->method, $c->req->url->path->to_abs_string ),
            },
        );
        return;
    }
    if ( $current_file->exists ) {
        my $error_code = 400;
        my $error_msg  = "The requested resource is already existed";
        $c->app->log->warn($error_msg);
        $c->render(
            status => $error_code,
            json   => {
                message   => $error_msg,
                errorCode => $error_code,
                created   => DateTime->now( time_zone => $cu->time_zone ),
                request   => sprintf( "%s %s", $c->req->method, $c->req->url->path->to_abs_string ),
            },
        );
        return;
    }

    # copy uploaded file
    my $ret = $upload_file->move_to("$current_file");
    unless ($ret) {
        my $error_code = 500;
        my $error_msg  = "Failed to copy uploaded file";
        $c->app->log->warn($error_msg);
        $c->render(
            status => $error_code,
            json   => {
                message   => $error_msg,
                errorCode => $error_code,
                created   => DateTime->now( time_zone => $cu->time_zone ),
                request   => sprintf( "%s %s", $c->req->method, $c->req->url->path->to_abs_string ),
            },
        );
        return;
    }

    if ( $current_file->exists ) {
        $c->app->log->info( sprintf( "%s: created file: [%s] %d bytes", $cu->email, $current_file, $upload_file->size ) );
    }

    $c->render(
        json => {
            message      => "Success",
            destFilename => $current_file->basename,
            created      => DateTime->now( time_zone => $cu->time_zone ),
            request => sprintf( "%s %s", $c->req->method, $c->req->url->path->to_abs_string ),
        },
    );
};

get '/api/app/files' => sub {
    my $c = shift;

    my $cu  = $c->app->rs("User")->find({ id => $c->app->config->{test}{user_id} });
    my $dir = q{};

    $c->app->log->debug( sprintf( "%s: opening dir: [%s]", $cu->email, $dir ) );

    my $current_dir = $c->get_req_dir( $cu->home_dir, $dir );
    unless ($current_dir) {
        my $error_code = 404;
        my $error_msg  = "Not found";
        $c->app->log->warn($error_msg);
        $c->render(
            status => $error_code,
            json   => {
                message   => $error_msg,
                errorCode => $error_code,
                created   => DateTime->now( time_zone => $cu->time_zone ),
                request   => sprintf( "%s %s", $c->req->method, $c->req->url->path->to_abs_string ),
            },
        );
        return;
    }
    my ( $dirs, $files ) = $c->sorted_dirs_files($current_dir);

    my @result;
    for my $p ( @$dirs, @$files ) {
        my $file_stat = stat($p);
        my $mtime = DateTime->from_epoch(
            epoch     => $file_stat->mtime,
            time_zone => $cu->time_zone,
        );
        my $description = sprintf( '%s %s', $mtime->ymd, $mtime->hms );
        push(
            @result,
            {
                name        => $p->basename,
                description => $description,
                isType      => ( $p->is_dir ? "dir" : "file" ),
            },
        );
    }

    $c->render(
        json => {
            message     => "Success",
            files       => \@result,
            dirBasename => q{},
            created     => DateTime->now( time_zone => $cu->time_zone ),
            request     => sprintf( "%s %s", $c->req->method, $c->req->url->path->to_abs_string ),
        },
    )
};

get '/api/app/files/*dir' => sub {
    my $c = shift;

    my $cu  = $c->app->rs("User")->find({ id => $c->app->config->{test}{user_id} });
    my $dir = $c->param("dir");

    $c->app->log->debug( sprintf( "%s: opening dir: [%s]", $cu->email, $dir ) );

    my $current_dir = $c->get_req_dir( $cu->home_dir, $dir );
    unless ($current_dir) {
        my $error_code = 404;
        my $error_msg  = "Not found";
        $c->app->log->warn($error_msg);
        $c->render(
            status => $error_code,
            json   => {
                message   => $error_msg,
                errorCode => $error_code,
                created   => DateTime->now( time_zone => $cu->time_zone ),
                request   => sprintf( "%s %s", $c->req->method, $c->req->url->path->to_abs_string ),
            },
        );
        return;
    }
    my ( $dirs, $files ) = $c->sorted_dirs_files($current_dir);

    my @result;
    for my $p ( @$dirs, @$files ) {
        my $file_stat = stat($p);
        my $mtime = DateTime->from_epoch(
            epoch     => $file_stat->mtime,
            time_zone => $cu->time_zone,
        );
        my $description = sprintf( '%s %s', $mtime->ymd, $mtime->hms );
        push(
            @result,
            {
                name        => $p->basename,
                description => $description,
                isType      => ( $p->is_dir ? "dir" : "file" ),
            },
        );
    }

    $c->render(
        json => {
            message     => "Success",
            files       => \@result,
            dirBasename => path($dir)->basename,
            created     => DateTime->now( time_zone => $cu->time_zone ),
            request     => sprintf( "%s %s", $c->req->method, $c->req->url->path->to_abs_string ),
        },
    )
};

app->start;
