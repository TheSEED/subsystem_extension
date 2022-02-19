package SubsystemExtension::ValidationInterface;


use strict;
use warnings;
use FIG;
use Subsystem;
use SubsystemExtension::RoleCandidate;
use SubsystemExtension::SubsystemCandidate;
use SubsystemExtension::VariantAnalysis;

use Data::Dumper;
use CGI;
use constant DEBUG => 1;


=pod

=head1 SubsystemExtension::ValidationInterface

This Class contains a set of methods needed for the validation of the automated subsystem extension 
It validates a SubsystemCandidate
=back

=cut

=pod

this Class encaplsulated functionality to display role candidates and 
offer the user functionality to controll the results and modify the assignments.

=back

=cut

=pod

=head1 new
Constructor:

Params
    subsystem: submit reference to subsystem object or subsystem name 
    organism: organism name (taxon id)
	fig: fig object (optional)

=cut

    1;

sub new {

	my ($class, $fig, $subsystem, $organism , $subsystem_candidate, $parameters) = @_;

	my $self  = {};

	$self->{fig}  = ref $fig ? $fig : FIG->new();
	$self->{subsystem} = ref $subsystem ? $subsystem : $self->{fig}->get_subsystem($subsystem);
	$self->{organism} = $organism;
	$self->{subsystem_candidate} = $subsystem_candidate; # hashref
	# optional parameters

	$self->{header} = $parameters->{header};
	$self->{controller} = $parameters->{controller};

	bless $self, $class;

	print STDERR "created validation interface: \n" if (DEBUG);

	return $self;

	
}


sub html_output {
	my ($self, $cgi) = @_;
	my $q = ref $cgi ? $cgi : CGI->new();

	my $html = $self->{'header'} ? $q->header().
	    $q->start_html(-title=>'SubsystemExtension: ValidationInterface',
			   -author=>'hneuwege@cebitec.uni-bielefeld.de',
			   -base=>'true',
			   -meta=>{'keywords'=>'SEED Subsystem Extension',
				   'copyright'=>'copyright 2005'}
			   ) : '';
	

	$html .= $q->table({-width=>'100%'}, $q->Tr($q->th($q->h2("Validation Interface"))));
	$html .= $q->h3($q->a({-target=>'_blank', -href=>"subsys.cgi?request=show_ssa&user=".$q->param('user')."&ssa_name=".$self->{subsystem}->get_name()},$self->{subsystem}->get_name())." ".$self->{organism}." ".$self->{fig}->genus_species($self->{organism}));
	
	# show the variants...
	
	my $va = SubsystemExtension::VariantAnalysis->new($self->{subsystem});
	$html .= $va->to_html();

	$html .= $q->h4(sprintf "Probably variant %s, role pattern %.2f %% similar to %s", $self->subsystem_candidate()->functional_variant(), $self->subsystem_candidate()->functional_variant_score() * 100,$self->subsystem_candidate()->functional_variant_template()." ".$self->{fig}->genus_species($self->subsystem_candidate()->functional_variant_template()));
	
	my %variants;
	foreach ($self->subsystem()->get_variant_codes()) {
	    $variants{$_} = 1;
	}
 	
	$html .= $q->start_form($self->{controller});
	$html .= "Select variant:".$q->popup_menu(-name=>'variant',
						  -values=>[sort keys %variants],
						  -default=>$self->subsystem_candidate()->functional_variant()
						  );
	$html .= $q->br();
	$html .= $q->input({-type=>'hidden', -value=>$self->{subsystem}->get_name(), -name=>'subsystem'});
	$html .= $q->input({-type=>'hidden', -value=>$self->{organism}, -name=>'genome'});	
	$html .= $q->input({-type=>'hidden', -value=>"add_genome", -name=>'request'});	
	
	$html .= $q->input({-type=>'hidden', -value=>$q->param("user") ? $q->param("user") : 'subsystemextension' , -name=>'user'});
	
	$html .= $self->subsystem_candidate()->to_html($q, $self->{fig});


	$html .= $q->submit(-name=>'assign',
			    -value=>'Just Make Assignments');
	$html .= $q->submit(-name=>'add',
			    -value=>'Add Genome');
	$html .= $q->end_form();
		
	$html .= $self->{'header'} ? $q->end_html() : '';

	return $html;
}

sub subsystem {
	my ($self, $value) = @_;

	return $self->{subsystem} if (scalar(@_) == 1);
	$self->{subsystem} = $value;

}

sub subsystem_candidate {
	my ($self, $value) = @_;

	return $self->{subsystem_candidate} if (scalar(@_) == 1);
	$self->{subsystem_candidate} = $value;
}



    
