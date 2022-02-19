package SubsystemExtension::RoleCandidate::SEED;


use Subsystem;
use strict;
use warnings;
no warnings qw(redefine);
use base qw(SubsystemExtension::RoleCandidate);
use FIG;

1;

sub assign {
    my ($self, $fig, $user) = @_;
    
    if (! $user) { $user = "master:extension" }

    if ($user =~ /master:(.*)/)
    {
	my $userR = $1;
	$fig->assign_function($self->{id},'master',$self->role(),'');
	$fig->add_annotation($self->{id},$userR,"Set master function to\n".$self->role()."\n");
    }
    else
    {

	$fig->assign_function($self->{id},$user,$self->role(),"");
	$fig->add_annotation($self->{id},$user,"Set function to\n".$self->role()."\n");
    }
}
sub to_html {

    my ($self, $q, $fig, $form) = @_;
    
    # my $rcm = SubsystemExtension::RoleCandidateMatch->new($self->{match}, 100, 140, 70, 110, 170, 160);

    my @subsys = $fig->subsystems_for_peg($self->{id});
    my $mouseover = '';
    my $conflict_count = 0;

    my $mouseover_match = $fig->function_of($self->{match}, 'master');

    foreach my $ent (@subsys) {

	if ($ent->[0] ne $self->{subsystem}) {
	    $mouseover .= $q->b($ent->[0]).": ".$ent->[1].$q->br();
	    $conflict_count++;
	}

    }
    my $neighbors = '-';
    if (scalar $self->neighbors() > 0) {
	$neighbors = join '<br/>', map {'<a href="protein.cgi?user='.$q->param('user').'&prot='.$_->id().'">'.$_->id().'</a>'} $self->neighbors();
    }
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
		  $q->td({-class => 'highlight1', -onMouseover=>"javascript:if(!this.tooltip) this.tooltip=new Popup_Tooltip(this, 'Subsystems', '$mouseover', ''); this.tooltip.addHandler(); return false;" },$conflict_count > 0 ? $conflict_count : '' ), 
		  
		  $q->td({-class => 'highlight1'},$q->a({-href=>'protein.cgi?prot='.$self->{id}."&user=".$q->param('user')},$self->{id}) ),
		  $q->td({-class => 'highlight1', -onMouseover=>"javascript:if(!this.tooltip) this.tooltip=new Popup_Tooltip(this, 'Function', '$mouseover_match', ''); this.tooltip.addHandler(); return false;" },$q->a({-href=>'protein.cgi?prot='.$self->{match}."&user=".$q->param('user')},$self->{match})),
		  $q->td({-class => 'highlight1'},$self->{sims_count}),
		  $self->{bbhs_count} > 0 ? $q->td({-bgcolor=>'#00CC00'},$self->{bbhs_count}) : $q->td({-class => 'highlight1'},'-'),
		  $q->td({-class => 'highlight1'},$self->{psc}),
		  # $q->td({-class => 'highlight1'},sprintf "%0.2f", $self->{identity}*100),
		  $q->td({-class => 'highlight1'},$self->{rcm} ? $q->img({-src=>$self->{rcm}->to_png()}) : $self->{ld}),
		  $q->td({-class => 'highlight1'},$self->{samefunc}.": ".$self->{function}),
		  $q->td({-class => 'highlight1'},$neighbors),
		  $q->td({-class => 'highlight1'},sprintf "%0.2f", $self->score())
		  );
    
}

