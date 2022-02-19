package SubsystemExtension::AEOS;


use strict;
use warnings;
use Carp;
use SubsystemExtension::VariantAnalysis;
use SubsystemExtension::SubsystemCandidate;
use SubsystemExtension::RoleCandidate;
use SubsystemExtension::RoleCandidate::SEED;
use SubsystemExtension::ExtensionConfig qw(MULTIPLEROLES);


use Subsystem;
use constant DEBUG => 0;
no warnings qw(redefine);

1;


sub new {

    my ($class, $fig, $subsystem, $organism , $subsystem_candidate, $parameters) = @_;

    my $self  = {};

    $self->{fig}  = ref $fig ? $fig : FIG->new();
    $self->{subsystem} = ref $subsystem ? $subsystem : $self->{fig}->get_subsystem($subsystem);
    $self->{organism} = $organism;
    $self->{subsystem_candidate} = $subsystem_candidate; # hashref
    # optional parameters
    $self->{params} = $parameters;
    $self->{score_cutoff} = $parameters->{score_cutoff} ? $parameters->{score_cutoff} : 150;
    $self->{score_cutoff_range} = $parameters->{score_cutoff_range} ? $parameters->{score_cutoff_range} : 0.90;
    $self->{variant_cutoff} = $parameters->{variant_cutoff} ? $parameters->{variant_cutoff} : 0.75;
    
    bless $self, $class;

    print STDERR "created AEOS for $subsystem \n" if (DEBUG);

    return $self;


}

sub subsystem {
    my ($self, $value) = @_;
    
    return $self->{subsystem} if (scalar(@_) == 1);
    $self->{subsystem} = $value;
}


sub organism {
    my ($self, $value) = @_;
    
    return $self->{organism} if (scalar(@_) == 1);
    $self->{organism} = $value;

}

sub subsystem_candidate {
    my ($self, $value) = @_;

    return $self->{subsystem_candidate} if (scalar(@_) == 1);
    $self->{subsystem_candidate} = $value;
}

sub extend {

    # this method filters the role candidates, checks
    # for the remaining roles for a function and generates
    # annotations if propbaility for whole subssyetm is above
    # a threshold of a functional variant


    my ($self) = @_;

    
    # use this hash to store the trusted candidates for each role with their score 
    # if one peg is assigned to more than one fr, use only the role with the best score

    # only one exception is tolerated, if fused gened exist for the fr the peg is candidate of 
    my %trusted_candidates;

    # for each role select the best scoring candidates
    # and remove additional candidates
    
    foreach my $role ($self->subsystem_candidate->roles()) {

	my @role_instances;
	my @role_candidates = sort {$b->score() <=> $a->score()} values %{$self->subsystem_candidate->{role_candidates}->{$role}};

	my $cutoff = $self->{score_cutoff};
	foreach my $role_candidate (@role_candidates) {
	    if ($role_candidate->score() >= $cutoff) {
		# adjust the cutoff for the next best hit to 90%
		$cutoff = $role_candidate->score() * $self->{score_cutoff_range} if ($cutoff == $self->{score_cutoff}); #### less false negatives!!!!! mit 90 evtl besser
		$cutoff = $self->{score_cutoff} if $cutoff < $self->{score_cutoff};
		push @role_instances, $role_candidate;
		$role_candidate->trusted(1);
		$trusted_candidates{$role_candidate->id()} = {} unless (ref $trusted_candidates{$role_candidate->id()});
		$trusted_candidates{$role_candidate->id()}->{$role} = $role_candidate;
	    
	    } else {
		$role_candidate->trusted(0);
	    }
	}

    }

    # select the best role for each candidate with more than one role

    foreach my $peg (keys %trusted_candidates) {
	my $best_role;
	my %best_role_pegs;

	# sort the role candidates of this peg descending by score
	# best one is kept, subseeding are checked if fused gene are annotated in subsystem
	# otherwise discarded
	foreach my $candidate (sort {$b->score() <=> $a->score()} values %{$trusted_candidates{$peg}}) { 
	    
	    if ($best_role) {
		unless (MULTIPLEROLES) { 
		    # this means that only the best matching role is kept for a peg
		    $candidate->trusted(0);
		} else {
		    # check if multiple roles are common for the pair (best_role, this_role) in the subsystem
		    
		    my $multiple_count = 0;
		    my $this_role = $candidate->role();
		    foreach (@{$self->subsystem()->functional_role_instances($candidate->role(), 1)}) {
			$multiple_count++ if ($best_role_pegs{$_});
		    }
		    
		    # if more than 75% are annotated as fused, this is candidate is also good
		    # otherwise not trusted
		    if ((scalar keys %best_role_pegs == 0) || ($multiple_count / scalar keys %best_role_pegs) < 0.75) {
			$candidate->trusted(0);
		    }
		} 
	    } else {
		
		$best_role = $candidate->role();
		if (MULTIPLEROLES) {
		    foreach (@{$self->subsystem()->functional_role_instances($candidate->role(), 1)}) {
			$best_role_pegs{$_} = 1;
		    }
		}
	    }

	}
    } 

    
    my $va = SubsystemExtension::VariantAnalysis->new($self->subsystem_candidate()->subsystem());

    $va->validateFunctionalVariant($self->subsystem_candidate());
    
    if ($self->subsystem_candidate->functional_variant_score() > $self->{variant_cutoff}) {
	## add to subsystem
	print STDERR "assigning subsystem candidate!\n" unless ($self->{params}->{mute});
	$self->subsystem_candidate->assign() unless ($self->{params}->{mute});
    } else {
	## just assign functions to remaining hits
	foreach my $role ($self->subsystem_candidate->roles()) {
	    foreach my $role_instance (values %{$self->subsystem_candidate->{role_candidates}->{$role}}) {
		print STDERR "assigning role candidates!\n" unless ($self->{params}->{mute});
		$role_instance->assign() unless ($self->{params}->{mute});
	    }
	}
    }

    return $self->subsystem_candidate;

}



