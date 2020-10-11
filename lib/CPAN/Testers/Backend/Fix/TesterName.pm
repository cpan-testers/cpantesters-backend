package CPAN::Testers::Backend::Fix::TesterInfo;
our $VERSION = '0.006';
# ABSTRACT: Fix testers name and e-mail address

=head1 SYNOPSIS

    beam run <container> <service> [--like <match>] <email> <name>

=head1 DESCRIPTION

This task fixes a tester who has C<NONAME> as a name by editing all the
right places.

=head1 ARGUMENTS

=head2 email

The email address of the tester.

=head2 name

The full name of the tester to change to.

=head1 OPTIONS

=head2 --like <match>

Use a SQL LIKE match to find values to fix up. This is matched against
the tester's name.

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
    GetOptionsFromArray(
        \@args,
        \my %opt,
        'like=s',
    );
    my ( $email, @name ) = @args;
    die "Email and name are required" unless $email && @name;
    die "--like is required (until a new query type is made)" unless $opt{like};
    my $name = join " ", @name;

    $self->schema->resultset( 'MetabaseUser' )
        ->search({
            fullname => { -like => $opt{like} },
        })
        ->update({
            fullname => $name,
            email => $email,
        });

    $self->schema->resultset( 'Stats' )
        ->search({
            tester => { -like => $opt{like} },
        })
        ->update({
            tester => sprintf '"%s" <%s>', $name, $email,
        });

    my $rs = $self->schema->resultset( 'TestReport' )
        ->search({ report => \qq{->>"\$.reporter.name" LIKE '$opt{like}'} });
    $rs->update({ report => \qq{JSON_SET( report, '\$.reporter.name', '$name' )} });
    $rs->update({ report => \qq{JSON_SET( report, '\$.reporter.email', '$email' )} });

    # Update old testers_email
    $self->metabase_dbh->do(
        q{UPDATE testers_email SET fullname=?,email=? WHERE fullname LIKE ?},
        {},
        $name, $email, $opt{like},
    );
}

1;
