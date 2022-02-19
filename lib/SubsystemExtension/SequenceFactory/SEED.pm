package SubsystemExtension::SequenceFactory::SEED;


use strict;
use warnings;
use Carp;
use Data::Dumper;
use integer;
use FIG;


1;


sub new {
	my ($class, $genomes, $type, $fig) = @_;

	my $self = { 
		fig => $fig ? $fig : FIG->new(),
		genomes => $genomes,
		type => $type ? $type : 'cog'
		}; 

	bless $self, $class;

	return $self;
}


sub createSequences {

    my($self) = @_;


    my @genomes;
    my @sequences;
    my %categories;
    
    my($relational_db_response);
    my $rdbH = $self->{fig}->db_handle;
    my $category = 1;
    my $genomeIndex = 0;
    if ($rdbH->table_exists('localid_cid') && $rdbH->table_exists('localfam_cid')) {
		foreach my $genome (@{$self->{genomes}}) {
			my @pegs = $self->{fig}->pegs_of($genome);
			my ($genus, $domain) = $self->{fig}->genus_species_domain($genome);
			print STDERR $genomeIndex;
			my $genome_hashref = {
				id => $genome,
				name => $genus,
				abbreviation => $genome,
				size => scalar @pegs,
				genes => []	
				};
			
			my @sequence;
			my $statement  = "SELECT localfam_cid.family, localfam_function.function, localid_cid.localid from localfam_cid, localfam_function, localid_cid WHERE localid_cid.localid like 'fig|$genome.peg.%'  and localid_cid.cid = localfam_cid.cid and localfam_cid.family = localfam_function.family and localfam_cid.family like '".$self->{type}."|%'";


			if (($relational_db_response = $rdbH->SQL($statement)) && (@$relational_db_response > 1))
			{
				
				
				foreach my $tuple (@$relational_db_response) { 
					if ( $tuple->[2] =~ /peg\.(\d+)/) {
						my $index = $1;
						
						if (($tuple->[0] =~ /(.+)\|(\D+)(\d+)/)) {
							#$1 family type (cog, mcl, figfam ...)
							#$2 family type
							#$3 decimal number (id)
							
							# use only those with matching type ('cog', 'fig', 'sp', 'pir', 'kegg', 'pfam')
							next unless $1 eq $self->{type};
							my $family = $3 * 1;
							# print STDERR "$peg: $index -> $family\n";
							# print STDERR "$genome: $1 $2 $3 $index => $family\n";
							$sequence[$index] = $family;
							
							$genome_hashref->{genes}->[$index] = {
								id => $index,
								family => $family,
								strand => ($self->{fig}->strand_of($tuple->[2]) eq '+') ? 1 : -1,
								category => $tuple->[1],
								name => $tuple->[2],
								description => $2.$3
								};
							foreach my $subsystem ($self->{fig}->subsystems_for_peg($tuple->[2])) {
								$genome_hashref->{genes}->[$index]->{"Subsystem ".$subsystem->[0]} = $subsystem->[1];
							}

						}
					}
				}
			
				# only add this genome to the list if entries for the category exist
			
				push @sequences, \@sequence;
				push @genomes, $genome_hashref; 
				
				$genomeIndex++;
			}
			
		}
		
    }
    
    my @sorted_sequences = sort {scalar @$a <=> scalar @$b}  @sequences;
    my @sorted_genomes = sort {scalar @{$a->{genes}} <=> @{$b->{genes}}} @genomes;
    
    return (\@sorted_sequences, \@sorted_genomes, \%categories);
    
}
