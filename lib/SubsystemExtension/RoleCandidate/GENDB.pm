package SubsystemExtension::RoleCandidate::GENDB;


use SubsystemExtension::RoleCandidate;
use strict;
use warnings;
use constant DEBUG => 1;

use base qw(SubsystemExtension::RoleCandidate);

1;


sub new {
    my ($class, $id, $role, $role_index, $subsystem, $genome, $observation, $parameters) = @_;

    
    my $self = $class->SUPER::new($id, $role, $role_index, $subsystem, $genome, $parameters);
    
    $self->{observation} = $observation;
    $self->{gendb_master} = $observation->_master();
    
    return bless $self, $class;
 
}

sub assign {

    my ($self) = @_;

    my $annotator = $self->{gendb_master}->Annotator->init_name("SubsystemExtension");

    my $observation_data = $self->{observation}->_parse_description();
    my $annotation_data = $self->{observation}->get_annotation_data();
    
    my $role_annotation = $self->{gendb_master}->Annotation->Function->CDS->create(time(),$annotator,$self->{observation}->region(),'Hypothetical protein',0,2); # no evidence, automaticaly annotated


    if ($annotation_data->{'EC Number'}) {
	$role_annotation->ec_number($annotation_data->{'EC Number'});
    }
    if ($annotation_data->{'Roles'}) {
	$role_annotation->roles($annotation_data->{'Roles'});
    }
    
    $role_annotation->name($self->role_abbreviation());

    push @{$role_annotation->observations()}, $self->{observation};


    my $description = "Subsystem: ".$self->subsystem()->get_name()."\n";
    $description .= $self->role;
    $role_annotation->description($description);
    $role_annotation->function($self->role);
    
}
