package SubsystemExtension::ClusterView::GFX;


use strict;
use warnings;
use Carp;
use SubsystemExtension::Cluster;
use SubsystemExtension::JoinedCluster;

use base qw(SubsystemExtension::ClusterView);
use FIGjs;

use constant GENEWIDTH => 32;
use constant GENEHEIGHT => 12;
use constant SPACING => 5;


sub new {

    my ($class, $cluster) = @_;

    my $self;
    $self->{cluster} = $cluster;
	$self->{map} = '';

    bless $self, $class;

    return $self;

}


sub cluster {

	my ($self, $value) = @_;

	return $self->{cluster} if (scalar(@_) == 1);
	if (ref $value && $value->isa("SubsystemExtension::Cluster")) {
		$self->{cluster} = $value;
		
	} 
	
}


sub _cluster_color {
	my ($self, $family)  = @_;
		
	return $self->{colors}->{$family};
	
}


sub _init_cluster_colors {
    my ($self, $im, $gfx_pkg) = @_;

	$gfx_pkg = "GD" unless $gfx_pkg;
	
	eval "use $gfx_pkg";

    $self->{colors} = {};
    my $index = 0;
    
	foreach my $geneFamily (sort keys %{$self->cluster()->{containedGenes}}) {
		$index++;
		$self->{colors}->{$geneFamily} = $im->colorResolve($index * 221 % 255, 
														   $index * 173 % 255, 
														   $index * 57 % 255);
	}

}

sub _mouseover {

    my ($self, $gene, $genome, $x, $y) = @_;
    
    my $info = '';
	my $action = '';

	if ($gene->{name} && ($gene->{name} =~ /fig/)) {
		$action = '<a href="protein.cgi?prot='.$gene->{name}.'&user=heiko">Show Gene in the SEED</a>';
	}

    foreach (sort {lc $a cmp lc $b} keys %$gene) {
		$info .= "<b>".ucfirst($_).":</b> ".$gene->{$_}."<br/>";
    }
	
    $self->{map} .= sprintf(
		'<area shape="rect" coords="%d, %d, %d, %d" alt="%s" %s/>', 
		$x, $y, $x+GENEWIDTH, $y + GENEHEIGHT, $gene->{family},  
		&FIGjs::mouseover($genome.": ".$gene->{id}, $info, $action ));
}



sub image_map {

	my ($self) = @_;
	return $self->{map};

}


sub _svg_link {
	my ($self, $im, $x, $y) = @_;
	
	

}

sub output {

    my ($self, $gfx_pkg, $q) = @_;
	
	$gfx_pkg = "GD" unless $gfx_pkg;

	# Define some global packages for ease of use
	my $image_class = $gfx_pkg . '::Image';
	my $font_class  = $gfx_pkg . '::Font';
	my $poly_class  = $gfx_pkg . '::Polygon';
	
	eval "use $gfx_pkg";
    
	my $cluster = $self->cluster();


	$self->{map} = '';

    $self->{map} .= '<map name="'.$cluster->{id}.'">';

    my $clusterGeneSize = $cluster->_clusterGeneSize();
    my $clusterGenomeSize = scalar keys %{$cluster->{spanSeq}};
	
    my $im = $image_class->new($clusterGeneSize * (GENEWIDTH + 2 * SPACING) + GENEWIDTH * 2, 
							   $clusterGenomeSize * (GENEHEIGHT * 2 + SPACING) + 33);
    my $map = '';
	
    my $white = $im->colorResolve(255,255,255);
    my $black = $im->colorResolve(0,0,0);
    my $blue = $im->colorResolve(0,0,255);

	$self->_init_cluster_colors($im, $gfx_pkg);
	
    if (($gfx_pkg eq "GD") && $q) {

		$im->string($font_class->Tiny(), $clusterGeneSize * (GENEWIDTH + 2 * SPACING) + GENEWIDTH, 
					$clusterGenomeSize * (GENEHEIGHT * 2  + SPACING) + 20 , 'svg',$black);

		$self->{map} .= sprintf(
			'<area shape="rect" coords="%d, %d, %d, %d" alt="SVG image" href="gecko_cluster_gfx.cgi?download=1&type=svg&cluster=%s&user=%s&session=%s"/>', 
			$clusterGeneSize * (GENEWIDTH + 2 * SPACING) + GENEWIDTH, 
			$clusterGenomeSize * (GENEHEIGHT * 2  + SPACING) + 20, 
			$clusterGeneSize * (GENEWIDTH + 2 * SPACING) + 2 * GENEWIDTH, 
			$clusterGenomeSize * (GENEHEIGHT * 2 + SPACING) + 32,
			$cluster->{id},
			$q->param('user'),
			$q->param('session')
			
		);
	}

		
	

    # iterate the spanning sequences
    # each sequence represents one line

    my $row = 0;
    my $column = 0;

    foreach my $seqIndex (sort keys %{$cluster->{spanSeq}}) {
	$row++;
	$column = 0;
	my $left = 0;
	$im->string($font_class->Tiny(), SPACING, $row * (GENEHEIGHT * 2  + SPACING) - GENEHEIGHT , $cluster->{spanSeq}->{$seqIndex},$black);
	
	foreach my $location (sort {$a->{start} <=> $b->{start}} grep {$_->{sequence} == $seqIndex} @{$cluster->{sortedLocations}}) {
	    
	    $column++;
	    my $gap = $left == 0 ? '| ' : "< ";
		$gap .=	$location->{start} - $left -1;
	    # paint the left gap
	    $im->string($font_class->Tiny(), $column * (GENEWIDTH + 2 * SPACING), $row * (GENEHEIGHT * 2 + SPACING) + 2 ,$gap." >" ,$black);
	    my $index = $location->{start};
	    foreach my $gene (@{$location->{genes}}) {
			$column++;
			# paint the genes with their cluster color
			
			$self->_mouseover($gene, $cluster->{spanSeq}->{$seqIndex},  $column * (GENEWIDTH + 2 * SPACING), $row * (GENEHEIGHT * 2 + SPACING) );
			
			$self->_arrow($im, $gene, $column * (GENEWIDTH + 2 * SPACING), $row * (GENEHEIGHT * 2  + SPACING), $gfx_pkg);
			$index++;
	    }
	    
	    $left = $location->{stop};
	}
	$column++;
	# paint the right gap $geneCount - $left


	$im->string($font_class->Tiny(), $column * (GENEWIDTH + 2 * SPACING), $row * (GENEHEIGHT * 2 + SPACING) + 2, "< ".($left + 1)." |" ,$black);
	
}
    my $format = ($gfx_pkg eq 'GD::SVG') ? 'svg' : 'png';

	$self->{map} .= '</map>';
   
    
	return $im->$format();
    
}



sub _arrow {
    
    my ($self, $im, $gene, $x, $y, $gfx_pkg) = @_;

	$gfx_pkg = "GD" unless $gfx_pkg;

	# Define some global packages for ease of use
	
	my $font_class  = $gfx_pkg . '::Font';
	my $poly_class  = $gfx_pkg . '::Polygon';
	
	eval "use $gfx_pkg";

    my $color =  $self->_cluster_color($gene->{family});    
	my $black	= $im->colorResolve(0,0,0);
	my $white = $im->colorResolve(255,255,255);

    my $poly = new $poly_class;
    
    # make a polygon (clockwise, with arrow)
    # 1______
    # |      \
    # |______/

    
    if ($gene->{strand} == 1) {
		$poly->addPt($x, $y);
		$poly->addPt($x+GENEWIDTH,$y);
		$poly->addPt($x+GENEWIDTH+(GENEWIDTH / 5),$y + (GENEHEIGHT /2));
		$poly->addPt($x+GENEWIDTH,$y + GENEHEIGHT);
		$poly->addPt($x,$y + GENEHEIGHT);
    } else {
		# make a polygon (clockwise, with arrow left)
		#   ______
		# 1/      |
		#  \______|
		
		$poly->addPt($x, $y + (GENEHEIGHT /2));
		$poly->addPt($x+(GENEWIDTH/5),$y);
		$poly->addPt($x+GENEWIDTH+(GENEWIDTH / 5),$y);
		$poly->addPt($x+GENEWIDTH+(GENEWIDTH / 5),$y + GENEHEIGHT);
		$poly->addPt($x+(GENEWIDTH/5),$y + GENEHEIGHT);
    }
    
    
    # draw the polygon, filling it with a color

    $im->filledPolygon($poly,$color); # fill
    $im->polygon($poly,$black); #outline the polygon

	my ($r,$g,$b) = $im->rgb($color);
	
    # print the label of the gene family

	my $textcolor = ($r + $g + $g < 256) ? $white : $black;
	my $label = ($gene->{genename} && ($gene->{genename} ne '----'))  ? 
		$gene->{genename} :
		$gene->{family};
    
	$im->string($font_class->Small(), 
				$x + (GENEWIDTH / 5) , 
				$y, 
				$label, 
				$textcolor);

	
}

1;
