package Tick;

use Carp::Assert;

# ----------------------------------------------------------------------
#
# new
#
# ----------------------------------------------------------------------

sub new {
    my $invocant = shift;
    my $class = ref($invocant) || $invocant;

    my $date = shift;

    my $calendars = {
	AP => {
	    months => {
		'january' => 0,
		'february' => 1,
		'march' => 2,
		'april' => 3,
		'may' => 4,
		'june' => 5,
		'july' => 6,
		'august' => 7,
		'september' => 8,
		'october' => 9,
		'november' => 10,
		'december' => 11,
	    },
	    seasons => {
		'spring' => 0,
		'summer' => 3,
		'autumn' => 6,
		'winter' => 9,
	    },
	},
	WK => {
	    months => {
		'meadow' => 0,
		'heat' => 1,
		'breeze' => 2,
		'fruit' => 3,
		'harvest' => 4,
		'vintage' => 5,
		'frost' => 6,
		'snow' => 7,
		'ice' => 8,
		'thaw' => 9,
		'seedtime' => 10,
		'blossom' => 11,
	    },
	    seasons => {
		'beltane' => 0,
		'spring' => 0,
		'lugnasad' => 3,
		'summer' => 3,
		'samhain' => 6,
		'autumn' => 6,
		'candlemansa' => 9,
		'winter' => 9,
	    },
	},
	CM => {
	    months => {	
		'lebh' => 0,
		'life' => 0,
		'khomets' => 2,
		'bread' => 2,
		'porekh' => 4,
		'dust' => 4,
		'ov' => 6,
		'ancestor' => 6,
		'toyt' => 8,
		'death' => 8,
		'vint' => 10,
		'wind' => 10,
		'kindheyt' => 12,
		'childhood' => 12,
		'shakhres' => 14,
		'prayer' => 14,
		'brenen' => 16,
		'burning' => 16,
		'mablen' => 18,
		'rain' => 18,
	    },
	    divisions => {
		'aroplezn' => 0,
		'ap.' => 0,
		'lower' => 0,
		'ariber' => 1,
		'ab.' => 1,
		'upper' => 1,
	    },
	},
    };

    # --------------------
    # Check if we are doing copy constructor
    # --------------------
    
    if (ref($date) eq 'Tick')
    {
	my $self = {
	    tick => $date->{tick},
	    calendar => $date->{calendar},
	    date => $date->{date},
	};
	bless($self, $class);
	return $self;
    }
    if (ref($date) eq "HASH")
    {
	croak if !exists($date->{calendar});
	croak if !exists($date->{tick});
	$self = {
	    tick => $date->{tick},
	    calendar => $date->{calendar}
	};
	bless($self, $class);
	$self->{date} = $self->CDate();
	return $self;
    }

    # --------------------
    # allocate locals
    # --------------------
    
    my ($tick, $day, $hmonth, $month, $year, $cal);

    # --------------------
    # Split date
    # --------------------
    
    my @bits = split(/[ ,\.\/]+/, $date);
    if (scalar(@bits) < 2)
    {
	printf(STDERR "Tick: incorrect date %s.\n", $date);
	exit 1;
    }

    # --------------------
    # Last part always the calendar
    # --------------------
	
    $cal = pop(@bits);

    if (!$calendars->{$cal})
    {
	print STDERR "Tick: known calendar \'$cal\' in date \'$date\'.\n";
	exit 1;
    }

    my $calendar = $calendars->{$cal};

    # --------------------
    # Check if already in tick format
    # --------------------

    if ((scalar(@bits) == 1) && ($bits[0] =~ /^[0-9]+$/))
    {
	$tick = $bits[0];
    }

    # --------------------
    # See if it is Communique Mercantile
    # --------------------
    
    elsif ($cal eq "CM")
    {
	$year = pop(@bits);
	if (!($year =~ m:^[0-9]+$:))
	{
	    print STDERR "Tick: unknown CM year $year.\n";
	    exit 1;
	}
	$month = pop(@bits);
	$month =~ tr:A-Z:a-z:;
	if (! exists($calendar->{months}->{$month}))
	{
	    print STDERR "Tick: unknown month $month in $date.\n";
	    exit 1;
	}
	$month = $calendar->{months}->{$month};
	
	my $div = pop(@bits);
	$div =~ tr:A-Z:a-z:;

	if (!exists($calendar->{divisions}->{$div}))
	{
	    print STDERR "Tick: CM date missing upper/lower indicator.\n";
	    exit 1;
	}
	$month += $calendar->{divisions}->{$div};

	if (scalar(@bits))
	{
	    $day = pop(@bits);
	    if (!$day =~ m:^[0-9]+$:)
	    {
		print STDERR "Tick: Day $day not a number.\n";
	    }
	}
	else
	{
	    $day = 1;
	}
	$tick = $year * 400 + $month * 20 + $day;
    }

    # --------------------
    # Otherwise it is AP or WK
    # --------------------
    
    else
    {
	if ($bits[0] =~ /[A-Za-z]+/)
	{
	    $month = $bits[0];
	    $day = $bits[1];
	}
	elsif ($bits[1] =~ /[A-Za-z]+/)
	{
	    $month = $bits[1];
	    $day = $bits[0];
	}
	else
	{
	    $day = $bits[0];
	    $month = $bits[1];
	}
	if ($month =~ /[A-Za-z]+/)
	{
	    my $t = lc($month);

	    if (exists($calendar->{seasons}->{$t}))
	    {
		$month = $calendar->{seasons}->{$t};
		$day = 0;
	    }
	    elsif (!exists($calendar->{months}->{$t}))
	    {
		print STDERR "Tick: unknown month \'$t\' in \'$date\'.\n";
		exit(1);
	    }
	    else
	    {
		$month = $calendar->{months}->{$t};
	    }
	}
	else
	{
	    $month -= 1;
	}
	$year = pop(@bits);

#	print "++ $day $month $year $calandar\n";
	
	if ($cal eq "AP")
	{
	    $year += 1900 if ($year < 100);
	    
	    my @md = (0, 31, 59, 89, 120, 151, 181, 212, 243, 273, 304, 334);
	    $tick += ($year - 1970) * 364;
	    $tick += $md[$month];
	    $tick += $day - 1;
	    $tick += 273;
	}
	else
	{
	    my @md = (1, 31, 61, 92, 122, 152, 183, 213, 243, 274, 304, 334);
	    $tick += ($year - 770) * 364;
	    $tick += $md[$month];
	    $tick += $day - 1;
	}
    }
    my $self = {
	tick => $tick,
	calendar => $cal,
	date => $date,
    };
    bless($self, $class);
    return $self;
};

# ----------------------------------------------------------------------
#
# CDate
#
# ----------------------------------------------------------------------

sub TM {
    my $self = shift(@_);

    my $cal = $self->{calendar};
    my $tick = $self->{tick};

    my $res = undef;
    my ($year, $quarter, $month, $day, $week_day, $year_day);

    if ($cal eq "WK")
    {
	$year = int($tick/364);
	$tick -= $year * 364;
	$year_day = $tick;
	$quarter = int($tick/91);
	$tick -= $quarter * 91;
	$month = $quarter * 3 + int(($tick-1)/30);
	$day = $tick - ($day%3)*30;
	$week_day = $year_day%7;

	$res = {
	    year => $year + 770,
	    month => $month,
	    day => $day,
	    week_day => $week_day,
	    year_day => $year_day,
	    calendar => 'WK',
	};
	
	if ($day == 0)
	{
	    my @t = ('Beltane', 'Lugnasad', 'Samhain', 'Candlemansa');
	    $res->{day_name} = $t[$quarter];
	}
	else
	{
	    my @day_names = ('Moonday', 'Duesday', 'Wotansday', 'Thunorsday', 'Freyasdar', 'Reapsday', 'Sunday');
	    my @month_names = ('Meadow', 'Heat', 'Breeze', 'Fruit', 'Harvest', 'Vintage', 'Frost', 'Snow', 'Ice', 'Thaw', 'Seedtime', 'Blossom');
	    $res->{month_name} = $month_names[$month];
	    $res->{day_name} = $day_names[$week_day];
	}
    }
    elsif ($cal eq 'AP')
    {
	$tick = $tick - 273;
	$year = int($tick/364);
	$tick = $tick - $year*364;
	$year_day = $tick;
	    
	my  @month_day = (0, 31, 59, 89, 120, 151, 181, 212, 243, 273, 304, 334);
	for my $m (0 .. 11)
	{
	    if ($tick >= $month_day[$m])
	    {
		$month = $m;
		break;
	    }
	}
	$day = $tick - $month_day[$month];
	my @month_name = ('January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December');
	$res = {
	    year => $year + 1970,
	    month => $month,
	    day => $day + 1,
	    month_name => $month_name[$month],
	    calendar => 'AP',
	}
    }
    elsif ($cal eq "CM")
    {
	$year = int($tick / 400);
	$tick -= 400*$y;

	$month = int($tick / 20);
	$day = $tick - $month*20;
	my $up = $month % 2;
	$month = int($month / 2);

	my @month_names = ('Lebh', 'Khomets', 'Porehk', 'Ov', 'Toyt', 'Vint', 'Kindheyt', 'Shakhres', 'Brenen', 'Mablen');
	$res = {
	    year => $year,
	    month => $month,
	    upper => $up,
	    lower => 1 - $up,
	    day => $day,
	    month_name => sprintf("%s %s", $up ? "Ariber":"Aroplezn", $month_names[$m]),
	    calendar => 'CM',
	};
    }
    else
    {
	print STDERR "Unknown calandar $cal for tick $tick\n";
	exit 1;
    }
    return $res;
}

sub CDate {
    my $self = shift(@_);

    my $cal = $self->{calendar};
    my $tick = $self->{tick};

    my $res;

    if ($cal eq "WK")
    {
	my ($ny, $nq, $nm, $nd);
	$ny = int($tick/364);
	$tick -= $ny * 364;
	$nq = int($tick/91);
	$tick -= $nq * 91;
	$nm = $nq * 3 + int(($tick-1)/30);
	$nd = $tick - ($nm%3)*30;
	if ($nd == 0)
	{
	    my @t = ('Beltane', 'Lugnasad', 'Samhain', 'Candlemansa');
	    $res = sprintf("%s %d WK", $t[$nq], $ny + 770);
	}
	else
	{
	    my @t = ('Meadow', 'Heat', 'Breeze', 'Fruit', 'Harvest', 'Vintage', 'Frost', 'Snow', 'Ice', 'Thaw', 'Seedtime', 'Blossom');
	    $res = sprintf("%s %d, %d WK", $t[$nm] ,$nd, $ny + 770);
#	    $res = sprintf("%d.%d.%d WK", $nd, $nm+1, $ny + 770);
	}
    }
    elsif ($cal eq 'AP')
    {
	$tick = $tick - 273;
	$year = int($tick/364);
	$tick = $tick - $year*364;
	my  @month_day = (0, 31, 59, 89, 120, 151, 181, 212, 243, 273, 304, 334);
	for my $m (0 .. 11)
	{
	    croak;
	    if ($tick >= $month_day[$m])
	    {
		$month = $m;
		break;
	    }
	}
	$day = $tick - $month_day[$month];
	my @month_name = ('January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December');
	$res = sprintf("%s %d, %d AP", $month_name[$month], $day+1, $year + 1970);
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
	$res = sprintf("%d %s %s %d CM", $d, $up ? "Ariber":"Aroplezn", $t[$m], $y);
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
# TO_JSON
#
# ----------------------------------------------------------------------

sub TO_JSON {
    my ($self) = shift;
    my $ret = {
	tick => $self->{tick},
	calendar => $self->{calendar},
	date => $self->{date},
	cdate => $self->CDate(),
    };
    return $ret;
}
	

sub tick {
    my ($self) = shift;
    return $self->{tick};
}

sub calendar {
    my ($self) = shift;
    return $self->{calendar};
}

sub yaml_dump {
    my ($self) = shift;
    my $ret = {
	tick => $self->{tick},
	calendar => $self->{calendar},
	date => $self->{date},
	cdate => $self->CDate(),
    };
    return $ret;
}

use overload failback => 1,
    '""' => sub {
	my ($self) = shift;
	$self->CDate();
	#	sprintf("%d %s", $self->tick(), $self->calendar());
},
    '-' => sub {
	my ($self, $other) = @_;

	$tick -= ref($other) eq 'Tick' ? $other->{tick} : $other;
	my $new = {
	    tick => $tick,
	    calendar => $self->{calendar}
	};
	bless($new);
},
    '>' => sub {
	my ($self, $other) = @_;
	$self->tick() > $other->tick();
},
    '+' => sub {
	my ($self, $other) = @_;
	my $tick = $self->{tick};
	
	$tick += ref($other) eq 'Tick' ? $other->{tick} : $other;
	my $new = {
	    tick => $tick,
	    calendar => $self->{calendar}
	};
	bless($new);
},
    '=' => sub {
	my ($self) = @_;
	
	my $new = {
	    tick => $self->{tick},
	    calendar => $self->{calendar}
	};
	bless($new);
	$new;
},
    '+=' => sub {
	my ($self, $other) = @_;
	
	my $tick = $self->{tick};
	if (ref($other) eq 'Tick')
	{
	    $self->{tick} += $other->{tick};
	}
	else
	{
	    $self->{tick} += $other;
	}
	$self;
},
    '==' => sub {
	my ($self, $other) = @_;
	($self->{calendar} eq $other->{calendar}) && ($self->{tick} == $other->{tick});
},
    '<' => sub {
	my ($self, $other) = @_;
	($self->{calendar} eq $other->{calendar}) && ($self->{tick} < $other->{tick});
};

1;
