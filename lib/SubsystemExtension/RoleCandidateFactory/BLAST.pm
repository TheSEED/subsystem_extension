package SubsystemExtension::RoleCandidateFactory::BLAST;


use strict;
use warnings;
use Carp;
use SubsystemExtension::RoleCandidate;
use SubsystemExtension::Configs;
use base qw(SubsystemExtension::RoleCandidateFactory);
use Subsystem;
use constant DEBUG => 1;
use FIG;

no warnings qw(redefine);

1;


### the stop and start codons for different genetic codes


use constant START_CODONS => { 1 => [qw(ATG CTG TTG)],
			       4 => [qw(TTA TTG CTG ATG ATT ATC ATA GTG)],
			       11 => [qw(ATG CTG GTG TTG)]};

use constant STOP_CODONS => { 1 => [qw(TAA TAG TGA)],
			      4 => [qw(TAA TGA)],
			      11 => [qw(TAA TAG TGA)]};


sub _is_stop_codon {

    my ($codon, $genetic_code) = @_;
    $genetic_code = $genetic_code ? $genetic_code : 11;

    $codon =~ tr/atcg/ATCG/;

    foreach (@{STOP_CODONS->{$genetic_code}}) {
	return 1 if ($_ eq $codon);
    }

    return 0;

}

sub _is_start_codon {

    my ($codon, $genetic_code) = @_;

    $genetic_code = $genetic_code ? $genetic_code : 11;

    $codon =~ tr/atcg/ATCG/;

    foreach (@{START_CODONS->{$genetic_code}}) {
	return 1 if ($_ eq $codon);
    }

    return 0;

}


sub _next_start {

    my ($fig, $genome, $contig, $start, $stop);

    # get a range of nucleotides before and after the 
    # stop position of the original hit

    my $start_range = $start < $stop ? $start - 1500 : $start + 1500;

    my $seq = $fig->get_dna($genome, $contig, $start_range, $start);


    # iterate over every codon in the region before the start of the hsp and return 
    # the absolute start position
    my $start_pos = length($seq);
    while ($start_pos > 0) {
	last if _is_startcodon(substr $seq, $start_pos,  3);
	$start_pos = $start_pos + 3;
    } 

    return $start < $stop : $start - $start_pos : $start + $start_pos;

}



sub _next_stop {

    my ($fig, $genome, $contig, $start, $stop);

    # get a range of nucleotides before and after the 
    # stop position of the original hit

    my $stop_range = $start < $stop ? $stop + 1500 : $stop - 1500;

    my $seq = $fig->get_dna($genome, $contig, $stop, $stop_range);


    # iterate over every codon in the region be`ind the stop and return 
    # the relative position
    my $stop_pos =0;
    while ($stop_pos < 1500) {
	last if _is_stopcodon(substr $seq, $stop_pos,  3);
	$stop_pos = $stop_pos + 3;
    } 

    return $start < $stop : $stop + $stop_pos : $stop - $stop_pos;

}


sub _internal_stop {

    my ($fig, $genome, $contig, $start, $stop);

    my $seq = $fig->get_dna($genome, $contig, $start, $stop);

    my $num = length($seq)/3 + 1;
    foreach (unpack( "a3" x $num, uc($seq))) {
	return 1 if _is_stopcodon($_);
	last;
    }
    return 0;

}

sub _overlaps {
    my ($fig, $genome, $contig, $start, $stop) = @_;

    my ($overlapping_genes, $beg1, $end1) = $fig->genes_in_region($genome, $contig, $start, $stop);

    if (scalar @$ovelapping_genes > 0) {
	return 1;
    } else {
	return 0;
    }
    
}


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

    if (! $ENV{"BLASTMAT"}) { $ENV{"BLASTMAT"} = "$FIG_Config::fig/BLASTMAT"; }


    my $db = "$FIG_Config::temp/role_pegs.$$";
    open (DB, ">$db");
    foreach (@role_pegs) {
	print DB ">$_\n".$self->fig()->get_translation($_)."\n";
    }

    # blastx      compares the  six-frame  conceptual  translation
    #             products  of  a  nucleotide query sequence (both
    #             strands) against a  protein  sequence  database.
    #             For  bl2seq,  the nucleotide should be the first
    #             sequence given.
    

    system "formatdb -i $db -p T";
    print STDERR "blastall -d $FIG_Config::organisms/$genome/contigs -i $db -e 1e-20 -p blastx $parms > tmp$$.blastout\n";
    system("blastall -i $FIG_Config::organisms/$genome/contigs -d \"$db\" -e 1e-20 -p tblastn $parms > tmp$$.blastout");

    open(TMP,"<tmp$$.blastout")
	|| die "could not open tmp$$.blastout";

    while (defined($line = <TMP>))
    {
	chomp $line;
	if ($line =~ /^Query=\t(\S+)\t(.*)\t(\d+)/)
	{
	    $id1 = $1;
	    $ln1 = $3;
	    if (! $sims->{$id1}) { $sims->{$id1} = [] }
	}
	elsif ($line =~ /^>\t(\S+)\t(.*)\t(\d+)/)
	{
	    $id2  = $1;
	    $ln2  = $3;
	    $def2 = ($2 && $keep_def) ? $2 : undef;
	}
	elsif ($line =~ /^HSP/)
	{
#           HSP  score  exp  p_n  p_val  n_match  n_ident  n_sim  n_gap  dir  q1  q2  q_sq  s1  s2  s_sq
	    my (undef,$score,$exp,undef,undef,$n_match,$n_ident,undef,undef,undef,$b1,$e1,$seq1,$b2,$e2,$seq2) = split(/\t/,$line);
	    $ali = $keep_ali ? [$seq1,$seq2] : undef;
	    if ($n_match)
	    {
		$sim = [$id1,
			$id2,
			int(($n_ident * 100)/$n_match),
			length($seq1),
			$n_match - $n_ident,
			undef,
			$b1,
			$e1,
			$b2,
			$e2,
			$exp,
			$score,
			$ln1,
			$ln2,
			"blastp",
			$def2,
			$ali
			];
		bless($sim,"Sim");
		push(@{$sims->{$id1}},$sim);
	    }
	}
    }
    unlink("tmp$$.fasta");
    # unlink("tmp$$.blastout");


    foreach my $sim ($sims) {


	# check for internal stop codons
	
	if (_internal_stop($self->fig(), $self->genome(), $sim->id1(), $sim->b1, $sim->b2)) {
	    print STDERR "internal stop codon!\n";
	    next;
	}
	

	# extend to next start and stop

	my $start = _next_start($self->fig(), $self->genome(), $sim->id1(), $sim->b1, $sim->b2);
	my $stop = _next_stop($self->fig(), $self->genome(), $sim->id1(), $sim->b1, $sim->b2);
	

	# check for overlaps

	if (_overlaps($self->fig(), $self->genome(), $sim->id1(), $start, $stop)) {

	    print STDERR "overlapping genes!\n";
	    next;

	}



	print STDERR &Dumper($sim);
	my $i =1;
	$candidates{$sim->id2."_".$i} = SubsystemExtension::RoleCandidate::SEED->new($sim->id2."_".$i, $self->role, $self->subsystem->get_name(), $self->organism(), {
	    contig => $contig,
	    start => $start,
	    stop => $stop,
	    bbh => 0, 
	    psc => $sim->psc,
	    match => $sim->id1,
	    frac => &FIG::min(($sim->e1+1 - $sim->b1) / $sim->ln1, ($sim->e2+1 - $sim->b2) / $sim->ln2),
	    sf => 0,
	    nbh => 0,
	    ld => abs($sim->ln1 - $sim->ln2),
	    gene_prediction => 1

	});
	

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
    foreach (@{$self->subsystem()->functional_role_instances( $self->role())}) {
	$instances{$_} = $self->fig->get_translation($_);
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


sub _buildRoleHMM {


}
 
sub _buildRoleBLASTDB {


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



sub _buildInstanceDistanceMatrix {

    my ($self, $distance, $genome) = @_;

    my $size = scalar keys %{$self->{instances}};

    my @sim_candidates;

    #foreach my $key (1..$size) {
	
#	foreach my $sim ($self->fig()->sims($peg, 1000, 1.0e-20, "fig")) {
	#    push @sim_candidates, $sim if ($sim->id2 =~ /fig\|$genome/);
	#} 
	
	

    #}

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
#		print STDERR "$_\n";
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

