package SubsystemExtension::SubsystemCandidateFactory::SEED;


use strict;
use warnings;
use Carp;
use SubsystemExtension::SubsystemCandidate;
use SubsystemExtension::RoleCandidate;
use SubsystemExtension::RoleCandidateFactory::SEED;
use base qw(SubsystemExtension::SubsystemCandidateFactory);
use FIG;
use Subsystem;
use constant DEBUG => 0;
no warnings qw(redefine);

1;

sub generate {

    my ($self, $genomes2add) = @_;

    # fuer jedes gen ergibt sich eine score die sich 
    # aus der similarity der edist(assigned_function, role) und
    # der summe von functional coupling data mit anderen genen des subsystems
    # check for naming of the genes
    # check for neighboring information

    $self->{fig} = new FIG;
    
   
    my @missing_genomes;
    if ((ref $genomes2add eq "ARRAY") && (scalar @$genomes2add > 0)) {
	print STDERR join ", ", @$genomes2add, " will be extended\n" if (DEBUG); 
	@missing_genomes = @$genomes2add;
    } else {
	my %in = map { $_ => 1 } $self->subsystem()->get_genomes;
	print STDERR "getting missing genomes for subsystem\n" if (DEBUG); 
	@missing_genomes = grep { ! $in{$_} } grep { $_ !~ /^99999/ } $self->{fig}->genomes("complete");
    }


    my $subsystem_candidates =  {};

    foreach my $genome (@missing_genomes) {
	print STDERR "Genome: $genome\n" if (DEBUG);
	my $role_candidates = {};
	foreach my $role ($self->sortRolesByRelevance($self->{fig}, $self->subsystem())) {
	
	    print STDERR "\tRole: $role\n" if (DEBUG);
	    my $roleFactory = SubsystemExtension::RoleCandidateFactory::SEED->new($role, $self->subsystem(), $genome, $self->{evalue_cutoff}, $self->{depth});
	    $role_candidates->{$role} = $roleFactory->generate();
	    
	}
	my $subsystem_candidate = SubsystemExtension::SubsystemCandidate->new($self->subsystem(), $genome, $role_candidates);
	$subsystem_candidate->_detectRoleCandidateClusters();
	$subsystem_candidates->{$genome} = $subsystem_candidate;

    }


    if (wantarray) {
	return values %$subsystem_candidates;
    } else {
	return $subsystem_candidates;
    }
    	
}


sub fig {

    my ($self, $value) = @_;

    return $self->{fig} if (scalar(@_) == 1);
    $self->{fig} = $value;
}




