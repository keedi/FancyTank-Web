#!/usr/bin/env perl

use utf8;
use strict;
use warnings;
use feature qw( say );

use Path::Tiny;

use FancyTank::Schema;

my ( $email, $admin ) = @ARGV;

die "Usage: $0 <email> <admin>\n" unless $email;

#
# read from config
#
my $CONF = eval path("fancytank-web.conf")->slurp_utf8;

#
# load db orm
#
my $SCHEMA = FancyTank::Schema->connect(
    {
        dsn      => $CONF->{database}{dsn},
        user     => $CONF->{database}{user},
        password => $CONF->{database}{pass},
        %{ $CONF->{database}{opts} },
    }
);

my $user = $SCHEMA->resultset("User")->find( { email => $email } );

#
# update admin
#
$user->update(
    {
        admin => $admin ? 1 : 0,
    },
)
