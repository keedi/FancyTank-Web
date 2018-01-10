#!/usr/bin/env perl

use utf8;
use strict;
use warnings;
use feature qw( say );

use Path::Tiny;

use FancyTank::Schema;

my @password_chars = (
    0 .. 9,
    'a' .. 'z',
    'A' .. 'Z',
    '!', '@', '#', '$', '%', '^', '&', '*', '(', ')', '-', '_', '=', '+',
    '[', ']', '{', '}',
);
my $password_length = 16;

my ( $email, $first_name, $last_name, $time_zone ) = @ARGV;

die "Usage: $0 <email> <first_name> <last_name> <time_zone>\n"
    unless $email && $first_name && $last_name && $time_zone;

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

my $tmp_password = q{};
for ( 1 .. 16 ) {
    my $random_index = 0;

    my $count = @password_chars;
    $random_index = int(rand($count));
    
    $tmp_password .= $password_chars[$random_index];
}

my $user = $SCHEMA->resultset("User")->create(
    {
        email      => $email,
        password   => $tmp_password,
        first_name => $first_name,
        last_name  => $last_name,
        time_zone  => $time_zone,
    },
);

printf "%-25s temporary password: %s\n", $user->email, $tmp_password;
