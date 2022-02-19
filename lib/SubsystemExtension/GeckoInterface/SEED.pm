package SubsystemExtension::GeckoInterface::SEED;


use strict;
use warnings;
use FIG;
use Subsystem;
use SubsystemExtension::ClusterDetectionSparse;
use SubsystemExtension::ClusterList;
use SubsystemExtension::Cluster;
use SubsystemExtension::ClusterView::GFX;

use SubsystemExtension::SequenceFactory::SEED;
use SubsystemExtension::SequenceFactory::COG;


use File::Temp qw/ tempdir /;

use Data::Dumper;
use CGI;
use constant DEBUG => 1;
use constant USECLUSTER => 1;
use SubsystemExtension::GeckoConfig qw(TEMPDIR BINDIR QSUB SGE_ROOT);

no warnings qw(redefine);
use MIME::Base64 ();
use FIGjs;



=pod

=head1 SubsystemExtension::GeckoInterface::SEED

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

	return $self;


}


sub _progress {

}

sub output {

   my ($self, $q) = @_;

   $q = $q ? $q : $self->{cgi};

   my $html = $self->_header();
   
   $html .= $self->_title();
   $html .= $self->_wizard();
   $html .= $self->_help($q);

   if ($q->param('logout')) {
	   $html .= $self->logout(); 
   } elsif (!$q->param('user')) {
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
   
   return $html;

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
max-height:350px; 
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
#menulinks th{color:white;border: 1px solid black;background:#9a9aba;text-align:center;}

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
padding-bottom:100px;
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
	
	my $myself = $q->self_url();
	
	my $html = $q->start_div({-id=>"menulinks"});
    $html .= $q->h3( "Progress");
    $html .= $q->start_table();

	$html .= $q->Tr( $q->param('user') ? $q->td( $q->a({-href=>$q->url()}, "Login&nbsp;&nbsp;&nbsp;") )  : $q->th( $q->a({-href=>$q->url()}, "Login&nbsp;&nbsp;&nbsp;") ) );
	
	# genomes menu entry
	if ($q->param('user') && !$q->param('logout'))  {
		
		$myself = $q->self_url();
		$myself =~ s/minclustersize=[^;&]+//;	
		$myself =~ s/genomes=[^;&]+//;	
		$myself =~ s/cluster=[^;&]+//;	
			
		if  (!$q->param('genomes') && !$q->param('seqfile')) {
			
			print STDERR $myself;

			$html .= $q->Tr( $q->th($q->a({-href=>$myself}, "Genomes") ) );
		} else {
			$html .= $q->Tr( $q->td($q->a({-href=>$myself}, "Genomes") ) );
		}
	} else {
		$html .= $q->Tr( $q->td("Genomes"));
	}

	
	if ($q->param('genomes') || $q->param('seqfile'))  {
		$myself = $q->self_url();
		$myself =~ s/minclustersize=[^;&]+//;	
		$myself =~ s/cluster=[^;&]+//;	

		if ($q->param('minclustersize')) {
			$html .= $q->Tr( $q->td( $q->a({-href=>$myself}, "Parameters") ) );
		} else {
			$html .= $q->Tr( $q->th($q->a({-href=>$myself}, "Parameters") ) );
		}
	} else {
		$html .= $q->Tr( $q->td( 'Parameters' ) );
	}
	if ($q->param('minclustersize')) {
		$myself = $q->self_url();
		$myself =~ s/cluster=[^;&]+//;	
		$myself =~ s/subsystemname=[^;&]+//;	
		
		if ( $q->param('cluster') ) {
			$html .= $q->Tr( $q->td( $q->a({-href=>$myself}, "Results") ) );
		} else {
			$html .= $q->Tr( $q->th( $q->a({-href=>$myself}, "Results") ) );
		}
	} else {
		$html .= $q->Tr( $q->td( 'Results') );
	}
	if ( $q->param('cluster') ) {
		if ($q->param('subsystemname') ) {
			$html .= $q->Tr( $q->td( $q->a({-href=>$q->self_url()}, "Subsystem")  ) );
		} else {
			$html .= $q->Tr( $q->th( $q->a({-href=>$q->self_url()}, "Subsystem")  ) );
		}
	} else {
		$html .= $q->Tr( $q->td( 'Subsystem') );
	}

	if ($q->param('user') && $q->param('session') && !$q->param('logout')) {
		
		$html .= $q->Tr( $q->th( $q->a({-href=>$q->url()."?logout=1&session=".$q->param('session')."&user=".$q->param('user')}, "Logout") ) );
	}

	$html .= $q->end_table();
    
    $html .= $q->end_div();
    
}

sub _help {

	my ($self, $q) = @_;

    $q = $q ? $q : $self->{cgi};
    
	my $html = $q->start_div({-id=>"menurechts"});
    
	$html .= $q->h3( "Help" );
		
	if (!$q->param('user')) {
	    $html .= $q->ul($q->li("Please enter your SEED login. If you want to create subsystems based on detected clusters use the master user.")); 
	} elsif (!$q->param('genomes') && !$q->param('seqfile'))  {
	    $html .= $q->ul($q->li("Please select at least two genomes from the list of complete bacterial genomes that you would like to analyze for gene clusters."));
	} elsif (!$q->param('minclustersize')) {
	    $html .= $q->ul($q->li("Please enter the parameters for the cluster detection algorithm, <b>minimal cluster size</b> delineates the minmal number of distinct genes and <b>minimal genome count</b> defines the number of genomes that have to occur in one cluster. </br>
The algorithm joins clusters if the defined percentage value of their genes <b>overlap</b>.</br> The last paramater that can be set is the type of <b>protein familily information</b> that will be used."));
	} elsif (!$q->param('cluster')) {
	    $html .= $q->ul($q->li("The detected clusters are shown in the list on top. A visual representation with additional pop up information is presented at the bottom. Mark those clusters you would like to create a subsystem from and click the <i>create</i> button."));
	} elsif (!$q->param('subsystemname')) {
	    $html .= $q->ul($q->li("Please enter names for the complete subsystem and every functional role. Use gene names if possible for the role abbreviation. Proposed functional roles and genomes can be excluded from the subsystem by unmarking the respective checkboxes."));
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
    
    my $html .= $self->{'no_header'} ? '' : $q->header();
    
    if ($q->param('computing') && $q->param('user') && $q->param('session') && !(-e TEMPDIR."/gecko/".$q->param('user')."_".$q->param('session')."/clusterlist.cls")) {
	$html .= $q->start_html(-title=>'Gecko Cluster Detection Web Interface',
				-author=>'hneuwege@cebitec.uni-bielefeld.de',
				-base=>'true',
				-head=>$q->meta({-http_equiv=>'REFRESH',-content=>'30;URL='.$q->self_url()}),
				-style=>{'type'=>"text/css", 'code'=>&_new_css()}
				);

    } else {
	$q->delete('computing');
	
	$html .= $q->start_html(-title=>'Gecko Cluster Detection Web Interface',
				-author=>'hneuwege@cebitec.uni-bielefeld.de',
				-base=>'true',
				-meta=>{'keywords'=>'SEED Subsystem Extension Gecko Cluster',
					'copyright'=>'Copyright 2005'},
				-style=>{'type'=>"text/css", 'code'=>&_new_css()}
				);
    }
    
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


    # get all complete procaryotic genomes
    my @genomes = $self->{fig}->genomes(1, undef, "Bacteria");

    my $html;
	$html .= $q->start_div({-id=>"content"});
    $html .= $q->start_form(-action => $q->url(), -method => 'post', -enctype => "multipart/form-data");
    
    my %genome_labels;
    foreach (@genomes) {
		$genome_labels{$_} = "$_: ".$self->{fig}->genus_species($_)." [" . $self->{fig}->genome_domain($_)."] ".$self->{fig}->genome_pegs($_)." Genes";
    }	
    


    $html .= $q->hidden(-name => 'user', -value => $q->param('user'), -override => 1);
	
	# create a temporary directory for the current user 
	my $template = $q->param('user')."_XXXXX";
	my $tempdir = tempdir ( $template, DIR => TEMPDIR."/gecko/" );
	chmod 0766, $tempdir;
	# change the permissions to allow qhosts to write their results

	my $session;
	if ($tempdir =~ /_(.*)/) {
		$session = $1;
		$html .= $q->hidden(-name => 'session', -value => $session, -override => 1);
	}
	print STDERR $session."\n";

	print STDERR $tempdir." ".$template."\n\n";

    $html .= $q->table({-width =>'100%'},
					   $q->Tr($q->td( $q->h3("Select Genomes for cluster detection"))),
					   $q->Tr($q->td(
								  $q->scrolling_list( -name   => 'genomes',
													  -values => \@genomes,
													  -size   => 10,
													  -labels => \%genome_labels,
													  -multiple => 'multiple'
													),
							  )),
					   
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
		open DAT,'>'.TEMPDIR.$fname or die 'Error processing file: ',$!;

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
    $html .= $q->hidden(-name => 'computing', -value => 1, -override => 1);
 	
    $html .= $q->hidden(-name => 'user', -value => $q->param('user'), -override => 1);
	$html .= $q->hidden(-name => 'session', -value => $q->param('session'), -override => 1);
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


sub computation {

    my ($self, $q) = @_;
    
    my $html = $q->start_div({-id=>"content"});
    $html .= $q->h3("Cluster computation in progress...");
    $html .= $q->h5("This page will refresh every 30 seconds...");
    $html .= $q->start_pre();
    if (-e TEMPDIR."/gecko/".$q->param('user')."_".$q->param('session')."/log.txt") {
	open LOG, "<".TEMPDIR."/gecko/".$q->param('user')."_".$q->param('session')."/log.txt";
	while (<LOG>) {
	    $html .= $_;
	}
	close LOG;
    }


    $html .= $q->end_pre();
    $html .= $q->end_div();

    return $html;
}



sub cluster_detection {

    my ($self, $q) = @_;

    $q = $q ? $q : $self->{cgi};
    
    my @genomes =  $q->param('genomes');
        
    my $html;

    # this holds the results
 
    my $clusterList;

    # create a view object that will be responsible
    # for the graphical representation of the clusters
    
    my $clusterview_gfx = new SubsystemExtension::ClusterView::GFX;
        
    # this page may be called several times. for the firts time invocation the
    # ClusterDetectionSparse is created and executed. The resulting cluster List will be
    # stored as file and an html form param is set which indicates that the resultlist is 
    # present.

    if (USECLUSTER) {

	if ((-e TEMPDIR."/gecko/".$q->param('user')."_".$q->param('session')."/clusterlist.cls") && (!$q->param('computing'))) {
	    
	    # load the results from file
	    

	    $clusterList = SubsystemExtension::ClusterList->fromFile(TEMPDIR."/gecko/".$q->param('user')."_".$q->param('session')."/clusterlist.cls");
	    # print STDERR &Dumper($clusterList);
	    
	    # html output
	    
	    $html .= &FIGjs::toolTipScript();
	    $html .= $q->start_div({-id=>"content"});
	    $html .= $q->start_form(-action => $q->url(), -method => 'post');
	    
	    # add the user params to the form as hidden fields
	    
	    $html .= $q->hidden(-name => 'genomes', -value => \@genomes, -override => 1);
	    $html .= $q->hidden(-name => 'seqfile', -value => $q->param('seqfile'));
	    $html .= $q->hidden(-name => 'user', -value => $q->param('user'), -override => 1);
	    $html .= $q->hidden(-name => 'minclustersize', -value => $q->param('minclustersize'), -override => 1);
	    $html .= $q->hidden(-name => 'mingenomes', -value => $q->param('mingenomes'), -override => 1);
	    $html .= $q->hidden(-name => 'clusteroverlap', -value => $q->param('clusteroverlap'), -override => 1);
	    $html .= $q->hidden(-name => 'famcat', -value => $q->param('famcat'), -override => 1);
	    $html .= $q->hidden(-name => 'session', -value => $q->param('session'), -override => 1);
	    
	    
	    
	    $html .= $q->start_div({-id =>"clustertable"});
	    $html .= $clusterList->to_html_table($q);
	    $html .= $q->end_div();
	    $html .= $q->submit({-name => 'create'}, 'Create subsystem' );
	    
	    #unless ($q->param('sort')) {
	    $html .= $q->start_div({-id =>"clusterimage"});
	    $html .= $q->h3("Visual representation");
	    # use 
	    foreach my $cluster ($clusterList->clusters($q->param('sort'))) {
		
		# set the cluster in the clusterview object
		$clusterview_gfx->cluster($cluster);
		$html .= $q->a({-name=>$cluster->{id}},"Cluster ".$cluster->{id}.$q->br());
		$html .= $q->img({border => 0, 
				  usemap => "#".$cluster->{id}, 
				  src => &inline_image($clusterview_gfx->output("GD", $q))});
		$html .= $clusterview_gfx->image_map();
		$html .= $q->br();
	    }
	    
	    
	    $html .= $q->end_div();
	    
	    $html .= $q->end_form();
	    $html .= $q->end_div();
	    
	    
	    
	} elsif ($q->param('computing')) {

	    my $sessiondir = TEMPDIR."/gecko/".$q->param('user')."_".$q->param('session')."/";

	    unless (-e $sessiondir."/log.txt") {
			open LOG, ">".$sessiondir."log.txt";
			print LOG "[Parsing genome data:]\n";
			close LOG;
			open GENOMES, ">".$sessiondir."genomes.txt";
			foreach (@genomes) {
				print GENOMES "$_\n";
			}
			close GENOMES;
			# $html =  $self->computation($q);
		
			print STDERR 'SGE_ROOT='.SGE_ROOT.'; export SGE_ROOT; '.QSUB." -b y -q '*\@\@smphosts' -e $sessiondir/qsub.err ".BINDIR.'cluster_detection -s '.$sessiondir.'/genomes.txt -d '.$sessiondir.' -t '.$q->param('famcat').' -c '.$q->param('minclustersize').' -g '.$q->param('mingenomes').' -o '.$q->param('clusteroverlap');

			system ('SGE_ROOT='.SGE_ROOT.'; export SGE_ROOT; '.QSUB." -b y -q '*\@\@smphosts' -e $sessiondir/qsub.err  -o $sessiondir/qsub.out ".BINDIR.'cluster_detection -s '.$sessiondir.'/genomes.txt -d '.$sessiondir.' -t '.$q->param('famcat').' -c '.$q->param('minclustersize').' -g '.$q->param('mingenomes').' -o '.$q->param('clusteroverlap').' &');
    

	    }
	    $html =  $self->computation($q);
	} 
	
    } else {

	unless ($q->param('sort')) {
	    my $cluster_detection = SubsystemExtension::ClusterDetectionSparse->new($q->param('minclustersize'), $q->param('mingenomes'), $q->param('clusteroverlap'), 1);
	    unless (ref $cluster_detection && $cluster_detection->isa("SubsystemExtension::ClusterDetectionSparse")) {
		$html = &_error($q, "Could not initialize a SubsystemCandidateFactory object for the subsystem");
	    } else {
		# system call mit cluster detection durchfuehren
		
		my ($sequences, $genomes);
		if (scalar @genomes > 0 ) {
		    my $seed_factory = SubsystemExtension::SequenceFactory::SEED->new(\@genomes, $q->param('famcat') ? $q->param('famcat') : 'cog');
		    ($sequences, $genomes) = $seed_factory->createSequences();
		}
		print STDERR "[seqfile] ".$q->param('seqfile')."\n";
		
		if ($q->param('seqfile')) {
		    my $cog_factory = SubsystemExtension::SequenceFactory::COG->new(TEMPDIR.$q->param('seqfile'));
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
		$clusterList->toFile(TEMPDIR."/gecko/".$q->param('user')."_".$q->param('session')."/clusterlist.cls");
		foreach my $cluster ($clusterList->clusters()) {
		    $cluster->toFile(TEMPDIR."/gecko/".$q->param('user')."_".$q->param('session')."/cluster_".$cluster->{id}.".cls");
		}
	    }
	}
	
	$clusterList = SubsystemExtension::ClusterList->fromFile(TEMPDIR."/gecko/".$q->param('user')."_".$q->param('session')."/clusterlist.cls");
	# print STDERR &Dumper($clusterList);
	
	# html output
	
	$html .= &FIGjs::toolTipScript();
	$html .= $q->start_div({-id=>"content"});
	$html .= $q->start_form(-action => $q->url(), -method => 'post');
	
	# add the user params to the form as hidden fields
    
	$html .= $q->hidden(-name => 'genomes', -value => \@genomes, -override => 1);
	$html .= $q->hidden(-name => 'seqfile', -value => $q->param('seqfile'));
	$html .= $q->hidden(-name => 'user', -value => $q->param('user'), -override => 1);
	$html .= $q->hidden(-name => 'minclustersize', -value => $q->param('minclustersize'), -override => 1);
	$html .= $q->hidden(-name => 'mingenomes', -value => $q->param('mingenomes'), -override => 1);
	$html .= $q->hidden(-name => 'clusteroverlap', -value => $q->param('clusteroverlap'), -override => 1);
	$html .= $q->hidden(-name => 'famcat', -value => $q->param('famcat'), -override => 1);
	$html .= $q->hidden(-name => 'session', -value => $q->param('session'), -override => 1);
	

	
	$html .= $q->start_div({-id =>"clustertable"});
	$html .= $clusterList->to_html_table($q);
	$html .= $q->end_div();
	$html .= $q->submit({-name => 'create'}, 'Create subsystem' );
	
	#unless ($q->param('sort')) {
	$html .= $q->start_div({-id =>"clusterimage"});
	$html .= $q->h3("Visual representation");
	# use 
	foreach my $cluster ($clusterList->clusters($q->param('sort'))) {
	    
	    # set the cluster in the clusterview object
	    $clusterview_gfx->cluster($cluster);
	    $html .= $q->a({-name=>$cluster->{id}},"Cluster ".$cluster->{id}.$q->br());
	    $html .= $q->img({border => 0, 
			      usemap => "#".$cluster->{id}, 
			      src => &inline_image($clusterview_gfx->output("GD", $q))});
	    $html .= $clusterview_gfx->image_map();
	    $html .= $q->br();
	}
	
	
	$html .= $q->end_div();
	
	$html .= $q->end_form();
	$html .= $q->end_div();

    } 

    return $html;
}



sub subsystem_form {
    my ($self, $q) = @_;

    $q = $q ? $q : $self->{cgi};
    
    my $html;

    $html .= $q->start_div({-id=>"content"});
    $html .= $q->start_form(-action => $q->url(), -method => 'post');

    my @genomes = $q->param('genomes');

    $html .= $q->hidden(-name => 'seqfile', -value => $q->param('seqfile'), -override=>1);
    $html .= $q->hidden(-name => 'genomes', -value => \@genomes, -override => 1);
    $html .= $q->hidden(-name => 'user', -value => $q->param('user'), -override => 1);
    $html .= $q->hidden(-name => 'minclustersize', -value => $q->param('minclustersize'), -override => 1);
    $html .= $q->hidden(-name => 'mingenomes', -value => $q->param('mingenomes'), -override => 1);
    $html .= $q->hidden(-name => 'clusteroverlap', -value => $q->param('clusteroverlap'), -override => 1);
    $html .= $q->hidden(-name => 'famcat', -value => $q->param('famcat'), -override => 1);
    $html .= $q->hidden(-name => 'cluster', -value => $q->param('cluster'), -override => 1);
    my $cluster = SubsystemExtension::Cluster->fromFile(TEMPDIR."/gecko/".$q->param('user')."_".$q->param('session')."/cluster_".$q->param('cluster').".cls");
    
    $html .= $q->start_table();
    $html .= $q->Tr($q->td({-colspan=>'3'}, $q->h3("Enter data for subsystem creation")));
    $html .= $q->Tr($q->td("Subsystem name:"), $q->td({-colspan=>'2'}, $q->input({-type => 'text', -size=> '50', -name => 'subsystemname', -value=> ''})));
    
    $html .= $q->Tr($q->td({-colspan=>'3'}, "Functional roles:"));
    $html .= $q->Tr($q->td("Use"), $q->td("Role description"), $q->td("Abbreviation"));
    my $i =0;
    foreach ($cluster->containedGenes()) {
	$i++;

	my $desc = $_;
	
	foreach my $loc (@{$cluster->{sortedLocations}}) {
	    foreach my $gene (@{$loc->{genes}}) {
		if ($gene->{family} == $_) {
		    $desc = $gene->{category};
		    last;
		}
	    }
	}


	$html .= $q->Tr(
			$q->td($q->checkbox({-label=> "Role $i", -name => "role_$i", -checked => 1, -value=>1})),
			$q->td($q->input({-type => 'text', -size => '50', -name => "rolename_$i", -value=> $desc}))."\n",
			$q->td($q->input({-type => 'text', -size => '10', -name => "roleabbr_$i", -value=> $_}))."\n"
			);
	
    }
    $html .= $q->end_table();
    
    # spreadsheet
    $html .= $q->start_table();
    $html .= $q->start_Tr();
    $i = 0;
    foreach ($cluster->containedGenes()) {
	$i++;
	
	$html .= $q->th("Role $i")."\n";
	
    }
    $html .= $q->end_Tr();
    
    my %genes;
	#                 genome_id  family_id       gene_ids
	#%genes  $genes->{83333.1}->{437}      =    [456, 899]
	my %rolegenes;

	# take all locations and collect the occuring genes
    foreach my $location (@{$cluster->{sortedLocations}}) {
		my $i = 0;
		foreach my $fam (@{$location->{genes}}) {
			$i++;
			unless (ref $genes{$location->{sequence}}->{$fam->{family}} eq "ARRAY") {
				$genes{$location->{sequence}}->{$fam->{family}} = [];
			};
			push @{$genes{$location->{sequence}}->{$fam->{family}}}, $location->{start} + $i;
			
		}
	}
	
	# spannedSequences = zeilenanzahl
	# containedGenes = spaltenanzahl
    $i = 0;
	my $genome_index = 0;
	foreach my $seq ($cluster->spannedSequences()) {
		
		$html .= $q->start_Tr();
		$html .= $q->td($q->checkbox({-label=> "Genome ".$genomes[$seq], -name => "genome_$seq", -checked => 1, -value=>$genomes[$seq]}));
		$genome_index++;
		$i = 0;
		foreach my $fam ($cluster->containedGenes()) {
			$i++;
			foreach (@{$genes{$seq}->{$fam}}) {
				$html .= $q->hidden(-name => "gene_".$seq."_".$i, -value=>$_);
			}
			$html .= $q->td(join ', ', @{$genes{$seq}->{$fam}});
		}	
		$html .= $q->end_Tr()."\n";
	}

    
    $html .= $q->end_table();
    $html .= $q->submit("create subsystem");
    $html .= $q->end_form();
    $html .= $q->end_div();
    
    return $html;
    
}


sub subsystem_creation {

    my ($self, $q) = @_;
    
    $q = $q ? $q : $self->{cgi};
    
	 
    my $html;
    

    my $vars = $q->Vars();
    
    print STDERR &Dumper($vars);
    
    my $subsystem = Subsystem->new($q->param('subsystemname'), $self->{fig}, 1);
    
	unless (ref $subsystem && $subsystem->isa("Subsystem")) {
		# the creation of the subsystem failed
		$html .= $q->h3("Creation of Subsystem ".$q->param('subsystemname')." failed");
		
	}
    
    my %roles;
    my %genomes;
    my %pegs;


    # collect the information on roles from the
    # cgi params and store them as hashes in
    # a roles hash. Each role subhash can be accessed by its 
    # role_id as shown in the web-page
    
    foreach my $param (keys %$vars) {
	
	if ($param =~ /rolename_(\d+)/) {
	    unless ($roles{$1}) {
		$roles{$1} = {id => $1};
	    }
	    $roles{$1}->{name} = $vars->{$param};
	}
	
	if ($param =~ /roleabbr_(\d+)/) {
	    unless ($roles{$1}) {
		$roles{$1} = {id => $1};
	    }
	    $roles{$1}->{abbr} = $vars->{$param};
	}
	
	if ($param =~ /role_(\d+)/) {
	    unless ($roles{$1}) {
		$roles{$1} = {id => $1};
	    }
	    $roles{$1}->{active} = 1;
	}
	
	if ($param =~ /genome_(\d+)/) {
		$genomes{$1} = $vars->{$param};
	}

	if ($param =~ /gene_(\d+)_(\d+)/) {
		my @genes = split "\0", $vars->{$param};
		print STDERR $param." \n";
		print STDERR join ", ", @genes;

		unless (ref $pegs{$1}) {
			$pegs{$1} = {};
		}
		unless (ref $pegs{$1}->{$2}) {
			$pegs{$1}->{$2} = \@genes;
		} else {
			push @{$pegs{$1}->{$2}}, @genes;
		}
	}
	
    }
    
    # get the activated roles and sort them by their id
    # for each activated role create one entry in the subsystem
    
    foreach my $role (sort {$a->{id} <=> $b->{id}} 
					  grep {$_->{active}} values %roles) {
	
		$subsystem->add_role($role->{name}, $role->{abbr});
    }


	# get the activated genomes 
    # for each activated genome create one entry in the subsystem
    
    foreach my $genome_nr (sort keys %genomes) {
		print STDERR "adding genome ".$genomes{$genome_nr}."\n";
		$subsystem->add_genome($genomes{$genome_nr});
    }

	
	foreach my $genome (keys %pegs) {
		print STDERR "adding pegs for $genome\n";
		foreach my $role_id (keys %{$pegs{$genome}}) {
		
			my @pegs =  map {"fig|".$genomes{$genome}.".peg.".$_} @{$pegs{$genome}->{$role_id}};		
			print STDERR "adding pegs ".&Dumper(@pegs)."\n";;
			if ($roles{$role_id}->{active} && $roles{$role_id}->{abbr}) {
				$subsystem->set_pegs_in_cell($genome, $roles{$role_id}->{abbr}, \@pegs);
			}
		}

    }

    $subsystem->write_subsystem();
    
    # add the genomes and their pegs to the spreadsheet
   
    $html .= $q->h3("Subsystem created: ".$q->param('subsystemname')); 
    
    return $html;

}


sub subsystem {
	my ($self, $value) = @_;

	return $self->{subsystem} if (scalar(@_) == 1);
	$self->{subsystem} = $value;

}



    
sub logout {
	my ($self, $q) = @_;
	
	$q = $q ? $q : $self->{cgi};
    
	

	my $session_dir = TEMPDIR."/gecko/".$q->param('user').'_'.$q->param('session');
	if (-d $session_dir && -w $session_dir) {
		print STDERR "session dir $session_dir deleted\n";
		unlink glob "$session_dir/* $session_dir/.*";
		rmdir $session_dir;
	}

	$q->delete('user');
	$q->delete('genomes');
	$q->delete('session');
		
	$self->login($q)
}
