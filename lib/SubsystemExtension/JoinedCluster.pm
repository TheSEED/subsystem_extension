package SubsystemExtension::JoinedCluster;


use strict;
use warnings;
use Carp;
use GD;
use CGI;
use base qw(SubsystemExtension::Cluster);
use Data::Dumper;

sub new {

    my ($class, $id, $clusters) = @_;

    my $self;
    $self->{id} = $id;
	$self->{containedGenes} = {};
	$self->{spanSeq} = {};
	$self->{sortedLocations} = [];
    $self->{png} = '';
    $self->{map} = '';
	$self->{subclusters} = $clusters;
	
	bless $self, $class;
	
	foreach my $cluster (@$clusters) {
		foreach ($cluster->containedGenes()) {
			$self->{containedGenes}->{$_} = 1;
		} 
		foreach ($cluster->spannedSequences()) {
			$self->{spanSeq}->{$_} = $cluster->{spanSeq}->{$_};
		} 
		foreach ($cluster->sortedLocations()) {
		   $self->addLocation($_);
		}
	}

  
    return $self;

}



sub containedByGenePercent {
	my ($self, $percent, $larger) = @_;
	my $match = 0;
	foreach (keys %{$self->{containedGenes}}) {
		$match++ if ($larger->{containedGenes}->{$_});
	}

	if ($match / scalar keys %{$self->{containedGenes}} > $percent/100) {
		return 1;
	} elsif  ($match / scalar keys %{$larger->{containedGenes}} > $percent/100) {
		return 1;
	} else {
		return;
	}
	
}

sub _cluster_color {
	my ($self, $im, $family)  = @_;
	
	unless (ref $self->{colors}) {
		$self->_init_cluster_colors($im);
	}

	return $self->{colors}->{$family};
	
}

sub to_table_row {
	my ($self, $cgi) = @_;
	my $html;
	if (ref $cgi && $cgi->isa("CGI")) {
		$html .= $cgi->Tr($cgi->td($cgi->checkbox({-name=>'cluster', -label=>'', -checked=>0, -value=>$self->{id}}).$cgi->a({-href=>$cgi->self_url()."#".$self->{id}},$self->{id})), $cgi->td(scalar keys %{$self->{containedGenes}}),$cgi->td(scalar keys %{$self->{spanSeq}}),$cgi->td(scalar @{$self->{subclusters}}),$cgi->td(join ', ', sort {$a <=> $b} keys %{$self->{containedGenes}}));
		
	} else {
		
		$html .= sprintf ("<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>", $self->{id}, scalar keys %{$self->{containedGenes}},  scalar keys %{$self->{spanSeq}}, scalar @{$self->{subclusters}} , join ', ', sort {$a <=> $b} keys %{$self->{containedGenes}});
	}

	return $html;

}

sub to_string  {

	my ($self) = @_;
	
	my  $erg = "";
	
	my $containedGenesCount = scalar keys %{$self->{containedGenes}};
	my $spanSeqCount = scalar keys %{$self->{spanSeq}};
	$erg .= $self->{id}.":  ";
	$erg .= "#".$self->geneCount()."#  ";
	$erg .= "*".$self->sequencesCount()."*  ";
	foreach  (@{$self->{sortedLocations}}) {
		if (ref $_ eq "HASH") { 
			$erg .= "S".$_->{sequence}." (".$_->{start}.", ".$_->{stop}.") ";
		}
	}
	$erg .= "  Genes: [";
	$erg .= join ', ', $self->containedGenes();
	
	$erg .= "]";

	$erg .= " SubClusters: [";
	$erg .= join ', ', map {$_->{id};} $self->subClusters();
	$erg .= "]\n";

	return $erg;
}


sub subClusters {
	my ($self) = @_;

	if (wantarray) {
		return @{$self->{subclusters}};
	} else {
		return $self->{subclusters};
	}

}


=pod

=head3 addLocation

This function adds a location to those existing in the cluster.
Therefore it checks wheter the new location is already completely
covered by an old one. In this case it is not added to the
list of locations. 
If the location covers existing locations these are removed and the
location is appended to the list.

=cut


sub addLocation {
	my ($self, $location) = @_;
	
	# easy case empty list

	if (scalar @{$self->{sortedLocations}} == 0) {

		push @{$self->{sortedLocations}}, $location;

	} else {

		my $index = 0;

		# iterate through all existing locations and remember the current
		# position in the list.

		foreach my $existing_loc (@{$self->{sortedLocations}}) {
			
			$index++;

			# ignore those that originate from other sequences
			next if ($existing_loc->{sequence} != $location->{sequence});
			
			# ex_loc:  xxxx
			# loc:      xx

			if (($existing_loc->{start} <= $location->{start}) && ($existing_loc->{stop} >= $location->{stop})) {
				
				# we have to do nothing because this location is already present
				return;

			} elsif (($existing_loc->{start} >= $location->{start}) && ($existing_loc->{stop} <= $location->{stop})) {

				# ex_loc:   xx
				# loc:     xxxx

				# groessere location als alte
				# also fliegt die alte raus
				
				my $drop = splice (@{$self->{sortedLocations}}, $index-1 , 1);
				$index--;
			}  elsif (($location->{start} > $existing_loc->{start}) && ($location->{start} <= $existing_loc->{stop})) {
				
                # append the overlapping genes to the existing
				# 
				# ex_loc:   xxxx
				# loc:        xxxx

				

				
				my $diff = $location->{stop} - $existing_loc->{stop};
				my $genes = scalar @{$location->{genes}};
				$existing_loc->{stop} = $location->{stop};
				
				push @{$existing_loc->{genes}}, @{$location->{genes}}[$genes - $diff .. $genes];
				
				return;

			} elsif (($existing_loc->{start} > $location->{start}) && ($existing_loc->{start} <= $location->{stop})) { 
				# prepend the overlapping genes to the existing
				# 
				# ex_loc:    xxxx
				# loc:     xxxx
				
				# the non overlapping genes at the beginning of the new lcation will 
				# be prepended to the existing location
				# diff is the number of non-overlapping genes

				my $diff = $existing_loc->{start} - $location->{start};
				
				$existing_loc->{start} = $location->{start};
				
				unshift @{$existing_loc->{genes}}, @{$location->{genes}}[0..$diff-1];
				

				return;

			}
            # jetzt noch der overlap fall!!!!
			# sollte eine zu mehr als ... in der anderen 
			# vorhanden sein, dann merge die beiden regionen zu einer!
			# finde min start und max stop und hole jeweils die 
			# genes aus den beiden regionen
		}

		push @{$self->{sortedLocations}}, $location;
	}
}


=pod

=head3 addCluster

This function adds the locations of the cluster and thereby joins 
it with this JoinedCluster object. 
The spanned sequences and contained genes are updated/extended as well.

=cut



sub addCluster {

	my ($self, $cluster) = @_;

	push @{$self->{subclusters}}, $cluster;


	foreach ($cluster->containedGenes()) {
		$self->{containedGenes}->{$_} = 1;
	} 
	foreach ($cluster->spannedSequences()) {
		$self->{spanSeq}->{$_} = $cluster->{spanSeq}->{$_};
	} 
	foreach ($cluster->sortedLocations()) {
		$self->addLocation($_);
	}
	
	$self->{geneCount} = scalar keys %{$self->{containedGenes}};
	
	$self->{sequencesCount} = scalar keys %{$self->{spanSeq}};

}


1;
