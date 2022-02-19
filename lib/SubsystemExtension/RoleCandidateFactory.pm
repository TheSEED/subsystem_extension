package SubsystemExtension::RoleCandidateFactory;


use strict;
use warnings;
use Carp;
use FIG;
use Subsystem;
use SameFunc;
use SubsystemExtension::RoleCandidateScore;
use SubsystemExtension::ExtensionConfig qw (EXTENSIONEVAL EXTENSIONDEPTH);

1;

sub new {

    my ($class, $role, $subsystem, $organism, $evalue_threshold, $depth, $scoring) = @_;
    my $self =  {
	evalue_threshold => $evalue_threshold ? $evalue_threshold : EXTENSIONEVAL,
	depth => $depth ? $depth : EXTENSIONDEPTH,
	role => $role,
	subsystem => $subsystem,
	organism => $organism,
	role_index => $subsystem->get_role_index($role), 
	role_abbr => $subsystem->get_role_abbr($subsystem->get_role_index($role)),
	score => SubsystemExtension::RoleCandidateScore->new($scoring ? $scoring : 'default')
	
	};

    return bless $self, $class;
}


sub generate {
    croak "called abstract generate method for RolecandidateFactory";
}
sub tune {
    croak "called abstract tune method for RolecandidateFactory";
}


# get/set method
sub subsystem {
	my ($self, $value) = @_;

	return $self->{subsystem} if (scalar(@_) == 1);
	$self->{subsystem} = $value;

}


sub organism {
    my ($self, $organism) = @_;
    
    return $self->{organism} if (scalar(@_) == 1);
    $self->{organism} = $organism;
    
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


sub evalue_threshold {

    my ($self , $value) = @_;
    
    return $self->{evalue_threshold} if (scalar(@_) == 1);
    $self->{evalue_threshold} = $value;

}


sub depth {

    my ($self , $value) = @_;
    
    return $self->{depth} if (scalar(@_) == 1);
    $self->{depth} = $value;

}


