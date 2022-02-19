package SubsystemExtension::SubsystemCandidateFactory;



use strict;
use warnings;
use Carp;
use FIG;
use Subsystem;
use SubsystemExtension::ExtensionConfig qw (EXTENSIONEVAL EXTENSIONDEPTH);


1;

sub new {

    my ($class, $subsystem,  $user, $evalue_cutoff, $depth) = @_;

    
    my $self = {};
    
    $self->{fig}  = FIG->new();
    $self->{subsystem} = ref $subsystem ? $subsystem : $self->{fig}->get_subsystem($subsystem);
    $self->{user} = $user ? $user : 'master';
    $self->{depth} = $depth ? $depth : EXTENSIONDEPTH;
    $self->{evalue_cutoff} = $evalue_cutoff ? $evalue_cutoff : EXTENSIONEVAL;

    return bless $self, $class;

}


sub generate {
    croak "called abstract generate method for SubsystemCandidateFactory";
}


# get/set method
sub subsystem {
    my ($self, $value) = @_;

    return $self->{subsystem} if (scalar(@_) == 1);
    $self->{subsystem} = $value;

}

sub user {
    my ($self, $value) = @_;

    return $self->{user} if (scalar(@_) == 1);
    $self->{user} = $value;


}

sub sortRolesByRelevance {

    my ($self) = @_;	
    
    # only functional variants are taken into account, 
    # int = number of variants this role is in, frac = fraction of occurence/#functional variants 

    my @active_genomes;
    
    foreach my $genome ($self->subsystem()->get_genomes) {
	push @active_genomes , $genome if ($self->subsystem()->get_variant_code($self->subsystem()->get_genome_index($genome)) > 0); 
	
    }

    if (scalar @active_genomes >= 0) {
	my $relevant_role;
	my $relevance = {};
	my $occurence = {};

	foreach my $role ($self->subsystem->get_roles()) {
	    $relevance->{$role} = 0;
	    $occurence->{$role} = 0;
	    my %variants;
	    foreach my $genome ( @active_genomes  ) {
		$occurence->{$role}++ if ($self->subsystem->get_pegs_from_cell($genome, $role) > 0);
		unless ($variants{$self->subsystem()->get_variant_code_for_genome($genome)}) {
		    $variants{$self->subsystem()->get_variant_code_for_genome($genome)} = 1;
		    $relevance->{$role}++;
		}
	    }

	    
	    my $frac = 0;

	    if ( $occurence->{$role} > 0) {
		$frac =  $#active_genomes / $occurence->{$role};
	    }

	    $relevance->{$role} += $frac;
	    
	}
	return sort {$relevance->{$b} cmp $relevance->{$a}} keys %$relevance;
	
    } else {
	return $self->subsystem->get_roles();
    }
}


