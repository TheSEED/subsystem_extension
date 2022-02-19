package SubsystemExtension::ExtensionInterface::SEED;


use strict;
use warnings;
use FIG;
use Subsystem;
use SubsystemExtension::RoleCandidate;
use SubsystemExtension::SubsystemCandidate;
use SubsystemExtension::SubsystemCandidateFactory::GENDB;
use SubsystemExtension::ValidationInterface;
use Data::Dumper;
use CGI;
use constant DEBUG => 1;

use GPMS::Application_Frame::GENDB;

# default name for this type of generic tools
use constant DEFAULT_TOOL_NAME => 'SubsystemExtension';

# use base qw(SubsystemExtension::ExtensionInterface);

=pod

=head1 SubsystemExtension::ExtensionInterface::

This Class is a concrete implementation of the interactive subsystem extension interface

=back

=cut

=pod

this class encaplsulated functionality to display organisms included and missing in subsystems

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

	my ($class, $q, $fig, $master, $parameters) = @_;

	my $self  = {};

	$self->{fig}  = ref $fig ? $fig : FIG->new();

	my $gendbAppFrame = GPMS::Application_Frame::GENDB->new('hneuwege' , '2refu$e');

	$gendbAppFrame->project('GENDB_GC_Startpred');

	$self->{gendb_master} = ref $master ? $master : $gendbAppFrame->application_master();

	$self->{header} = $parameters->{header};
	$self->{controller} = $parameters->{controller};
	$self->{cgi} = $q ? $q : new CGI;
	
	bless $self, $class;

	print STDERR "created extension interface: \n" if (DEBUG);

	return $self;


}


sub output {

   my ($self, $q) = @_;

   $q = $q ? $q : $self->{cgi};
 
   my $html = $self->_header();
   
   $html .= $self->_title();

   if (!$q->param('user')) {
       $html .= $self->login(); 
   } elsif (!$q->param('subsystem')) {
       $html .= $self->subsystem_selection();
   } elsif (!$q->param('project')) {
       $html .= $self->project_selection();
   } elsif (!$q->param('genome')) {
       $html .= $self->organism_selection();
   } elsif ($q->param('extend')) {
       $html .= $self->extension();
   } elsif ($q->param('assign')) {
       $html .= $self->assignment();
   } elsif ($q->param('add')) {
       $html .= $self->addition();
   }

   $html .= $self->_footer()

}


sub _css {

    my $css_definition = "
body {font-family: Verdana, Arial, Helvetica, sans-serif; font-size: 12px; color: #333333; background-color: #FFFFFF} 

body.login {font-family: Verdana, Arial, Helvetica, sans-serif; font-size: 12px; color: #333333; background-color: #FFFFFF} 

th {font-family: Verdana, Arial, Helvetica, sans-serif; font-size: 12px; color: #333333; background-color: #DDDDDD}

td {font-family: Verdana, Arial, Helvetica, sans-serif; font-size: 12px; color: #333333}

td:highlight1 {background-color: #E6F3FF}
td:highlight2 {background-color: #CEE7F1}
td:highlight3 {background-color: #6495ED}


table {border-spacing:1px; background-color: #EEEEEE; }

.nicetable { border-spacing:1px; background-color: #EEEEEE; }

td:nicetable { background-color: #E6F3FF }
tr:nicetable { background-color: #FDFDFD }

li {color: #339966; list-style-type: square}

ul {color: #339966; list-style-type: square}

ol {color: #339966}

h4.login {color: #8F8F98}

li.login {color: #AD4C4C; list-style-type: square}

ul.login {color: #AD4C4C; list-style-type: square}

ol.login {color: #AD4C4C}


.highlight1 {background-color: #e6e6d9}
.highlight2 {background-color: #ddddcf}
.highlight3 {background-color: #6495ED}

.error { font-weight:bold; color: #FF0000}


.mytext {font-family: Verdana, Arial, Helvetica, sans-serif; font-size: 14px; color: #437AA6 background-coloe: #FFFFFF}


a.mytext:link {color: #333333; text-decoration: none; background-color: #EEEEFF}

a.mytext:visited {color: #666666; text-decoration: none}

a.mytext:active {color: #333333; text-decoration: none; background-color: #EEEEFF}

a.mytext:hover {color: #999933; text-decoration: none; background-color: #EEEEFF}";

		    return $css_definition;


}


sub _error {

    my ($q, $message) = @_;
    
    return $q->p($message);

}

sub _header {
    my ($self, $q) = @_;

    $q = $q ? $q : $self->{cgi};
    
    my $html = $self->{'no_header'} ? '' : $q->header() ;

    $html .= $q->start_html(-title=>'Subsystem Extension Web Interface',
			    -author=>'hneuwege@cebitec.uni-bielefeld.de',
			    -base=>'true',
			    -meta=>{'keywords'=>'GENDB Subsystem Extension',
				    'copyright'=>'Copyright 2005'},
			    -style=>{'type'=>"text/css", 'code'=>&_css()}
			    );
    
    return $html;

}

sub _footer {

    my ($self, $q) = @_;
    
   $q = $q ? $q : $self->{cgi}; 
    
    my $html = $q->end_div(),$q->end_html();

    return $html;

}



sub _title {
    my ($self, $q) = @_;

    $q = $q ? $q : $self->{cgi};

    
    my $html = $q->start_div({-style=>"height:80px;padding-left:15px;padding-right:15px;"});
    $html .= $q->table({-class =>'nicetable',-width =>'100%'},
		       $q->Tr({-class=>'highlight3'},
			      $q->td( $q->h2("Subsystem Extension Web Interface"))
			      )
		       );
    $html .= $q->end_div();

    $html .= $q->start_div({-style=>"height:400px;padding-left:15px;padding-right:15px;"});

    return $html;
}


sub login {

    my ($self, $q) = @_;

    $q = defined $q ? $q : $self->{cgi};
    
    my $html = $q->start_form({-action => $q->url(), -method => 'post'});
    $html .= $q->table({-class =>'nicetable',-width =>'100%'},
		       $q->Tr({-class=>'highlight3'},$q->td( $q->h3("User Login"))),
		       $q->Tr($q->td($q->input({-type => 'text', -name => 'user'}))),
		       $q->Tr({-class=>'highlight3'},$q->td( $q->h3("User Password"))),
		       $q->Tr($q->td($q->input({-type => 'password', -name => 'password'}))),
		       $q->Tr($q->td($q->submit({-name=>'login_extension', -value=>'Login'})))
		       ).$q->end_form();

    return $html;

}

sub subsystem_selection {

    # this method will generate a drop down element integrated into a formated
    # html table that presents the subsystem that are acessible to the user

    my ($self, $q) = @_;

    $q = $q ? $q : $self->{cgi};

    my $html;

    my @subsystems = $self->{fig}->all_subsystems();
    
    $html .= $q->start_form({-action => $q->url(), -method => 'post'});
    $html .= $q->table({-class =>'nicetable',-width =>'100%'},
		       $q->Tr({-class=>'highlight3'},$q->td( $q->h3("Subsystems"))),
		       $q->Tr($q->td(
				     $q->hidden(-name => 'request', -value => 'extend_ssa', -override => 1),
				     $q->hidden(-name => 'user', -value => $q->param('user'), -override => 1),
				     $q->scrolling_list( -name   => 'subsystem',
							 -values => [sort @subsystems],
							 -size   => 10 ))),
		       
		       $q->Tr($q->td(
				     $q->submit({-name=>'seed_extension', -value=>'Extend subsystem'})))
		       );
    $html .= $q->end_form();

    return $html;

}


sub project_selection {
    my ($self, $q) = @_;

    $q = defined $q ? $q : $self->{cgi};
    
    my $html = $q->start_form({-action => $q->url(), -method => 'post'});
    $html .= $q->table({-class =>'nicetable',-width =>'100%'},
		       $q->Tr({-class=>'highlight3'},$q->td( $q->h3("Project"))),
		       $q->Tr($q->td($q->input({-type => 'text', -name => 'project'}))),
		       $q->Tr($q->td($q->submit({-name=>'project_selection', -value=>'Select'})))
		       ).$q->end_form();

    return $html;

}

sub organism_selection {

    my($self, $q) = @_;

    $q = $q ? $q : $self->{cgi};

    my($genome,%known_hits);

    my $subsystem = $self->{fig}->get_subsystem($q->param('subsystem'));

    

    unless (ref $subsystem && $subsystem->isa("Subsystem")) {
	return &_error($q, "Could not initilaize subsystem ".$q->param('subsystem')."!");
    }

    my %in = map { $_ => 1 } $subsystem->get_genomes;

    my $included = scalar keys %in;

    my @out = grep { ! $in{$_} } grep { $_ !~ /^99999/ } $self->{fig}->genomes("complete");

    my $missing = scalar @out;

    #foreach $genome (@out)
    #{
    #	$known_hits{$genome} = &known_hits($self->{fig},$genome,\@roles);
    #}

    # @out = sort { ($known_hits{$b} <=> $known_hits{$a}) or ($a cmp $b) } @out;

    my $html;

    $html .= $q->start_form(-action => $q->url(), -method => 'post');
    
    my %out_labels;
    foreach (@out) {
	$out_labels{$_} = "$_: ".$self->{fig}->genus_species($_)." [" . $self->{fig}->genome_domain($_)."]";
    }	
    

    $html .= $q->hidden(-name => 'subsystem', -value => $q->param('subsystem'), -override => 1);
    $html .= $q->hidden(-name => 'user', -value => $q->param('user'), -override => 1);
    $html .= $q->table({-class =>'nicetable',-width =>'100%'},
		       $q->Tr({-class=>'highlight3'},$q->td( $q->h3("Genomes not included in Subsystem ". $subsystem->get_name()))),
		       $q->Tr($q->td( "$missing genomes missing in subsystem")), 
		       $q->Tr($q->td(
				     $q->scrolling_list( -name   => 'genome',
							 -values => [ sort {$self->{fig}->genus_species($a) cmp $self->{fig}->genus_species($b);}  @out ],
							 -size   => 10,
							 -labels => \%out_labels
							 ),
				     )),
		       $q->Tr($q->td( "Scoring mechanism:")), 
		       $q->Tr($q->td($q->scrolling_list( -name   => 'scoring', -values => ['default'], -size => 1 ))),

		       $q->Tr($q->td($q->submit({-name => 'extend'}, 'Pick a Genome to add' )))
		       );
    $html .= $q->end_form();
    $html .= $q->hr();


    my %in_labels;
    foreach (keys %in) {
	$in_labels{$_} = "$_: ".$self->{fig}->genus_species($_)." [" . $self->{fig}->genome_domain($_)."]";
    }
    $html .= $q->start_form(-action => $q->url(), -method => 'post');
    $html .= $q->hidden(-name => 'subsystem', -value => $q->param('subsystem'), -override => 1);
    $html .= $q->hidden(-name => 'user', -value => $q->param('user'), -override => 1),
    $html .= $q->table({-class =>'nicetable',-width =>'100%'},
		       $q->Tr({-class=>'highlight3'},$q->td( $q->h3("Genomes in Subsystem ". $subsystem->get_name()))),
		       $q->Tr($q->td( "$included genomes annotated in subsystem")), 
		       $q->Tr($q->td(
				     $q->scrolling_list( -name   => 'genome',
							 -values => [ sort {$self->{fig}->genus_species($a) cmp $self->{fig}->genus_species($b);} keys %in ],
							 -size   => 10,
							 -labels => \%in_labels
							 ))),
		       $q->Tr($q->td( "Scoring mechanism:")), 
		       $q->Tr($q->td($q->scrolling_list( -name   => 'scoring', -values => ['default'], -size => 1 ))),

		       $q->Tr($q->td($q->submit({-name => 'extend'},'Pick a Genome to complete' )))
		       );      
    
    $html .= $q->end_form();
    
    return $html;

}


sub extension {

    my ($self, $q) = @_;

    $q = $q ? $q : $self->{cgi};

    my $subsystem = $self->{fig}->get_subsystem($q->param('subsystem'));
    my $extension = SubsystemExtension::SubsystemCandidateFactory::GENDB->new($subsystem);

    my $html;

    unless (ref $extension) {
	$html = &_error($q, "Could not initialize a SubsystemCandidateFactory object for the subsystem");
    } else {


	print STDERR "in extension $subsystem $extension created\n";
	
	if (ref $extension && $extension->isa("SubsystemExtension::SubsystemCandidateFactory")) {
	    my $candidates = $extension->generate([$q->param('genome')]);
	    
	    foreach (keys %$candidates) {
		my $validation_interface = SubsystemExtension::ValidationInterface->new($self->{fig}, $subsystem, $q->param('genome'), $candidates->{$_});
		$html .= $validation_interface->html_output();
	    }
	} else {
	    $html .= &_error($q, "Could not initialize a validation interface object for the subsystem extension");
    	}
    }

    return $html;
}


sub addition {
    my ($self, $q) = @_;

    $q = $q ? $q : $self->{cgi};

    my $subsystem = $self->{fig}->get_subsystem($q->param('subsystem'));
    my $genome = $q->param('genome');

    my $subsystemcandidate = SubsystemExtension::SubsystemCandidateFactory::HTML();
    
    $subsystemcandidate->assign();

    my $html "assigned subsystem to $genome!";
    
    $self->organism_selection();

    return $html;


}

sub html_output {

    my ($self) = @_;
    my $q = CGI->new();
    
    
    my $html .= $q->h3("SubsystemExtension Interface");
    $html .= $q->h4($self->{subsystem}->get_name() ." ".$self->{organism});
    
    
    $html .= $q->h5("Probably variant ".$self->subsystem_candidate()->functional_variant()." score ".$self->subsystem_candidate()->functional_variant_score()." similar to ".$self->subsystem_candidate()->functional_variant_template());
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


sub doAssignment {
    my ($self, $q) = @_;
  

}
    
