package SubsystemExtension::RoleFamilies;

use lib "/homes/hneuwege/Graph-0.65/blib";


use Graph::Undirected;
use FIG;
use FIG_Config;
use Subsystem;
use Data::Dumper;
use strict;
use warnings;
use Heap::Fibonacci;


sub create_role_graph {
    # unshift @INC, "/homes/hneuwege/Graph-0.65/blib/lib/";
    my ($fig, $subsystem, $role, $evalue_cutoff, $sim_depth) = @_;
    my %instances;
    $evalue_cutoff = $evalue_cutoff ? $evalue_cutoff : 1.0e-20;
    $sim_depth = $sim_depth ? $sim_depth : 250;

    
    foreach ($subsystem->functional_role_instances($role)) {
	$instances{$_} = 1;
    }
    if (scalar keys %instances > 0) {
	my $graph = Graph::Undirected->new();
	foreach my $instance (sort keys %instances) {
	    
	    foreach my $sim (grep {$instances{$_->id2}} $fig->sims($instance, $sim_depth, $evalue_cutoff, "fig")) {
		
		my $weight = ($sim->psc == 0) ? 181 : int(-log($sim->psc));
		$graph->add_weighted_edge($instance, $weight, $sim->id2) unless $graph->has_edge($instance, $sim->id2);
		
	    }
	} 
    
	return $graph
    }

    return -1;
    
}



sub mincut {
    my ($graph, $weight) = @_;
    my $min_cut;
    my $vertex;

    #while ($graph->vertices() > 1) {
	foreach ($graph->vertices()) {
	    print STDERR "$_\n";
	    if ($graph->edges($_) > 0) {
		$vertex = $_;
		last;
	    }
	}
	my $phase_cut = &mincutphase($graph, $weight, $vertex);
	$min_cut = ( $phase_cut < $min_cut ) ? $phase_cut : $min_cut;
	
    #}

    return ($graph, $graph, $min_cut);
}


sub mincutphase {

    my ($graph, $weight, $vertex) = @_;

    my $graph_size = $graph->vertices();


    print STDERR "graph size $graph_size\n";

    my %a;
    my %queue;
    my $last = $vertex;
    my $next;
   
    &update_queue($graph, \%queue, \%a, $vertex);

    my $i = 0;

    while ($i < $graph_size) {
	$i++;
	# get next from the priority queue
	$next =  &get_next_from_queue(\%queue);
	# update the queue and calculate the connected edge weigths to %a
	&update_queue($graph, \%queue, \%a, $next);

	# store the last two vertices that were added;
	$last = $next;
    }
    
    &join_vertices($graph, $last, $next);

    my $cut = [$last, $next];

    return $cut;

}



sub update_queue {
    my ($graph, $queue, $a, $vertex) = @_;

    
    $a->{$vertex} = 1;
    $queue->{$vertex} =0;
    print STDERR "$vertex is added to $a\n";
    #iterate over all neighbours of vertex 
    foreach my $w ($graph->neighbours($vertex)) {
	print STDERR "$w is not in a and connected to $vertex and is increased by $graph->get_edge_weight($vertex, $w)\n";
	
	$queue->{$w} += $graph->get_edge_weight($vertex, $w); # increasw
    }    
    
    return $queue;
    
}


sub get_next_from_queue {

    my ($queue) = @_;

    print STDERR "[getting next from queue]\n";

    my $max =0 ;
    my $next = '';
    foreach (keys %$queue) {
	if ($queue->{$_} > $max) {

	    $max = $queue->{$_};
	    $next = $_;

	    print STDERR "current max: $max\n";
	}
    }
    return $next;
}

sub join_vertices { 
    my ($graph, $v1, $v2) = @_;
    
    print STDERR "[joining $v1, $v2]\n";
    
    return $graph unless ($graph->has_edge($v1, $v2));
    
    my %new_edges;
    foreach ($graph->edges($v1)) {
	$new_edges{$_} = $graph->get_edge_weight($v1, $_);
    }
    foreach ($graph->edges($v2)) {
	$new_edges{$_} += $graph->get_edge_weight($v2, $_);
    }
    print STDERR &Dumper(%new_edges);


    $graph->delete_vertex($v1);
    $graph->delete_vertex($v2);
    
    my %v2_edges;
    
    $graph->add_vertex("$v1,$v2");
    foreach (keys %new_edges) {
	$graph->add_weighted_edge("$v1,$v2", $_, $new_edges{$_});
    }
    

}

sub gnuplot_output {

    my ($graph) = @_;
  
    my $topology = Graph::Layout::Aesthetic::Topology->from_graph($graph);
    # Set up some $topology here, see Graph::Layout::Aesthetic::Toplogy
    my $aglo = Graph::Layout::Aesthetic->new($topology);
    
    # Decide what kind of aesthetic properties we want
    # We want nodes not to close to each other
    $aglo->add_force("node_repulsion");
    # We want edge lengths short
    $aglo->add_force("min_edge_length");
    
    # Do the actual layout and monitor progress (optional)
    $aglo->gloss(monitor => Graph::Layout::Aesthetic::Monitor::GnuPlot->new);
    
    # Display the result
    my $result;
    my $i;
    for ($aglo->all_coordinates) {
	$result .= "Vertex ", $i++, ": @$_\n";
    }
    
    return $result;

}


sub weightedHCS {

    # input: weighted undirected graph representing the role instances as vertexes
    # an -log e-value scores as edge-weights

    my ($graph) = @_;

    my ($h1, $h2, $c) = &mincut($graph);

    my $weight_cutset;
    foreach (@$c) {
	$weight_cutset += $_;
    }
    my $weight_edges;
    map {$weight_edges += $_;} (@$graph->edges);

    my $x = $graph->vertices() *  $weight_cutset / $weight_edges;


    if ($x > ($graph->vertices() / 2)) {
	return $graph;
    } else {
	&weightedHCS($h1);
	&weightedHCS($h2);
    }
}

1;
