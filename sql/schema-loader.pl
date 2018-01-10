use strict;
use warnings;

use File::Which;
use IPC::Open2;
use Path::Tiny;

my $namespace = "FancyTank";

my $CONF = eval path("fancytank-web.conf")->slurp_utf8;

{
    schema_class => "${namespace}::Schema",
    connect_info => {
        dsn  => $CONF->{database}{dsn},
        user => $CONF->{database}{user},
        pass => $CONF->{database}{pass},
        %{ $CONF->{database}{opts} },
    },
    loader_options => {
        dump_directory            => "lib",
        components                => [
            "DateTime::Epoch",
            "TimeStamp",
        ],
        result_base_class         => "${namespace}::Schema::ResultBase",
        result_components_map     => {
            User => [ "EncodedColumn" ],
        },
        naming                    => { ALL => "v8" },
        skip_load_external        => 1,
        relationships             => 1,
        col_collision_map         => "column_%s",
        overwrite_modifications   => 1,
        datetime_undef_if_invalid => 1,
        filter_generated_code     => sub {
            my ( $type, $class, $source ) = @_;

            my $tidyall = File::Which::which("tidyall");
            die "cannot find tidyall binary\n" unless $tidyall;

            my $path = $class;
            $path =~ s{::}{/}g;
            $path = "lib/$path.pm";

            my ( $stdout, $stdin );
            my $pid = open2( $stdout, $stdin, "tidyall", "-p", $path );
            print $stdin $source;
            close $stdin;
            my $destination = do { local $/; <$stdout> };
            close $stdout;
            waitpid( $pid, 0 );

            return "#<<<\n$destination\n#>>>\n";
        },
        custom_column_info        => sub {
            my ( $table, $col_name, $col_info ) = @_;

            use experimental qw( switch );

            given ($col_name) {
                when ("create_time") {
                    return +{
                        %$col_info,
                        inflate_datetime => 1,
                        set_on_create    => 1,
                    };
                }
                when ("update_time") {
                    return +{
                        %$col_info,
                        inflate_datetime => 1,
                        set_on_create    => 1,
                        set_on_update    => 1,
                    };
                }
                when (/_time$/) {
                    return +{
                        %$col_info,
                        inflate_datetime => 1,
                    };
                }
                when ("password") {
                    return +{
                        %$col_info,
                        encode_column       => 1,
                        encode_class        => "Digest",
                        encode_args         => { algorithm => "SHA-1", format => "hex", salt_length => 10 },
                        encode_check_method => "check_password",
                    };
                }
            }

            return;
        },
    },
}
