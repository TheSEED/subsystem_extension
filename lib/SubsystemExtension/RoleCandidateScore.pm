package SubsystemExtension::RoleCandidateScore;

use strict;
use warnings;
use Data::Dumper;




sub new {
    
    my ($class, $id, $scoring_params) = @_;

    # print STDERR "created $id scoring scheme\n";

    my $self = {};
    $self->{id} = $id;
    $self->{bbh_bonus} = $scoring_params->{bbh_bonus} ? $scoring_params->{bbh_bonus} : 50;
    $self->{samefunc_bonus} = $scoring_params->{samefunc_bonus} ? $scoring_params->{samefunc_bonus} : 25;
    $self->{nb_bonus} = $scoring_params->{nb_bonus} ? $scoring_params->{nb_bonus} : 30;
    $self->{nb_multi} = $scoring_params->{nb_multi} ? $scoring_params->{nb_multi} : 10;
    $self->{sims_multi} = $scoring_params->{sims_multi} ? $scoring_params->{sims_multi} : 1;
    $self->{bbhs_multi} = $scoring_params->{bbhs_multi} ? $scoring_params->{bbhs_multi} : 2;
    $self->{ld_div} = $scoring_params->{ld_div} ? $scoring_params->{ld_div} : 7.5;
    

    bless $self, $class;
}



sub score {
    
    my ($self, $rc) = @_;

    # bonus for best bidirectional hits
    my $score = $rc->{bbh} ? $self->{bbh_bonus} : 0;
    
    # coverage of the hit
    $score +=	$rc->{frac} * 50 if ($rc->{frac}); 
    $score +=	$rc->{samefunc} * $self->{samefunc_bonus} if ($rc->{samefunc}); 
    $score += $rc->{psc} != 0 ? - log( $rc->{psc})/log(10) : 181;

    my @nbs =  $rc->neighbors();
    $score += (scalar @nbs > 0) ?  $self->{nb_bonus} + (scalar @nbs *  $self->{nb_multi}) : 0;


    # prefer most common variant of the role
    # $score += $rc->sims_count * $self->{sims_multi} if ($rc->sims_count());

    $score += $rc->bbhs_count * $self->{bbhs_multi} if ($rc->bbhs_count());


    # treat length distances with negative values
    $score -= $rc->{ld} / $self->{ld_div};

    # print STDERR $candidate->{id}. " Score: $score\n"; 
    return $score;

}



sub toFile {

    my ($self, $filename) = @_;

    open TMP, ">$filename";
    print TMP &Dumper([$self]);
    close TMP;


}

sub fromFile {
    my ($class, $filename) = @_;
    
    my $self = do $filename;
    
    return $self;
}

1;
