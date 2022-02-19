package SubsystemExtension::SequenceFactory::COG;


use strict;
use warnings;
use Carp;
use Data::Dumper;
use integer;

1;


sub new {
	my ($class, $filename) = @_;

	my $self = { filename => $filename}; 

	bless $self, $class;

	return $self;


}


sub createSequences {
	my ($self) = @_;
	
	my %categories;
	my @sequences;
	my @genomes;

	open (COG, $self->{filename});
	my $state = 0;

	my ($genomeIndex, $geneIndex, $genome, $size, $geneCount);
	$genomeIndex = -1;

	while (<COG>) {
		chomp;
		next if ($_ eq "");
		unless ($_ =~ /^\d+.+/)  {
			# header for organisms
			
			($genome, $size) = split ',', $_;

			if ($genome && $size) {
				$genomeIndex++;
				$geneIndex = 0;
				$sequences[$genomeIndex] = [0];


				if ($size =~ /\-\s+\d+\.\.(\d+)/) {
					$size = $1;
				} else {
					$size = 0;
				}
				print STDERR "Genome: $genomeIndex $genome\n";
				push @genomes, { id => $genomeIndex,
								 name => $genome,
								 abbreviation => substr($genome,1,5),
								 size => $size,
								 genes => [0]
							   }
			}
			
		} else {
			if ($_ =~ /(\d+)\s+proteins/) {
				$genomes[$genomeIndex]->{gene_count} = $1;
			} elsif ($_ =~ /^(\d+)\s+/) {
				
				$geneIndex++;
				my ($cogID, $strand, $cogCategory, $geneName, $geneDescription) = split "\t", $_;
				$categories{$cogID * 1} = $cogCategory;
				push @{$sequences[$genomeIndex]}, $cogID * 1;
				push @{$genomes[$genomeIndex]->{genes}}, {id => $geneIndex,
													 family => $cogID * 1,
													 strand => $strand eq '+' ? 1 : -1,
													 category => $cogCategory,
													 genename => $geneName,
													 description => $geneDescription}
			   
			}
		}

	}
	close (COG);

	my @sorted_sequences = sort {scalar @$a <=> scalar @$b}  @sequences;
	my @sorted_genomes = sort {$a->{size} <=> $b->{size}} @genomes;

	
	return (\@sorted_sequences, \@sorted_genomes, \%categories);
	
}



