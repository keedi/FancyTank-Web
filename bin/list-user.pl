#!/usr/bin/env perl

use utf8;
use strict;
use warnings;
use feature qw( say );

use Path::Tiny;

use FancyTank::Schema;

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

my $rs = $SCHEMA->resultset("User");
my $display_fmt = "%-2s %-20s %-50s %-20s %-10s %-19s %-19s\n";
printf(
    $display_fmt,
    "id",
    "email",
    "cryped password",
    "name (first/last)",
    "time_zone",
    "create_time",
    "update_time",
);
while ( my $item = $rs->next ) {
    printf(
        $display_fmt,
        $item->id,
        $item->email,
        $item->password,
        $item->first_name . q{ } . $item->last_name,
        $item->time_zone,
        $item->create_time,
        $item->update_time,
    );
}
