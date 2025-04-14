# ----------------------------------------------------------------------
#
# TickToWK
#
# ----------------------------------------------------------------------

sub TickToCDate {
    my ($tick, $cal) = @_;
    my $res;
    if ($cal eq "WK" || $cal eq "AP")
    {
	my ($ny, $nq, $nm, $nd);
	$ny = int($tick/364);
	$tick = $tick - $ny * 364;
	$nq = int($tick/91);
	$tick = $tick - $nq * 91;
	$nm = $nq * 3 + int(($tick-1)/30);
	$nd = $tick - ($nm%3)*30;
	if ($nd == 0)
	{
	    my @t = ('Beltane', 'Lugnaad', 'Samhain', 'Candlemansa');
	    $res = sprintf("%s %d WK", $t[$nq], $ny + 770);
	}
	else
	{
	    my @t = ('Meadow', 'Heat', 'Breeze', 'Fruit', 'Harvest', 'Vintage', 'Frost', 'Snow', 'Ice', 'Thaw', 'Seedtime', 'Blossom');
	    #	$res = sprintf("%s %d, %d WK", $t[$nm] ,$nd, $ny + 770);
	    $res = sprintf("%d.%d.%d WK", $nd, $nm+1, $ny + 770);
	}
    }
    elsif ($cal eq "CM")
    {
	my $y = int($tick / 400);
	$tick -= 400*$y;

	my $m = int($tick / 20);
	my $d = $tick - $m*20;
	my $up = $m % 2;
	$m = int($m / 2);

	my @t = ('Lebh', 'Khomets', 'Porehk', 'Ov', 'Toyt', 'Vint', 'Kindheyt', 'Shakhres', 'Brenen', 'Mablen');
	$res = sprintf("%d %s %s %d CM\n", $d, $up ? "Ariber":"Aroplezn", $t[$m], $y);
    }
    else
    {
	print STDERR "Unknown calandar $cal for tick $tick\n";
	exit 1;
    }
    return $res;
}

# ----------------------------------------------------------------------
#
# TickToTM
#
# ----------------------------------------------------------------------

sub TickToTM {
    my ($tick) = @_;
    my ($ny, $nq, $nm, $nmd, $nyd, $nwd);
    $ny = int($tick/364);
    $tick = $tick - $ny * 364;
    $nyd = $tick;
    $nq = int($tick/91);
    $tick = $tick - $nq * 91;
    $nm = $nq * 3 + int(($tick-1)/30);
    $nd = $tick - ($nm%3)*30;
    $nwd = $nyd%7;
    my @res = ($nd, $nm, $ny, $nwd, $nyd);
    return @res;
}

# ----------------------------------------------------------------------
#
# TickToWK
#
# ----------------------------------------------------------------------

sub TickToWK {
    my ($tick) = @_;
    return Tick->new({tick => $tick, calendar => 'WK'});
}

1;
