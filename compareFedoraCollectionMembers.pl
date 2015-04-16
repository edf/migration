#!/usr/bin/perl
#
# compare contents of collections during Fedora data migration -ekf 2015-0317-2236
#
use strict;
use warnings;
use URI::Escape;
use 5.010;

if ( $#ARGV != 0 ) {
    print STDERR "\n     Usage is $0 <fedora collection PID>\n\n";
    exit(8);
}
my $pidValue = $ARGV[0];
chomp $pidValue;
my $oldUserName                      = "fedoraAdmin";
my $oldPassWord                      = 'oldFedoraAdminPassword';
my $oldFedoraServerInfo              = "old-fedora.FQDN.org";
my $newUserName                      = "fedoraAdmin";
my $newPassWord                      = "newFedoraAdminPassword";
my $newFedoraServerInfo              = "new-fedora.FQDN.org";
my ($pidNameSpace,$pidNumber)        = split(/:/, $pidValue);

my @pidsOld    = getPids( $pidValue, $oldUserName, $oldPassWord, $oldFedoraServerInfo );
my @pidsNew    = getPids( $pidValue, $newUserName, $newPassWord, $newFedoraServerInfo );
print "\n";
my ( @isect, @diff, %isect );
my @union = @isect = @diff = ();
my %union = %isect = ();
my %count = ();

foreach my $e ( @pidsOld, @pidsNew ) { $count{$e}++ }
foreach my $e ( keys %count ) {
    push( @union, $e );
    if ( $count{$e} == 2 ) {
        push @isect, $e;
    }
    else {
        push @diff, $e;
    }
}

my @onlyOld = ();
my @onlyNew = ();
foreach my $term (@pidsOld) {
    if ( grep $_ eq $term, @diff ) {
        push @onlyOld, $term;
    }
}
foreach my $term (@pidsNew) {
    if ( grep $_ eq $term, @diff ) {
        push @onlyNew, $term;
    }
}

my $collectionOld = @pidsOld;
my $onlyOld       = @onlyOld;
print "\nIn collection $pidValue containing $collectionOld objects, $onlyOld ";
print "PIDs only in Fedora Repository on $oldFedoraServerInfo\n";
foreach (@onlyOld) {
    chomp;
    say;
}

my $collectionNew = @pidsNew;
my $onlyNew       = @onlyNew;
print "\nIn Collection $pidValue containing $collectionNew objects, $onlyNew ";
print "PIDs only in Fedora Repository on $newFedoraServerInfo\n";
foreach (@onlyNew) {
    chomp;
    say;
}
print "\n";
######################################################
sub getPids {
    my ( $PID, $username, $password, $server ) = @_;
    my $searchString
        = 'select $member from <#ri> where ('
        . '$member <fedora-rels-ext:isMemberOf> <info:fedora/'
        . $pidValue
        . '>  or $member <fedora-rels-ext:isMemberOfCollection> <info:fedora/'
        . $pidValue
        . '> ) and $member <fedora-model:state> <info:fedora/fedora-system:def/model#Active>'
        . 'order by $member; ';
    my $searchStringEncoded = uri_escape($searchString);
    my $pidQuery
        = qq("http://$server:8080/fedora/risearch?type=tuples&lang=itql&format=CSV&dt=on&query=$searchStringEncoded");
    my $pidQ = qx(curl -s -u $username:$password $pidQuery);

    open( my $fh, "<", \$pidQ ) or die " cannot open file $! ";
    my $queryResultCounter = 0;
    my @collectionPid;
    while ( my $line = <$fh> ) {
        chomp $line;
        $line =~ s/^\s+|\s+$//g;  # remove both leading and trailing whitespace
        next if $line =~ m/^"member"/;
        my ( $frontPart, $pid ) = split( /\//, $line );
        push( @collectionPid, $pid );
        $queryResultCounter++;
    }
    my @sortedListCollectionPid
        = map { $_->[0] }
        sort { $a->[1] <=> $b->[1] || $a->[0] cmp $b->[0] }
        map { [ $_, ( split /:/ )[ 1, 0 ] ] } @collectionPid;
    return @sortedListCollectionPid;
}
