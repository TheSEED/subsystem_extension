package SubsystemExtension::SubsystemCandidateFactory::GENDB;


use strict;
use warnings;
use Carp;
use SubsystemExtension::SubsystemCandidate::GENDB;
use SubsystemExtension::RoleCandidate;
use SubsystemExtension::RoleCandidateFactory::GENDB;
use base qw(SubsystemExtension::SubsystemCandidateFactory);
use GPMS::Application_Frame::GENDB;


use Subsystem;
use constant DEBUG => 1;

1;

sub new {

    my ($class, $subsystem, $user, $tool) = @_;
    
    my $self = $class->SUPER::new($subsystem, $user);
    
    $self->{tool} = $tool;
    $self->{gendb_master} = $tool->_master();


    return bless $self, $class;
}


sub generate {

    my ($self, $contigs2add) = @_;

    # fuer jedes gen ergibt sich eine score die sich 
    # aus der similarity der edist(assigned_function, role) und
    # der summe von functional coupling data mit anderen genen des subsystems
    # get the BBHS as ross did 
    # check for naming of the genes
    # check for neighboring information

    my $master =  $self->gendb_master();

    my @missing_genomes;
    if ((ref $contigs2add eq "ARRAY") && (scalar @$contigs2add > 0)) {
		print STDERR join ", ", @$contigs2add, " will be extended\n" if (DEBUG); 
		@missing_genomes = @$contigs2add;
		
	} else {
		print STDERR "getting missing genomes for subsystem\n" if (DEBUG); 
		@missing_genomes = @{$self->gendb_master->Region->Source->Contig->fetchall()};
	}


    my $subsystem_candidates =  {};

    foreach my $genome (@missing_genomes) {
	print STDERR "Genome: ".$genome->name()."\n" if (DEBUG);
	my $role_candidates = {};
	foreach my $role ($self->sortRolesByRelevance($self->{fig}, $self->subsystem())) {
	    
	    print STDERR "\tRole: $role\n" if (DEBUG);
	    my $roleFactory = SubsystemExtension::RoleCandidateFactory::GENDB->new($role, $self->subsystem(), $self->{tool}, $genome);
	    $roleFactory->gendb_master($self->gendb_master());
	    $role_candidates->{$role} = $roleFactory->generate();
	    
	}
	print STDERR "creating SubsystemCandidate!\n";

	my $subsystem_candidate = SubsystemExtension::SubsystemCandidate::GENDB->new($self->subsystem(), $genome, $role_candidates);

	print STDERR "Subsystem candidate $subsystem_candidate\n" ;
	$subsystem_candidate->_detectRoleCandidateClusters();
	$subsystem_candidates->{$genome->name()} = $subsystem_candidate;
	
    }
    

    if (wantarray) {
	return values %$subsystem_candidates;
    } else {
	return $subsystem_candidates;
    }
    	
}


sub gendb_master {

    my ($self, $value) = @_;

    return $self->{gendb_master} if (scalar(@_) == 1);
    $self->{gendb_master} = $value;
}




