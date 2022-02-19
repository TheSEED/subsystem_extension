package SubsystemExtension::RoleCandidateMatch;

use strict;
use warnings;
use GD ();
use MIME::Base64 ();
no warnings qw(redefine);

1;

sub new {
    my ($class, $hit, $from1, $to1, $from2, $to2, $length1, $length2) = @_;
    
    my $self = {
	hit => $hit,
	from1 => $from1,
	from2 => $from2,
	to1 => $to1,
	to2 => $to2,
	length1 => $length1,
	length2 => $length2
	};
    
    bless $self, $class;
    
    return $self;
    
}

sub to_png {
    
    my ($self) = @_;


    my ($offset1, $offset2, $width, $height);

    $height = 24;
    
    if ($self->{from1} > $self->{from2}) {
	$offset1 = 50;
	$offset2 = 50 +$self->{from1} - $self->{from2};
    } else {
	$offset2 = 50;
	$offset1 = 50 +$self->{from2} - $self->{from1};
    }

    if ($self->{length1} + $offset1 > $self->{length2} + $offset2) {
	$width = $self->{length1} + $offset1 + 50;
    } else {
	$width = $self->{length2} + $offset2 + 50;
    }

    my $scale = 100 / $width;

    my $image = new GD::Image(130,$height);
    my $white = $image->colorAllocate(220,220,220);
    my $black = $image->colorAllocate(0,0,0);
    my $yellow = $image->colorAllocate(255,255,0);
    
    my $color = $image->colorAllocate(120, 120, 120);
    my $colorhit = $image->colorAllocate(0, 225, 0);
    my $lightcolor = $image->colorAllocate(200,200,200);
    my $darkcolor = $image->colorAllocate(30,30,30);

    my $font = GD::Font->Tiny();

    $image->line(0,$height/4, $width * $scale, $height/4, $black);
    $image->line(0,($height/4)*3, $width * $scale, ($height/4)*3, $black);
    $image->string($font, 105,($height/12),$self->{length1},$black);
    $image->filledRectangle($offset1 * $scale , $height/12, ($offset1 +  $self->{length1}) * $scale , ($height/12)*5, $color);
    $image->filledRectangle(($offset1  + $self->{from1})  * $scale, $height/12, ($offset1 +  $self->{to1}) * $scale, ($height/12)*5, $colorhit);

    $image->filledRectangle($offset2  * $scale, ($height/12)*7, ($offset2 +  $self->{length2}) * $scale, ($height/12)*11, $color);
    
    $image->string($font, 105,($height/12)*7,$self->{length2},$black);
    
    $image->filledRectangle(($offset2 + $self->{from2})  * $scale, ($height/12)*7, ($offset2 +  $self->{to2}) * $scale, ($height/12)*11, $colorhit);
    
    

    return "data:image/png;base64,".MIME::Base64::encode_base64((ref $image && $image->isa('GD::Image')) ? $image->png : '');

}

