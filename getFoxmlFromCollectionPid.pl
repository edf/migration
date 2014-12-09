#!/usr/bin/perl
#                   use collection PID to migrate Fedora Objects  -ekf 2014-1106
use strict;
use warnings;
no warnings qw(uninitialized);
use LWP::Simple;
use URI::Escape;
use XML::XPath;
use File::Basename;

if ( $#ARGV != 0 ) {
    print "\n Usage is $0 <collection pid> \n\n";
    exit(8);
}

#TODO

my $collectionPid = $ARGV[0];
chomp $collectionPid;
my ( $nameSpace, $pidNumber ) = split( /:/, $collectionPid );
## local settings to configure
#       variables of fedora server, port, username, and password
my $ServerName    = "http://fedora.coalliance.org";
my $ServerPort    = "8080";
my $fedoraContext = "fedora";
my $fedoraURI =
  $ServerName . ":" . $ServerPort . "/" . $fedoraContext . "/objects";

my $UserName = "fedoraAdminBot";
my $PassWord = 'PASSWORD';

my $collectionMemberQuery =
    'select $object from <#ri>'
  . 'where ($object <fedora-rels-ext:isMemberOf> <info:fedora/'
  . $collectionPid . '>'
  . ' or $object <fedora-rels-ext:isMemberOfCollection> <info:fedora/'
  . $collectionPid . '> )'
  . 'minus ($object <fedora-model:hasModel> <info:fedora/islandora:collectionCModel>'
  . '   or $object <fedora-model:hasModel> <info:fedora/'
  . $nameSpace . ':'
  . $nameSpace
  . 'BasicCollection>)'
  . 'minus ($object <fedora-rels-ext:isMemberOfCollection> <info:fedora/islandora:ContentModelsCollection>'
  . '   or $object <fedora-rels-ext:isMemberOf> <info:fedora/islandora:ContentModelsCollection>)';

## <info:fedora/fedora-system:def/model#Active>
my $activeObjectQuery = $collectionMemberQuery;
$activeObjectQuery .= q!and $object <fedora-model:state> <info:fedora/fedora-system:def/model#Active> order by $object!;

## <info:fedora/fedora-system:def/model#Inactive>
my $inactiveObjectQuery = $collectionMemberQuery;
$inactiveObjectQuery .= q!and $object <fedora-model:state> <info:fedora/fedora-system:def/model#Inactive> order by $object!;

## <info:fedora/fedora-system:def/model#Deleted>
my $deletedObjectQuery = $collectionMemberQuery;
$deletedObjectQuery .= q!and $object <fedora-model:state> <info:fedora/fedora-system:def/model#Deleted> order by $object!;

my $formatOutput = "count";
my $activePidsCount = riSearch( $collectionPid, $activeObjectQuery, $formatOutput );
$formatOutput = "CSV";
my $pidStatus = "active";
my @activePidsRaw = riSearch( $collectionPid, $activeObjectQuery, $formatOutput );

print "collection $collectionPid has $activePidsCount active, ";
foreach my $line (@activePidsRaw) {
    getFoxml( $line, $collectionPid, $pidStatus );
}

$formatOutput = "count";
my $inactivePidsCount = riSearch( $collectionPid, $inactiveObjectQuery, $formatOutput );
my @inactivePidsRaw;
if ( $inactivePidsCount == 0 ) {
    print "$inactivePidsCount inactive, and ";
}
else {
    print "$inactivePidsCount inactive, and \n@inactivePidsRaw\n";
    $formatOutput = "CSV";
    @inactivePidsRaw = riSearch( $collectionPid, $inactiveObjectQuery, $formatOutput );
    my $pidStatus = "inactive";
    foreach my $line (@inactivePidsRaw) {
        getFoxml( $line, $collectionPid, $pidStatus );
    }
}

$formatOutput = "count";
my $deletedPidsCount = riSearch( $collectionPid, $deletedObjectQuery, $formatOutput );
my @deletedPidsRaw;
if ( $deletedPidsCount == 0 ) {
    print "$deletedPidsCount deleted PIDs\n";
}
else {
    print "$deletedPidsCount deleted PIDs\n@deletedPidsRaw\n";
    $formatOutput = "CSV";
    @deletedPidsRaw = riSearch( $collectionPid, $deletedObjectQuery, $formatOutput );
    my $pidStatus = "deleted";
    foreach my $line (@deletedPidsRaw) {
        getFoxml( $line, $collectionPid, $pidStatus );
    }
}

sub riSearch {
    my ( $collectionPid, $query, $resultFormat ) = @_;

    my $queryEncode = uri_escape($query);
    my $theQuery = qq(http://fedora.coalliance.org:8080/fedora/risearch?type=tuples&lang=itql&format=$resultFormat&dt=on&query=$queryEncode) ;    ## uses CSV output or count
    if ( $theQuery =~ /CSV/ ) {
        my @queryResult = get $theQuery;
        my @pids;
        while ( my $lineQ = <@queryResult)> ) {
            next if $lineQ =~ m#"object"#;
            next if $lineQ =~ m#^object#;
            next if $lineQ =~ m#^\)#;
            $lineQ =~ s#info:fedora/##g;
            push( @pids, $lineQ );
        }
        return @pids;
    }
    elsif ( $theQuery =~ /count/ ) {
        my $queryResult = get $theQuery;
        return $queryResult;
        ####TODO  the following needs to be updated
    }
    else { print "error:  unknown format - $theQuery\n"; }
}

sub getFoxml {
    my ( $PID, $collectionPid, $status ) = @_;

    my (
        $pid,             $collection,       $contentModel,
        $auditDatastream, $objectProperties, $contentLocation,
        @objText,         $modsDatastream,   $dcDatastream,
        $marcDatastream,  $dissXmlDatastream
    );
    my $UserName = 'fedoraAdminBot';
    my $PassWord = 'PASSWORD';
    my ( $nameSpace, $pidNumber ) = split( /:/, $PID );
#my $foxmlString =  qx(curl -s -u ${UserName}:${PassWord} "http://fedora.coalliance.org:8080/fedora/objects/$PID/export?context=migrate");
    my $foxmlString = qx(curl -s -u ${UserName}:${PassWord} "http://fedora.coalliance.org:8080/fedora/objects/$PID/export?context=archive");
    my $xp = XML::XPath->new( xml => $foxmlString );
    my $xPathQueryForVersion = q!//foxml:digitalObject/@VERSION!;
    my $nodesetVersion       = $xp->find($xPathQueryForVersion);
    foreach my $node ( $nodesetVersion->get_nodelist ) {
        my $resultString = XML::XPath::XMLParser::as_string($node);
        $resultString =~ s/^\s+//g;    #  strip white space before string
        $resultString =~ s/\s+$//g;    #  strip white space after string   #  print "$resultString\n";
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
    my $xPathQueryForDc = q!//foxml:datastream[@ID='DC']!;
    my $nodesetDc       = $xp->find($xPathQueryForDc);
    foreach my $node ( $nodesetDc->get_nodelist ) {
        my $resultString = XML::XPath::XMLParser::as_string($node);
        $dcDatastream = $resultString;
    }
    # get MARCxml datastream for cospl
       if ($nameSpace =~ /^co$/) {
            my $xPathQueryForMarc = q!//foxml:datastream[@ID='MARC']!;
            my $nodesetMarc       = $xp->find($xPathQueryForMarc);
            foreach my $node ( $nodesetMarc->get_nodelist ) {
                my $resultString = XML::XPath::XMLParser::as_string($node);
                $marcDatastream = $resultString;
            }
        }   # end get MARCxml datastream for cospl
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
    my $niceCollectionPid = $collectionPid;
    $niceCollectionPid =~ s/:/_/g;

    if ( $status =~ /inactive/ ) { $niceCollectionPid .= "-inactive"; }
    if ( $status =~ /deleted/ )  { $niceCollectionPid .= "-deleted"; }

    my $nameFoxml = ${nicePID} . "_foxml.xml";
    mkdir "$niceCollectionPid", 0775 unless -d "$niceCollectionPid";  # make directory unless it already exists
    open my $foxmlOut, ">", "./$niceCollectionPid/$nameFoxml" or die " unable to open file $nameFoxml\n";
    print $foxmlOut qq(<foxml:digitalObject VERSION="1.1" PID="$pid" xmlns:foxml="info:fedora/fedora-system:def/foxml#" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="info:fedora/fedora-system:def/foxml# http://www.fedora.info/definitions/1/0/foxml1-1.xsd">\n);
    print $foxmlOut "$objectProperties\n";
    print $foxmlOut "$auditDatastream\n";
    print $foxmlOut "$marcDatastream\n";
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
    # content model based on filename extention    using $relsIntDatastream
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
    else { print "\nERROR: undefined file extension\n"; exit(8); }

    print $foxmlOut <<RELSEXT2;
            </rdf:Description>
        </rdf:RDF>
      </foxml:xmlContent>
    </foxml:datastreamVersion>  
</foxml:datastream>
RELSEXT2
    foreach (@objText) {
        chomp;
        if (m/ID="$relsIntDatastream"/) {
            s#ID="$relsIntDatastream"#ID="OBJ"#g;
            s#CONTROL_GROUP="X"#CONTROL_GROUP="M"#g;
            s#LABEL="(.+?)"#LABEL="$relsIntDatastream" CREATED="#g;
        }
        if (m#ID="${relsIntDatastream}.#) {
            s#LABEL="(.+?)"#LABEL="$relsIntDatastream" CREATED="#g;
        }
        print $foxmlOut $_;
        print $foxmlOut "\n";
    }
    print $foxmlOut "</foxml:digitalObject>\n";
}
my $collectionPidDirectory = $collectionPid;
$collectionPidDirectory =~ s/:/_/g;
my @ingestCommandOutput = qx( /opt/fedora/client/bin/fedora-ingest.sh dir ./$collectionPidDirectory info:fedora/fedora-system:FOXML-1.1 localhost:8080 adrbot 1adrAdm1n http "" ;date);
foreach my $line (@ingestCommandOutput) {
    $line =~ s/\R/\n/g;
    if    ( $line =~ /SUCCESS/ ) { print " $line \n"; }
    elsif ( $line =~ /ERROR/ )   { print " $line \n"; }
    elsif ( $line =~ /WARNING/ ) { print " $line \n"; }
    elsif ( $line =~ m/A detailed log is at / ) {
        chomp $line;
        #print "preprocessed--$line --preprocessed \n";
        print "$line\n";
        #$line = s#A detailed log is at ##g;
        my $ingestLogFile = basename($line);
        #print "ingest--$line \n";
    }
    else { #print "line--$line--line\n"; }
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
