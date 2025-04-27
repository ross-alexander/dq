# ----------------------------------------------------------------------
#
# TickToTM
#
# ----------------------------------------------------------------------

sub TickToTM {
    my ($tick) = @_;
    my ($year, $quarter, $month, $day, $year_day, $week_day);
    $year = int($tick/364);
    $tick -=  $year * 364;
    $year_day = $tick;
    $quarter = int($tick/91);
    $tick -= $quarter * 91;
    $month = $quarter * 3 + int(($tick-1)/30);
    $day = $tick - ($month%3)*30;
    $week_day = $year_day%7;
    return ($day, $month, $year, $week_day, $year_day);
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
