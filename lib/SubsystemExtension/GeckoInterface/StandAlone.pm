package SubsystemExtension::GeckoInterface::StandAlone;


use strict;
use warnings;

use SubsystemExtension::ClusterDetectionSparse;
use SubsystemExtension::ClusterList;
use SubsystemExtension::Cluster;

use SubsystemExtension::SequenceFactory::COG;

use SubsystemExtension::GeckoConfig;

use Data::Dumper;
use CGI;
use constant DEBUG => 1;
use constant TEMPDIR => '/var/tmp/';
no warnings qw(redefine);
use MIME::Base64 ();
use FIGjs;



=pod

=head1 SubsystemExtension::GeckoInterface::

This Class is a concrete implementation of the interactive cluster detection interface

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
   $html .= $self->_help($q);
   if (!$q->param('user')) {
       $html .= $self->login(); 
   } elsif (!$q->param('genomes') && !$q->param('seqfile')) {
       $html .= $self->organism_selection();
   } elsif (!$q->param('minclustersize')) {
       $html .= $self->parameter_selection();
   } elsif (!$q->param('cluster')) {
       $html .= $self->cluster_detection();
   } elsif (!$q->param('subsystemname')) {
       $html .= $self->subsystem_form();
   } else {
       $html .= $self->subsystem_creation($q);
   }


   $html .= $self->_footer();

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
width:180px;}
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
margin:0 190px 0 130px;
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



sub _wizard {

    my ($self, $q) = @_;
    
    $q = $q ? $q : $self->{cgi};
    
    my $html = $q->start_div({-id=>"menulinks"});
    $html .= $q->h3( "Progress");
    $html .= $q->table(
		       $q->Tr( $q->td( $q->a({-href=>$q->self_url()}, "Login&nbsp;&nbsp;&nbsp;") ) ),
		       $q->Tr( $q->td( $q->a({-href=>$q->self_url()}, "Genomes") ) ),
		       $q->Tr( $q->td( $q->a({-href=>$q->self_url()}, "Parameters") ) ),
		       $q->Tr( $q->td( $q->a({-href=>$q->self_url()}, "Results") ) ),
		       );
    
    $html .= $q->end_div();
    
}

sub _help {

	my ($self, $q) = @_;

    $q = $q ? $q : $self->{cgi};
    
	my $html = $q->start_div({-id=>"menurechts"});
    
	$html .= $q->h3( "Help" );
		
	if (!$q->param('user')) {
	    $html .= $q->ul($q->li("Please enter your login."));
	} elsif (!$q->param('genomes') && !$q->param('seqfile'))  {
	    $html .= $q->ul($q->li("Please select the genomes from the list of completed bacterial genomes that you would like to analyze for clusters. 
Expect a runtime of the algorithm  per genome of about 20 seconds."));
	} elsif (!$q->param('minclustersize')) {
	    $html .= $q->ul($q->li("Please enter the parameters for the cluster detection algorithm, Minimal cluster Size correponds to the number of genes that have to appear as direct neighbors on the chromosome, Minimal genome count cooreponds to the number of genomes a cluster has to be present in. The algorithm is able to join single clusters, selecting the percent identity rate of the gene families present this can be infulenced. Use lower values for larger resulting clusters. The last paramater that can be set is the type of protein familily information that will be used for the clustering."));
	} elsif (!$q->param('cluster')) {
	    $html .= $q->ul($q->li("The detected clusters are shown in the list on top. A visual representation with additional pop up information is presented at the bottom."));
	}
	
	$html .= $q->end_div();

}



sub _error {

    my ($q, $message) = @_;
    
    return $q->p($message);

}

sub _header {
    my ($self, $q) = @_;

    $q = $q ? $q : $self->{cgi};
    
    my $html = $self->{'no_header'} ? '' : $q->header() ;

    $html .= $q->start_html(-title=>'Gecko Cluster Detection Web Interface',
			    -author=>'hneuwege@cebitec.uni-bielefeld.de',
			    -base=>'true',
			    -meta=>{'keywords'=>'Gecko Cluster',
				    'copyright'=>'Copyright 2005'},
			    -style=>{'type'=>"text/css", 'code'=>&_new_css()}
			    );
    
    return $html;

}

sub _footer {

    my ($self, $q) = @_;
    
   $q = $q ? $q : $self->{cgi}; 
    
    my $html = $q->div({-id=>"foot"}, $q->p("(C) 2005 CeBiTec / BRF")); 
		$html .= $q->end_html();

    return $html;

}



sub _title {
    my ($self, $q) = @_;

    $q = $q ? $q : $self->{cgi};

    
    my $html = $q->start_div({-id=>"head"});
    $html .=  $q->h1("Gecko Web Interface");
    $html .= $q->end_div();
    return $html;
}


sub login {

    my ($self, $q) = @_;

    $q = defined $q ? $q : $self->{cgi};
    
    my $html;
	$html .= $q->start_div({-id=>"content"});
	$html .= $q->start_form({-action => $q->url(), -method => 'post'});
    $html .= $q->table(
		       $q->Tr($q->td( $q->h3("User Login"))),
		       $q->Tr($q->td($q->input({-type => 'text', -name => 'user'}))),
		       $q->Tr($q->td($q->submit({-name=>'login_extension', -value=>'Login'})))
		       ).$q->end_form();
	$html .= $q->end_div();

    return $html;

}


sub organism_selection {

    my($self, $q) = @_;

    $q = $q ? $q : $self->{cgi};

    my($genome,%known_hits);

	$html .= $q->start_div('content');
	$html .= $q->start_form(-action => $q->url(), -method => 'post', -enctype => "multipart/form-data");

	$html .= $q->hidden(-name => 'user', -value => $q->param('user'), -override => 1);
	$html .= $q->table({-width =>'100%'},
					   $q->Tr($q->td( $q->h3("Upload your own sequence data"))),
					   $q->Tr($q->td( $q->filefield({ -name=>"seqfile", -size=>"30"}))),
					   $q->Tr($q->td($q->submit({-name => 'select'}, 'Select genomes' ))),
					  );
    $html .= $q->end_form();
    $html .= $q->end_div();



    
    return $html;

}



sub parameter_selection {

    my($self, $q) = @_;

	my $html;

    $q = $q ? $q : $self->{cgi};

	my $fname;
	my $file = $q->param("seqfile");
	
	if ($file) {
		print STDERR "$file\n";


        # dateinamen erstellen und die datei auf dem server speichern
		$fname = 'file_'.$$.'_'.$ENV{REMOTE_ADDR}.'_'.time;
		open DAT,'>'.GeckoConfig::temp.$fname or die 'Error processing file: ',$!;

		print STDERR "$fname\n";

# Dateien in den Binaer-Modus schalten
		binmode $file;
		binmode DAT;

		my $data;
		while(read $file,$data,1024) {
			print DAT $data;
		}
		close DAT;
	}



	$html .= $q->start_div({-id=>"content"});
	$html .= $q->start_form(-action => $q->url(), -method => 'post', -enctype => "multipart/form-data");
	
	my %choices=(
		'fig'	=> "FIGfams",
		'tigr'	=> "TIGRfams",
		'pfam'	=> "PFAM",
		'sp'	=> "SwissProt",
		'kegg'	=> "KEGG",
		'pir'	=> "PIR SuperFams",
		'mcl'	=> "MCL",
		'cog'	=> "COG",
	);
	
	my $default = $q->param("famcat"); unless ($default) {$default='cog'};
  
	

	my @genomes = $q->param('genomes');

    $html .= $q->hidden(-name => 'genomes', -value => \@genomes, -override => 1);
    $html .= $q->hidden(-name => 'seqfile', -value => $fname, -override => 1) if ($fname);

	
    $html .= $q->hidden(-name => 'user', -value => $q->param('user'), -override => 1);
    $html .= $q->table({-class =>'nicetable',-width =>'100%'},
					   $q->Tr({-class=>'highlight3'},$q->td( $q->h3("Select parameters for cluster detection"))),
					   #join "\n", map {$q->Tr($q->td($_));}, @{$q->param('genomes')},
					   
					   
					   $q->Tr($q->td( "Minimal cluster size: (2..30)")), 
					   $q->Tr($q->td($q->input({-type => 'text', -name => 'minclustersize', -value=> '2'}))),
					   $q->Tr($q->td( "Minimal occurence in genomes: (2..45)")), 
					   $q->Tr($q->td($q->input({-type => 'text', -name => 'mingenomes', -value=>'2'}))),
					   $q->Tr($q->td( "Join overlapping clusters: (1%..100%)")), 
					   $q->Tr($q->td($q->input({-type => 'text', -name => 'clusteroverlap',-value=>'75'}), "%")),
					   $q->Tr($q->td( "Join on which family (cog, kegg, mcl, ...)")), 
					   $q->Tr($q->td($q->popup_menu(
										 -name     => "famcat",
										 -values   => [keys %choices],
										 -labels   => \%choices,
										 -default  => $default,
									 ))),
					   
					   
					   $q->Tr($q->td($q->submit({-name => 'detect'}, 'Start detection' )))
					  );
    $html .= $q->end_form();
    $html .= $q->end_div();
    
    return $html;

}

sub inline_image {
    my ($im) = @_;
    return "data:image/png;base64,".MIME::Base64::encode_base64((ref $im && $im->isa('GD::Image')) ? $im->png : $im);
}





sub cluster_detection {

    my ($self, $q) = @_;

    $q = $q ? $q : $self->{cgi};
    
    my @genomes =  $q->param('genomes');
    #print STDERR join "\n", @genomes;
        
    my $html;
    

    # this holds the results
 
    my $clusterList;
    
    $html .= &FIGjs::toolTipScript();
    $html .= $q->start_div({-id=>"content"});
        
    # add the user params to the form as hidden fields
    
    
    $html .= $q->hidden(-name => 'genomes', -value => \@genomes, -override => 1);
    $html .= $q->hidden(-name => 'seqfile', -value => $q->param('seqfile'));
    $html .= $q->hidden(-name => 'user', -value => $q->param('user'), -override => 1);
    $html .= $q->hidden(-name => 'minclustersize', -value => $q->param('minclustersize'), -override => 1);
    $html .= $q->hidden(-name => 'mingenomes', -value => $q->param('mingenomes'), -override => 1);
    $html .= $q->hidden(-name => 'clusteroverlap', -value => $q->param('clusteroverlap'), -override => 1);
    $html .= $q->hidden(-name => 'famcat', -value => $q->param('famcat'), -override => 1);
    
    
    
    # this page may be called several times. for the firts time invocation the
    # ClusterDetectionSparse is created and executed. The resulting cluster List will be
    # stored as file and an html form param is set which indicates that the resultlist is 
    # present.

    unless ($q->param('sort')) {
		my $cluster_detection = SubsystemExtension::ClusterDetectionSparse->new($q->param('minclustersize'), $q->param('mingenomes'), $q->param('clusteroverlap'), 1);
		unless (ref $cluster_detection && $cluster_detection->isa("SubsystemExtension::ClusterDetectionSparse")) {
			$html = &_error($q, "Could not initialize a SubsystemCandidateFactory object for the subsystem");
		} else {
			my ($sequences, $genomes);
			print STDERR "[seqfile] ".$q->param('seqfile')."\n";
			
			if ($q->param('seqfile')) {
				my $cog_factory = SubsystemExtension::SequenceFactory::COG->new(GeckoConfig::temp.$q->param('seqfile'));
				my ($user_sequences, $user_genomes) = $cog_factory->createSequences();
				
				push @$sequences, @$user_sequences;
				push @$genomes, @$user_genomes;
				
			}
			
			# print STDERR &Dumper($sequences);
			$cluster_detection->sequences($sequences);
			$cluster_detection->genomes($genomes);
			
			$cluster_detection->connecting_intervalls();
			$clusterList = $cluster_detection->clusterList();
			
			# store the results
			$clusterList->toFile(GeckoConfig::temp."clusterlist.cls");
			foreach my $cluster ($clusterList->clusters()) {
				$cluster->toFile(GeckoConfig::temp."cluster_".$cluster->{id}.".cls");
			}
		}
	} else {
		# load the results from file
		
		print STDERR "loading results from file \n sorting by ".$q->param('sort')."\n";
		$clusterList = SubsystemExtension::ClusterList->fromFile(GeckoConfig::temp."clusterlist.cls");
		# print STDERR &Dumper($clusterList);
    }		
	
    # html output
    
    $html .= $q->start_div({-id =>"clustertable"});
    $html .= $clusterList->to_html_table($q);
    $html .= $q->end_div();
    
    
    $html .= $q->start_div({-id =>"clusterimage"});
    $html .= $q->h3("Cluster representation");
    foreach my $cluster ($clusterList->clusters($q->param('sort'))) {
		$html .= $q->img({border => 0, usemap => "#".$cluster->{id}, src => &inline_image($cluster->to_png())});
		$html .= $cluster->{map};
		$html .= $q->br();
    }
    $html .= $q->end_div();

    $html .= $q->end_div();
    return $html;
}




    
