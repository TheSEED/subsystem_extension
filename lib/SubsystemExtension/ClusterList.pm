package SubsystemExtension::ClusterList;


use strict;
use warnings;
use Carp;
use Data::Dumper;
use CGI;
use integer;
use SubsystemExtension::Cluster;
use Storable qw (nstore retrieve);


use constant DEBUG => 0;
no warnings qw(redefine);


sub new{

    my ($class) = @_;

    my $self = {
	list => [],
	count => 0
	    
	};

    bless $self, $class;

    return $self;
}


sub joinClusters {

    my ($self, $percent) = @_;

    $percent = 75 unless $percent;
    
    my $joinedIndex; 
    my $index = 0;

	# for each cluster in the list that has not been joined ...

    foreach my $current (@{$self->{list}}) {
	

		# check if it is not yet joined to a larger cluster
		if (ref $current && $current->isa("SubsystemExtension::Cluster")  && !$current->{joined}) {
			my @joines;
			push @joines, $current;

			# collect all clusters that share more than $percent of their
			# contained genes. This may mean that the larger contains
			# more than $percent of the current or the other way around
			
			foreach my $larger (@{$self->{list}}[$index+1..$self->count()-1]) {
				
				if (ref $larger 
					&& $larger->isa("SubsystemExtension::Cluster") 
					&& !$larger->{joined} 
					&& ($current->containedByGenePercent($percent, $larger) || $larger->containedByGenePercent($percent, $current))) {
					
					push @joines, $larger;
					
					$larger->{joined} = 1;
					$current->{joined} = 1;
					# mark this cluster as 'joined'
					# the cluster will be ignored in the remaining iterations
				}
			}
			
			# create joined cluster if list @joines contains more than one entry

			if (scalar @joines > 1) {
				$joinedIndex++;
				my $clustercount = scalar @joines;
				my $joinedCluster = SubsystemExtension::JoinedCluster->new($joinedIndex, \@joines);

				push @{$self->{list}}, $joinedCluster;
				$current->{joined} = 1;
				
			}
		}
		$index++;
    }



    my @list = grep {!$_->{joined}} @{$self->{list}};
	$self->{list} = \@list;

	$self->{count} = scalar @{$self->{list}};

}

sub clusters {

    my ($self, $sort) = @_;

    my @result;
    
    if ($sort) {
		
		if ($sort eq "genes_asc") {
			@result = sort {$a->geneCount() <=> $b->geneCount() or $a->sequencesCount() <=> $b->sequencesCount() } @{$self->{list}}; 
		} elsif($sort eq "genes_desc") {
			@result = sort {$b->geneCount() <=> $a->geneCount() or $b->sequencesCount() <=> $a->sequencesCount()} @{$self->{list}}; 
		} elsif($sort eq "genomes_asc") {
			@result = sort {$a->sequencesCount() <=> $b->sequencesCount() or $a->geneCount() <=> $b->geneCount()} @{$self->{list}}; 
		} elsif($sort eq "genomes_desc") {
			@result = sort {$b->sequencesCount() <=> $a->sequencesCount() or $b->geneCount() <=> $a->geneCount()} @{$self->{list}}; 
		} elsif($sort eq "id_asc") {
			@result = sort {$a->id() cmp $b->id()} @{$self->{list}}; 
		} elsif($sort eq "id_desc") {
			@result = sort {$b->id() cmp $a->id()} @{$self->{list}}; 
		}
		

		if (wantarray) { 
			return @result;
		} else {
			return \@result;
		}
		
    } else {

		if (wantarray) {
			return @{$self->{list}};
		} else {
			return $self->{list};
		}
    }

}


sub joinedCount {
    my ($self) = @_;

    my $joinedCount = 0;

    foreach (@{$self->{list}}) {
		$joinedCount++ if ($_->isa("SubsystemExtension::JoinedCluster"));
	}

    return $joinedCount;

}

sub count {

    my ($self) = @_;

    return $self->{count};
}


sub clusterAt {

    my ($self, $index) = @_;

    return $self->{list}->[$index];

}

sub deleteCluster {
    
    my ($self, $index) = @_;

    print STDERR "deleting cluster $index\n" if (DEBUG);

    splice (@{$self->{list}}, $index, 1);

    $self->{count} = scalar @{$self->{list}};
    
    return $self->{count};

}

sub addCluster2 {
    
    my ($self, $cluster) = @_;
    
    my $skip = 0;
    
    foreach my $list_cluster (@{$self->{list}}) {
		if ($cluster->containedIn($list_cluster)) {
			$skip = 1;
			last;
		}
    }
	
    if  ($skip == 0) {
		push @{$self->{list}}, $cluster;
		$self->{count} = scalar @{$self->{list}};
    }
    
    return $self->{count};
    

}

sub addCluster {
    my ($self, $cluster) = @_;
    
    my $go  = 1;
    my $add = 1;
    my $state =0;
    my $index = 0;

    while  ($go && ($index < scalar @{$self->{list}})) {
		my $comp_cluster = $self->{list}->[$index];
		$state = 1 if ($comp_cluster->sequencesCount() > $cluster->sequencesCount());
		$state = 2 if ($comp_cluster->sequencesCount() < $cluster->sequencesCount());
		$state = 3 if ($comp_cluster->geneCount() > $cluster->geneCount()) && ($state == 2);
		$state = 1 if ($comp_cluster->geneCount() > $cluster->geneCount()) && ($state == 0);
		$state = 3 if ($comp_cluster->geneCount() < $cluster->geneCount()) && ($state == 1);
		$state = 2 if ($comp_cluster->geneCount() < $cluster->geneCount()) && ($state == 0);
		
	
	
	if ($state == 0) {
	    if ($cluster->containedIn($comp_cluster)) {
			
			$go = 0;  # den cluster gibts schon
			$add = 0;
	    } elsif ($comp_cluster->containedIn($cluster)) { 
			
			splice (@{$self->{list}}, $index, 1);
			# $_ = undef; # der cluster is groesser als ein bestehender
			# deswegen den alten loeschen und add auf 1 lassen!
	    } else {
			$index ++;
	    }
	} elsif ($state == 1) {
	    if ($cluster->containedIn($comp_cluster)) { 
			$go = 0; # den cluster gibts schon!
			$add = 0;
	    } else {
			$index++;
	    }
	} elsif ($state == 2) {
	    if ($comp_cluster->containedIn($cluster)) { 
			splice (@{$self->{list}}, $index, 1);
	    } else {
			$index++;
	    }
	} elsif ($state == 3) {
	    $index++;
	}

}
    
    if ($add == 1) {
	push @{$self->{list}}, $cluster;

    }
    
    $self->{count} = scalar @{$self->{list}};
    
    return $self->{count};

}



sub to_html_table {
    my ($self, $q, $count) = @_;
    
    $q = new CGI unless $q;

    $count = $count ? $count : 1;

    my $html;
    
    my $myself = $q->self_url();

    # remove the sorts
    $myself =~ s/sort=[^&;]+[&;]?//g;

    $html .= $q->start_table();
    $html .= $q->Tr($q->td({-colspan=>6}, $q->h3($self->count()." clusters detected")));

    $html .= $q->Tr($q->th("ID".$q->a({-href=>$myself."&sort=id_asc"}, $q->img({-src=>"/asc.png", -border => 0, -title=>"Sort ascending", -alt=>"Sort ascending"})).$q->a({-href=>$myself."&sort=id_desc"}, $q->img({-src=>"/desc.png", -border => 0, -title=>"Sort descending", -alt=>"Sort descending"}))), 
		    $q->th("# Genes ".$q->a({-href=>$myself."&sort=genes_asc"}, $q->img({-src=>"/asc.png", -border => 0, -title=>"Sort ascending", -alt=>"Sort ascending"})).$q->a({-href=>$myself."&sort=genes_desc"}, $q->img({-src=>"/desc.png", -border => 0, -title=>"Sort descending", -alt=>"Sort descending"}))), 
		    $q->th("# Genomes ".$q->a({-href=>$myself."&sort=genomes_asc"}, $q->img({-src=>"/asc.png", -title=>"Sort ascending", -border => 0})).$q->a({-href=>$myself."&sort=genomes_desc"}, $q->img({-src=>"/desc.png", -title=>"Sort descending", -border => 0}))), 
		    $q->th("# SubClusters"), 
		    $q->th("Gene families")
		    );
    

    foreach my $cluster (@{$self->clusters($q->param('sort'))}[0..$count]) {
	$html .= $cluster->to_table_row($q);
    }
    $html .= $q->end_table();
    
    return $html;
	
}


sub toFile {

    my ($self, $filename) = @_;
    
    nstore $self, $filename;
    
}

sub fromFile {

    my ($class, $filename) = @_;
    
    my $self;
    
    # $self = do $filename;
    $self = retrieve $filename;
    
    return $self;
}

1;
