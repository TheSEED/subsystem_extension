package SubsystemExtension::ExtensionConfig;

use base ("Exporter");
use FIG_Config;


our @EXPORT=qw(DEBUG TEMPDIR BINDIR SGE_ROOT QSUB PSSMDB_DIR FASTADB_DIR USECLUSTER EXTENSIONDEPTH EXTENSIONEVAL MULTIPLEROLES);

my $tempdir;
# we want to use /home/seed/aeos if it exists, else we want to use the Tmp location
# put this in a BEGIN so it is calculated when we load the package.
BEGIN {
    $tempdir=$FIG_Config::temp."/aeos/";
    if (-e "/home/seed/aeos/") {$tempdir="/home/seed/aeos/"} # on UofC machines, the extension directories are all shared
}


use constant DEBUG => 0;
use constant TEMPDIR => $tempdir;
use constant BINDIR => $FIG_Config::bin;
use constant SGE_ROOT => "/vol/codine-6.0";
use constant QSUB => "/vol/codine-6.0/bin/sol-sparc/qsub";
use constant PSSMDB_DIR => 0;
use constant FASTADB_DIR => 0;
use constant USECLUSTER => 0;
use constant EXTENSIONDEPTH => 30;
use constant EXTENSIONEVAL  => 1.0e-10;
use constant MULTIPLEROLES => 0;

1;
