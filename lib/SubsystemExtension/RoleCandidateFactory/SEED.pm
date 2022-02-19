package SubsystemExtension::RoleCandidateFactory::SEED;


use strict;
use warnings;
use Carp;
use SubsystemExtension::RoleCandidate::SEED;
use SubsystemExtension::RoleCandidateMatch;
use base qw(SubsystemExtension::RoleCandidateFactory);
use SubsystemExtension::ExtensionConfig qw (FASTADB_DIR);
use SameFunc;
use FIG;
use Subsystem;
use constant DEBUG => 0;
use Bio::AlignIO;
no warnings qw(redefine);

1;

sub generate {

    my ($self) = @_;

    # fuer jedes gen ergibt sich eine score die sich 
    # aus der similarity der edist(assigned_function, role) und
    # der summe von functional coupling data mit anderen genen des subsystems
    # get the BBHS as ross did 
    # check for naming of the genes
    # check for neighboring information

    $self->{fig} = new FIG;

    $self->_fetch_instances();
    
    my @role_pegs = keys %{$self->instances()};

    my $func_score;
    my @sim_candidates;
    my %candidates; # a hash , key is id, value is reference to RoleCandidate object




    # check if the organism has already been added to the subsystem
    # and if this role was already assigned

    print STDERR "detecting candidates for role ".$self->role()."\n";

    my %existing_annotations;

    if ($self->subsystem->get_genome_index($self->organism()) && ($self->subsystem->get_genome_index($self->organism()) > 0)) {
	# this genome was already added mark collect those pegs
	my $cell = $self->subsystem()->get_cell($self->subsystem->get_genome_index($self->organism()),$self->subsystem->get_role_index($self->role()));
	foreach (@$cell) {

	    print STDERR "$_ is human annotatedt  as ".$self->role()."\n" if (DEBUG);
	    $existing_annotations{$_} = 1;

	}
    }	    
    

    if (scalar @role_pegs > 0) {
	
        
        # get the nearest neighbors for bbh and sim scan
        my $genome = $self->organism();
        my @close_role_pegs = map { $_->[0] }
        sort { $a->[1] <=> $b->[1] }
        map { my $peg = $_; [$peg,$self->fig->crude_estimate_of_distance($genome,&FIG::genome_of($peg))] }
        @role_pegs;
        
        my $how_many  = ((@close_role_pegs > $self->depth()) ? $self->depth() : scalar @close_role_pegs) - 1;

        my @role_instances = @close_role_pegs[0.. $how_many];




	print STDERR "filtering bbhs: \n" if (DEBUG);
	my @bbh_candidates =  sort { $a->[2] <=> $b->[2] }
	$self->fig()->best_bbh_candidates_additional( $self->organism(), $self->evalue_threshold(), $self->depth(), \@role_instances );
	              
	
	if (scalar @bbh_candidates > 0) {
	    foreach my $bbh (@bbh_candidates) {
		
		print STDERR "created BBH Role Candidate $$bbh[0] $$bbh[1] $$bbh[2] $$bbh[3] \n" if (DEBUG); 
		
		my $loc = $self->fig()->feature_location($$bbh[0]);
		my ($contig,$beg,$end) = $self->fig()->boundaries_of($loc);

		my $rcm = SubsystemExtension::RoleCandidateMatch->new($$bbh[0], $$bbh[4],$$bbh[5], $$bbh[6], $$bbh[7], $$bbh[8], $$bbh[9]);
		my $bbh_candidate = SubsystemExtension::RoleCandidate::SEED->new($$bbh[0], 
										 $self->role, 
										 $self->subsystem()->get_role_index($self->role), 
										 $self->subsystem()->get_name(), $self->organism(), {
										     bbh => 1, 
										     contig => $contig,
										     start => $beg,
										     stop => $end,
										     psc => $$bbh[2],
										     frac => $$bbh[3],
										     match => $$bbh[1],
										     role_abbr => $self->role_abbreviation(),
										     function => scalar $self->fig()->function_of($$bbh[0], 'master'),
										     sf => (SameFunc::same_func(scalar $self->fig()->function_of($$bbh[0], 'master'), $self->role)) ? 1 : 0,
										     nbh => $self->neighboringSubSysPegs($$bbh[0]),
										     ld =>  abs($self->fig()->translation_length($$bbh[0]) - $self->fig()->translation_length($$bbh[1]) ),   
										     human => $existing_annotations{$$bbh[0]},
										     rcm => ref $rcm ? $rcm : ''
										 });
		
                # if this candidate was not yet found set it
		unless (defined $candidates{$$bbh[0]}) {
		    $candidates{$$bbh[0]} = $bbh_candidate;
		} elsif ($candidates{$$bbh[0]}->score < $bbh_candidate->score) {
		    $candidates{$$bbh[0]} = $bbh_candidate;
		} else {
		    $candidates{$$bbh[0]}->inc_bbhs_count();
		}
	    }
	}

	

	# usage: @sims = $fig->sims($peg,$maxN,$maxP,$select)

	# Returns a list of similarities for $peg such that

	#    there will be at most $maxN similarities,
	#    each similarity will have a P-score <= $maxP, and

	#    $select gives processing instructions:
	#        "raw" means that the similarities will not be expanded (by far fastest option)
	#        "fig" means return only similarities to fig genes
	#        "all" means that you want all the expanded similarities.

	print STDERR "filtering sims: \n" if (DEBUG);

	# this should speed up the process of finding sim candidates



	foreach my $peg (@role_instances) { #@role_pegs
	    print STDERR "\tsearching for sims from $peg\n" if (DEBUG); 
	    foreach my $sim ($self->fig()->sims($peg, 750, $self->evalue_threshold(), "all")) {
		push @sim_candidates, $sim if ($sim->id2 =~ /fig\|$genome/);
	    } 
	}

	if (scalar @sim_candidates > 0) {
	    foreach my $sim (@sim_candidates) {
		print STDERR "created SIM Role Candidate ".$sim->id2." ".$sim->id1."\n" if (DEBUG); 

		# a hash keeps track of those pegs that could fulfill the role
		# and helps to select the best similarity
		my $loc = $self->fig()->feature_location($sim->id2);
		my ($contig,$beg,$end) = $self->fig()->boundaries_of($loc);

		my $rcm = SubsystemExtension::RoleCandidateMatch->new($sim->id1, $sim->b1, $sim->e1, $sim->b2, $sim->e2, $sim->ln1, $sim->ln2);

		my $sim_candidate = SubsystemExtension::RoleCandidate::SEED->new($sim->id2,
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
										     frac => &FIG::min(($sim->e1+1 - $sim->b1) / $sim->ln1, ($sim->e2+1 - $sim->b2) / $sim->ln2),
										     sf => (SameFunc::same_func(scalar $self->fig()->function_of($sim->id2, 'master'), $self->role)) ? 1 : 0,
										     function => scalar $self->fig()->function_of($sim->id2, 'master'),
										     nbh => $self->neighboringSubSysPegs($sim->id2),
										     ld =>  abs($sim->ln1 - $sim->ln2),
										     sims_count => 0,
										     human => $existing_annotations{$sim->id2}
										 });
		

		# if this candidate was not yet found set the candidate
		unless (defined $candidates{$sim->id2}) {
		    $candidates{$sim->id2} = $sim_candidate;
		} elsif ($candidates{$sim->id2}->score() < $sim_candidate->score()) {
		    $candidates{$sim->id2} = $sim_candidate;
		} else {
		    $candidates{$sim->id2}->inc_sims_count();
		}
		
	    }
	}


	if ((scalar keys %candidates == 0) && $self->{predict}) {
	    # build fasta file and blast against the genomic sequence
	    my $blast_candidates; # $self->blast_contig($genome, \@role_pegs, '');
	    foreach my $sim (@$blast_candidates) {
		# print STDERR &Dumper(["Blast result: ", $_]);

		$candidates{$sim->id2} = { id => $sim->id2,
					   bbh => 0, 
					   psc => $sim->psc,
					   frac => &FIG::min(($sim->e1+1 - $sim->b1) / $sim->ln1, ($sim->e2+1 - $sim->b2) / $sim->ln2),
					   sf => (SameFunc::same_func($sim->id2, $self->role)) ? 1 : 0
					   }  unless ($candidates{$sim->id2});
		
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


sub _fetch_instances {

    my ($self) = @_;

    my %instances;
    foreach (@{$self->subsystem()->functional_role_instances( $self->role(),1)}) {
	
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


sub _buildRolePSSM {

    

    my $inputfilename = "testaln.fasta";
    my $in  = Bio::AlignIO->new(-file => $inputfilename ,
				'-format' => 'fasta');
    my $out = Bio::AlignIO->new(-file => ">out.aln.pfam" ,
				'-format' => 'pfam');
    # note: we quote -format to keep older perl's from complaining.

    while ( my $aln = $in->next_aln() ) {
	$out->write_aln($aln);
    }


}

sub _buildInstanceFASTA {

    my ($self) = @_;

    my $size = scalar keys %{$self->{instances}};
    
    open INSTANCEFASTA, ">".FASTADB_DIR.$self->role().".faa";
    foreach my $key (%{$self->instances()}) {
	print INSTANCEFASTA $key."\t".$self->role()."\n".${$self->instances()}->{$key}."\n";
    }
    close INSTANCEFASTA;

}



# calculates a value between 0 and 1 describing the fraction of
# roles that are in the chromosomal neighborhood (10.000 bp) of the current candidate


sub neighboringSubSysPegs {

    my ($self, $peg, $dist) =@_;

    my $nbh =0;
    $dist = $dist ? $dist : 5000;
    my %close_genes;
    foreach ($self->fig()->close_genes($peg, $dist)) {
	$close_genes{$_} = 1;
    }
    my $genome = $self->fig()->genome_of($peg);
    my $row = $self->subsystem->get_row($self->subsystem->get_genome_index($genome)); 
    
    my $roles = scalar @$row;
    foreach my $cell (@$row) {
	foreach (@$cell) {
	    $nbh++ if ($close_genes{$_} && ($_ ne $peg));
	    print STDERR "\t$_ close to $peg\n" if ($close_genes{$_} && ($_ ne $peg) && (DEBUG)); 
	}
    }

    return $nbh / $roles;
}

