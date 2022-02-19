package SubsystemExtension::RoleCandidateFactory::MultiSEED;


use strict;
use warnings;
use Carp;
use SubsystemExtension::RoleCandidate::SEED;
use SubsystemExtension::RoleCandidateMatch;
use base qw(SubsystemExtension::RoleCandidateFactory);
use SameFunc;
use FIG;
use Subsystem;
use constant DEBUG => 0;
no warnings qw(redefine);

1;

sub generate {

    my ($self, $genomes) = @_;

    $genomes = [$self->organism] unless ($genomes);
    
    $self->{fig} = new FIG;
    
    $self->_fetch_instances();
    
    my @role_instances = keys %{$self->instances()};


    my %candidates; # a hash , key is genome, value is ref of hash of RoleCandidate objects
    
    my %genomes;
    my %sim_candidates;
    my %existing_annotations;
    
    if (scalar @role_instances > 0) {

	foreach (@$genomes) {
	    $genomes{$_} = 1;
	    $sim_candidates{$_} = [];
	    $candidates{$_} = {};
	    $existing_annotations{$_} = {};
	}
    


	# check if the organism has already been added to the subsystem
	# and if this role was already assigned

	print STDERR "\ndetecting candidates for role ".$self->role();
	
	
	foreach my $genome (@$genomes) {
	    
	    if ($self->subsystem->get_genome_index($genome) && ($self->subsystem->get_genome_index($genome) > 0)) {
		# this genome was already added mark collect those pegs
		my $cell = $self->subsystem()->get_cell($self->subsystem->get_genome_index($genome),$self->subsystem->get_role_index($self->role()));
		foreach (@$cell) {
		    
		    print STDERR "$_ is human annotatedt  as ".$self->role()."\n" if (DEBUG);
		    $existing_annotations{$genome}->{$_} = 1;
		    
		}
	    }	    
	}
	
	# get all sims for the functional role instances 
	# and store those that belong to genomes we would like to extend
	
	foreach my $peg (@role_instances) { #@role_pegs
	    print STDERR "\tsearching for sims from $peg\n" if (DEBUG); 
	    foreach my $sim ($self->fig()->sims($peg, 2000, $self->evalue_threshold(), "fig")) {
		my $sim_genome = $sim->id2;
		if ($sim_genome =~ /fig\|(\d+\.\d+)\./) {
		    $sim_genome = $1;
		    
		    if ($genomes{$sim_genome}) {
			push @{$sim_candidates{$sim_genome}}, $sim;
			#print STDERR ".";# if (DEBUG);
		    }
		}
	    } 
	}
	
	foreach my $genome (@$genomes) {
	    if (scalar @{$sim_candidates{$genome}} > 0) {
		foreach my $sim (@{$sim_candidates{$genome}}) {
		    print STDERR "created SIM Role Candidate ".$sim->id2." ".$sim->id1."\n" if (DEBUG); 
		    
		    # a hash keeps track of those pegs that could fulfill the role
		    # and helps to select the best similarity
		    my $loc = $self->fig()->feature_location($sim->id2);
		    my ($contig,$beg,$end) = $self->fig()->boundaries_of($loc);
		    
		    my $rcm = SubsystemExtension::RoleCandidateMatch->new($sim->id1, $sim->b1, $sim->e1, $sim->b2, $sim->e2, $sim->ln1, $sim->ln2);
		    
		    my $sim_candidate = SubsystemExtension::RoleCandidate::SEED
			->new($sim->id2,
			      $self->role,
			      $self->subsystem()->get_role_index($self->role), 
			      $self->subsystem->get_name(), $self->organism(), {
				  contig => $contig,
				  start => $beg,
				  stop => $end,
				  bbh => 0, 
				  psc => $sim->psc,
				  match => $sim->id1,
				  rcm => ref $rcm ? $rcm : '',
				  role_abbr => $self->role_abbreviation(),
				  frac => &FIG::min(($sim->e1+1 - $sim->b1) / $sim->ln1, 
						    ($sim->e2+1 - $sim->b2) / $sim->ln2),
				  
				  sf => (SameFunc::same_func(scalar $self->fig()->function_of($sim->id2, 'master'), $self->role)) ? 1 : 0,
				  function => scalar $self->fig()->function_of($sim->id2, 'master'),
				  ld =>  abs($sim->ln1 - $sim->ln2),
				  sims_count => 0,
				  human => $existing_annotations{$genome}->{$sim->id2},
				  identity => $sim->iden()
			      });
		    
		    
		    # if this candidate was not yet found set the candidate
		    unless (defined $candidates{$genome}->{$sim->id2}) {
			$candidates{$genome}->{$sim->id2} = $sim_candidate;
		    } elsif ($candidates{$genome}->{$sim->id2}->score() < $sim_candidate->score()) {
			$candidates{$genome}->{$sim->id2} = $sim_candidate;
		    } else {
			$candidates{$genome}->{$sim->id2}->inc_sims_count();
		    }
		    
		}
	    }
	}
	
	# mark those role candidates that do have bbhs to the functional role instances
	
	foreach my $peg (@role_instances) {
	    foreach my $tuple ($self->fig->bbhs($peg)) {
		
		my $bbh_peg = $tuple->[0];
		if ($bbh_peg =~ /^fig\|(\d+.\d+)/) {
		    my $bbh_genome = $1;
		    if (ref $candidates{$bbh_genome}->{$bbh_peg} && $candidates{$bbh_genome}->{$bbh_peg}->isa("SubsystemExtension::RoleCandidate")) {
			$candidates{$bbh_genome}->{$bbh_peg}->bbh(1);
			$candidates{$bbh_genome}->{$bbh_peg}->inc_bbhs_count();
		    }
		    
		}
	    }
	}
	
	    
    } else {
	print STDERR "No candidate genes, no extension for ".$self->role()."\n" if (DEBUG); 
    }
    
    
    if (wantarray) {
	return values %candidates;
    } else {
	return \%candidates;
    }
    
}

sub _samefunc {
    my ($self, $annotation) = @_;
    my $same = 0;

    if ($annotation) {
	foreach (split ' / ', $annotation) {
	    $same = 1 if SameFunc::same_func($_, $self->role);
	}

	foreach (split '; ', $annotation) {
	    $same = 1 if SameFunc::same_func($_, $self->role);
	}
    }

    return $same;
}


sub _fetch_instances {

    my ($self) = @_;

    my %instances;
    foreach (@{$self->subsystem()->functional_role_instances( $self->role(), 1)}) {
	
	$instances{$_} = $self->fig->get_translation($_) if ($self->fig()->genome_of($_) ne $self->organism());
	
    }
    
    
    $self->instances(\%instances);


}

sub instances {
    my ($self, $value) = @_;
    return $self->{instances} if (scalar(@_) == 1);
    $self->{instances} = $value;
}


sub fig {

    my ($self, $value) = @_;

    return $self->{fig} if (scalar(@_) == 1);
    $self->{fig} = $value;
}



