package SubsystemExtension::RoleCandidate;


use Subsystem;
use strict;
use SubsystemExtension::RoleCandidateMatch;
use warnings;
no warnings qw(redefine);

1;


sub new {
    my ($class, $id, $role, $role_index, $subsystem, $genome, $parameters) = @_;
    
    my $self = {
	id => $id,                                # unique identifier in gendb, the seed or a gff file
	genome => $genome,                        # the genome this gene belongs to 
	contig => $parameters->{'contig'},        # the contig this gene belongs to
	start => $parameters->{'start'},          # start relative to $contig
	stop => $parameters->{'stop'},            # stop relative to $contig
	role => $role,                            # the potential role
	role_index => $role_index,                # the index of the role
	role_abbr => $parameters->{'role_abbr'},
	subsystem => $subsystem,                  # subsystem to assign to
	rcm => $parameters->{'rcm'} ? $parameters->{'rcm'} : '',
	match => $parameters->{'match'},          # best matching gene from an organism already in the subsystem
	bbh  => $parameters->{'bbh'} ? $parameters->{'bbh'} : 0,             # boolean: bbh yes or no
	psc => $parameters->{'psc'},              # evalue of the match
	frac => $parameters->{'frac'},            # frac = percent identity 
	samefunc => $parameters->{'sf'} ? $parameters->{'sf'} : 0,          #
	nb_roles => $parameters->{'nbh'},
	nb_candidates => $parameters->{'nb_candidates'} ? $parameters->{'nb_candidates'} : [],
	ld => $parameters->{'ld'},                # length distance in AA residues
	human => $parameters->{'human'},          # candidate was confirmed by human
	function => $parameters->{'function'},
	sims_count => $parameters->{'sims_count'} ? $parameters->{'sims_count'} : 0 ,
	bbhs_count => $parameters->{'bbhs_count'} ? $parameters->{'bbhs_count'} : 0,
	trusted => $parameters->{'trusted'} ? $parameters->{'trusted'} : 0,
	identity => $parameters->{'identity'}
	};
    
    return bless $self, $class;

}


sub assign {

    my ($self) = @_;
    print STDERR "abstract assign() method called on RoleCandidate instance\n";

}

sub compare {

    my ($self, $candidate) = @_;

    if (ref $candidate && $candidate->isa("SubsystemExtension::RoleCandidate")) {

	if ($self->score < $candidate->score) {
	    return -1;
	} else {
	    return 1;
	}

    }

}

sub _psc2bgcolor {
    my ($psc) = @_;
    my $color = '#00';
    $color .= hex((1 - $psc) * 200 + 55);

}

sub to_html {

    my ($self, $form) = @_;
    
    
    my $q = new CGI();


    # my $rcm = SubsystemExtension::RoleCandidateMatch->new($self->{match}, 100, 140, 70, 110, 170, 160);

    return $q->Tr({-bgcolor=>$self->{human} ? '#BBBBFF' : $self->trusted() ? '#99FF99' : ''},
		  ($form) ? $q->td({-class => 'highlight1'}, 
				   $q->checkbox(-name=>"Role_".$self->{role_index},
						-checked=> $self->trusted() ? 'checked' : '',
						-value=>$self->id,
						-label=>'Assign')
#,
#				   $q->checkbox(-name=>"ExRole_".$self->{role_index},
#						-checked=>'',
#						-value=>$self->id,
#						-label=>'Exclusive')

				   ) : '',
		  $q->td({-class => 'highlight1'},$q->a({-href=>'protein.cgi?prot='.$self->{id}},$self->{id})),
		  $q->td({-class => 'highlight1'},$q->a({-href=>'protein.cgi?prot='.$self->{match}},$self->{match})),
		  $q->td({-class => 'highlight1'},$self->{sims_count}),
		  $self->{bbh} ? $q->td({-bgcolor=>'#00CC00'},'yes') : $q->td({-class => 'highlight1'},'-'),
		  $q->td({-class => 'highlight1'},$self->{psc}),
		  $q->td({-class => 'highlight1'},sprintf "%0.2f", $self->{frac}*100),
		  $q->td({-class => 'highlight1'},$self->{rcm} ? $q->img({-src=>$self->{rcm}->to_png()}) : $self->{ld}),
		  $q->td({-class => 'highlight1'},$self->{samefunc}.": ".$self->{function}),
		  $q->td({-class => 'highlight1'},join '<br/>', map {'<a href="protein.cgi?prot='.$_->id().'">'.$_->id().'</a>'} $self->neighbors()),
		  $q->td({-class => 'highlight1'},sprintf "%0.2f", $self->score())
		  );
    
}


sub add_neighbor {
    my ($self, $neighbor) = @_;
    push @{$self->{nb_candidates}}, $neighbor if (ref $neighbor && $neighbor->isa("SubsystemExtension::RoleCandidate"));
}




sub matched_peg {

    my ($self, $value) = @_;

    return $self->{match} if (scalar(@_) == 1);
    $self->{macth} = $value;

}

sub neighbors {
    my ($self, $value) = @_;

    my %nbs;
    if (scalar(@_) == 1) {
	foreach (@{$self->{nb_candidates}}) {

	    $nbs{$_->id()} = $_ if (ref $_ && $_->isa("SubsystemExtension::RoleCandidate"));
	}
	return values %nbs;
    }
    $self->{nb_candidates} = $value if (ref $value eq 'ARRAY');
}


sub id {

    my ($self, $value) = @_;

    return $self->{id} if (scalar(@_) == 1);
    $self->{id} = $value;
}


sub role {

    my ($self, $value) = @_;

    return $self->{role} if (scalar(@_) == 1);
    $self->{role} = $value;

}


sub role_index {

    my ($self, $value) = @_;
    
    return $self->{role_index} if (scalar(@_) == 1);
    $self->{role_index} = $value;
    
}

sub role_abbreviation {

    my ($self, $value) = @_;
    
    return $self->{role_abbr} if (scalar(@_) == 1);
    $self->{role_abbr} = $value;
    
}



sub contig {

    my ($self, $value) = @_;

    return $self->{contig} if (scalar(@_) == 1);
    $self->{contig} = $value;

}



sub start {

    my ($self, $value) = @_;

    return $self->{start} if (scalar(@_) == 1);
    $self->{start} = $value;

}

sub stop {

    my ($self, $value) = @_;

    return $self->{stop} if (scalar(@_) == 1);
    $self->{stop} = $value;

}

sub psc {
    my ($self, $value) = @_;
    return $self->{psc} if (scalar(@_) == 1);
    $self->{psc} = $value;
}

sub trusted {
    my ($self, $value) = @_;
    return $self->{trusted} if (scalar(@_) == 1);
    $self->{trusted} = $value;
}

sub sims_count {
    my ($self, $value) = @_;
    return $self->{sims_count} if (scalar(@_) == 1);
    $self->{sims_count} = $value;
}

sub inc_sims_count {
    my ($self) = @_;
    $self->{sims_count}++;
    return $self->{sims_count};

}

sub bbh {
    my ($self, $value) = @_;
    return $self->{bbh} if (scalar(@_) == 1);
    $self->{bbh} = $value;
}

sub bbhs_count {
    my ($self, $value) = @_;
    return $self->{sims_count} if (scalar(@_) == 1);
    $self->{sims_count} = $value;
}

sub inc_bbhs_count {
    my ($self) = @_;
    $self->{bbhs_count}++;
    return $self->{bbhs_count};

}


sub score {
    my ($self) = @_;


    # bonus for best bidirectional hits
    my $score = $self->{bbh} ? 50 : 0;
    
    # coverage of the hit
    $score +=	$self->{frac} * 50 if ($self->{frac}); 
    $score +=	$self->{samefunc} * 20 if ($self->{samefunc}); 
    $score += $self->{psc} != 0 ? - log( $self->{psc})/log(10) : 180;


    my @nbs =  $self->neighbors();
    $score += (scalar @nbs > 0) ? 55 + (scalar @nbs * 10) : 0;


    # prefer most common variant of the role
	# $score += $self->sims_count  if ($self->sims_count());

    $score += $self->bbhs_count * 1 if ($self->bbhs_count());


    # treat length distances with negative values
    $score -= $self->{ld} / 10;

    # print STDERR $candidate->{id}. " Score: $score\n"; 
    return $score;

}



sub _isNeighbor {
    
    my ($self, $cand, $dist) = @_;

    $dist = 5000 unless $dist; 
    
    # compares this RoleCandidate to $cand and checks if they share one contig and the centers
    # of their nucleotide sequences have no further distance than 5000 bp;

    if (($self->contig() eq $cand->contig()) && ($self->id() ne $cand->id()) && (abs((($self->start() + $self->stop) / 2) - ($cand->start() + $cand->stop) / 2) < $dist)) {
	return 1;
    } else {
	return 0;
    };
}

sub subsystem {

    my ($self, $value) = @_;

    return $self->{subsystem} if (scalar(@_) == 1);
    $self->{subsystem} = $value;

}


