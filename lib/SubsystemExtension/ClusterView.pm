package SubsystemExtension::ClusterView;


use strict;
use warnings;
use Carp;


use constant GENEWIDTH => 32;
use constant GENEHEIGHT => 12;
use constant SPACING => 5;


sub new {

    my ($class, $cluster) = @_;

    my $self;
    $self->{cluster} = $cluster;
	
    bless $self, $class;

    return $self;

}


sub update {
	my ($self, $cluster) = @_;

	$self->{cluster} = $cluster if (ref $cluster && $cluster->isa("SubsystemExtension::Cluster"));

}

sub output {

	my ($self, $params) = @_;
	carp "abstract output for a cluster\n"; 
}





1;
