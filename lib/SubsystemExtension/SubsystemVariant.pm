package SubsystemExtension::SubsystemVariant;

use strict;
use warnings;

1;

sub new {
    
    my ($class, $id, $subsystem) = @_;

    my $self = {};
    $self->{id} = $id;
    $self->{subsystem} = $subsystem;
    $self->{counter} = 0;
    $self->{roles} = {};
    foreach ($subsystem->get_roles()) {
	$self->{roles}->{$_} = 0;
    }

    bless $self, $class;
}


sub add_instance {
    my ($self, $roles) = @_;
    $self->{counter}++;

    foreach (keys %$roles) {
	$self->{roles}->{$_}++;
    }
    
}


sub role_counter {

    my ($self, $role) = @_;

    return $self->{roles}->{$role};


}

sub role_significance {
    my ($self, $role) = @_;
    
    if ($self->{roles}->{$role}) {
	return $self->{roles}->{$role} / $self->{counter};
    } else {
	return 0;
    }

}

sub occurences {

    my ($self) = @_;

    return $self->{counter};
}

sub id {

    my ($self) = @_;

    return $self->{id};
}


sub match {
    my ($self, $roles) = @_;

    # the match candidate is represented as a hash $roles with role names as key and scores of
    # the best role instance as values

    # this method returns a arrayreference to a three tupel

    my $matchscore = 0;
    my $present = 0;

    # get the total number of roles that are used in this variant
    my $total = 0;
    foreach (values %{$self->{roles}}) {
	$total ++ if ($_ > 0);  
    }
    
    # iterate over the roles
    # those that are present  have value >= 1
    # missing == 0
    # this functional variant

    foreach my $role (keys %{$self->{roles}}) {
	#print STDERR $role."\n";
	# if a role is present in the match candidate add score and counter
	if (($roles->{$role}) && ($self->{roles}->{$role} > 0)) {
	    #print STDERR "both there\n";
	    $present++;
	    $matchscore += $self->role_significance($role) - 0.5;
	} elsif ((!$roles->{$role}) && ($self->{roles}->{$role} == 0)) {
	    #print STDERR "both missing\n";
	    $matchscore -= $self->role_significance($role) - 0.5;
	} elsif (($roles->{$role}) && ($self->{roles}->{$role} == 0)) {
	    #print STDERR "both missing\n";
	    $matchscore += $self->role_significance($role) - 0.5;
	} else {
	    #print STDERR "=!"; 
	    # is a role is needed for the variant but i not present del role_sig from counter
	    $matchscore -= $self->role_significance($role) - 0.5;
	}
    }

    
    if ($total > 0) {
	# print STDERR sprintf "%f %f %f", $present / $total, $present, $matchscore;
	return [$present / $total, $present, $matchscore];
    } else {
	return [0,0,0];
    }

}

sub to_html {
    my ($self, $roles) = @_;
    my $html = "<Tr><td>".$self->id().": ".$self->occurences()."</td>\n";
    foreach my $role (@$roles) {
	$html .= "<td";
	$html .= $self->role_significance($role) > 0 ?  " bgcolor=\"".$self->role_significance_color($role)."\"" : "";
	$html .= ">".$self->role_counter($role)."</td>";
    }
    
    $html .= "</Tr>";

    return $html;

}


sub role_significance_color {
    my ($self, $role) = @_;
    return sprintf("#9999%X",127 + 128 * $self->role_significance($role),127 + 128 * $self->role_significance($role), );
}
