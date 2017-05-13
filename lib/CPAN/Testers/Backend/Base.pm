use utf8;
package CPAN::Testers::Backend::Base;
our $VERSION = '0.001';
# ABSTRACT: Base module for importing standard modules, features, and subs

=head1 SYNOPSIS

    # lib/CPAN/Testers/Backend/MyModule.pm
    package CPAN::Testers::Backend::MyModule;
    use CPAN::Testers::Backend::Base;

    # t/mytest.t
    use CPAN::Testers::Backend::Base 'Test';

=head1 DESCRIPTION

This module collectively imports all the required features and modules
into your module. This module should be used by all modules in the
L<CPAN::Testers::Backend> distribution. This module should not be used by
modules in other distributions.

This module imports L<strict>, L<warnings>, and L<the sub signatures
feature|perlsub/Signatures>.

=head1 SEE ALSO

=over

=item L<Import::Base>

=back

=cut

use strict;
use warnings;
use base 'Import::Base';
use experimental 'signatures';

our @IMPORT_MODULES = (
    'strict', 'warnings',
    feature => [qw( :5.24 signatures refaliasing )],
    '-warnings' => [qw( experimental::signatures experimental::refaliasing )],
);

our %IMPORT_BUNDLES = (
    Runnable => [
        'Moo',
        'Types::Standard' => [qw( InstanceOf )],
        'Log::Any' => [qw( $LOG )],
        'Log::Any::Adapter' => [qw( Syslog )],
        'Getopt::Long' => [qw( GetOptionsFromArray )],
        sub( $bundles, $args ) {
            Moo::Role->apply_roles_to_package( $args->{package}, 'Beam::Runnable' );
        },
    ],
    Test => [
        'Test::More',
    ],
);

1;
