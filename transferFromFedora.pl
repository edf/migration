#!/usr/bin/perl
#
#    transfer using URIfile with pid list, single PID or collection PID  -ekf 2015-0729-1307 updated 2015-0804-1754
#
use strict;
use warnings;
use XML::XPath;
use POSIX qw(strftime);
use 5.010;

if ( $#ARGV != 0 ) {
    print "\n     Usage is $0 PID\n";
    print "           or $0 filename\n\n";
    exit(8);
}

my $MagentaText = "\e[1;35m";
my $RedText     = "\e[1;31m";
my $GreenText   = "\e[1;32m";
my $BlueText    = "\e[0;44m";
my $NormalText  = "\e[0m";
# local settings
my $ServerName    = "http://adr-fcrepo.uwyo.edu";
my $ServerPort    = "8080";
my $fedoraContext = "fedora";
my $UserName      = "fedoraUserName";
my $PassWord      = "fedoraUserPassWord";
my $sourceAuthN   = "-u " . $UserName . ":" . $PassWord;
my $fedoraURI     = $ServerName . ":" . $ServerPort . "/" . $fedoraContext;
my $timeStamp     = POSIX::strftime( "%Y-%m%d-%H%M-%S", localtime );
my $option = $ARGV[0];
chomp $option;
my $optionType = typeOfOption( $option, $sourceAuthN, $fedoraURI );
say $optionType;
my $directoryName = "/tmp/testLargeExport/testDir"
    ;    # use full path (i.e. absolute path) for directory
my $tmpDirectory = "/tmp/testLargeExport/tmp"
    ;    # use full path (i.e. absolute path) for directory
if ( $optionType eq "singleObject" ) {
    my $PID = $option;
#TODO check if PID already exists
#my $objectTest = qx(curl -s -u ${newUserName}:${newPassWord}  "$newFedoraURI/$pidIn/validate");
#if ( $objectTest =~ m#Object not found in low-level storage: $pidIn# ) {
#                        my $pidStatus = "active";
#                        eval {
#                            getFoxml( $pidIn, $directoryName, $pidStatus, $UserName, $PassWord, $fedoraURI );
#                        };
#                        $pidCounter++;
#if ($@) {
#                            my $timeStampWarn = POSIX::strftime( "%Y-%m%d-%H%M-%S", localtime );
#                            warn qq($timeStampWarn ERROR: $pidIn has an error\n$@\n);
#                            $errorCounter++;
#                        }
#                    }
#                    else { print "$line already exists in $newFedoraURI\n"; }
    my $nicePID = $PID;
    $nicePID =~ s/:/_/g;
    # make directory unless it already exists
    mkdir "$directoryName", 0775
        unless -d "$directoryName";
    mkdir "$tmpDirectory/$nicePID", 0775
        unless -d "$tmpDirectory/$nicePID";
### get FoxML string
    my $foxmlString
        = qx(curl -s -u ${UserName}:${PassWord} "${fedoraURI}/objects/$PID/export?context=migrate" |tidy --wrap 0 --input-xml yes -f Error.tidy.txt);
    my $xp = XML::XPath->new( xml => $foxmlString );
    my @foxml = qq(<?xml version="1.0" encoding="utf-8"?>
<foxml:digitalObject VERSION="1.1" PID="$PID" xmlns:foxml="info:fedora/fedora-system:def/foxml#" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="info:fedora/fedora-system:def/foxml# http://www.fedora.info/definitions/1/0/foxml1-1.xsd">
);
    my $objPropQuery = '//foxml:objectProperties';
    my @objProperties = xpathQuery( $objPropQuery, $xp );
    push @foxml, @objProperties;
    my $inlineQuery = '//foxml:datastream[@CONTROL_GROUP="X"]/@ID';
    my @inlineDatastreams = xpathQuery( $inlineQuery, $xp );
    foreach my $inLine (@inlineDatastreams) {
        $inLine =~ s/^\s+//g;    #  strip white space before string
        $inLine =~ s/\s+$//g;    #  strip white space after string
        $inLine =~ s/ID="//g;
        $inLine =~ s/"//g;
        print $MagentaText . "$inLine " . $NormalText;
        my $inlineDatastreamType = $inLine;
        my @xResult = useXpathQuery( $inlineDatastreamType, $xp );
        push @foxml, @xResult;
        #TODO if MODS or DC remove empty tags, create string from array
        #foreach my $xLine( @xResult) {
        #     say  $xLine;
        #}
    }
    my $managedQuery = '//foxml:datastream[@CONTROL_GROUP="M"]/@ID';
    my @managedDatastreams = xpathQuery( $managedQuery, $xp );
    foreach my $line (@managedDatastreams) {
        $line =~ s/^\s+//g;    #  strip white space before string
        $line =~ s/\s+$//g;    #  strip white space after string
        $line =~ s/ID="//g;
        $line =~ s/"//g;
        print $MagentaText . "$line " . $NormalText;
        my $datastreamType = $line;
        my @idResult = useXpathQuery( $datastreamType, $xp );
        my $counter;
        foreach my $lineID (@idResult) {
            $counter++;
            my $location
                = qq(<foxml:contentLocation TYPE="INTERNAL_ID" REF="file:///$directoryName/$nicePID/$datastreamType" />\n);
            # regex to capture from <foxml:contentLocation to />
            my $foxmlDatastream = $lineID;
            $foxmlDatastream =~ m#(?<foxmlDS>\<foxml:datastream.*\>)#;
            my $fDS = $+{foxmlDS};
            push @foxml, $fDS;
            my $foxmlDatastreamVersion = $lineID;
            $foxmlDatastreamVersion
                =~ m#(?<foxmlDSver>\<foxml:datastreamVersion.*\>)#;
            my $fDSver = $+{foxmlDSver};
            push @foxml, $fDSver;
            my $contentLocation = $lineID;
            $contentLocation
                =~ m#(?<startOfline>.*)(?<refPart>REF="http://localhost:8080/fedora/get/)(?<pid>\w+:\w+/)(?<datastream>.*/)(?<timestamp>.*\/\>)(?<remaining>.*)#;
            my $uriFromString        = $+{refPart};
            my $startOfString        = $+{startOfline};
            my $pidFromString        = $+{pid};
            my $datastreamFromString = $+{datastream};
            my $timestampFromString  = $+{timestamp};
            my $endOfString          = $+{remaining};
            $datastreamFromString =~ s/\///g;
            $pidFromString        =~ s/\///g;
            my $pidForDir = $pidFromString;
            $pidForDir =~ s/:/_/g;
            my $stingOfDS = $startOfString
                . qq(REF="file://$tmpDirectory/$nicePID/)    #  needs file:/
                . $datastreamFromString
                . qq(" />$endOfString\n</foxml:datastreamVersion>\n</foxml:datastream>\n);
            push @foxml, $stingOfDS;
            my $curlCommand
                = qq(curl -s -u ${UserName}:${PassWord} \"${fedoraURI}/get/$PID/$datastreamFromString\" -o $tmpDirectory/$nicePID/$datastreamFromString);
            system($curlCommand);
        }
    }
    my $nameFoxml = ${nicePID} . "-foxml.xml";
    open my $foxmlOut, ">", "$directoryName/$nameFoxml"
        or die " unable to open file $nameFoxml\n";
    my $digitalObjectCloseString = "</foxml:digitalObject>\n";
    push @foxml, $digitalObjectCloseString;
    print $foxmlOut @foxml;
}
else {
    print "option not yet implemented\n";
}
my $tidyFile = "Error.tidy.txt";
unlink $tidyFile;
print "\n";
## == == == == == == == == == == == == == == == == == == == == == ##
sub xpathQuery {
    my @result;
    my ( $query, $xp1 ) = @_;
    my $nodeset = $xp1->find($query);
    foreach my $node ( $nodeset->get_nodelist ) {
        my $resultString = XML::XPath::XMLParser::as_string($node);
        chomp $resultString;
        push( @result, $resultString );
    }
    return @result;
}

sub useXpathQuery {
    my @result;
    my ( $objectType, $xp2 ) = @_;
    my $xPathQuery = q!//foxml:datastream[@ID="! . $objectType . q!"]!;
    print "$xPathQuery\n";
    my $nodeset = $xp2->find($xPathQuery);
    foreach my $node ( $nodeset->get_nodelist ) {
        my $resultString = XML::XPath::XMLParser::as_string($node);
        $resultString =~ s#VERSIONABLE="true"#VERSIONABLE="false"#g;
        $resultString =~ s#VERSIONABLE="TRUE"#VERSIONABLE="FALSE"#g;
        $resultString =~ s#>$#>\n#g;
        push( @result, $resultString );
    }
    return @result;
}

sub typeOfOption {
    my ( $commandLineSwitch, $authN, $uri ) = @_;
    my $type = "blank";
    # match a PID
    if ( $commandLineSwitch =~ m/:/ ) {    # matches a PID
        chomp $option;
        my $tidyCommand
            = qq(|tidy --wrap 0 --input-xml yes -f Error.tidy.txt );
        my $curlCommand
            = qq(curl -s $authN "$uri/objects/$commandLineSwitch/datastreams/RELS-EXT/content" $tidyCommand );
        my @curlOutput = qx($curlCommand);
        # collection object or Fedora object
        foreach my $line (@curlOutput) {
            chomp $line;
            if ( $line =~ m/collectionCModel/i ) {
                $type = "collectionPID";
            }
        }
        if ( $type eq "blank" ) {
            $type = "singleObject";
        }
    }
    else {
        # otherwise a file
        print "\a file, not anytype of PID\n";
        $type = "filename";
    }
    return $type;
}
