package SubsystemExtension::SubsystemCandidate::SEED;


use SubsystemExtension::RoleCandidate;
use strict;
use warnings;
use constant DEBUG => 1;
use Data::Dumper;
use FIG;
use Storable qw (nstore retrieve);

use base qw(SubsystemExtension::SubsystemCandidate);

1;


sub annotate {

    my ($self, $fig, $filter) = @_;

    foreach my $role ($self->roles()) {
	
	my $role_index = $self->subsystem->get_role_index($role);
		
	foreach my $candidate (values %{$self->{role_candidates}->{$role}}) {
	    
	    if (ref $filter && (ref $filter eq 'HASH')) {
		if ($filter->{$role_index}->{$candidate->id()}) {

		    my $matched_function = $fig->function_of($candidate->matched_peg(),"master");
		    print STDERR "Function of matched peg ".$candidate->matched_peg().": $matched_function \n" if (DEBUG);

		    my $original_function = $fig->function_of($candidate->id(),"master");
		    if ($original_function ne $matched_function) {
			$candidate->role($matched_function);
			$candidate->assign($fig, $filter->{'user'}); 
		    }
		}
	    } else {
		
		$candidate->assign($fig) if $candidate->trusted();
	    }
	}
	
    }


}

sub assign {

    my ($self, $fig, $filter) = @_;

    # the filter contains the genes and variant


    $self->subsystem->add_genome($self->genome);

    my $genome_index = $self->subsystem->get_genome_index($self->genome);
    
    print STDERR $self->functional_variant()." functional variant for genome $genome_index !\n" if (DEBUG);

    
    if ($filter->{'variant'}) {
	$self->subsystem->set_variant_code($genome_index, $filter->{'variant'});
    } else {
	$self->subsystem->set_variant_code($genome_index, $self->functional_variant());
    }
    
    foreach my $role ($self->roles()) {
	
	my $role_index = $self->subsystem->get_role_index($role);
		
	foreach my $candidate (values %{$self->{role_candidates}->{$role}}) {
	    
	    if (ref $filter && (ref $filter eq 'HASH')) {
		if ($filter->{$role_index}->{$candidate->id()}) {

		    # ROSS' SUGGESTION No. 2

		    # assign the function of the  matched protein to the candidate
		    # if the PEG does not already have the assignment of the matched protein
		    
		    my $matched_function = $fig->function_of($candidate->matched_peg(),"master");
		    print STDERR "Function of matched peg ".$candidate->matched_peg().": $matched_function \n";

		    my $original_function = $fig->function_of($candidate->id(),"master");
		    if ($original_function ne $matched_function) {
			$candidate->role($matched_function);
			$candidate->assign($fig, $filter->{'user'}); 
		    }
		}
	    } else {
		
		$candidate->assign($fig) if $candidate->trusted();
	    }
	}
	
    

	my @pegs = $fig->seqs_with_role($role,$filter->{'user'},$self->genome);
	
	if (@pegs > 0)
	{

	    # ROSS' SUGGESTION No.3
 
	    # ... Then add the genome, connecting any gene that now matches the
	    #     functional  role (whether it was assigned or not)" 
	    
	    # therefore the following line is deactivated 
	
	    # @pegs = grep {$filter->{$role_index}->{$_}} @pegs;

	    $self->subsystem->set_pegs_in_cell($genome_index, $role_index,\@pegs);
	}
    }
    
    $self->subsystem()->write_subsystem();
    
}


sub _multiple_annotation {
    my ($self, $candidate, $filter) = @_;
    
    my $annotation = $candidate->role();

    foreach my $role_index (keys %$filter) {
	if (ref $filter->{$role_index} eq 'HASH') {
	    foreach my $peg (keys %{$filter->{$role_index}}) {
		if (($peg eq $candidate->id()) && ($candidate->role_index() != $role_index)) {
		    $annotation .= " / ".$self->subsystem->get_role($role_index);
		}
	    }
	}
	
    }
    
    return $annotation;

}

sub to_html {

    my ($self, $q, $fig, $form) = @_;
    
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
			$q->th({-class => 'highlight2'},'SC') ,
			$q->th({-class => 'highlight2'},'Candidate'),
			$q->th({-class => 'highlight2'},'Match'),
			$q->th({-class => 'highlight2'},'#Sims'), 
			$q->th({-class => 'highlight2'},'#BBHs'),
			$q->th({-class => 'highlight2'},'E-Value'), 
			#$q->th({-class => 'highlight2'},'%Ident.'),
			$q->th({-class => 'highlight2'},'Blast hit'),
			$q->th({-class => 'highlight2'},'Function. annot.'),
			$q->th({-class => 'highlight2'},'Cluster'),
			$q->th({-class => 'highlight2'},'Score')
		    ); 

	my @role_candidates = sort {$b->score() <=> $a->score()} values %{$self->{role_candidates}->{$role}};
	
	if (scalar @role_candidates > 0) {
	    foreach my $candidate (@role_candidates) {
		$html .= $candidate->to_html($q, $fig, 'form');
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


