package SubsystemExtension::ClusterDetection;


use strict;
# use warnings;
use Carp;
use FIG;
use Data::Dumper;

#use SubsystemExtension::ClusterList;
use SubsystemExtension::Cluster;

use Subsystem;
use constant DEBUG => 0;
no warnings qw(redefine);

1;


sub new {

    my ($class, $minClusterSizeGenes, $minClusterSizeGenomes, $joinOverlap) = @_;

    my $self  = {};

    $self->{fig}  = FIG->new();

    # configuration params for the CI algorithm
    $self->{minClusterSizeGenes} = $minClusterSizeGenes ? $minClusterSizeGenes : 2;
    $self->{minClusterSizeGenomes} = $minClusterSizeGenomes ? $minClusterSizeGenomes : 2;
	$self->{clusterList} = [];

    $self->{joinOverlap} = $joinOverlap ? $joinOverlap : 0.75;
    $self->{sequences} = [];  # reference on array of taxon_ids
    $self->{sequence_count} = 0;
    $self->{maxSteps} = $self->{sequence_count} - $self->{minClusterSizeGenomes} +1;
	$self->{delta} = $self->{maxSteps};
	print STDERR "clusterzize : ".$self->{minClusterSizeGenomes}. "\n";

#    $self->{cluster} = new ClusterList;
#    $self->{joinedCluster} new ClusterList;
    


    bless $self, $class;

    print STDERR "created ClusterDetection\n" if (DEBUG);
    
    return $self;


}


sub sequences {

    my ($self, $value) = @_;

    return $self->{sequences} if (scalar(@_) == 1);
	if (ref $value eq "ARRAY") {
		$self->{sequences} = $value;
		$self->{sequence_count} = scalar @$value;
		
		print STDERR "clusterzize : ".$self->{minClusterSizeGenomes}. "\n";

		$self->{maxSteps} = $self->{sequence_count} - $self->{minClusterSizeGenomes} +1;
	}
}

sub get_sequence {

	my ($self, $index) = @_;

	
	if (wantarray) {
		return @{$self->{sequences}->[$index]}; 
	} else {
		return $self->{sequences}->[$index]; 
	}
}




sub fig {
	my ($self, $value) = @_;
	
	return $self->{fig} if (scalar(@_) == 1);
	$self->{fig} = $value;

}


sub fetch_SEED_families {

    my($self,$genomes, $type) = @_;



	my @sequences;

    my($relational_db_response);
    my $rdbH = $self->fig->db_handle;
		

	if ($rdbH->table_exists('localid_cid') && $rdbH->table_exists('localfam_cid')) {
		foreach my $genome (@$genomes) {
			my @sequence;
			
			
			my @pegs = $self->fig->pegs_of($genome);

			foreach my $peg (@pegs) {
				if (($relational_db_response = $rdbH->SQL("SELECT localfam_cid.family from localfam_cid,  
localid_cid WHERE localid_cid.localid = '$peg' and localid_cid.cid = localfam_cid.cid")) && #  and localfam_cid.family like '$type%'" )) &&
					(@$relational_db_response > 1))
				{
					foreach my $tuple (grep {$_->[0] =~ /$type/} @$relational_db_response) { 
						if ( $peg =~ /peg\.(\d+)/) {
							my $index = $1;
							if ($tuple->[0] =~ /$type\|\D+(\d+)/) {
								my $family = $1 * 1;
								print STDERR "$genome: $index => $family\n";
								$sequence[$index] = $family;
							}
						}
					}
				}
			}
			
			push @sequences, \@sequence;
			
		}
	
	}
	
	if (wantarray) {
		return @sequences;
	} else {
		return \@sequences;
	}
	
}



sub parse_COG {

	my ($self, $COG) = @_;

	my @sequences;
	my %genomes;

	open (COG, $COG);
	my $state = 0;

	my ($genomeIndex, $geneIndex, $genome, $size, $geneCount);
	$genomeIndex = -1;

	while (<COG>) {
		chomp;
		next if ($_ eq "");
		unless ($_ =~ /^\d+.+/)  {
			# header for organisms
			
			($genome, $size) = split ',', $_;

			if ($genome && $size) {
				$genomeIndex++;
				$geneIndex = 0;
				$sequences[$genomeIndex] = [0];


				if ($size =~ /\-\s+\d+\.\.(\d+)/) {
					$size = $1;
				} else {
					$size = 0;
				}
				print STDERR "Genome: $genomeIndex $genome\n";
				$genomes{$genome} = { id => $genomeIndex,
									  name => $genome,
									  size => $size,
									  genes => []
									}
			}
			
		} else {
			if ($_ =~ /(\d+)\s+proteins/) {
				$genomes{$genome}->{gene_count} = $1;
			} elsif ($_ =~ /^(\d+)\s+/) {
				
				$geneIndex++;
				my ($cogID, $strand, $cogCategory, $geneName, $geneDescription) = split "\t", $_;
				
				push @{$sequences[$genomeIndex]}, $cogID * 1;
				push @{$genomes{$genome}->{genes}}, {id => $geneIndex,
													 family => $cogID * 1,
													 strand => $strand eq '+' ? 1 : -1,
													 category => $cogCategory,
													 name => $geneName,
													 description => $geneDescription}
			   
			}
		}

	}
	close (COG);
	
	return (\@sequences, \%genomes);
	
}


sub parafam {
    my ($self, $genomes) = @_;
    my @l;
    my $sequence_count = scalar @$genomes;

    foreach my $genome (@$genomes) {
		my %infamily;
		foreach my $peg ($self->fig->pegs_of($genome)) {
			unless ($infamily{$peg}) {
				my @f;
				my @l = [$peg];
				while (@l) {
					push @f, $_;
					
					
				}  
			}
			
		}
    }


}

sub homofam {

}


sub build_pos {

    my ($self, $sequence) = @_;
    my %pos; # store the gene index that belong to one family
	         # in a hash

             # pos{132} => [1,2,5,88] means that genes 1,2,5 and 
             # 88 belong to family 132
    
	
	my $index = 0;
	foreach my $family (@$sequence) {
		
		
		if ($family && ($family > 0)) {
			unless ($pos{$family}) {
				$pos{$family} = [$index];
			} else {
				push @{$pos{$family}}, $index;
			}
		}
		$index++;
	} 

	return \%pos;
}



sub build_num {
    
    # creates a n time n table

	#     1 2 3 4 5 6 7 8 (j)
	#    ----------------
	# 1 | 1 2 3 4 4 5 5 5
    # 2 |   1 2 3 3 4 4 5
    # 3 |     1 2 2 3 4 5
    # (i)

	# num(i,j) tells how many different families are between the 
    # i and j. j >= i
	
    my ($self, $sequence) = @_;

    my @num;
	
	my $geneCount = scalar @$sequence;


	# hier dynamic programming????

    foreach my $i (0..$geneCount -1) {

		$num[$i] = [];
		my @known;
		
		my $last = 0;

		foreach my $j ($i..$geneCount-1) {
			if (($sequence->[$j] > 0) && (! $known[$sequence->[$j]])) {
				$known[$sequence->[$j]] = 1;
				$last++;
			}
			$num[$i][$j] = $last;

		}
    }

    return \@num;

}

sub build_num_dp {
    
    # creates a n time n table

	#     1 2 3 4 5 6 7 8 (j)
	#    ----------------
	# 1 | 1 2 3 4 4 5 5 5
    # 2 |   1 2 3 3 4 4 5
    # 3 |     1 2 2 3 4 5
    # (i)

	# num(i,j) tells how many different families are between the 
    # i and j. j >= i
	
    my ($self, $sequence) = @_;

    my @num;
	
	my $geneCount = scalar @$sequence;
	
	my @known;

	# hier dynamic programming????

	my $last = 0;

	$num[1] = [];

	foreach my $j (1..$geneCount) {
		#if ($sequence->[$j] > 0) {
			if (! $known[$sequence->[$j]]) {
				$last++;
			}
			$known[$sequence->[$j]]++;
		#}
		$num[1][$j] = $last;
	}

	foreach my $i (2..$geneCount) {
		# print STDERR "iteration $i\n";
		
		@{$num[$i]} = @{$num[$i-1]};
		# $num[$i] = \@temp;
		
	    my $lost = $sequence->[$i-1];

		foreach my $x ($i .. $geneCount ) {
			$num[$i][$x]--;# = $num[$i][$x]-1;
			last if ($sequence->[$x] == $lost);
		}
		
		$num[$i][$i-1] = undef;

	}

    return \@num;

}



sub createEfficient {

    my ($genome) = @_;

}

sub connecting_intervalls {

    # in order to save memory large arrays could be represented as hashes
    # preprocessing

    my ($self) = @_;


    my $i;
    my $j;
    


    my %isDuplicate;

    # s1 und s2 werden als arrays repraesentiert
    # nur die methoden elementAt und length werden benoetigt



    # Iteriere ueber alle sequenzen in seq (seq.length - kPrime +1)
    # um seq1 zu setzen
    foreach my $step (0 .. $self->{maxSteps}-1  ) {
		print STDERR  localtime(time())."\n";
		print STDERR sprintf("init %d / %d \n", $step, $self->{maxSteps});
		
		$self->{delta} = $self->{maxSteps} - ($step+1);
		
		my @seq1 = $self->get_sequence($step);

		# print STDERR &Dumper(["seq1:", @seq1]);

		my @miss;
		my @last;
		
		foreach my $x (1..scalar @seq1)
		{
			$miss[$x] = [];
			$last[$x] = [];
		    foreach my $y (1..scalar @seq1)
			{
				$last[$x][$y] = $step;
				$miss[$x][$y] = 0;
			}
		}

		my %mark;  # all fields are 'false'
		my %loc;   # all fields are 'null'


		my $num = $self->build_num_dp(\@seq1); # arrayref
		# my $num2 = $self->build_num(\@seq1); # arrayref
		
		#print STDERR join ', ', @{$num->[1]};
		#print STDERR join ', ', @{$num2->[1]};

		print STDERR "num: ".localtime(time())."\n";
		my $pos = $self->build_pos(\@seq1); # hashref
		print STDERR "pos: ".localtime(time())."\n";

		print STDERR "preprocessing completed\n";
        # Iteriere ueber alle sequenzen in seq (seq.length - kPrime +1)
		# um seq2 zu setzen

		
		foreach my $aktSeq ($step .. $self->{sequence_count} -1) {
			print STDERR sprintf("Step %d / %d /  %d\n", $step, $aktSeq, $self->{sequence_count});
			my @seq2 = $self->get_sequence($aktSeq); 
			
			
			my $start = 0;
			my $end = 0;
			
			
			my $gene_count = scalar @seq1;
			my $gene_count2 = scalar @seq2;
			print STDERR "Gene counts : $gene_count, $gene_count2\n";

			foreach my $i (1..$gene_count2 -1) {  # $i = linke grenze
				
				my @bucket; # elemente sind hashreferenzen
				my %occ; # flagged jede family die vorkommt

				my $j = $i; # $j = rechte grenze
				while (($j < $gene_count2 -1) && ($seq2[$j]) &&
					   ($seq2[$j] != $seq2[$i-1]) && 
					   ($seq2[$j] != 0)) {
					$occ{$seq2[$j]} = 1;
					
					# $c beinhalted den character
					my $c = $seq2[$j];
					
					while (($seq2[$j+1]) && $occ{$seq2[$j+1]}) {	$j++; }


					# hole alle positionen fur den character c
					my $u = 0;
					my @familyPos = ref $pos->{$c} ? @{$pos->{$c}} : (); 
					foreach my $p (@familyPos) {
						# print STDERR "$c ist an position $p\n";
						my $nextNumber = 0;
						if ($u < scalar @familyPos -1) {
							$nextNumber = $familyPos[$u+1];
						}
						
						$u++;


						# build and fill the bucket hashes

						
						if ((ref $bucket[$p-1] eq "HASH") && $bucket[$p-1]->{visited}) {
							$start = $bucket[$p-1]->{left};
						} else {
							$start = $p;
						}

						if ((ref $bucket[$p+1] eq "HASH") && $bucket[$p+1]->{visited}) {
							$end = $bucket[$p+1]->{right};
						} else {
							$end = $p;
						} 

						
						if (ref $bucket[$start] eq "HASH") {
							$bucket[$start]->{right} = $end;
						} else {
							$bucket[$start] = {right => $end};
						}
						if (ref $bucket[$end] eq "HASH") {
							$bucket[$end]->{left} = $start;
						} else {
							$bucket[$end] = {left => $start};
						}
						if (ref $bucket[$p] eq "HASH") {
							$bucket[$p]->{visited} = 1;
						} else {
							# print STDERR "neuer visited bucket $p";
							$bucket[$p] = {visited => 1, right => 0, left => 0};
						}
						
						my $occuredFamilies = scalar keys %occ;
						
						# print STDERR "Occured families:$occuredFamilies \n";

						if (
							(! $isDuplicate{$step."-".$start."-".$end}) && 
							($num->[$start][$end]) &&
							($num->[$start][$end] >= $self->{minClusterSizeGenes}) &&
							($num->[$start][$end] == $occuredFamilies) &&
							(
							 (!$nextNumber) || ($nextNumber == 0) || 
							 ($nextNumber>($end+1))
							)
						)
						{
							print STDERR $i;
							if (($step == $aktSeq) 
								&& ($start != $i) 
								&& (!$mark{"$i-$j"})) {

								# if this location is not defined create and anonymous list
								# otherwise just add the CSLoc hash
								unless (ref $loc{$i}->{$j} eq "ARRAY") {
									$loc{$i}->{$j} = [];
								}
								print STDERR "a) adding location for $aktSeq [$start - $end] \n";
								push @{$loc{$i}->{$j}}, {
									startPosition => $start,
									endPosition => $end,
									sequence => $aktSeq
									};
								$mark{"$start-$end"} = 1;
							}
							
							if (($aktSeq > $step) && (!$mark{"$start-$end"})) {
								my $missing = $aktSeq - ($last[$start][$end] ? $last[$start][$end] : $step);
								$last[$start][$end] = $aktSeq;
								if ($missing && ($missing > 1)) {
									$miss[$start][$end] += $missing-1;
								}
								if ($miss[$start][$end] && ($miss[$start][$end] > $self->{delta})) {
									$mark{"$start-$end"}=1; 
								} else  {
									unless (ref $loc{$start}->{$end} eq "ARRAY")  {
										$loc{$start}->{$end}=[];
									}
									print STDERR "b) adding location for $aktSeq [$start - $end] \n";
									push @{$loc{$start}->{$end}}, {
										startPosition => $i,
										endPosition => $j,
										sequence => $aktSeq
										};
								}
							}
						} # end isDuplicate
					}
					$j++;
					
				}
				
			}
			
		}
		
	    $self->buildOutput($step, \@miss, \@last, \%mark, \%loc, \%isDuplicate);

		
    } # Ende der $step schleife
	
	my $clusters = scalar @{$self->{clusterList}};
	print STDERR "Found $clusters clusters\n";
	print STDERR "end: ".localtime(time())."\n";
	foreach my $cluster ($self->{clusterList}) {
		print STDERR $cluster->to_string();
	}
	print STDERR Dumper($self->{clusterList});
	
}


sub buildOutput {

    my ($self, $step, $miss, $last, $mark, $loc, $isDuplicate) = @_;
	my $k=scalar @{$self->{sequences}};
	my $k1 = $k-1;


	# irgendwie wird hier alles durchlaufen die if bedingungen scheinen]
	# nicht korrekt zu funtionieren. addRegion wird fuer jede kombination i < j wobei i und j element N < seq_count!!!!

	my @seq = $self->get_sequence($step);
    for my $i (1  .. scalar @seq - 1) {
		
		for my $j ( $i .. @seq)  {
			
			if ((!$mark->{"$i-$j"}) && 
				(($miss->[$i][$j])+($k1 - ($last->[$i][$j] ? $last->[$i][$j] : $step) ) <= $self->{delta}))  {
				print STDERR "+";
				# my $first = $step+1;
				# my $second = 0;
				# my $occurring = $k-($step+($miss->[$i][$j] ? $miss->[$i][$j] : 0)+(($k-1)- ($last->[$i][$j] ? $last->[$i][$j] : 1) ));
				my $temp = new SubsystemExtension::Cluster($step."-".$i."-".$j, $self->sequences());
				$temp->addRegion($step,$i,$j);
				my $begin = $step;
				foreach my $l (@{$loc->{$i}->{$j}})  {
					my %actual = %$l;
					if ($actual{sequence} > $step) { 
						$isDuplicate->{$actual{sequence}."-".$actual{startPosition}."-".$actual{endPosition}} = 1; # nicht paraloge werden nie wieder ausgegeben !
						if ($actual{sequence} != $begin)  {
							$begin = $actual{sequence};
							# $second = $begin+1;
						}
						$temp->addRegion($actual{sequence},$actual{startPosition},$actual{endPosition});
					}
					push @{$self->{clusterList}}, $temp; # hier wird der aufgebaute Cluster in die Ergebnisliste eingetragen
				}
			}
		}
	}
}
