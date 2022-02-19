package SubsystemExtension::SequenceFactory;


use strict;
use warnings;
use Carp;
use Data::Dumper;
use integer;

1;


sub new {
	my ($class);

	my $self = {}; 

	bless $self, $class;

	return $self;


}


sub createSequences {

	carp "called abstract createSequences method from SequenceFactory\nUse Subclasses like COG or SEED\n";

}

