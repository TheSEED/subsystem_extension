package SubsystemExtension::ClusterView::SVG;


use strict;
use warnings;
use Carp;
use base qw(SubsystemExtension::ClusterView);
use GD::SVG;

use constant GENEWIDTH => 32;
use constant GENEHEIGHT => 12;
use constant SPACING => 5;


sub new {

    my ($class, $cluster) = @_;

    my $self;
    $self->{cluster} = $cluster;

    bless $self, $class;

    return $self;

}


sub cluster {

	my ($self, $value) = @_;

	if ($value) {
		$self->{cluster} = $value;
	} else {
		return $self->{cluster};
	}
}


sub _cluster_color {
	my ($self, $im, $family)  = @_;
	
	unless (ref $self->{colors}) {
		$self->_init_cluster_colors($im);
	}

	return $self->{colors}->{$family};
	
}

sub output {

    my ($self, $cluster) = @_;

	unless ($cluster) {
		$cluster = $self->{cluster};
	}


}



sub _arrow_right {
	
	my ($self, $im, $gene, $x, $y) = @_;


	my $color =  $self->_cluster_color($im, $gene);
	# make a polygon (clockwise, with arrow)
	#  ______
	# |      \
	# |______/


	my $textcolor = $im->colorResolve(0,0,0);

	my $poly = new GD::Polygon;
	$poly->addPt($x, $y);
	$poly->addPt($x+GENEWIDTH,$y);
	$poly->addPt($x+GENEWIDTH+(GENEWIDTH / 5),$y + (GENEHEIGHT /2));
	$poly->addPt($x+GENEWIDTH,$y + GENEHEIGHT);
	$poly->addPt($x,$y + GENEHEIGHT);
	
	# draw the polygon, filling it with a color
	$im->filledPolygon($poly,$color);
	# print the label of the gene family
	$im->string(gdSmallFont, $x + (GENEWIDTH / 4) , $y -2, $gene,$textcolor);

}


sub geneCount {
	

}

sub to_table_row {
	my ($self, $cgi) = @_;
	my $html;
	if (ref $cgi && $cgi->isa("CGI")) {
		$html .= $cgi->Tr($cgi->td($self->{id}), $cgi->td(scalar keys %{$self->{containedGenes}}),$cgi->td(scalar keys %{$self->{spanSeq}}),$cgi->td("-"),$cgi->td(join ', ', sort keys %{$self->{containedGenes}}));
		
	} else {
		
		$html .= sprintf ("<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>", $self->{id}, scalar keys %{$self->{containedGenes}},  scalar keys %{$self->{spanSeq}}, "-" , join ', ', sort keys %{$self->{containedGenes}});
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
	$erg .= join ', ', sort keys %{$self->{containedGenes}};
	
	$erg .= "]\n";

	return $erg;
}

sub _arrow_left {
	
	my ($self, $im, $color, $x, $y) = @_;

	# make a polygon
	my $poly = new GD::Polygon;
	$poly->addPt($x, $y);
	$poly->addPt($x - GENEWIDTH,$y);
	$poly->addPt($x - GENEWIDTH - (GENEWIDTH / 5),$y + (GENEHEIGHT /2));
	$poly->addPt($x - GENEWIDTH,$y + GENEHEIGHT);
	$poly->addPt($x,$y + GENEHEIGHT);
	
	# draw the polygon, filling it with a color
	$im->filledPolygon($poly,$color);
	

}




sub to_imagemap {

}


sub max_genes {
    

}

sub id {

	my ($self) = @_;

    return $self->{id};
}

sub genomes {

    my ($self) = @_;

    if (wantarray) {
		$self->{genomes};
    } else {
		return scalar $self->{genomes};
    }
    
}




sub to_html {

    my $html;


    return $html;

}

sub addRegion {

	my ($self, $sequenceIndex, $start, $stop, $genes) = @_;

	foreach (@$genes) {
		$self->{containedGenes}->{$_} = 1 if ($_ > 0);
	}

	unless (ref  $self->{sortedLocations} eq "ARRAY") {
		$self->{sortedLocations} = [];
	}
	$self->{spanSeq}->{$sequenceIndex} = 1; 

	push @{$self->{sortedLocations}}, {sequence => $sequenceIndex, start => $start, stop => $stop, genes => $genes};

}


1;
