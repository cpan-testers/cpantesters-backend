package CPAN::Testers::Backend::Fix::TesterNoname;
our $VERSION = '0.006';
# ABSTRACT: Fix a tester with "NONAME" as a name

=head1 SYNOPSIS

    beam run <container> <service> <email> <name>

=head1 DESCRIPTION

This task fixes a tester who has C<NONAME> as a name by editing all the
right places.

=head1 ARGUMENTS

=head2 email

The email address of the tester to fix.

=head2 name

The full name of the tester to change to. Only test reports marked as
C<NONAME> will be fixed.

=head1 SEE ALSO

L<CPAN::Testers::Backend>, L<CPAN::Testers::Schema>, L<Beam::Runnable>

=cut

use CPAN::Testers::Backend::Base 'Runnable';
with 'Beam::Runnable';
use Getopt::Long qw( GetOptionsFromArray );
use Data::Dumper;

=attr schema

A L<CPAN::Testers::Schema> object to access the database.

=cut

has schema => (
    is => 'ro',
    isa => InstanceOf['CPAN::Testers::Schema'],
    required => 1,
);

=attr metabase_dbh

The L<DBI> object connected to the C<metabase> database.

=cut

has metabase_dbh => (
    is => 'ro',
    isa => InstanceOf['DBI::db'],
    required => 1,
);

sub run( $self, @args ) {
    my ( $email, @name ) = @args;
    die "Email and name are required" unless $email && @name;
    my $name = join " ", @name;

    $self->schema->resultset( 'MetabaseUser' )
        ->search({ email => $email, fullname => 'NONAME' })
        ->update({ fullname => $name });

    $self->schema->resultset( 'Stats' )
        ->search({ tester => sprintf '"%s" <%s>', 'NONAME', $email })
        ->update({ tester => sprintf '"%s" <%s>', $name, $email });

    $self->schema->resultset( 'TestReport' )
        ->search({ report => [
                    \q{->>"$.reporter.name"='NONAME'},
                    \qq{->>"\$.reporter.email"='$email'},
                ]})
        ->update({ report => \qq{JSON_SET( report, '\$.reporter.name', '$email' )} });

    # Update old testers_email
    $self->metabase_dbh->do(
        q{UPDATE testers_email SET fullname=? WHERE fullname='NONAME' && email=?},
        {},
        $name, $email,
    );
}

1;
