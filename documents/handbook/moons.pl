#!/usr/bin/perl

# ----------------------------------------------------------------------
#
# 2024-04-10
#
# Generate phases of the moon using Cairo and arcs
#
# ----------------------------------------------------------------------

use 5.34.0;
use Cairo;
use Math::Trig; #  ':pi cos sin tan';

# ----------------------------------------------------------------------

sub moon {
    my ($cr, $r, $state) = @_;
    
    $cr->move_to($r, 0);
    $cr->arc(0, 0, $r, 0, 2*pi);
    $cr->set_source_rgb(0,0,0) if (($state eq "waning") || ($state eq "new"));
    $cr->set_source_rgb(1,1,1) if (($state eq "waxing") || ($state eq "full"));
    $cr->fill();
    
    if (($state eq "waxing") or ($state eq "waning"))
    {
	$cr->move_to(0, -$r);
	$cr->arc(0, 0, $r, -pi/2, pi/2);

	my $matrix = $cr->get_matrix();
	$cr->scale(0.5, 1);
	$cr->arc_negative(0, 0, $r, pi/2, -pi/2);
	$cr->set_matrix($matrix);
	
	$cr->set_source_rgb(1,1,1) if ($state eq "waning");
	$cr->set_source_rgb(0,0,0) if ($state eq "waxing");
	$cr->fill();
    }
    $cr->move_to($r, 0);
    $cr->arc(0, 0, $r, 0, 2*pi);
    $cr->set_source_rgb(0,0,0);
    $cr->stroke();
}


my $r = 100;
my $m = 10;
my $name = "moon";

# my $image = Cairo::ImageSurface->create('argb32', $r*4, $r*4);

my $phases = [
    { file => 'moon0.pdf', name => "full" },
    { file => 'moon1.pdf', name => "waning" },
    { file => 'moon2.pdf', name => "new" },
    { file => 'moon3.pdf', name => "waxing" },
    ];

for my $phase (@$phases)
{
    my $image = Cairo::PdfSurface->create($phase->{file}, $r*2 + $m*2, $r*2 + $m*2);
    my $cr = Cairo::Context->create($image);
    $cr->save();
    $cr->translate($r + $m, $r + $m);
    moon($cr, $r, $phase->{name});
    $cr->restore();
}

exit 0;

# $cr->save();
# $cr->translate(2*$r + $r, $r);
# moon($r, "waning");
# $cr->restore();


# $cr->save();
# $cr->translate($r, 2*$r + $r);
# moon($r, "waxing");
# $cr->restore();

# $cr->save();
# $cr->translate(2*$r + $r, 2*$r + $r);
# moon($r, "new");
# $cr->restore();


# $image->write_to_png("$name.png");
