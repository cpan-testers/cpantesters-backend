package CPAN::Testers::Backend::Fix::DeletePerl6Stats;
our $VERSION = '0.006';
# ABSTRACT: Delete any stats from reports for Perl 6

=head1 SYNOPSIS

    beam run <container> <service>

=head1 DESCRIPTION

This task will remove any stats rows not from Perl 5.

=head1 ARGUMENTS

=head1 OPTIONS

=head1 SEE ALSO

L<CPAN::Testers::Backend>, L<CPAN::Testers::Schema>, L<Beam::Runnable>

=cut

use CPAN::Testers::Backend::Base 'Runnable';
with 'Beam::Runnable';
use Getopt::Long qw( GetOptionsFromArray );
use Data::Dumper;
use List::Util qw( min );

=attr schema

A L<CPAN::Testers::Schema> object to access the database.

=cut

has schema => (
    is => 'ro',
    isa => InstanceOf['CPAN::Testers::Schema'],
    required => 1,
);

sub run( $self, @args ) {
    GetOptionsFromArray(
        \@args,
        \my %opt,
    );

    my $schema = $self->schema;
    my $stats = $schema->resultset('Stats');
    my $reports = $schema->resultset('TestReport')->search({
      report => \[ "->> '\$.environment.language.name'=?", 'Perl 6' ],
    });
    $stats->search({
        guid => {
            -in => $reports->get_column('id')->as_query,
        },
    })->delete;
    return 0;
}

1;
