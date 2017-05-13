package CPAN::Testers::Backend::Migrate::MetabaseUsers;
our $VERSION = '0.001';
# ABSTRACT: Migrate old metabase users to new table for metabase lookups

=head1 SYNOPSIS

    beam run <container> <service>

=head1 DESCRIPTION

This task migrates the users in the C<metabase.tester_emails> table to the
C<cpanstats.metabase_user> table. This makes these users available to the
L<CPAN::Testers::Schema> for when new Metabase reports come in.

Only the latest name and e-mail address for a given Metabase resource GUID
will be migrated.

=cut

use CPAN::Testers::Backend::Base 'Runnable';
with 'Beam::Runnable';

=attr metabase_dbh

The L<DBI> object connected to the C<metabase> database.

=cut

has metabase_dbh => (
    is => 'ro',
    isa => InstanceOf['DBI::db'],
    required => 1,
);

=attr schema

The L<CPAN::Testers::Schema> to write users to.

=cut

has schema => (
    is => 'ro',
    isa => InstanceOf['CPAN::Testers::Schema'],
    required => 1,
);

sub run( $self, @args ) {
    my @from_users = $self->metabase_dbh->selectall_array( 'SELECT resource,fullname,email FROM testers_email ORDER BY id ASC', { Slice => {} } );

    # Save the last user for this GUID
    my %users;
    for \my %user ( @from_users ) {
        $users{ $user{resource} } = \%user;
    }

    # Update the user in the mapping table
    for \my %user ( values %users ) {
        $self->schema->resultset( 'MetabaseUser' )->update_or_create( \%user );
    }
}

1;
