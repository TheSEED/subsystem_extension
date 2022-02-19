package SubsystemExtension::Cluster;


use strict;
use warnings;
use Carp;
use Data::Dumper;
use Storable qw (nstore retrieve);

use constant GENEWIDTH => 32;
use constant GENEHEIGHT => 12;
use constant SPACING => 5;


sub new {

    my ($class, $id) = @_;

    my $self;
    $self->{id} = $id;
    $self->{containedGenes} = {};
    $self->{spanSeq} = {};
    $self->{sortedLocations} = [];
    $self->{map} = '';
    $self->{joined} = 0;
    # $self->{sequences} = $sequences;

    bless $self, $class;

    return $self;

}


sub hasSequence {
    my ($self, $seq) = @_;

    return $self->{spanSeq}->{$seq};

}


sub hasGene {
    my ($self, $gene) = @_;

    return $self->{containedGenes}->{$gene};

}

sub containedIn {

    # testet ob self in cluster enthalten ist
    # d.h. alle self sequences, genes und locations muessen auch in cluster sein!
    my ($self, $cluster) = @_;
    
    # zwei direkte abbruchbedingungen:
    # $self hat mehr sequenzen oder $self hat mehr gene!

    return 0 if ($self->{sequencesCount} > $cluster->{sequencesCount});
    
    return 0 if ($self->{geneCount} > $cluster->{geneCount});

    # abbruch wenn eine sequenz in $self nicht in $cluster ist1
    
    foreach ($self->spannedSequences()) {
		return 0 unless ($cluster->hasSequence($_));
    }

    # abbruch wenn ein gen in $self nicht in $cluster ist!

    foreach ($self->containedGenes()) {
		return 0 unless ($cluster->hasGene($_));
    }

    foreach my $location (@{$self->{sortedLocations}}) {
	
		# diese location ist erstmal nicht vorhanden!
		my $present = 0;
		# iteriere ueber alle locations des zweiten clusters und vergleiche
		# die locations
		foreach my $cluster_location (@{$cluster->{sortedLocations}}) {
			
			if (($location->{sequence} == $cluster_location->{sequence}) && 
				($location->{start} >= $cluster_location->{start}) &&
				($location->{stop} <= $cluster_location->{stop})) {
				$present = 1;
				last;
			}
		}
		return 0 unless $present;

    }

    return 1;
}


sub containedByElement {
    
    my ($self, $larger) = @_;

    # tests if all the own genes are contained in larger 

    return if ($self->geneCount() > $larger->geneCount());
    
    
    foreach ($self->containedGenes()) {
	return unless $larger->{containedGenes}->{$_};
    }

    return 1;
}

sub containedByGenePercent {
    my ($self, $percent, $larger) = @_;
    my $match = 0;

    foreach (keys %{$self->{containedGenes}}) {
	$match++ if ($larger->{containedGenes}->{$_});
    }
	
    if ($match / scalar keys %{$self->{containedGenes}} > $percent/100) {
		return 1;
    } elsif  ($match / scalar keys %{$larger->{containedGenes}} > ($percent/100)) {
		return 1;
    } else {
		return 0;
    }
    
}

sub toFile {

    my ($self, $filename) = @_;

    nstore $self, $filename;
    
}

sub fromFile {
    my ($class, $filename) = @_;
    
    my $self;

    $self = retrieve $filename;
    
    return $self;
}


sub _clusterGeneSize {
    my ($self) = @_;

    my %width;
    
    foreach my $location (@{$self->{sortedLocations}}) {
	
	$width{$location->{sequence}} += scalar @{$location->{genes}} + 1; # + 1 because of gap!
    }

    my $max = 0;

    foreach (values %width) {
		$max = $_ if ($_ > $max);
    }

    return $max + 1; #+ 1 because of last gap number
}





sub geneCount {
    my ($self) = @_;

    return  scalar keys %{$self->{containedGenes}};
   
	unless ($self->{geneCount}) {
		$self->{geneCount} = scalar keys %{$self->{containedGenes}};
	}
	
	return $self->{geneCount};
 
}

sub sequencesCount {
    my ($self) = @_;
	
	unless ($self->{sequencesCount}) {
		$self->{sequencesCount} = scalar keys %{$self->{spanSeq}};
	}
	
    return $self->{sequencesCount};
    
}

sub containedGenes {

    my ($self) = @_;

    my @genes = sort {$a <=> $b} keys %{$self->{containedGenes}};

    if (wantarray) {
		return @genes;
    }  else {
		return \@genes;
    }
}

sub spannedSequences {
    my ($self) = @_;
    
    my @seqs = sort {$a <=> $b} keys %{$self->{spanSeq}};
    
    if (wantarray) {
		return @seqs;
    }  else {
		return \@seqs;
    }
}

sub all_genes {
    my ($self, $genome) = @_;
    
    my @genes;
    foreach my $location (@{$self->{sortedLocations}}) {
	foreach my $gene (@{$location->{genes}}) {
	    # print STDERR &Dumper($gene);
	    push @genes, $gene;
	}
    }
    
    return @genes;
}

sub sortedLocations {

    my ($self) = @_;
        
    if (wantarray) {
		return @{$self->{sortedLocations}};
    }  else {
		return $self->{sortedLocations};
    }

}


sub to_table_row {
    my ($self, $cgi) = @_;
    my $html;
    if (ref $cgi && $cgi->isa("CGI")) {
	$html .= $cgi->Tr($cgi->td($cgi->checkbox({-name=>'cluster', -label=>'', -checked=>0, -value=>$self->{id}}).$cgi->a({-href=>$cgi->self_url()."#".$self->{id}},$self->{id})), $cgi->td(scalar keys %{$self->{containedGenes}}),$cgi->td(scalar keys %{$self->{spanSeq}}),$cgi->td("-"),$cgi->td(join ', ', sort {$a <=> $b} keys %{$self->{containedGenes}}));
	
    } else {
	
		$html .= sprintf ("<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>", $self->{id}, scalar keys %{$self->{containedGenes}},  scalar keys %{$self->{spanSeq}} , join ', ', sort {$a <=> $b} keys %{$self->{containedGenes}});
    }
	
    return $html;

}

sub to_string  {

    my ($self) = @_;
    
    my  $erg = "";
    
    my $containedGenesCount = scalar keys %{$self->{containedGenes}};
    my $spanSeqCount = scalar keys %{$self->{spanSeq}};
    $erg .= $self->{id}.":  ";
    $erg .= "#".$containedGenesCount."#  ";
    $erg .= "*".$spanSeqCount."*  ";
    foreach  (@{$self->{sortedLocations}}) {
	if (ref $_ eq "HASH") { 
	    $erg .= "S".$_->{sequence}." (".$_->{start}.", ".$_->{stop}.") ";
	}
    }
    $erg .= "  Genes: [";
    $erg .= join ', ', sort {$a <=> $b} keys %{$self->{containedGenes}};
    
    $erg .= "]\n";

    return $erg;
}

sub id {

    my ($self) = @_;

    return $self->{id};
}

sub genomes {

    my ($self) = @_;

    my %genomes;
    
    foreach my $location (@{$self->{sortedLocations}}) {
	foreach my $gene (@{$location->{genes}}) {
	    if ($gene->{name} =~ /fig\|(\d+\.\d+)\./) {
		$genomes{$1} = 1;
		last;
	    }
	}
    }
    
    return keys %genomes;

    
}





sub addRegion {
	
    my ($self, $sequenceIndex, $start, $stop, $genes, $sequenceName) = @_;
	
    foreach (@$genes) {
		$self->{containedGenes}->{$_->{family}} = 1 if ($_->{family} && ($_->{family} > 0));
    }
	
    unless (ref  $self->{sortedLocations} eq "ARRAY") {
		$self->{sortedLocations} = [];
    }
	
    $self->{spanSeq}->{$sequenceIndex} = $sequenceName ? $sequenceName : 1; 
    
    push @{$self->{sortedLocations}}, {sequence => $sequenceIndex, start => $start, stop => $stop, genes => $genes};
	
	@{$self->{sortedLocations}} = sort {$a->{start} <=> $b->{start}} @{$self->{sortedLocations}};
	
	$self->{geneCount} = scalar keys %{$self->{containedGenes}};
	
	$self->{sequencesCount} = scalar keys %{$self->{spanSeq}};

}


1;
