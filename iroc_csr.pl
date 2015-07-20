#!/usr/bin/perl
#
#   wrapper for migrating content from i6 to i7 using Islandora module iroc-csr
#
#   adjust site specific --root and --uri to local settings
#
use strict;
use warnings;
#use URI::Escape;
use 5.010;
if ( $#ARGV != 1 ) {
    print STDERR "\n     Usage is $0 <fedora collection PID> <Object PID>\n\n";
    exit(8);
}
my $collectionPid = $ARGV[0];
my $pid = $ARGV[1];
my $result = qx(drush --root=/var/www/coalliance/current --uri http://sitename.coalliance.org --user=1 iroc-csr --fedora_pid=$pid --parent_collection=$collectionPid );
print "PID - $pid collection - $collectionPid\n";
say $result;
