package SubsystemExtension::SubsystemCandidate::GENDB;


use SubsystemExtension::RoleCandidate;
use strict;
use warnings;
use constant DEBUG => 1;

use base qw(SubsystemExtension::SubsystemCandidate);

1;


sub new {
    my ($class, $subsystem, $genome, $role_candidates, $parameters) = @_;
    
    my $self = $class->SUPER::new($subsystem, $genome, $role_candidates, $parameters);

    $self->{gendb_master} = $genome->_master();
    
    return bless $self, $class;
 
    print STDERR "created SubsystemCandidate::GENDB\n";

}

sub assign {

    my ($self) = @_;
  
    my $annotator = $self->{gendb_master}->Annotator->init_name("SubsystemExtension");

    
    my $subsystem_annotation = $self->{gendb_master}->Annotation->Function->create(time(),$annotator,$self->{genome},'Hypothetical protein',0,2); # no evidence, automaticaly annotated


    my $description = $self->subsystem()->get_name()."\n";
    $description .= sprintf "Functional variant: %d (%.2f %%) similar to %s \n",
    $self->functional_variant(), $self->functional_variant_score(),$self->functional_variant_template(); 
    
    foreach my $role ($self->roles())  {
	my @instances = values %{$self->{role_candidates}->{$role}};
	if (scalar @instances > 0) {
	    $description .= "$role: ";
	    $description .= join ", ", map { $_->id();} (@instances);
	    $description .= "\n";
	}
    }
    
    $subsystem_annotation->name($self->subsystem()->get_name());
    $subsystem_annotation->description($description);
    $subsystem_annotation->comment("Missing roles:\n".join "\n", $self->missing_roles());

    foreach my $role (keys %{$self->{role_candidates}}) {

	foreach my $candidate (values %{$self->{role_candidates}->{$role}}) {
	    $candidate->assign();
	}
    }
    
}


