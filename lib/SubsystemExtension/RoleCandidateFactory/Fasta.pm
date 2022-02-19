package SubsystemExtension::RoleCandidateFactory::Fasta;


=head1 NAME

SubsystemExtension::RoleCandidateFactory::Fasta

    =head1 DESCRIPTION

    CandidateFactory implementation that also implements the interface of the TOOL::Generic Class of GENDB


    =head2 Additional methods

    =over 4

=cut

use strict;
use warnings;
use Subsystem;
use FIG;
use Bio::SeqIO;


use vars qw(@ISA);
unshift @ISA, qw(SubsystemExtension::RoleCandidateFactory);

($VERSION) = ('$Revision: 1.1.1.1 $ ' =~ /([d.]+)/g);

1;


sub generate {
    my ($self, $dbfile) = @_;

    # check if the database file is readable
    # and if it is in the proper format

    # create temporary direcrtories and direct the blastoutput to that dir

    # check if blast database for subsystem exists,

    # call blast on global subsystem_proteins database
    

    die "Database $dbfile does not exist" unless  (-e $dbfile);


    my %candidates;

    # get a global O2DBI-2 master object
    my $master = $gendbAppFrame->application_master();
    
    foreach my $observation ($master->Observation->Function->Blast->SEED->fetchallby_subsystem_role($self->subsystem()->get_name()) {
	my $candidate = $self->_observation2candidate($observation);
	$candidates{$candidate->id} = $candidate;
    }

    if (wantarray) {
	return values %candidates;
    } else {
	return \%candidates;
    }	


    
}


sub _generate_roledb {


    my ($self) = @_;

    my $role_index = $self->subsystem->get_role_index($self->role());

    my $candidates = ROLEDB_DIR.$self->subsystem->get_name."_".$role_index.".faa";
    
    if (!-e $candidates) {
	# create multiple fasta file and blast against 
	
	open CANDIDATES, ">$candidates";
	
	
	my $col = $self->subsystem()->get_col($role_index);
	my $i = 0;
	for my $cell (@$col)
	{
	    
	    if (@$cell > 0)
	    {
		for my $peg (@$cell)
		{
		    # print STDERR "\tCandidate: $peg\n";
		    print CANDIDATES ">$peg\n".$fig->get_translation($peg)."\n";# if ($subsystem->get_variant_code($i) > 0);
		}
	    }
	    $i++;
	}
	close CANDIDATES;
	my $formatdb_cmd =
	    GENDB_FORMATDB . " -i $candidates -l /dev/null -o T -p T ";
	# print STDERR "Format DB $formatdb_cmd \n";
	system($formatdb_cmd);
    }
   
    
}


sub _blastresult2candidate {
    my ($self, $result_file) = @_;

    my $current_iteration;
    my %obs_data = ();
    my @db_ids;

    # this function parses the result fiel that is formated in the tabular blast

    open RESULT "<$result_file";
    while (RESULT) {
	chomp;
	if (substr($_, 0, 1) eq '#') {
	    # skip other comments
	    next;
	}
	
	my @raw = split(/\s+/, $_);
	next unless (scalar(@raw) == 12);


	contig => $region->abs_parent_region->name(),

	    $data->{start} = ($raw[6] - 1) * 3 + 1;
	    $data->{stop} = $raw[7] * 3;
	    $data->{db_from} = ($raw[8] - 1) * 3 + 1;
	    $data->{db_to} = $raw[9] * 3;
	start => $region->start(),
	stop => $region->stop(),
	bbh => 0, 
	psc => $raw[10],
	match => $observation->description(),
	frac => &FIG::min(($sim->e1+1 - $sim->b1) / $sim->ln1, ($sim->e2+1 - $sim->b2) / $sim->ln2),
	sf => (SameFunc::same_func($region->latest_annotation_function()->function(), $self->role)) ? 1 : 0,
	nbh => 0,
	ld =>  abs($region->length() - $observation->start())   
	});	

	my $data = {evalue => $raw[10],
		    tool => $self,
		    region => $region,
		    db_reference => $raw[1],
		    score => $raw[11],
		    identity => $raw[2] * 100,
		    iteration => $current_iteration};
	
	# store database id for later retrival of the entry
	push @db_ids, $raw[1];
	
	# depending on the database format, we have to convert
	# the start and stop positions


	}
	
	# generate a key from the data set
	# and store it in the observation hash
	my $key = join('!',$data->{db_reference}, $data->{start},
		       $data->{stop}, $data->{db_from}, $data->{db_to});
	

	my $candidate = SubsystemExtension::RoleCandidate->new($region->name(), $observation->function(), $self->subsystem->get_name(), $region->abs_parent_region->name(), $data);


    }
    
    # we need to get additional information about the database
    # entries, like entry length and description
    my $db_seqs_raw = $self->_get_db_entry_data(@db_ids);
    
    # strip off the leading database and GI definitions from the
    # database ids. blast does not report them correctly in all cases...
    my $db_seqs = {};
    while (my ($id, $value)= each(%$db_seqs_raw)) {
	my @parts = split (/\|/, $id);
	$db_seqs->{pop @parts} = $value;
    }
    
    # add information to observations
    foreach my $obs_key (keys %obs_data) {
	my @parts = split (/\|/, $obs_data{$obs_key}->{db_reference});
	my $seq = $db_seqs->{pop @parts};
	unless (ref($seq)) {
	    print STDERR "unable to get database entry for id ".$obs_data{$obs_key}->{db_reference}.", skipping observation.\n";
	    delete $obs_data{$obs_key};
	}
	else {
	    $obs_data{$obs_key}->{db_length} = $seq->{length};
	    $obs_data{$obs_key}->{description} = $seq->{description};
	}
    }

    close 
    
    # postprocess the result sets and store them 
    @datalist = map {$self->hsp_to_data($_,undef)} values %obs_data;
    
    
    

    my $region = $observation->region();

    
    
    return $candidate if (ref $candidate);
}


