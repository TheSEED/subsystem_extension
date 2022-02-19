package SubsystemExtension::RoleCandidateFactory::GENDB;


=head1 NAME

SubsystemExtension::RoleCandidateFactory::GENDB

    =head1 DESCRIPTION

    CandidateFactory implementation that also implements the interface of the TOOL::Generic Class of GENDB


    =head2 Additional methods

    =over 4

=cut

use strict;
use warnings;
use Subsystem;
use GPMS::Application_Frame::GENDB;
use base qw(SubsystemExtension::RoleCandidateFactory);
use SubsystemExtension::RoleCandidate::GENDB;

1;




sub new {
    
    my ($class, $role, $subsystem, $tool, $genome, $user) = @_;

    my $self = $class->SUPER::new($role, $subsystem, $genome);

    $self->{user} = $user ? $user : 'master';
    $self->{gendb_master} = $tool->_master();
    $self->{tool} = $tool;
    $self->{genome} = $genome;


    return bless $self, $class;
}


sub generate {
    my ($self) = @_;

    # initalize a gendb application frame and initialize the selected project
    my %candidates;

    
    foreach my $observation ($self->gendb_master->Observation->Function->Blast->SEED->fetchallby_subsystem_role($self->subsystem()->get_name(), $self->role())) {
	if ($observation->region->abs_parent_region->name() eq $self->genome()->name()) {
	    my $candidate = $self->_observation2candidate($observation);
	    $candidates{$candidate->id} = $candidate;
	}
    }

    if (wantarray) {
	return values %candidates;
    } else {
	return \%candidates;
    }	
    
}


sub gendb_master {

    my ($self, $value) = @_;

    return $self->{gendb_master} if (scalar(@_) == 1);
    $self->{gendb_master} = $value;
}

sub genome {

    my ($self, $value) = @_;

    return $self->{genome} if (scalar(@_) == 1);
    $self->{genome} = $value;
}

sub tool {

    my ($self, $value) = @_;

    return $self->{tool} if (scalar(@_) == 1);
    $self->{tool} = $value;
}



sub _observation2candidate {
    my ($self, $observation) = @_;
    my $region = $observation->region();

    my $candidate = SubsystemExtension::RoleCandidate::GENDB->new($region->name(), $self->role(), $self->subsystem()->get_role_index($self->role), $self->subsystem, $region->abs_parent_region->name(), $observation, {
	contig => $region->abs_parent_region->name(),
	start => $region->start(),
	stop => $region->stop(),
	bbh => 0,
	role_abbr => $self->role_abbreviation(),
	psc => $observation->evalue(),
	match => $observation->db_reference(),
	frac => abs($observation->start() - $observation->stop()) / $observation->region()->length(), 
	sf => (SameFunc::same_func(ref $region->latest_annotation_function() ? $region->latest_annotation_function()->function() : '', $self->role)) ? 1 : 0,
	function => $region->latest_annotation_function() ? $region->latest_annotation_function()->function() : '',
	nbh => 0,
	ld =>  abs($region->length() - abs($observation->start()-$observation->stop()))   
	});


    return $candidate if (ref $candidate);
}


