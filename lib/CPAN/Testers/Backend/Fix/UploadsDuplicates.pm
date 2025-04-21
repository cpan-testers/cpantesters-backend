package CPAN::Testers::Backend::Fix::UploadsDuplicates;
our $VERSION = '0.006';
# ABSTRACT: Fix testers name and e-mail address

=head1 SYNOPSIS

    beam run <container> <service>

=head1 DESCRIPTION

This task will de-duplicate the uploads table and fix all the
relationships in the Stats, Release, etc... tables.

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

    # Find all the duplicated uploads rows
    my $has_dups = $self->schema->resultset('Upload')->search({}, {
        select => [qw( dist version )],
        as => [qw( dist version )],
        group_by => [qw( dist version )],
        having => \'COUNT(*) > 1',
      });
    while ( my $dup = $has_dups->next ) {
      my $dist = $dup->dist;
      my $version = $dup->version;
      my @ids = $self->schema->resultset('Upload')->search({ dist => $dist, version => $version })->get_column('uploadid')->all;
      my $save_id = min @ids;
      my @delete_ids = grep { $_ != $save_id } @ids;

      # Find the other IDs in related tables and update them to the
      # minimum ID
      for my $table (qw( LatestIndex Release ReleaseStat Stats )) {
        $self->schema->resultset($table)->search({ uploadid => \@delete_ids })->update({ uploadid => $save_id });
      }

      # Delete the other IDs
      $self->schema->resultset('Upload')->search({ uploadid => \@delete_ids })->delete();
    }
}

1;
