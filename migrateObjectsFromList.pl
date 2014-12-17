#!/usr/bin/perl
#                   migrate Fedora Objects from a file containing PIDs -ekf 2014-1211
use strict;
use warnings;
no warnings qw(uninitialized);
use LWP::Simple;
use URI::Escape;
use XML::XPath;
use File::Basename;
use POSIX qw(strftime);

if ( $#ARGV != 0 ) {
    print "\n Usage is $0 <text file with pids> \n\n";
    exit(8);
}
my $fileName = $ARGV[0];
chomp $fileName;

open( my $fh, "<", $fileName ) or die " cannot open file $! ";
my (
    $ServerName, $ServerPort,  $fedoraContext, $UserName,
    $PassWord,   $newUserName, $newPassWord
);    # local settings
my $configFile = "settings.config";
open my $configFH, "<", "$configFile" or die "\n\n Program $0 stopping, couldn't open the configuration file '$configFile' $!.\n\n";
my $config = join "", <$configFH>;    # print "\n$config\n";
close $configFH;
eval $config;
die "Couldn't interpret the configuration file ($configFile) that was given.\nError details follow: $@\n" if $@;
my $fedoraURI =
    $ServerName . ":"
  . $ServerPort . "/"
  . $fedoraContext ; #my $fedoraURI = $ServerName . ":" . $ServerPort . "/" . $fedoraContext . "/objects";

my $timeStamp = POSIX::strftime( "%Y-%m%d-%H%M-%S", localtime );
my $directoryName = "$fileName-" . $timeStamp;
print "$directoryName\n";
my $pidCounter = 0;
my $errorCounter = 0;

while ( my $pid = <$fh> ) {
    chomp $pid;
    my ( $nameSpace, $pidNumber ) = split( /:/, $pid );
    my $pidStatus = "active";
    eval {getFoxml( $pid, $directoryName, $pidStatus, $UserName, $PassWord, $fedoraURI ); };
    $pidCounter++;
    if ( $@ ) {
          my $timeStampWarn = POSIX::strftime( "%Y-%m%d-%H%M-%S", localtime );
          warn qq($timeStampWarn ERROR: $pid has an error\n$@\n);
          $errorCounter++;
        }

}    # end of file reading loop

sub getFoxml {
    my ( $PID, $directoryName, $status, $UserName, $PassWord, $fedoraURI ) = @_;
    my (
        $pid,             $collection,       $contentModel,
        $auditDatastream, $objectProperties, $contentLocation,
        @objText,         $modsDatastream,   $dcDatastream,
        $marcDatastream,  $policyDatastream, $dissXmlDatastream
    );
    my ( $nameSpace, $pidNumber ) = split( /:/, $PID );

#    my $foxmlString = qx(curl -s -u ${UserName}:${PassWord} "${fedoraURI}/objects/$PID/export?context=migrate");
    my $foxmlString = qx(curl -s -u ${UserName}:${PassWord} "${fedoraURI}/objects/$PID/export?context=archive");
    my $xp                   = XML::XPath->new( xml => $foxmlString );
    my $xPathQueryForVersion = q!//foxml:digitalObject/@VERSION!;
    my $nodesetVersion       = $xp->find($xPathQueryForVersion);
    foreach my $node ( $nodesetVersion->get_nodelist ) {
        my $resultString = XML::XPath::XMLParser::as_string($node);
        $resultString =~ s/^\s+//g;    #  strip white space before string
        $resultString =~ s/\s+$//g ;   #  strip white space after string
    }

    my $xPathQueryForDigitalObjectPID = q!//foxml:digitalObject/@PID!;
    my $nodesetDigitalObjectPID = $xp->find($xPathQueryForDigitalObjectPID);
    foreach my $node ( $nodesetDigitalObjectPID->get_nodelist ) {
        my $resultString = XML::XPath::XMLParser::as_string($node);
        $resultString =~ s/^\s+//g;    #  strip white space before string
        $resultString =~ s/\s+$//g;    #  strip white space after string
    }

    my $xPathQueryForPidLower = q!//foxml:datastream[@ID="RELS-EXT"]/foxml:datastreamVersion[last()]/foxml:xmlContent/rdf:RDF/rdf:description/@rdf:about!;
    my $nodesetPidLower = $xp->find($xPathQueryForPidLower);
    foreach my $node ( $nodesetPidLower->get_nodelist ) {
        my $resultString = XML::XPath::XMLParser::as_string($node);
        $resultString =~ s/^\s+//g;    #  strip white space before string
        $resultString =~ s/\s+$//g;    #  strip white space after string
        ( my $beginString, $pid ) = split( /\//, $resultString );
        $pid =~ s#"##g;
    }
    my $xPathQueryForPid = q!//foxml:datastream[@ID="RELS-EXT"]/foxml:datastreamVersion[last()]/foxml:xmlContent/rdf:RDF/rdf:Description/@rdf:about!;
    my $nodesetPid = $xp->find($xPathQueryForPid);
    foreach my $node ( $nodesetPid->get_nodelist ) {
        my $resultString = XML::XPath::XMLParser::as_string($node);
        $resultString =~ s/^\s+//g;    #  strip white space before string
        $resultString =~ s/\s+$//g;    #  strip white space after string
        ( my $beginString, $pid ) = split( /\//, $resultString );
        $pid =~ s#"##g;
    }

    my $xPathQueryForCollectionLower = q!//foxml:datastream[@ID="RELS-EXT"]/foxml:datastreamVersion[last()]/foxml:xmlContent/rdf:RDF/rdf:description/fedora:isMemberOfCollection/@rdf:resource!;
    my $nodesetCollectionLower = $xp->find($xPathQueryForCollectionLower);
    foreach my $node ( $nodesetCollectionLower->get_nodelist ) {
        my $resultString = XML::XPath::XMLParser::as_string($node);
        my ( $beginString, $endString ) = split( /\//, $resultString );
        $endString =~ s#"##g;
        if ( $endString ne "" ) {
            $collection = $endString;
        }
    }
    my $xPathQueryForCollection = q!//foxml:datastream[@ID="RELS-EXT"]/foxml:datastreamVersion[last()]/foxml:xmlContent/rdf:RDF/rdf:Description/fedora:isMemberOfCollection/@rdf:resource!;
    my $nodesetCollection = $xp->find($xPathQueryForCollection);
    foreach my $node ( $nodesetCollection->get_nodelist ) {
        my $resultString = XML::XPath::XMLParser::as_string($node);
        my ( $beginString, $endString ) = split( /\//, $resultString );
        $endString =~ s#"##g;
        if ( $endString ne "" ) {
            $collection = $endString;
        }
    }

# also query for isMemberOf if necessary # print "without namespace collection - ";
    my $xPathQueryForOldStyleCollectionLower = q!//foxml:datastream[@ID="RELS-EXT"]/foxml:datastreamVersion[last()]/foxml:xmlContent/rdf:RDF/rdf:description/isMemberOf/@rdf:resource!;
    my $nodesetOldStyleCollectionLower =
      $xp->find($xPathQueryForOldStyleCollectionLower);
    foreach my $node ( $nodesetOldStyleCollectionLower->get_nodelist ) {
        my $resultString = XML::XPath::XMLParser::as_string($node);
        my ( $beginString, $endString ) = split( /\//, $resultString );
        $endString =~ s#"##g;
        if ( $endString ne "" ) {
            $collection = $endString;
        }
    }
    my $xPathQueryForOldStyleCollectionRel = q!//foxml:datastream[@ID="RELS-EXT"]/foxml:datastreamVersion[last()]/foxml:xmlContent/rdf:RDF/rdf:Description/rel:isMemberOf/@rdf:resource!;
    my $nodesetOldStyleCollectionRel = $xp->find($xPathQueryForOldStyleCollectionRel);
    foreach my $node ( $nodesetOldStyleCollectionRel->get_nodelist ) {
        my $resultString = XML::XPath::XMLParser::as_string($node);
        my ( $beginString, $endString ) = split( /\//, $resultString );
        $endString =~ s#"##g;
        if ( $endString ne "" ) {
            $collection = $endString;
        }
    }
    my $xPathQueryForOldStyleCollectionRelLowerCase = q!//foxml:datastream[@ID="RELS-EXT"]/foxml:datastreamVersion[last()]/foxml:xmlContent/rdf:RDF/rdf:description/rel:isMemberOf/@rdf:resource!;
    my $nodesetOldStyleCollectionRelLowerCase = $xp->find($xPathQueryForOldStyleCollectionRelLowerCase);
    foreach my $node ( $nodesetOldStyleCollectionRelLowerCase->get_nodelist ) {
        my $resultString = XML::XPath::XMLParser::as_string($node);
        my ( $beginString, $endString ) = split( /\//, $resultString );
        $endString =~ s#"##g;
        if ( $endString ne "" ) {
            $collection = $endString;
        }
    }
    my $xPathQueryForOldStyleCollection = q!//foxml:datastream[@ID="RELS-EXT"]/foxml:datastreamVersion[last()]/foxml:xmlContent/rdf:RDF/rdf:Description/isMemberOf/@rdf:resource!;
    my $nodesetOldStyleCollection = $xp->find($xPathQueryForOldStyleCollection);
    foreach my $node ( $nodesetOldStyleCollection->get_nodelist ) {
        my $resultString = XML::XPath::XMLParser::as_string($node);
        my ( $beginString, $endString ) = split( /\//, $resultString );
        $endString =~ s#"##g;
        if ( $endString ne "" ) {
            $collection = $endString;
        }
    }

    # also query for hasModel if necessary
    my $xPathQueryForOldStyleContentModel = q!//foxml:datastream[@ID="RELS-EXT"]/foxml:datastreamVersion[last()]/foxml:xmlContent/rdf:RDF/rdf:Description/hasModel/@rdf:resource!;
    my $nodesetOldStyleContentModel =
      $xp->find($xPathQueryForOldStyleContentModel);
    foreach my $node ( $nodesetOldStyleContentModel->get_nodelist ) {
        my $resultString = XML::XPath::XMLParser::as_string($node);
        my ( $beginString, $endString ) = split( /\//, $resultString );
        $endString =~ s#"##g;
        if ( $endString ne "" ) {
            $contentModel = $endString;
        }
    }
    my $xPathQueryForContentModelLower = q!//foxml:datastream[@ID="RELS-EXT"]/foxml:datastreamVersion[last()]/foxml:xmlContent/rdf:RDF/rdf:description/fedora-model:hasModel/@rdf:resource!;
    my $nodesetContentModelLower = $xp->find($xPathQueryForContentModelLower);
    foreach my $node ( $nodesetContentModelLower->get_nodelist ) {
        my $resultString = XML::XPath::XMLParser::as_string($node);
        my ( $beginString, $endString ) = split( /\//, $resultString );
        $endString =~ s#"##g;
        if ( $endString ne "" ) {
            $contentModel = $endString;
        }
    }
    my $xPathQueryForContentModel = q!//foxml:datastream[@ID="RELS-EXT"]/foxml:datastreamVersion[last()]/foxml:xmlContent/rdf:RDF/rdf:Description/fedora-model:hasModel/@rdf:resource!;
    my $nodesetContentModel = $xp->find($xPathQueryForContentModel);
    foreach my $node ( $nodesetContentModel->get_nodelist ) {
        my $resultString = XML::XPath::XMLParser::as_string($node);
        my ( $beginString, $endString ) = split( /\//, $resultString );
        $endString =~ s#"##g;
        if ( $endString ne "" ) {
            $contentModel = $endString;
        }
    }
    my $xPathQueryForAudit = q!//foxml:datastream[@ID='AUDIT']!;
    my $nodesetAudit       = $xp->find($xPathQueryForAudit);
    foreach my $node ( $nodesetAudit->get_nodelist ) {
        my $resultString = XML::XPath::XMLParser::as_string($node);
        $auditDatastream = $resultString;
    }
    my $xPathQueryForPolicy = q!//foxml:datastream[@ID='POLICY']!;
    my $nodesetPolicy       = $xp->find($xPathQueryForPolicy);
    foreach my $node ( $nodesetPolicy->get_nodelist ) {
        my $resultString = XML::XPath::XMLParser::as_string($node);
        $policyDatastream = $resultString;
    }
    my $xPathQueryForDc = q!//foxml:datastream[@ID='DC']!;
    my $nodesetDc       = $xp->find($xPathQueryForDc);
    foreach my $node ( $nodesetDc->get_nodelist ) {
        my $resultString = XML::XPath::XMLParser::as_string($node);
        $dcDatastream = $resultString;
    }

    # get MARCxml datastream for cospl
    if ( $nameSpace =~ /^co$/ ) {
        my $xPathQueryForMarc = q!//foxml:datastream[@ID='MARC']!;
        my $nodesetMarc       = $xp->find($xPathQueryForMarc);
        foreach my $node ( $nodesetMarc->get_nodelist ) {
            my $resultString = XML::XPath::XMLParser::as_string($node);
            $marcDatastream = $resultString;
        }
    }    # end get MARCxml datastream for cospl

    my $xPathQueryForMODS = q!//foxml:datastream[@ID='MODS']!;
    my $nodesetMODS       = $xp->find($xPathQueryForMODS);
    foreach my $node ( $nodesetMODS->get_nodelist ) {
        my $resultString = XML::XPath::XMLParser::as_string($node);
        $modsDatastream = $resultString;
    }
    my $xPathQueryForDISSXML = q!//foxml:datastream[@ID='DISS_XML']!;
    my $nodesetDISSXML       = $xp->find($xPathQueryForDISSXML);
    foreach my $node ( $nodesetDISSXML->get_nodelist ) {
        my $resultString = XML::XPath::XMLParser::as_string($node);
        $dissXmlDatastream = $resultString;
    }
    my $xPathQueryForObjectProperties = q!//foxml:objectProperties!;
    my $nodesetObjectProperties = $xp->find($xPathQueryForObjectProperties);
    foreach my $node ( $nodesetObjectProperties->get_nodelist ) {
        my $resultString = XML::XPath::XMLParser::as_string($node);
        $objectProperties = $resultString;
    }

# search in last RELS-INT for rdf:Description that is not a TN then query for rdf:Description rdf:about for master OBJ
    my $xPathQueryForRelsIntDatastreams = q!//foxml:datastream[@ID="RELS-INT"]/foxml:datastreamVersion[last()]/foxml:xmlContent/rdf:RDF/rdf:Description/@rdf:about!;
    my $nodesetRelsIntDatastreams = $xp->find($xPathQueryForRelsIntDatastreams);
    my $relsIntDatastream;
    foreach my $node ( $nodesetRelsIntDatastreams->get_nodelist ) {
        my $resultString = XML::XPath::XMLParser::as_string($node);
        next if $resultString =~ m/-access.mp3"$/;
        next if $resultString =~ m/DISS_XML"$/;
        next if $resultString =~ m/.swf"$/;
        next if $resultString =~ m/.xml"$/;
        next if $resultString =~ m/internet-tn.jpg"$/;
        next if $resultString =~ m/TN"$/;
        next if $resultString =~ m/.jp2"$/;
        next if $resultString =~ m/lg.jpg"$/;
        next if $resultString =~ m/sm.jpg"$/;

        my ( $beginString, $middleString, $endString ) = split( /\//, $resultString );
        $endString =~ s#"##g;
        $relsIntDatastream = $endString;
        chomp $relsIntDatastream;
        my $xPathQueryForContentLocation = q!//foxml:datastream[@ID="!
          . $relsIntDatastream
          . q!"]/foxml:datastreamVersion[last()]/foxml:contentLocation/@REF!;
        my $nodesetContentLocation = $xp->find($xPathQueryForContentLocation);
        foreach my $node ( $nodesetContentLocation->get_nodelist ) {
            my $resultLocation = XML::XPath::XMLParser::as_string($node);
            $contentLocation = $resultLocation;
        }
        my $xPathQueryForDatastream = q!//foxml:datastream[@ID="! . $relsIntDatastream . q!"]!;
        my $nodesetDatastream = $xp->find($xPathQueryForDatastream);
        foreach my $node ( $nodesetDatastream->get_nodelist ) {
            my $resultLocation1 = XML::XPath::XMLParser::as_string($node);
            push( @objText, $resultLocation1 );
        }
    }
########################################################################################################################################
    my $nicePID = $PID;
    $nicePID =~ s/:/_/g;
    my $collectionPid = $collection;

    my $nameFoxml = ${nicePID} . "_foxml.xml";
    mkdir "$directoryName", 0775 unless -d "$directoryName";    # make directory unless it already exists
    open my $foxmlOut, ">", "./$directoryName/$nameFoxml" or die " unable to open file $nameFoxml\n";
    print $foxmlOut qq(<foxml:digitalObject VERSION="1.1" PID="$pid" xmlns:foxml="info:fedora/fedora-system:def/foxml#" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="info:fedora/fedora-system:def/foxml# http://www.fedora.info/definitions/1/0/foxml1-1.xsd">\n);
    print $foxmlOut "$objectProperties\n";
    print $foxmlOut "$marcDatastream\n";
    print $foxmlOut "$auditDatastream\n";
    print $foxmlOut "$policyDatastream\n";
    open( my $fh, "<", \$modsDatastream ) or die " cannot open file $! ";   # in memory file handler from a variable

    while (<$fh>) {
        if (m#CONTROL_GROUP="X"#) {
            s#CONTROL_GROUP="X"#CONTROL_GROUP="M"#g;
        }
        print $foxmlOut $_;             #"$modsDatastream\n";
    }
    open( my $fhDc, "<", \$dcDatastream ) or die " cannot open file $! ";   # in memory file handler from a variable
    while (<$fhDc>) {
        if (m#CONTROL_GROUP="X"#) {
            s#CONTROL_GROUP="X"#CONTROL_GROUP="M"#g;
        }
        print $foxmlOut $_;             #"$dcDatastream\n";
    }

    if ( defined $dissXmlDatastream and length $dissXmlDatastream ) {

        open( my $fhDissXml, "<", \$dissXmlDatastream ) or die " cannot open file $! ";      # in memory file handler from a variable
        while (<$fhDissXml>) {
            if (m#CONTROL_GROUP="X"#) {
                s#CONTROL_GROUP="X"#CONTROL_GROUP="M"#g;
            }
            print $foxmlOut $_;         #"$dissXmlDatastream\n";
        }
    }

    print $foxmlOut "\n";
    print $foxmlOut <<RELSEXT;
<foxml:datastream ID="RELS-EXT" STATE="A" CONTROL_GROUP="X" VERSIONABLE="true">
    <foxml:datastreamVersion ID="RELS-EXT.0" LABEL="RDF Statements about this Object" MIMETYPE="application/rdf+xml">
       <foxml:xmlContent>
        <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
          xmlns:fedora="info:fedora/fedora-system:def/relations-external#"
          xmlns:fedora-model="info:fedora/fedora-system:def/model#"
          xmlns:islandora="http://islandora.ca/ontology/relsext#">
RELSEXT
    print $foxmlOut qq(            <rdf:Description rdf:about="info:fedora/$pid">\n);
    print $foxmlOut qq(                <fedora:isMemberOfCollection rdf:resource="info:fedora/$collectionPid"/>\n);
    # content model based on filename extention    using $relsIntDatastream          # print "\ndatastream== $relsIntDatastream\n";
    my ( $filename, $dir, $ext ) = fileparse( $relsIntDatastream, qr/\.[^.]*/ ) ;    # split argument from commandline into components
    if ( $ext =~ /pdf/ ) {
        print $foxmlOut qq(                <fedora-model:hasModel rdf:resource="info:fedora/islandora:sp_pdf"/>\n);
    }
    elsif ( $ext =~ /wav/ ) {
        print $foxmlOut qq(                <fedora-model:hasModel rdf:resource="info:fedora/islandora:sp-audioCModel"/>\n);
    }
    elsif ( $ext =~ /tif/ ) {
        print $foxmlOut qq(                <fedora-model:hasModel rdf:resource="info:fedora/islandora:sp_large_image_cmodel"/>\n);
    }
    else { 
            my $timeStampError = POSIX::strftime( "%Y-%m%d-%H%M-%S", localtime );
            print "\n$timeStampError ERROR: $pid has an undefined file extension $ext\n\n"; 
            next;  
            }

    print $foxmlOut <<RELSEXT2;
            </rdf:Description>
        </rdf:RDF>
      </foxml:xmlContent>
    </foxml:datastreamVersion>
</foxml:datastream>
RELSEXT2
    foreach (@objText) {
        chomp;
        if ( $nameSpace =~ /^co$/ ) {
            if (m/ID="$relsIntDatastream"/) {
                s#ID="$relsIntDatastream"#ID="OBJ"#g;
                s#CONTROL_GROUP="X"#CONTROL_GROUP="M"#g;
                s#LABEL="(.+?)"#LABEL="$relsIntDatastream" CREATED="#g;
            }
            else {
                s#ID="${relsIntDatastream}.#ID="OBJ.#g;
                s#LABEL="(.+?)"#LABEL="$relsIntDatastream" CREATED="#g;
            }
        }
        else {
            if (m/ID="$relsIntDatastream"/) {
                s#ID="$relsIntDatastream"#ID="OBJ"#g;
                s#CONTROL_GROUP="X"#CONTROL_GROUP="M"#g;
                s#LABEL="(.+?)"#LABEL="$relsIntDatastream" #g;
            }
        }
        print $foxmlOut $_;
        print $foxmlOut "\n";
    }
    print $foxmlOut "</foxml:digitalObject>\n";
}

if ( $pidCounter > $errorCounter ) {

my $timeStampIngest = POSIX::strftime( "%Y-%m%d-%H%M-%S", localtime );
print "\nStarting fedora-ingest on $fileName at $timeStampIngest with $errorCounter errors of $pidCounter PIDs\n";
my @ingestCommandOutput = qx( /opt/fedora/client/bin/fedora-ingest.sh dir ./$directoryName info:fedora/fedora-system:FOXML-1.1 localhost:8080 $newUserName $newPassWord http "" ;date);

foreach my $line (@ingestCommandOutput) {
    $line =~ s/\R/\n/g;
    if    ( $line =~ /SUCCESS/ ) { print " $line \n"; }
    elsif ( $line =~ /ERROR/ )   { print " $line \n"; }
    elsif ( $line =~ /WARNING/ ) { print " $line \n"; }
    elsif ( $line =~ m/A detailed log is at / ) {
        chomp $line;
        print "$fileName-$line\n";
        my $ingestLogFile = basename($line);
    }
    else { #   print "line--$line--line\n";
    }
}

} else {
       print "No PIDs to process\n";
}


__DATA__
from s:\Project\Islandora 7\IslandoraContentModels.csv
@name,@pid,short name
Audio ,islandora:sp-audioCModel,audio
Basic Image,islandora:sp_basic_image,imgBasic
Book Page,islandora:pageCModel,pageBook
Book,islandora:bookCModel,book
Compound Object,islandora:compoundCModel,compound
Document,islandora:sp_document,document
Large Image,islandora:sp_large_image_cmodel,imgLarge
Newspaper,islandora:newspaperCModel,news
Newspaper Issue,islandora:newspaperIssueCModel,newsIssue
Newspaper Page,islandora:newspaperPageCModel,newsPage
PDF,islandora:sp_pdf,pdf
Video,islandora:sp_videoCModel,video

