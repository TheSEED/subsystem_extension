package SubsystemExtension::SubsystemCandidateFactory::MultiSEED;


use strict;
use warnings;
use Carp;
use SubsystemExtension::SubsystemCandidate;
use SubsystemExtension::RoleCandidate;
use SubsystemExtension::RoleCandidateFactory::MultiSEED;
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

    
    
    my $role_candidates_complete = {};
    foreach my $role ($self->sortRolesByRelevance($self->{fig}, $self->subsystem())) {
	
	
	my $roleFactory = SubsystemExtension::RoleCandidateFactory::MultiSEED->new($role, $self->subsystem(), $missing_genomes[0], $self->{evalue_cutoff});
	$role_candidates_complete->{$role} = $roleFactory->generate(\@missing_genomes);
	
    }
	
    foreach my $genome (@missing_genomes) {
	
	
	my $role_candidates = {};
	

	# fetch the candidates relevant for this genome from the complete
	# set of role candidates
	foreach my $role (keys %$role_candidates_complete) {
	    $role_candidates->{$role} = $role_candidates_complete->{$role}->{$genome};
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




