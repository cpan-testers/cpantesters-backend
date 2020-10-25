package CPAN::Testers::Backend;
our $VERSION = '0.006';
# ABSTRACT: Backend processes for CPAN Testers data and operations

=head1 DESCRIPTION

This distribution contains various backend scripts (inside runnable
modules) that process CPAN Testers data to support the APIs and website.

The runnable modules are all in the C<CPAN::Testers::Backend::> namespace,
and are configured into executable tasks by L<Beam::Wire> configuration files
located in C<etc/container>. The tasks are run using L<Beam::Runner>, which
contains the L<beam> command.

=head1 OVERVIEW

=head2 Logging

All processes should use L<Log::Any> to log important information. Logs will
be directed to syslog using L<Log::Any::Adapter::Syslog>, configured by
C<etc/container/common.yml>.

=head1 SEE ALSO

L<Beam::Runner>, L<Beam::Wire>

=cut

use CPAN::Testers::Backend::Base;
use Exporter qw( import );
use DBI;
use DBI::Const::GetInfoType;

our @EXPORT_OK = qw( check_mysql );

sub check_mysql( $dbh ) {
    # require a MySQL or MariaDB version with JSON support
    my $dbms_version_string = $dbh->get_info( $GetInfoType{SQL_DBMS_VER} );
    my $is_mariadb          = $dbms_version_string =~ /MariaDB/ ? 1 : 0;
    my ($dbms_version)      = $dbms_version_string =~ /(\d+\.\d+)*/;

    if ($is_mariadb) {
        my $min_version_with_json = 10.2;
        die "The CPAN Testers backend requires at least MariaDB version $min_version_with_json"
          if ( $dbms_version < $min_version_with_json );
    }
    else {
        my $min_version_with_json = 5.7;
        die "The CPAN Testers backend requires at least MySQL version $min_version_with_json"
          if $dbms_version < $min_version_with_json;
    }
    return 1;
}

1;

