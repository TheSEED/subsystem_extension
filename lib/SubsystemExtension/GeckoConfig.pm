package SubsystemExtension::GeckoConfig;

use base ("Exporter");
use FIG_Config;

our @EXPORT=qw(DEBUG TEMPDIR BINDIR SGE_ROOT QSUB);

use constant DEBUG => 0;
use constant TEMPDIR => $FIG_Config::temp;
use constant BINDIR => $FIG_Config::bin;
use constant SGE_ROOT => "/vol/codine-6.0";
use constant QSUB => "/vol/codine-6.0/bin/sol-sparc/qsub";

1;
