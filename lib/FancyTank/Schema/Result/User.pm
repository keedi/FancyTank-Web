#<<<
use utf8;

package FancyTank::Schema::Result::User;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

FancyTank::Schema::Result::User

=cut

use strict;
use warnings;

=head1 BASE CLASS: L<FancyTank::Schema::ResultBase>

=cut

use base 'FancyTank::Schema::ResultBase';

=head1 COMPONENTS LOADED

=over 4

=item * L<DBIx::Class::DateTime::Epoch>

=item * L<DBIx::Class::TimeStamp>

=item * L<DBIx::Class::EncodedColumn>

=back

=cut

__PACKAGE__->load_components( "DateTime::Epoch", "TimeStamp", "EncodedColumn" );

=head1 TABLE: C<user>

=cut

__PACKAGE__->table("user");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 email

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 password

  data_type: 'char'
  encode_args: {algorithm => "SHA-1",format => "hex",salt_length => 10}
  encode_check_method: 'check_password'
  encode_class: 'Digest'
  encode_column: 1
  is_nullable: 1
  size: 50

first 40 length for digest, after 10 length for salt(random)

=head2 first_name

  data_type: 'varchar'
  is_nullable: 0
  size: 64

=head2 last_name

  data_type: 'varchar'
  is_nullable: 0
  size: 64

=head2 time_zone

  data_type: 'varchar'
  is_nullable: 0
  size: 32

=head2 create_time

  data_type: 'integer'
  inflate_datetime: 1
  is_nullable: 1
  set_on_create: 1

=head2 update_time

  data_type: 'integer'
  inflate_datetime: 1
  is_nullable: 1
  set_on_create: 1
  set_on_update: 1

=cut

__PACKAGE__->add_columns(
    "id",
    {
        data_type         => "integer",
        extra             => { unsigned => 1 },
        is_auto_increment => 1,
        is_nullable       => 0,
    },
    "email",
    { data_type => "varchar", is_nullable => 0, size => 255 },
    "password",
    {
        data_type           => "char",
        encode_args         => { algorithm => "SHA-1", format => "hex", salt_length => 10 },
        encode_check_method => "check_password",
        encode_class        => "Digest",
        encode_column       => 1,
        is_nullable         => 1,
        size                => 50,
    },
    "first_name",
    { data_type => "varchar", is_nullable => 0, size => 64 },
    "last_name",
    { data_type => "varchar", is_nullable => 0, size => 64 },
    "time_zone",
    { data_type => "varchar", is_nullable => 0, size => 32 },
    "create_time",
    {
        data_type        => "integer",
        inflate_datetime => 1,
        is_nullable      => 1,
        set_on_create    => 1,
    },
    "update_time",
    {
        data_type        => "integer",
        inflate_datetime => 1,
        is_nullable      => 1,
        set_on_create    => 1,
        set_on_update    => 1,
    },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<email>

=over 4

=item * L</email>

=back

=cut

__PACKAGE__->add_unique_constraint( "email", ["email"] );

#>>>


# Created by DBIx::Class::Schema::Loader v0.07047 @ 2018-01-10 12:59:53
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:6TxYA7Lznt2H2LFMTNgy7g


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
