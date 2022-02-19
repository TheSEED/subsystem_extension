package SubsystemExtension::SubsystemCandidate;



use FIG;
use Subsystem;
use SubsystemExtension::RoleCandidate;
use strict;
use warnings;
use Storable qw (nstore retrieve);

use constant DEBUG => 0;
1;


sub new {
    my ($class, $subsystem, $genome, $role_candidates, $parameters) = @_;
    print STDERR @_ if (DEBUG);
    my @roles = $subsystem->get_roles();
    
    my $self = {
	genome => $genome,
	subsystem => $subsystem,
	role_candidates => $role_candidates, 
	human => $parameters->{'human'}, #has human annotations
	functional_variant => 0,
	functional_variant_score => 0,
	functional_variant_template => '',
	roles => \@roles 	

	};
    
    return bless $self, $class;
    
}

sub toFile {

    my ($self, $filename) = @_;

    ## do not store the subsystem object
    # therefore we overwrite this with the subsystem name

    my $tmp_subsys = $self->{subsystem};
    
    $self->{subsystem} = $self->{subsystem}->get_name();

    nstore $self, $filename; # use nstore to write in network order

    # and set it bach to the object after the data has been stored

    $self->{subsystem} = $tmp_subsys;
    

}

sub fromFile {
    my ($class, $filename) = @_;
    
    my $self = retrieve $filename;

    my $fig = FIG->new();
    $self->{subsystem} = $fig->get_subsystem($self->{subsystem}); 

    bless $self, $class;

    return $self;
}


sub fromFileFast {
    my ($class, $filename) = @_;
    
    my $self = retrieve $filename;

    bless $self, $class;

    return $self;
}

sub verify {
    my ($self, $verifier) = @_;

    if ($verifier->verifySubsystemCandidate($self)) {
	$self->assign();
    }
}

sub assign {

    die "Abstract method that creates annotations and functional assignments for a subsystem candidate\n";
}


sub to_xml {
    my ($self) = @_;
    my $xml = "<SubsystemCandidate>";
    foreach my $role ($self->roles()) {
	$xml .= "<RoleCandidates>";
	my @role_candidates = sort {$b->score() <=> $a->score()} values %{$self->{role_candidates}->{$role}};
	if (scalar @role_candidates > 0) {
	    foreach (@role_candidates) {
		$xml .= $_->to_xml();
	    }
	}
	$xml .= "</RoleCandidates>";
    }
    $xml .= "</SubsytemCandidate>";
    return $xml;
}

sub score2color {
    my ($self, $score) = @_;
    return '#00FF00' if ($score > 255);
    return sprintf("#00%X00",($score/2 + 127));
}

sub roles {
    my ($self, $value) = @_;

    return @{$self->{roles}} if (scalar(@_) == 1);
    $self->{roles} = $value;
}


sub to_html {

    my ($self, $form) = @_;
    
    my $q = new CGI();
    my $html;


    $html .= $q->start_table();
    $html .= $q->start_Tr();
    # foreach my $role (sort {$self->subsystem->get_role_index($a) cmp $self->subsystem->get_role_index($b)} keys %{$self->{role_candidates}}) {
    my $role_index = 0;
    foreach my $role ($self->roles()) {
	my @role_candidates = sort {$b->score() <=> $a->score()} values %{$self->{role_candidates}->{$role}};
	if (scalar @role_candidates > 0) {
	    
	    $html .= $q->td({-bgcolor=> $self->score2color($role_candidates[0]->score())},$role_candidates[0]->trusted() ? $q->b($self->subsystem->get_role_abbr($role_index)) :$self->subsystem->get_role_abbr($role_index) );
	    
	} else {
	    $html .= $q->td($self->subsystem->get_role_abbr($role_index));
	}
	$role_index++;
    }
    $html .= $q->end_Tr();
    $html .= $q->end_table();
    
    $role_index = 0;
    $html .= $q->br();
    $html .= $q->start_table();
    

    foreach my $role ($self->roles()) {
	
	$html  .= $q->Tr($q->th({-colspan => 11}, $q->h3($self->subsystem->get_role_abbr($role_index)." ".$role)));
	$html .= $q->Tr($q->th({-class => 'highlight2'},'Assign'), 
		    $q->th({-class => 'highlight2'},'Candidate PEG') ,
		    $q->th({-class => 'highlight2'},'Match'), 
		    $q->th({-class => 'highlight2'},'#Sims'), 
		    $q->th({-class => 'highlight2'},'BBH'),
		    $q->th({-class => 'highlight2'},'eValue'), 
		    $q->th({-class => 'highlight2'},'% Overlap'),
		    $q->th({-class => 'highlight2'},'Length diff'),
		    $q->th({-class => 'highlight2'},'Similar function. annot.'),
		    $q->th({-class => 'highlight2'},'Cluster'),
		    $q->th({-class => 'highlight2'},'Score')
		    ); 

	my @role_candidates = sort {$b->score() <=> $a->score()} values %{$self->{role_candidates}->{$role}};
	
	if (scalar @role_candidates > 0) {
	    foreach my $candidate (@role_candidates) {
		$html .= $candidate->to_html('form');
	    }
	} else {
	    $html .= $q->Tr($q->td({-colspan => 11, -bgcolor=>'#DD9999'}, 'No candidates detected'));
	}
	$html .= $q->Tr($q->td({-colspan => 11}, $q->br()));
	$role_index++;
    }
    $html .= $q->end_table();
    
    return $html;

}

# this will output a line starting with the name of the organism
# followed by the functional variant and a comma separated list of pegs for each
# functional role of the subsystem
# Each of these entries is separated by a tab \t

# example:  
#taxon_id    variant   peg_1, peg_2    peg_16    peg_17

sub to_ss_format {
    
    my ($self) = @_;

    my $ss_format = $self->genome()."\t".$self->functional_variant()."\t";
    

    foreach my $role ($self->roles()) {
	$ss_format .= join ",", map {$_->id;} values %{$self->{role_candidates}->{$role}};
	$ss_format .= "\t";
    }	

    return $ss_format;
}

sub _detectRoleCandidateClusters {

    my ($self) = @_;

    ##### this method fills up the neighborhood information
    # for candidates

    my $all_candidates = {}; # key => candidate_id, value [role1, role2....]


    # iterate over the roles
    foreach my $role (keys %{$self->{role_candidates}}) {

	# for each role get the candidates (values)
	foreach my $candidate (values %{$self->{role_candidates}->{$role}}) {

	    # iterate over the remaining roles
	    foreach my $role2 (keys %{$self->{role_candidates}}) {
		next if ($role2 eq $role);
		# for each other_role get the candidates (values)
		foreach my $candidate2 (values %{$self->{role_candidates}->{$role2}}) {
		    # and add it to the neighbours  
		    $candidate->add_neighbor($candidate2) if ($candidate->_isNeighbor($candidate2));
		}
	    }
	}
    }


}



sub subsystem {

    my ($self, $value) = @_;

    return $self->{subsystem} if (scalar(@_) == 1);
    $self->{subsystem} = $value;
}


sub genome {

    my ($self, $value) = @_;

    return $self->{genome} if (scalar(@_) == 1);
    $self->{genome} = $value;
}


sub role_candidates {

    my ($self, $role) = @_;

    # returns either a reference to the hash of candidates for $role {id => RoleCandidate object}
    # or a reference to the hash of role_candidates {role => has of candidates for that role

    if ($role) {
	return $self->{role_candidates}->{$role};
    }
    else {
	return $self->{role_candidates};
    }

}

sub functional_variant {

    my ($self) = @_;

    return $self->{functional_variant};

}




sub missing_roles {
    
    my ($self) = @_;
    
    my @missing_roles;

    foreach ($self->roles()) {
	
	push @missing_roles, $_ if (scalar keys %{$self->role_candidates->{$_}} == 0); 
    }

    return @missing_roles;
}

sub functional_variant_score {

    my ($self) = @_;

    return $self->{functional_variant_score};

}

sub functional_variant_template {

    my ($self) = @_;

    return $self->{functional_variant_template};

}
