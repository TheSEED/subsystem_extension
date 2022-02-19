package SubsystemExtension::ExtensionInterface::SEED;


use strict;
use warnings;
use FIG;
use Subsystem;
use SubsystemExtension::ExtensionConfig qw (TEMPDIR BINDIR QSUB SGE_ROOT USECLUSTER EXTENSIONEVAL EXTENSIONDEPTH);
use SubsystemExtension::RoleCandidate;
use SubsystemExtension::SubsystemCandidate;
use SubsystemExtension::SubsystemCandidate::SEED;
use SubsystemExtension::SubsystemCandidateFactory::SEED;
use SubsystemExtension::ValidationInterface;
use SubsystemExtension::AEOS;
use Data::Dumper;
use CGI;
use constant DEBUG => 1;


no warnings qw(redefine);

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

	my ($class, $q, $fig, $parameters) = @_;

	my $self  = {};

	$self->{fig}  = ref $fig ? $fig : FIG->new();
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
   $html .= $self->_wizard();
   #$html .= $self->_help($q);
    

   if (!$q->param('user')) {
       $html .= $self->login(); 
   } elsif (!$q->param('subsystem')) {
       $html .= $self->subsystem_selection();
   } elsif (!$q->param('genome')) {
       $html .= $self->organism_selection();
   } elsif ($q->param('extend')) {
       $html .= $self->extension();
   } elsif ($q->param('assign')) {
       $html .= $self->assignment();
   } elsif ($q->param('add')) {
       $html .= $self->addition();
   }

   if ($q->param('enqueue_extension')) {
       $html.=$self->enqueue_extension($q);
   }
    
   $html .= $self->_footer()

}


sub _new_css {
	my $css_definition = "

body{
color:black;
background:#f6f6f6;
padding:0;
margin:0;
font:13px verdana, sans-serif;}


#head{
color:black;
background:#cccccc;
border-bottom:3px solid black;
padding-top:20px;
margin:0;}
#head h1{
color:white;
background:#a8a8a8;
padding:2px;
margin:0;
border-top:1px solid black;
font:bold 18px verdana, sans-serif;}

#clustertable{
color:black;
border-bottom:1px solid black;
margin:0 5px 0 5px;
max-height:250px; 
overflow:auto;
margin:0;}

#clusterimage{
color:black;
border-bottom:1px solid black;
padding-bottom:10px;
max-height:250px; 
overflow:auto;
margin:0;}
#clustertable th {
background:#dddddd;
}
#clusterimage img {
border:1px solid black;
}

#menulinks{
float:left;
width:120px;}

#menulinks a{
color:black;
border:0px solid black;
padding:5px 20px 5px 20px;
font:bold 12px verdana, sans-serif;
text-decoration:none;
text-align:center;}
#menulinks a:hover{color:white;}
#menulinks td:hover{color:white;border: 1px solid black;background:#9a9a9a;text-align:center;}
#menulinks td{color:white;border: 1px solid black;background:#e1e1e1;text-align:center;}


#menurechts{
float:right;
width:100px;}
#menurechts ul{
margin:0px;
padding:10px 0 0 0px;
list-style:none;}
#menurechts li{
font:10px verdana, sans-serif;
padding:0 0 5px 0;
margin:0;}
#menurechts a{
color:black;
background:#e1e1e1;
padding:2px 20px 2px 20px;
border:1px solid black;
font:bold 10px verdana, sans-serif;
text-decoration:none;
text-align:center;}
#menurechts a:hover{color:white;background:#9a9a9a;}


#content{
color:black;
background:#ededed;
margin:0 0 0 130px;
padding-left:20px;
padding-top:20px;
padding-bottom:50px;
border-left:2px solid black;
border-right:2px solid black;}
#content h2{
margin:0 0 10px 0;
padding:2px 0 2px 5px;
font:bold 16px verdana, sans-serif;
border-left:10px solid #bcbcbc;
border-bottom:1px solid #bcbcbc;}
#content h3{
margin:25px 0 10px 0;
padding:2px 0 2px 5px;
font:bold 14px verdana, sans-serif;
border-left:8px solid #bcbcbc;
border-bottom:1px solid #bcbcbc;}
#content h4{
margin:25px 0 10px 0;
padding:2px 0 2px 5px;
font:bold 12px verdana, sans-serif;
border-left:6px solid #bcbcbc;
border-bottom:1px solid #bcbcbc;}


#foot{color:white;
background:#a8a8a8;
padding:0;
margin:0;
border-top:2px solid black;}
#foot p{margin:0;padding:4px;}";
	

	return $css_definition;

}


sub _error {

    my ($q, $message) = @_;
    
    return $q->p($message);

}

sub _wizard {

    my ($self, $q) = @_;
    
    $q = $q ? $q : $self->{cgi};
    my $user = $q->param('user') ? $q->param('user') : '';
    my $subsystem = $q->param('subsystem') ? $q->param('subsystem') : ''; 
    my $html = $q->start_div({-id=>"menulinks"});
    $html .= $q->h3( "Progress");
    $html .= $q->table(
		       $q->Tr( $q->td( $q->a({-href=>$q->url()}, "Login") ) ),
		       $q->Tr( $q->td( $q->a({-href=>$q->url()."?user=$user"}, "Subsystem") ) ),
		       $q->Tr( $q->td( $q->a({-href=>$q->url()."?user=$user&subsystem=$subsystem"}, "Genomes") ) )
#		       $q->Tr( $q->td( $q->a({-href=>$q->url()."?user=".$q->param('user')."&subsystem=".$q->param('subsystem')."&genome=".$q->param('genome')}, "Results") ) )
		       );
    
    $html .= $q->end_div();
    
}


sub _header {
    my ($self, $q) = @_;

    $q = $q ? $q : $self->{cgi};
    
    my $html = $self->{'no_header'} ? '' : $q->header() ;

    $html .= $q->start_html(-title=>'Subsystem Extension Web Interface',
			    -author=>'hneuwege@cebitec.uni-bielefeld.de',
			    -base=>'true',
			    -meta=>{'keywords'=>'SEED Subsystem Extension',
				    'copyright'=>'Copyright 2005'},
			    -style=>{'type'=>"text/css", 'code'=>&_new_css()},
			    -script=>{'src'=>"./Html/css/FIG.js", 'type'=>"text/javascript"}
			    );
    
    return $html;

}

sub _title {
    my ($self, $q) = @_;

    $q = $q ? $q : $self->{cgi};
    
    my $html = $q->start_div({-id=>"head"});
    $html .=  $q->h1("Subsystem Extension Web Interface");
    $html .= $q->end_div();


    return $html;
}

sub _footer {

    my ($self, $q) = @_;
    
    $q = $q ? $q : $self->{cgi}; 
    
    my $html = $q->div({-id=>"foot"}, $q->p("(C) 2005 FIG / CeBiTec ")); 
    $html .= $q->end_html();
    
    return $html;

}



sub login {

    my ($self, $q) = @_;

    $q = defined $q ? $q : $self->{cgi};

    my $html;
    $html .= $q->start_div({-id=>"content"});
    $html .= $q->start_form({-action => $q->url(), -method => 'post'});
    $html .= $q->table({-class =>'nicetable',-width =>'100%'},
		       $q->Tr({-class=>'highlight3'},$q->td( $q->h3("User Login"))),
		       $q->Tr($q->td($q->input({-type => 'text', -name => 'user'}))),
		       $q->Tr($q->td($q->submit({-name=>'login_extension', -value=>'Login'}))),
		       $q->Tr($q->td("Please use mozilla or firefox to get visualizations of similarity"))
		       ).$q->end_form();
    
    $html .= $q->end_div();

    return $html;

}

sub subsystem_selection {

    # this method will generate a drop down element integrated into a formated
    # html table that presents the subsystem that are acessible to the user

    my ($self, $q) = @_;

    $q = $q ? $q : $self->{cgi};

   

    my @subsystems = $self->{fig}->all_subsystems();
    my $html;
    $html .= $q->start_div({-id=>"content"});
    $html .= $q->start_form({-action => $q->url(), -method => 'post'});
    $html .= $q->table({-class =>'nicetable',-width =>'100%'},
		       $q->Tr({-class=>'highlight3'},$q->td( $q->h3("Subsystems"))),
		       $q->Tr($q->td(
				     $q->hidden(-name => 'request', -value => 'extend_ssa', -override => 1),
				     $q->hidden(-name => 'user', -value => $q->param('user'), -override => 1),
				     $q->scrolling_list( -name   => 'subsystem',
							 -values => [sort {uc($a) cmp uc($b)} @subsystems],
							 -size   => 10 ))),
		       
		       $q->Tr($q->td(
				     $q->submit({-name=>'seed_extension', -value=>'Extend subsystem'})))
		       );
    $html .= $q->end_form();
    $html .= $q->end_div();
    
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
    $html .= $q->start_div({-id=>"content"});
    $html .= $q->start_form(-action => $q->url(), -method => 'post');
    
    my %out_labels;
    foreach (@out) {
	$out_labels{$_} = "$_: ".$self->{fig}->genus_species($_)." [" . $self->{fig}->genome_domain($_)."]";
	
	if (-e TEMPDIR."/".$q->param('subsystem')."/$_.scs") {
	    
	    my $candidate = SubsystemExtension::SubsystemCandidate::SEED->fromFileFast( TEMPDIR."/".$q->param('subsystem')."/$_.scs");

	    if (ref $candidate && $candidate->isa("SubsystemExtension::SubsystemCandidate")) {
		if ($candidate->functional_variant() > 0) {
		    $out_labels{$_} .= sprintf " (Variant %s %.2f %%)", $candidate->functional_variant(), $candidate->functional_variant_score()*100;
		} else {
		    $out_labels{$_} .= " (No Variant)";
		}
	    }

	}
    }	
    

    $html .= $q->hidden(-name => 'subsystem', -value => $q->param('subsystem'), -override => 1);
    $html .= $q->hidden(-name => 'user', -value => $q->param('user'), -override => 1);
    $html .= $q->table({-class =>'nicetable',-width =>'100%'},
                       $q->Tr({-class=>'highlight3'},$q->td( $q->h3("Subsystem ".$subsystem->get_name()." last extended: ".
                                $self->update_date($subsystem->get_name())))),
		       $q->Tr({-class=>'highlight3'},$q->td( $q->h3("Genomes not included in Subsystem ". $subsystem->get_name()))),
		       $q->Tr($q->td( "$missing genomes missing in subsystem")), 
		       $q->Tr($q->td(
				     $q->scrolling_list( -name   => 'genome',
							 -values => [ sort {$self->{fig}->genus_species($a) cmp $self->{fig}->genus_species($b);}  @out ],
							 -size   => 10,
							 -labels => \%out_labels,
							 -multiple => 'multiple'
							 ),
				     )),
		       #$q->Tr($q->td( "Scoring mechanism:")), 
		       #$q->Tr($q->td($q->scrolling_list( -name   => 'scoring', -values => ['default'], -size => 1 ))),
		       $q->Tr($q->td($q->checkbox({-label=> "Recompute", -name => "recompute", -checked => 0, -value=>1}),
				     "E-value cutoff: ",
				     $q->input({-type => 'text',  -value => EXTENSIONEVAL,-name => 'evalue'}),
				     "Search depth: ",
				     $q->input({-type => 'text', -value => EXTENSIONDEPTH, -name => 'depth'}),
				     )
			      ),
		       
		       $q->Tr($q->td($q->submit({-name => 'extend'}, 'Pick a Genome to add' )))
		       );
    $html .= $q->end_form();
    $html .= $q->hr();


    my %in_labels;
    foreach (keys %in) {
	$in_labels{$_} = "$_: ".$self->{fig}->genus_species($_)." [" . $self->{fig}->genome_domain($_)."]";
	if (-e TEMPDIR."/".$q->param('subsystem')."/$_.scs") {
	    
	    my $candidate = SubsystemExtension::SubsystemCandidate::SEED->fromFileFast( TEMPDIR."/".$q->param('subsystem')."/$_.scs");
	    
	    if (ref $candidate && $candidate->isa("SubsystemExtension::SubsystemCandidate")) {
		if ($candidate->functional_variant() > 0) {
		    $in_labels{$_} .= sprintf " (Variant %s %.2f %%)", $candidate->functional_variant(), $candidate->functional_variant_score()*100;
		} else {
		    $in_labels{$_} .= " (No Variant)";
		}
	    }
	    
	}


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
							 -labels => \%in_labels,
							 -multiple => 'multiple'
							 ))),
		       #$q->Tr($q->td( "Scoring mechanism:")), 
		       #$q->Tr($q->td($q->scrolling_list( -name   => 'scoring', -values => ['default'], -size => 1 ))),

		       
		       $q->Tr($q->td($q->checkbox({-label=> "Recompute", -name => "recompute", -checked => 0, -value=>1}),
				     "E-value cutoff: ",
				     $q->input({-type => 'text',  -value => EXTENSIONEVAL, -name => 'evalue'}),
				     "Search depth: ",
				     $q->input({-type => 'text', -value => EXTENSIONDEPTH, -name => 'depth'}),
				     )
		              ),
		       $q->Tr($q->td($q->submit({-name => 'extend'},'Pick a Genome to complete' )))
		       );      
    
    $html .= $q->p($q->submit("enqueue_extension", "Queue this subsystem for extension"));
    $html .= $q->end_form();
    $html .= $q->end_div();

    return $html;

}

sub computation {

    my ($self, $q) = @_;
    
    my $html = $q->start_div({-id=>"content"});
    $html .= $q->h3($q->param('subsystem')." extension to ".$q->param('genome')." in progress...");
    $q->delete('recompute');

    $html .= $q->h5($q->a({-href=>$q->self_url()}, "Click here to update the progress report"));
    
    $html .= $q->start_pre();
    $html .= "Submitted to compute cluster\n";

    if (-e TEMPDIR."/".$q->param('subsystem')."/".$q->param('genome').".log") {
	open LOG, "<".TEMPDIR."/".$q->param('subsystem')."/".$q->param('genome').".log";
	while (<LOG>) {
	    $html .= $_;
	}
	close LOG;
    }


    $html .= $q->end_pre();
    $html .= $q->end_div();

    return $html;
}



sub extension {

    my ($self, $q) = @_;

    $q = $q ? $q : $self->{cgi};

    my $subsystem = $self->{fig}->get_subsystem($q->param('subsystem'));
   
    my $html;

    my $subsystem_directory =  TEMPDIR."/".$q->param('subsystem');
    
    
    # this approach enables us to use precomputed information

    if ($q->param('recompute') || 
	((!-e $subsystem_directory."/".$q->param('genome').".scs") && 
	 (!-e $subsystem_directory."/".$q->param('genome').".log"))) {
	

	if ($q->param('recompute')) {

	    unlink $subsystem_directory."/".$q->param('genome').".scs";
	    unlink $subsystem_directory."/".$q->param('genome').".log";
	}

	if (USECLUSTER) {
	    unless (-d $subsystem_directory."/") {
		mkdir $subsystem_directory;
	    }
	    my $esc_subsystem_directory = $subsystem_directory;

	    $esc_subsystem_directory =~ s/(\()/\\$1/g;
	    $esc_subsystem_directory =~ s/(\))/\\$1/g;

	    my $esc_subsystem_name = $q->param('subsystem');
	    $esc_subsystem_name =~ s/(\()/\\$1/g;
	    $esc_subsystem_name =~ s/(\))/\\$1/g;

	    my $call = 'SGE_ROOT='.SGE_ROOT.'; export SGE_ROOT; '.QSUB." -b y  -o ".$esc_subsystem_directory.'/'.$q->param('genome').".out  -e ".$esc_subsystem_directory.'/'.$q->param('genome').".log ".BINDIR."/subsystem_extension -s '".$esc_subsystem_name."' -d ".TEMPDIR."/ -t ".$q->param('genome').' -e '.$q->param('evalue'). ' -r '.$q->param('depth').' 1>&2'; 
	    
	    system ($call);
	} else {
	    my $extension = SubsystemExtension::SubsystemCandidateFactory::SEED->new($subsystem, $q->param('user'), $q->param('evalue'), $q->param('depth'));
	    my $candidates = $extension->generate([$q->param('genome')]);
	    
	    foreach (keys %$candidates) {
		my $aeos = SubsystemExtension::AEOS->new( $self->{fig}, $subsystem, $q->param('genome'), $candidates->{$_}, {mute=>1});
		$candidates->{$_} = $aeos->extend();
		unless (-d $subsystem_directory) {
		    mkdir $subsystem_directory;
		    my $mode = 0755;
		    chmod $mode, $subsystem_directory;
		}
		$candidates->{$_}->toFile($subsystem_directory."/".$q->param('genome').".scs");
	    }
	}
	
    }
            
    if (!-e $subsystem_directory."/".$q->param('genome').".scs") {
	
	$html = $self->computation($q);
	return $html;
	
    } else {

	if (-e $subsystem_directory."/".$q->param('genome').".log") {
	    unlink $subsystem_directory."/".$q->param('genome').".log";
	}
	my $candidate = SubsystemExtension::SubsystemCandidate::SEED->fromFile($subsystem_directory."/".$q->param('genome').".scs");

	my $aeos = SubsystemExtension::AEOS->new($self->{fig}, $subsystem, $q->param('genome'), $candidate, {mute=>1});
	$candidate = $aeos->extend();

	$html .= $q->start_div({-id=>"content"});
	                                       
	if (ref $candidate && $candidate->isa("SubsystemExtension::SubsystemCandidate")) {
	    
	    my $validation_interface = SubsystemExtension::ValidationInterface->new($self->{fig}, $subsystem, $q->param('genome'), $candidate);
	    $html .= $validation_interface->html_output($q);
	    
	} else {
	    $html .= &_error($q, "Could not initialize the subsystem candidate for the subsystem extension");
	}
	
	$html .= $q->end_div(); 
	
    }

    return $html;
}


sub addition {
    my ($self, $q) = @_;

    $q = $q ? $q : $self->{cgi};

    my $subsystem = $self->{fig}->get_subsystem($q->param('subsystem'));
    my $genome = $q->param('genome');
    my $user = $q->param('user');

    my $filter = $self->_annotation_filter($q);

    my $subsystemcandidate = SubsystemExtension::SubsystemCandidate::SEED->fromFile(TEMPDIR."/".$q->param('subsystem')."/$genome.scs");
    
    $subsystemcandidate->assign($self->{fig}, $filter );

    my $html = $q->h3("Assigned subsystem ".$subsystem->get_name()." to $genome!");
    $html .= $self->organism_selection();

    return $html;

}


sub _annotation_filter {

    my ($self, $q) = @_;

    my %filter;

    my %params = $q->Vars;

    foreach my $param (keys %params) {

	if ($param =~ /^Role_(\d+)/) {

	    my $role_index = $1;
	    unless ( ref $filter{$role_index}) {
		$filter{$role_index} = {};
	    }

	    foreach my $peg (split("\0",$params{$param})) {

		$filter{$role_index}->{$peg} = 1;
	    }
	    
	    
	}

	$filter{'variant'} = $params{'variant'};
	$filter{'user'} = $params{'user'};
	
    }

    return \%filter;
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


sub assignment {
    my ($self, $q) = @_;
 
    
    $q = $q ? $q : $self->{cgi};

    my $subsystem = $self->{fig}->get_subsystem($q->param('subsystem'));
    my $genome = $q->param('genome');
    my $user = $q->param('user');

    my $filter = $self->_annotation_filter($q);

    my $subsystemcandidate = SubsystemExtension::SubsystemCandidate::SEED->fromFile(TEMPDIR."/".$q->param('subsystem')."/$genome.scs");
    
    $subsystemcandidate->annotate($self->{fig}, $filter );
    
    
    my $html .= $q->h3("Only assigned functional roles to selected PEGs!");
    $html .= $self->organism_selection();
    
    return $html;
   

}
    
sub enqueue_extension {
    my ($self, $q) = @_;
    #my $file=$FIG_Config::data."/Subsystems/".$q->param('subsystem')."/ENQUEUE_EXTENSION";
    my $file=TEMPDIR."enqueued_extensions";
    open(OUT, ">>$file") || die "Can't open $file";
    print OUT $q->param('subsystem'), "\n";
    close OUT;
    return $q->h3("Extension of ".$q->param('subsystem')." has been queued\n");
}

sub update_date {
    my ($self, $subsys)=@_;
    return "Never" unless (-e TEMPDIR.$subsys);
    my @stat=stat(TEMPDIR.$subsys);
    return scalar(localtime($stat[10]));
}
