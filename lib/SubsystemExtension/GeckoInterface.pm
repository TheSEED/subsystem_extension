package SubsystemExtension::GeckoInterface;


use strict;
use warnings;
use FIG;
use Subsystem;
use ClusterDetection;
use Data::Dumper;
use CGI;
use constant DEBUG => 1;


=pod

=head1 SubsystemExtension::GeckoInterface

This Class contains a set of methods needed for the interactive cluster detection

=back

=cut

=pod

this Class encaplsulated functionality to display genes included in predicted clusters


=back

=cut

=pod

=head1 new
Constructor:

Params


=cut

    1;

sub new {

    my ($class, $fig, $parameters) = @_;
    
    my $self  = {};
    
    $self->{fig}  = ref $fig ? $fig : FIG->new();
    $self->{header} = $parameters=>{header};
    $self->{controller} = $parameters->{controller};
    
    bless $self, $class;
    
    print STDERR "created extension interface: \n" if (DEBUG);
    
    return $self;
     
}



sub organism_selection {}

sub html_output {
	my ($self) = @_;
	my $q = CGI->new();

	my $html = $self->{'header'} ? $q->header().
	    $q->start_html(-title=>'Gecko: NetInterface',
			   -author=>'hneuwege@cebitec.uni-bielefeld.de',
			   -base=>'true',
			   -meta=>{'keywords'=>'SEED Subsystem Extension Gecko',
				   'copyright'=>'copyright 2005'}
			   ) : '';
	

	$html .= $q->h3("Gecko: NetInterface");
	$html .= $q->h4($self->{subsystem}->get_name() ." ".$self->{organism});
	

	$html .= $q->h5("Probaly variant ".$self->subsystem_candidate()->functional_variant()." score ".$self->subsystem_candidate()->functional_variant_score()." similar to ".$self->subsystem_candidate()->functional_variant_template());
	$html .= $q->start_form($self->{controller});
	$q->input({-type=>'hidden', -value=>$self->{subsystem}->get_name(), -name=>'subsystem'});
	$q->input({-type=>'hidden', -value=>$self->{organism}, -name=>'genome'});	
	$q->input({-type=>'hidden', -value=>"add_genome", -name=>'request'});	
	
	$html .= $self->subsystem_candidate()->to_html();


	$html .= $q->submit(-name=>'assign',
			    -value=>'Just Make Assignments');
	$html .= $q->submit(-name=>'extend',
			    -value=>'Add Genome');
	$html .= $q->end_form();
		
	$html .= $self->{'header'} ? $q->end_html() : '';

	return $html;
}


sub doAssignment {
    my ($self, $q) = @_;
  

}
    
