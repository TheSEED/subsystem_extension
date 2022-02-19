package SubsystemExtension::ClusterDetectionSparse;

use strict;
# use warnings;
use Carp;
use Data::Dumper;
use CGI;
use integer;

use SubsystemExtension::ClusterList;
use SubsystemExtension::Cluster;
use SubsystemExtension::JoinedCluster;



use constant DEBUG => 0;
no warnings qw(redefine);

1;


sub new {

    my ($class, $minClusterSizeGenes, $minClusterSizeGenomes, $joinOverlap, $postprocessing, $validation_directory) = @_;

    my $self  = {};

    

    # configuration params for the CI algorithm
    $self->{minClusterSizeGenes} = $minClusterSizeGenes ? $minClusterSizeGenes : 2;
    $self->{minClusterSizeGenomes} = $minClusterSizeGenomes ? $minClusterSizeGenomes : 2;
    $self->{clusterList} = SubsystemExtension::ClusterList->new();
    $self->{joinedClusterList} = SubsystemExtension::ClusterList->new();
    $self->{joinOverlap} = $joinOverlap ? $joinOverlap : 75;
    $self->{postprocessing} = $postprocessing;
    $self->{sequences} = [];  # reference on array of taxon_ids
    $self->{genomes} = [];
    $self->{sequence_count} = 0;
    $self->{maxSteps} = $self->{sequence_count} - $self->{minClusterSizeGenomes} +1;
    $self->{delta} = $self->{maxSteps};
    

    $self->{validation_dir} = $validation_directory ? $validation_directory : '/var/tmp/';

    # $self->{cluster} = new ClusterList;
    # $self->{joinedCluster} new ClusterList;

    bless $self, $class;

    print STDERR "created ClusterDetection\n" if (DEBUG);
    
    return $self;

}


sub genomes {

    my ($self, $value) = @_;

    return $self->{genomes} if (scalar(@_) == 1);
    if (ref $value eq "ARRAY") {
	$self->{genomes} = $value;
    }
}


sub categories {

    my ($self, $value) = @_;

    return $self->{categories} if (scalar(@_) == 1);
    if (ref $value eq "HASH") {
	$self->{categories} = $value;
	$self->{categories_count} = scalar keys %$value;
    }

}

sub sequences {

    my ($self, $value) = @_;

    return $self->{sequences} if (scalar(@_) == 1);
    if (ref $value eq "ARRAY") {
	$self->{sequences} = $value;
	$self->{sequence_count} = scalar @$value;
	
	

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






sub clusterList {
    my ($self) = @_;

    return $self->{clusterList};
    

}

sub joinedClusterList {
    my ($self) = @_;

    return $self->{joinedClusterList};

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
	my $x = $i;
	foreach (@{$num[$i]}[$i .. $geneCount] ) {
	    $_--;# = $num[$i][$x]-1;
	    last if ($sequence->[$x] == $lost);
	    $x++;
	}
	
	#$num[$i][$i-1] = undef;
	
    }
    
    return \@num;

}

sub build_num_dp2 {
    
    # creates a n time n table

    #     1 2 3 4 5 6 7 8 (j)
    #    ----------------
    # 1 | 1 2 3 4 4 5 5 5
    #   2 | 1 2 3 3 4 4 5
    #     3 | 1 2 2 3 4 5
    # (i)

    # num(i,j-i) tells how many different families are between the 
    # i and j. j >= i
    # this has been implemented in order to save halve of the memory the 
    # algorithm uses and cut doen the precomputation time to half

    # the algorithm still runs in quadratic time but 
    # together with the dictionary based approach for the sparse matrices
    # the algorithm is now suitable for the application on a 
    # webserver with limited resources regarding memory
    # especially when multiple instances of the algorithm are performed simultaneously

    
    my ($self, $sequence) = @_;

    my @num;
    
    my $geneCount = scalar @$sequence;
    
    my @known;

    my $last = 0;

    $num[1] = [];

    foreach my $j (1..$geneCount) {
	
	if (! $known[$sequence->[$j]]) {
	    $last++;
	}
	$known[$sequence->[$j]]++;
	$num[1][$j] = $last;
    }

    foreach my $i (2..$geneCount) {
	
	@{$num[$i]} = @{$num[$i-1]}[1..scalar @{$num[$i-1]} -1];
	
	my $lost = $sequence->[$i-1];
	my $x = $i;
	foreach (@{$num[$i]}) {
	    $_--;# = $num[$i][$x]-1;
	    last if ($sequence->[$x] == $lost);
	    $x++;
	}
    }

    return \@num;

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

    open LOG, ">".$self->{validation_dir}."/log.txt";
    print LOG "[Starting computation]\n";
    close LOG;
    # Iteriere ueber alle sequenzen in seq (seq.length - kPrime +1)
    # um seq1 zu setzen
    foreach my $step (0 .. $self->{maxSteps}-1  ) {

	open LOG, ">>".$self->{validation_dir}."/log.txt";

	$self->{delta} = $self->{maxSteps} - ($step+1);
	
	my @seq1 = $self->get_sequence($step);
	
	# print STDERR &Dumper(["seq1:", @seq1]);
	
	my %miss;
	my %last;
	
	
	my %mark;  # all fields are 'false'
	my %loc;   # all fields are 'null'
	
	
	my $num = $self->build_num_dp2(\@seq1); # arrayref
	# my $num2 = $self->build_num(\@seq1); # arrayref
	
	#print STDERR join ', ', @{$num->[1]};
	#print STDERR join ', ', @{$num2->[1]};
	print LOG sprintf ("[Preprocessing %d of %d]\n", $step+1, $self->{maxSteps});
	print STDERR "num: ".localtime(time())."\n";
	my $pos = $self->build_pos(\@seq1); # hashref
	print STDERR "pos: ".localtime(time())."\n";
	
	print STDERR "preprocessing completed\n";
        # Iteriere ueber alle sequenzen in seq (seq.length - kPrime +1)
	# um seq2 zu setzen
	
	print LOG sprintf ("[Cluster detection %d of %d]\n", $step+1, $self->{maxSteps});

	foreach my $aktSeq ($step .. $self->{sequence_count} -1) {
	    
	    my @seq2 = $self->get_sequence($aktSeq); 
	    
	    my $start = 0;
	    my $end = 0;
	    
	    
	    my $gene_count = scalar @seq1;
	    my $gene_count2 = scalar @seq2;
	    	    
	    foreach my $i (1..$gene_count2 -1) {  # $i = linke grenze
		
		my @bucket; # elemente sind hashreferenzen
		my %occ; # flagged jede family die vorkommt

		my $j = $i; # $j = rechte grenze
		
		while (($j < $gene_count2 -1) && ($seq2[$j]) &&
		       ($seq2[$j] != $seq2[$i-1]) && 
		       ($seq2[$j] != 0)) {
		    
		    # $c beinhalted den character
		    my $c = $seq2[$j];
		    $occ{$c} = 1;
		    
		    
		    while (($seq2[$j+1]) &&  $occ{$seq2[$j+1]}) {	$j++; }
		    # while ($occ{$seq2[$j+1]}) {	$j++; }


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
			    ($num->[$start][$end-$start+1] >= $self->{minClusterSizeGenes}) &&
			    ($num->[$start][$end-$start+1] == $occuredFamilies) &&
			    (
			     (!$nextNumber) || ($nextNumber == 0) || 
			     ($nextNumber>($end+1))
			     )
			    )
			{
			    
			    if (($step == $aktSeq) 
				&& ($start != $i) 
				&& (!$mark{"$i-$j"})) {

				# if this location is not defined create and anonymous list
				# otherwise just add the CSLoc hash
				unless (ref $loc{$i}->{$j} eq "ARRAY") {
				    $loc{$i}->{$j} = [];
				}
				# print STDERR "a) adding location for $aktSeq [$start - $end] \n";
				push @{$loc{$i}->{$j}}, {
				    startPosition => $start,
				    endPosition => $end,
				    sequence => $aktSeq
				    };
				$mark{"$start-$end"} = 1;
			    }
			    
			    if (($aktSeq > $step) && (!$mark{"$start-$end"})) {
				my $missing = $aktSeq - ($last{"$start-$end"} ? $last{"$start-$end"} : $step);
				$last{"$start-$end"} = $aktSeq;
				if ($missing && ($missing > 1)) {
				    $miss{"$start-$end"} += $missing-1;
				}
				if ($miss{"$start-$end"} && ($miss{"$start-$end"} > $self->{delta})) {
				    $mark{"$start-$end"}=1; 
				} else  {
				    unless (ref $loc{$start}->{$end} eq "ARRAY")  {
					$loc{$start}->{$end}=[];
				    }
				    # print STDERR "b) adding location for $aktSeq [$start - $end] \n";
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
	my $misscount = scalar keys %miss;
	my $markcount = scalar keys %mark;
	my $loccount = scalar keys %loc;
	my $lastcount = scalar keys %last;
	my $duplicatecount = scalar keys %isDuplicate;
	print LOG "[Statistics]\nMiss: $misscount \nLast: $lastcount \nMark: $markcount \nLoc: $loccount \nDuplicate: $duplicatecount \n";
	print STDERR "[Statistics]\nMiss: $misscount \nLast: $lastcount \nMark: $markcount \nLoc: $loccount \nDuplicate: $duplicatecount \n";
	print LOG sprintf ("[Build output %d of %d]\n", $step+1, $self->{maxSteps});
	print STDERR "BuildOutput: ".localtime(time())." ";
	$self->buildOutput($step, \%miss, \%last, \%mark, \%loc, \%isDuplicate);
	print STDERR "end: ".localtime(time())."\n";

	close LOG;

    } # Ende der $step schleife
    
    my $clusters = $self->{clusterList}->count();
    my $i;

    #foreach my $cluster ($self->{clusterList}->clusters()) {
    #	if (ref $cluster && $cluster->isa("SubsystemExtension::Cluster")) {
    #		$i++;
    #		print STDERR $cluster->to_string();
    #open(PNG, ">/Users/heiko/cluster_$i.png") or die "could not open cluster png\n";
    #print PNG $cluster->to_png();
    #close PNG;
    #	}
    #}
    open LOG, ">>".$self->{validation_dir}."/log.txt";
    print STDERR "Found $clusters clusters\n";
    print LOG "[Join $clusters clusters]\n";

    $self->{clusterList}->toFile($self->{validation_dir}."/clusterlist_unjoined.cls");
    
    $self->{clusterList}->joinClusters($self->{joinOverlap});
    print STDERR "Joined to ".$self->{clusterList}->joinedCount(). " clusters\n";
    
    
    print LOG "[Total: ".$self->{clusterList}->count(). " clusters]\n";


    # print STDERR Dumper($self->{clusterList});
    close LOG;
    
}


sub from_to {
    $a->[0] <=> $b->[0]
	or 
	$b->[1] <=> $a->[1]
	
    }

sub buildOutput {

    my ($self, $step, $miss, $last, $mark, $loc, $isDuplicate) = @_;
    my $k=scalar @{$self->{sequences}};
    my $k1 = $k-1;

    my $delta = $self->{delta};
    

    my %potential_positions;

    foreach (keys %$last) {
	$potential_positions{$_} = 1;
    }

    foreach (keys %$miss) {
	$potential_positions{$_} = 1;
    }
    
    my @pos;

    foreach my $id (keys %potential_positions) {
	my ($i,$j) = split '-', $id;
	push @pos, [$i, $j, $id];
    }
    my @temp = sort from_to @pos;

    print STDERR "BuildOutput: potential pos ready and sorted ".localtime(time())."\n ";

    foreach (@temp) {

	my ($i, $j, $id) = @$_; 
	
	if ((!$mark->{$id}) && 
	    (($miss->{$id})+($k1 - ($last->{$id} ? $last->{$id} : $step) ) <= $delta))  {
	    

	    my $temp = new SubsystemExtension::Cluster($step."-".$i."-".$j);

	    my @genes = @{$self->{genomes}->[$step]->{genes}}[$i..$j];
	    $temp->addRegion($step,$i,$j,\@genes, $self->{genomes}->[$step]->{name});
	    my $begin = $step;
	    foreach my $actual (@{$loc->{$i}->{$j}})  {
		
		if ($actual->{sequence} > $step) { 
		    $isDuplicate->{$actual->{sequence}."-".$actual->{startPosition}."-".$actual->{endPosition}} = 1; # nicht paraloge werden nie wieder ausgegeben !
		    if ($actual->{sequence} != $begin)  {
			$begin = $actual->{sequence};
			# $second = $begin+1;
		    }
		    
		    # my @genes2 = @{$self->{sequences}->[$actual->{sequence}]}[$actual->{startPosition}..$actual->{endPosition}];
		    my @genes2 = @{$self->{genomes}->[$actual->{sequence}]->{genes}}[$actual->{startPosition}..$actual->{endPosition}];
		    
		    $temp->addRegion($actual->{sequence},$actual->{startPosition},$actual->{endPosition},\@genes2, $self->{genomes}->[$actual->{sequence}]->{name});
		    
		}
	    }
	    
	    $self->{clusterList}->addCluster2($temp);
	    # hier wird der aufgebaute Cluster in die Ergebnisliste eingetragen
	    
	}
    }
    
    my $clusters = $self->{clusterList}->count();
    
    print STDERR "ready: ".localtime(time())."Found $clusters clusters\n";

}

