#!/usr/bin/perl -w

BEGIN { $ENV{CATALYST_ENGINE} ||= 'CGI' }

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Social::CPAN::Web;

Social::CPAN::Web->run;

1;

=head1 NAME

social_cpan_web_cgi.pl - Catalyst CGI

=head1 SYNOPSIS

See L<Catalyst::Manual>

=head1 DESCRIPTION

Run a Catalyst application as a cgi script.

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT


This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
