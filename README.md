Migration
=========

Scripts to migrate PIDs from Islandora6 to Islandora7


1.  Run migration scripts on a collection-by-collection basis.
  1. Script exports content from Fedora 3.4.2 as “archive” (due to large objects and XACML restrictions)
  1. Script builds new FOXML from the exported FOXML
  1. Keep PID, Handle, XACML, audit trail, MODS & DC (versioned)
  1. Leaves behind derivatives, RELS-INT
  1. Creates new RELS-EXT (for normalization and ingest)
  1. Renames primary content file DSID to OBJ (involves some filtering)
1. Script ingests new FOXML into new Fedora with Fedora client command-line utilities https://wiki.duraspace.org/display/FEDORA37/fedora-ingest
1. Derivatives are run in a separate step using another script
1. Reports and error logs are generated for the export/ingest step and the derivatives generation step

Migration Considerations

1. Both Fedoras are currently being used as production servers. 
1. Migration tasks should be run after-hours or on weekends to minimize impact to sites creating content in production.
1. codu is the largest site left to migrate, with 40,000+ objects.
1. We should migrate one namespace at a time. We can work with each site to freeze content in the old Fedora before we clone their namespace.
1. Scripts we have built or that we’re currently working on
  1.  Built
      1.  Migrate an entire collection (all objects have to be going to the same content model)
  1.  Built, needs debugging or extending
     1.  Migrate an object with many content files attached as a single, parent compound object (no files attached) – we then create a zip of all the datastreams and ingest them as new child objects with the parent MODS record repeated for each object
     1.  Script that can migrate a single PID or list of PIDs (not collection based)
  1.  Scripts we will need
      1.  Script that can create a new Fedora object by selecting one primary content file and ignoring another one (based on file extension)
      1.  Script that can migrate just the FOXML and descriptive metadata (no object attached)
      1.  Scripts that can migrate parent compound objects (many files of same type or many files of different types) to new compound objects and create and associate child objects (this is where most of the custom work will be for each site)
d. Scripts for migrating ETDs (figuring out which PDF is the thesis and which files are cover sheets, datasets, or supplementary materials) 

Notes:

1.  from the Fedora 3.4.2 server in the DU colo FoxML with the archive switch is exported.  Ample space is required to store the Fedora object with all the object's datastreams.  In this instance the newly generated FoxML file is stored on an NFS mounted space (a UW-IT SAN) before being ingested into Fedora 3.7.1  
