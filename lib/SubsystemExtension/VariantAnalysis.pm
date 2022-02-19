package SubsystemExtension::VariantAnalysis;


use strict;
use warnings;
use FIG;
use Subsystem;
use constant DEBUG => 0;
use Data::Dumper;
use SubsystemExtension::SubsystemVariant;
use SubsystemExtension::RoleCandidate;
use SubsystemExtension::SubsystemCandidate;


1;

sub new {
    
    my ($class, $subsystem) = @_;
    
    my $self  = {};
    

    $self->{subsystem} = ref $subsystem ? $subsystem : FIG->new()->get_subsystem($subsystem);
    # a hash of 
    $self->{variants} = {};

    bless $self, $class;

    my @active_genomes;
    my %variants;

    foreach my $genome ($self->{subsystem}->get_genomes) {
	push @active_genomes , $genome if ($self->subsystem()->get_variant_code($self->subsystem()->get_genome_index($genome)) > 0);
    }
    
    my $role_relevance = {};
    my $role_occurence = {};
    
    print STDERR @active_genomes." active variants \n" if (DEBUG);
    if (scalar @active_genomes >= 0) {
	my $relevant_role;
	
	foreach my $genome ( @active_genomes  ) {

	    my $variant_code = $self->subsystem()->get_variant_code_for_genome($genome);
	    
	    unless (ref $self->{variants}->{$variant_code} && $self->{variants}->{$variant_code}->isa("SubsystemExtension::SubsystemVariant")) {
		$self->{variants}->{$variant_code} = SubsystemExtension::SubsystemVariant->new($variant_code, $self->{subsystem});
	    } 

	    my $present_roles = {};
	    foreach my $role ($self->subsystem->get_roles()) {
		
		if ($self->subsystem->get_pegs_from_cell($genome, $role) > 0) {
		    # ++$role_occurence->{$role};
		    $present_roles->{$role} = 1;
		}
		
		unless ($variants{$variant_code}) {
		    $variants{$variant_code} = 1;
		    # $role_relevance->{$role} ? ++$role_relevance->{$role} : $role_relevance->{$role} = 1;
		}
	    }
	    $self->{variants}->{$variant_code}->add_instance($present_roles);
	}
	
	my $frac = 0;
	
	#if ( $role_occurence->{$role} > 0) {
	#    $frac =  $#active_genomes / $role_occurence->{$role};
	#}
	
	#$role_relevance->{$role} += $frac;
	
    }
    $self->{role_occurence} = $role_occurence;
    $self->{role_relevance} = $role_relevance;
   

    return $self;
   
} 



sub to_html {
    my ($self) = @_;
    my $html = "<table>\n"; 
    my @roles = $self->subsystem->get_roles();
    $html .= "<tr>";
    $html .= "<th>Variant (#)</th>";
    foreach my $abbr ($self->subsystem->get_abbrs()) {
	$html .= "<th>$abbr</th>";
    }
    $html .= "</tr>";
    foreach (sort {$a->id() <=> $b->id()} values %{$self->{variants}}) {
	$html .= $_->to_html(\@roles);
    }
    $html .= "</table>\n";
}

sub roles_by_variant_relevance {

}

sub roles_by_occurence_relevance {

}

# get/set method
sub subsystem {
    my ($self, $value) = @_;

    return $self->{subsystem} if (scalar(@_) == 1);
    $self->{subsystem} = $value;

}

sub match_SubsystemCandidate {
    my ($self, $subsystem_candidate) = @_;

    # takes the best score of role candidates for 
    # each functional role and create a hash with rolename -> score

    my $score =0;
    my %candidate_roles;
    foreach my $role ($subsystem_candidate->roles()) {
	my %role_candidates = %{$subsystem_candidate->role_candidates($role)};

	foreach my $role_candidate (values %role_candidates) {
	    $candidate_roles{$role} = 1 if ($role_candidate->{trusted});
	}
    }

    my $best_variant;
    foreach my $variant (sort {$a->id() <=> $b->id()} values %{$self->{variants}}) { 
	my ($frac_present, $present, $matchscore) = @{$variant->match(\%candidate_roles)};
	print STDERR $subsystem_candidate->genome()." Variant ".$variant->id()." => ".$matchscore."\n";
	if ($matchscore && ($matchscore > $score)) {
	    $best_variant = $variant;
	    $score = $matchscore;
	}
    }
    if (ref $best_variant) {
	return $best_variant->id();
    } else {
	return;
    }
}


sub validateFunctionalVariant {

    
    my ($self, $subsystem_candidate) = @_;

    # returns the functionl variant this organism is most likely to feature
    # assigns a score   

    # the candidates variant characteristic is build as hash with defined
    # entries for existing role candidates

    my %candidate_variant;

    foreach my $role (keys %{$subsystem_candidate->{role_candidates}}) {
	# get all the candidates for each role

	my @role_candidates = values %{$subsystem_candidate->{role_candidates}->{$role}};
	# if at least one "trusted" candidate is found for a role
	# this is marked to be present in the organims
	
	foreach my $role_candidate (@role_candidates) {
	    $candidate_variant{$self->subsystem()->get_role_index($role)} = 1 if ($role_candidate->{trusted});
	}
    }

    print STDERR join ", ", keys %candidate_variant, "\n" if (DEBUG);

    $subsystem_candidate->{functional_variant_common} = 0; 

    foreach my $genome ($self->subsystem()->get_genomes()) {
	my %rep;
	my $i = 0; 
	my $featured_roles = 0;
	my $necessary_roles = 0;
	my $variant_code = $self->subsystem()->get_variant_code($self->subsystem->get_genome_index($genome));
	my $variant_score = 0;
	if (($variant_code ne '-1') && ($variant_code ne '0')) {
	    foreach my $cell (@{$self->subsystem()->get_row($self->subsystem->get_genome_index($genome))}) {
		if (scalar @$cell > 0) {
		    $necessary_roles++;
		    if ($candidate_variant{$i}) {
			$featured_roles++;
			print STDERR "[features common role $i]\n" if (DEBUG);
		    }
		}
		$i++;
	    }
	    print STDERR "$genome has similar variant: $variant_code, $featured_roles of $necessary_roles roles\n"  if (DEBUG);
	    
	    if (($necessary_roles > 0) && 
		((($featured_roles / $necessary_roles) > $subsystem_candidate->{functional_variant_score}) || 
		 (
		  (($featured_roles / $necessary_roles) == $subsystem_candidate->{functional_variant_score}) && 
		  ($featured_roles > $subsystem_candidate->{functional_variant_common}))
		 )
		) {
		$subsystem_candidate->{functional_variant} = $variant_code;
		$subsystem_candidate->{functional_variant_score} = ($featured_roles / $necessary_roles);
		$subsystem_candidate->{functional_variant_common} = $featured_roles;
		$subsystem_candidate->{functional_variant_template} = $genome;
	    }
	}
    }

}
