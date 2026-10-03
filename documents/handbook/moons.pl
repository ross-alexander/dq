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

# ----------------------------------------------------------------------
#
# M A I N
#
# ----------------------------------------------------------------------

my $r = 100;
my $m = 10;
my $name = "moon";

my $phases = [
    { id => 0, phase => "full" },
    { id => 1, phase => "waning" },
    { id => 2, phase => "new" },
    { id => 3, phase => "waxing" },
    ];

for my $phase (@$phases)
{
    my $pdf_path = sprintf("moon%d.pdf", $phase->{id});
    my $pdf_image = Cairo::PdfSurface->create($pdf_path, $r*2 + $m*2, $r*2 + $m*2);
    my $pdf_cr = Cairo::Context->create($pdf_image);
#    $cr->save();
    $pdf_cr->translate($r + $m, $r + $m);
    moon($pdf_cr, $r, $phase->{phase});
    #    $cr->restore();

    my $svg_path = sprintf("moon%d.svg", $phase->{id});
    my $svg_image = Cairo::SvgSurface->create($svg_path, $r*2 + $m*2, $r*2 + $m*2);
    my $svg_cr = Cairo::Context->create($svg_image);
#    $svg_cr->save();
    $svg_cr->translate($r + $m, $r + $m);
    moon($svg_cr, $r, $phase->{phase});
#    $cr->restore();
}

exit 0;
