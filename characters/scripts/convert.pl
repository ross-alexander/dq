#!/usr/bin/perl -I/locker/gaming/dq/characters/scripts

# ----------------------------------------------------------------------
#
# DQ ranking (LaTeX) to JSON or XML
#
# 2021-10-26: Ross Alexander
#   Add JSON export.
#
# 2018-03-22: Ross Alexander
#   Apply fixes for perl-5.26.1
#
# ----------------------------------------------------------------------

use 5.40.0;
use Getopt::Long;
use Carp::Assert;
use Encode;
use Tick;
use Perl6::Slurp;
use Data::Dumper;
use Carp;
use File::Spec::Functions qw(rel2abs splitpath file_name_is_absolute catdir);
use File::Basename;
use YAML::PP qw(DumpFile);
use JSON;
use JSON::XS;

# ----------------------------------------------------------------------
#
# days2weeks
#
# ----------------------------------------------------------------------

sub days2weeks {
    my ($time) = @_;
    my $weeks_text;
    my $days_text;
    if ($time > 0)
    {
	my $weeks = int($time / 7);
	my $days = $time - ($weeks * 7);
	if ($weeks > 0)
	{
	    $weeks_text = ($weeks == 1) ? "1 week" : "$weeks weeks";
	}
	if ($days > 0)
	{
	    $days_text .= (($days == 1) ? "1 day" : "$days days");
	}
	$weeks_text .= " ".$days_text if length($days_text);
    }
    else
    {
	$weeks_text = "No time";
    }
    return $weeks_text;
}

# ----------------------------------------------------------------------
#
# Update_Adventure
#
# ----------------------------------------------------------------------

sub Update_Adventure {

    my ($map, $state, $adventure) = @_;

    my $tick = $state->{'tick'};

    my $start = Tick->new($adventure->{start_tick});
    my $end = Tick->new($adventure->{end_tick});

    # --------------------
    # Print out adventure name
    # --------------------

    printf("* ----------------------------------------------------------------------\n");
    printf("* %s [%s - %s]\n", $adventure->{name}, $start, $end);
    printf("* ----------------------------------------------------------------------\n\n");
    
    # --------------------
    # Process Money
    # --------------------
    
    for my $m (@{$adventure->{monies} || []})
    {
	next if ($m->{ledger});
	my $in = $m->{in};
	my $out = 0;

	# --------------------
	# Check "in" is correct.
	# --------------------

	if ($state->{money} != $in)
	{
	    printf "Money computed value different from stored value (%d <> %d)\n", $state->{money}, $in;
	    exit(1);
	}
	
	for my $l (@{$m->{lines}})
	{
	    $in += $l->{in} if (exists($l->{in}));
	    $out += $l->{out} if (exists($l->{out}));
	}

	my $total = $in - $out;
	my $amount = $m->{out};

	if ($amount != $total)
	{
	    print STDERR "Error in money dated ", $m->{date}, " ($amount vs $total).\n";
	    exit(1);
	}
	$state->{money} = $amount;
	printf("Money: in $in -- spent -- $out -- out $amount\n\n");
    }

    # --------------------
    # Check Dates
    # --------------------
    
    if (!defined($tick))
    {
	$tick = Tick->new($start);
    }

    if ($tick > $start)
    {
	printf STDERR "Serious start date issue (Current %s [%s] -- Start %s [%s])!\n", $tick, $tick->CDate(), $start, $start->CDate();
	exit 1;
    }
    if ($start > $end)
    {
	printf STDERR "Serious date issue!\n";
	exit 1;
    }

    # --------------------
    # Set current time to end of adventure + 1 day
    # --------------------
    
    $tick = Tick->new($end);
    $tick += 1;
    
    # --------------------
    # Iterate over all the ranking nodes
    # --------------------

    my $ep_total = 0;
    
    for my $ranking (@{$adventure->{ranking}})
    {
	my $ranking_ep_total = 0;
	if ($ranking->{date})
	{
	    my $s = Tick->new($ranking->{date});
	    if (!$ranking->{star} && ($s < $tick))
	    {
		printf("Ranking for %s starts before end of the adventure\n", $ranking->{description});
		exit(1);
	    }
	    $ranking->{start_tick} = Tick->new($s);
	}
	else
	{
	    $ranking->{start_tick} = $ranking->{star} ? Tick->new($start) : Tick->new($tick);
	}
	
	printf("-- %s : %s%s\n\n", $ranking->{description}, $ranking->{start_tick}, $ranking->{star} ? "*" : "");

	my $days = 0;
	for my $block (@{$ranking->{blocks}})
	{
	    # --------------------
	    # Set block level ep and time counters to zero
	    # --------------------
	    
	    my $block_ep = 0;
	    my @time = (0, 0, 0);

	    # --------------------
	    # Iterate over every ranking line in the block
	    # --------------------
	    
	    for my $line (@{$block->{lines}})
	    {
		
		# Get the type ie skill, spell, ritual, etc

		my $type = $line->{type};

		# Make sure valid entry

		if (!exists $map->{$type})
		{
		    print STDERR "Type $type unknown -- exiting.\n";
		    exit 1;
		}

		my $name = $line->{name};

		if ((!exists($line->{initial}) || !length($line->{initial})) && $map->{type}->{_rankable_}) 
		{
		    print STDERR "$type $name does not have initial value.\n";
		    exit 1;
		}

		# --------------------
		# Create hash entry if it don't already exist
		# --------------------
		
		$map->{$type}->{$name} = {} if (!exists $map->{$type}->{$name});
		$map->{$type}->{$name}->{name} = $name;

		$map->{$type}->{$name}->{college} = $line->{college} if ($line->{college});
		$map->{$type}->{$name}->{ref} =  $line->{ref} if ($line->{ref});

		my $initial = $line->{initial};
		my $final = $line->{final};
		my $rank = $map->{$type}->{$name}->{rank};
		my $partial = int($line->{partial});
		
		if (exists($map->{$type}->{$name}->{rank}) && !$partial && ($rank ne $initial))
		{
		    printf "$type $name initial [%s] not same as current rank [%s]\n", $initial, $rank;
		    exit(1);
		}

		# Having got the initial ranking value its now time to get the final.

		if (exists($line->{final}) && !$partial)
		{
		    my $old = $map->{$type}->{$name}->{"rank"};
		    $map->{$type}->{$name}->{"rank"} = $final;
		}
		else
		{
		    $map->{$type}->{$name}->{"rank"} = $initial;
		}

		# --------------------
		# Check values
		# --------------------
		
		my ($em, $ep_calc, $ep, $ep_raw, $sum, $diff, $csum);

		$ep = $line->{ep};
		$ep_raw = $line->{ep_raw};
		
		if ($line->{initial} && $line->{final})
		{
		    $initial = 0 if ($initial eq "U" && ($final > 0));
		    if ($initial ne "U")
		    {
			$sum = $line->{sum};
			$csum = ($type eq "stat") ?
			    $final - $initial :
			    (($final * ($final + 1)) - ($initial * ($initial +1))) / 2;
		    
			if ($csum != $sum)
			{
			    print "Initial = $initial  Final = $final  sum = $csum (sum = $sum).\n";
			    print to_json($line), "\n";
			    exit(1);
			}
			if ($line->{em})
			{
			    $em = $line->{em};
			    $ep_calc = $sum * $em;
			    $ep = $line->{ep_raw} // $line->{ep};
			    if ($ep_calc != $ep)
			    {
				print "EP = $ep -- computed EP $sum * $em = $ep_calc\n";
				print to_json($line), "\n";
				exit(1);
			    }
			}
			else
			{
			    $ep = $line->{ep};
			}
			if ($line->{ep} && $line->{ep_raw})
			{
			    $ep_raw = $line->{ep_raw};
			    $diff = ($ep_raw >= $ep) ? $ep / $ep_raw : $ep / $ep_raw;
			}
		    }
		}

		# --------------------
		# Process time
		# --------------------

		my $time = 0;
		if (exists($line->{time}) && ($line->{time} =~ /([0-9]+) (day|days|week|weeks)/))
		{
		    $time = $1;
		    $time *= 7 if (defined($2) && (($2 eq "week") || ($2 eq "weeks")));
		}
		my $track = $line->{track};
		$line->{day_equiv} = $time;
		$time[$track] += $time;
		$block_ep += $line->{ep} if (exists($line->{ep}));
		$ep = $ep // 0;
		$ep_raw = $ep_raw // 0;
		$final = $final // 0;
		$diff = $diff // 0.0;
		$initial = $initial // "U";
		$line->{days} = $time;
		printf("%-30s (%3s..%3s) Raw EP = %d EP = %d Diff = %4.2f : Time = %s\n", $name, $initial, $final, $ep_raw, $ep, $diff, $time);
	    }
	    $block->{ep} = $block_ep;
	    $ep_total += $block_ep;
	    $ranking_ep_total += $block_ep;

	    # --------------------
	    # sort the time tracks to get maximum
	    # --------------------

	    my @tsort = sort { $a <=> $b } @time;
	    $block->{start_tick} = $ranking->{start_tick} + $days;
	    $block->{days} = $tsort[$#tsort];
	    $block->{time} = days2weeks($block->{days});
	    $block->{end_tick} = Tick->new($block->{start_tick});
	    $block->{end_tick} += ($block->{days} > 0 ? $block->{days}-1 : 0);
	    $days += $tsort[$#tsort];
	    printf("\n");
	    printf("EP: %d -- Track times = %s [%d %d]\n\n", $block->{ep}, join(" : ", @time), $block->{start_tick}->{tick}, $block->{end_tick}->{tick});
	}
	
	# Tick + integer doesn't work so work around it

	$ranking->{days} = $days;
	$ranking->{time} = days2weeks($days);
	$ranking->{end_tick} = Tick->new($ranking->{start_tick});
	$ranking->{end_tick} += $days;

	$ranking->{start} = $ranking->{start_tick}->CDate();
	$ranking->{end} = $ranking->{end_tick}->CDate();

	$ranking->{ep} = $ranking_ep_total;

	printf("-- %s : %s → %s (%d)\n\n", $ranking->{description}, $ranking->{start_tick}, $ranking->{end_tick}, $days);

	if (!$ranking->{star})
	{
	    $tick = Tick->new($ranking->{end_tick});
	}
    }

    # --------------------
    # Process total Experience
    # --------------------

    my $exp = $adventure->{experience};
    if (defined $exp)
    {
	croak if (!defined($exp->{in}));
	my $ep_in = int($exp->{in});
	my $ep_gained = int($exp->{gained});
	my $ep_spent = int($exp->{spent});
	my $ep_out = int($exp->{out});

	$state->{ep_total} += $ep_gained;
	my $in = $state->{"ep"};

	if ($in != $ep_in)
	{
	    print STDERR "Recorded transferred EP ($ep_in) is different from computed value ($in).\n";
	    exit(1);
	}

	my $out = $in + $ep_gained - $ep_total;

	if ($ep_total != $ep_spent)
	{
	    printf STDERR "Recorded spent EP (%d) is different from computed value (%d) [remaining %d vs %d].\n", $ep_spent, $ep_total, $ep_out, $out;
	    exit(1);
	}
	if ($out != $ep_out)
	{
	    print STDERR "Recorded remaining EP ($ep_out) is different from computed value ($out).\n";
	    exit(1);
	}
	$state->{ep} = $out;

	printf("EP: in %d gained %d spent %d out %d\n", $ep_in, $ep_gained, $ep_spent, $ep_out);
    }
    if ($adventure->{notes})
    {
	say($adventure->{notes});
    }
    
    $state->{"tick"} = $tick;
    printf("Time: start %s - end %s - current %s (%s) [%d]\n", $start->CDate(), $end->CDate(), $tick->CDate(), $tick->{tick}, $tick->{tick} - $end->{tick});
    printf("\n");
}


# ----------------------------------------------------------------------
#
# XML_File
#
# ----------------------------------------------------------------------

sub Update_Character {

    my ($conf, $character) = @_;

    # --------------------
    # Create reference to a hash which hold ranking values.
    # --------------------
    
    my $map = $conf->{_map_};
    
    # --------------------
    # Create refernece to a hash which holds state and values to pass
    # between adventures.
    # --------------------
    
    my $state = {
	'money' => 0,
	'ep' => 0,
	'ep_total' => 0,
	'tick' => undef,
    };

    $map->{'state'} = $state;

    # --------------------
    # Iterate over every adventure and process sequentially.
    # --------------------

    for my $a (@{$character->{adventures}})
    {
	&Update_Adventure($map, $state, $a);
    }

#    say "----------------------------------------------------------------------";
#    exit(1);
   
    $character->{_map_} = $map;
    $character->{_state_} = $state;
}

# ----------------------------------------------------------------------
#
# Convert_Items
#
# ----------------------------------------------------------------------

sub Convert_Items {
    my ($in) = @_;

    my $items = {};
    
    if (m/^\\begin\{items\}\{([A-Za-z0-9, ]+)\}/)
    {
	$items->{description} = $1;
    }

    while (<$in>)
    {
	chomp $_;
	return $items if (m:^\\end\{items\}:);
	s/[ ]?\\\\$//;
	push(@{$items->{item}}, $_);
    }
    return;
}

# ----------------------------------------------------------------------
#
# Convert_Monies
#
# ----------------------------------------------------------------------

sub Convert_Monies {
    my ($in) = @_;
    my $monies = {
	lines => []
    };
    my $date;

    if (m/^\\begin\{monies\}\[([A-Za-z ]+)\]\{(-?[0-9]+)\}\{(-?[0-9]+)\}\{([A-Za-z0-9\/,\. ]+)\}/)
    {
	$monies->{ledger} = $1;
	$monies->{in} = $2;
	$monies->{out} = $3;
	$monies->{date} = $4;
	$date = $4;
    }
    elsif (m/^\\begin\{monies\}\{(-?[0-9]+)\}\{(-?[0-9]+)\}\{([A-Za-z0-9\/,\. ]+)\}/)
    {
	$monies->{in} = $1;
	$monies->{out} = $2;
	$monies->{date} = $3;
	$date = $3;
    }
    $monies->{tick} = Tick->new($date);

    while (<$in>)
    {
	chomp $_;
	return $monies if (m:^\\end\{monies\}:);
	s/[ ]?\\\\([ ]?(\\hline)?)$//;
	my ($desc, $out, $in) = split(/[ \t]+?\&[ ]?/, $_);
	my $line = {};
	$line->{description} = $desc;
	$line->{out} = $out if (length($out));
	$line->{in} = $in if (length($in) && !length($out));
	push(@{$monies->{lines}}, $line);
    }
}

# ----------------------------------------------------------------------
#
# Convert_Ranking
#
# ----------------------------------------------------------------------

sub Convert_Ranking {
    my ($opts, $in) = @_;

    my $ranking = {};
    
    if (m:\\begin\{(ranking\*?)\}\{(.*)\}\{(.*)\}:)
    {
	$ranking->{description} =  $2;
	$ranking->{star} = 1 if ($1 eq "ranking*");
	$ranking->{date} = $3 if (length($3));
    }
    elsif (m:\\begin\{(ranking\*?)\}\{(.*)\}:)
    {
	$ranking->{description} =  $2;
	$ranking->{star} = 1 if ($1 eq "ranking*");
    }
    else
    {
	print STDERR "Bad ranking line $_\n";
	return undef;
    }

    my $block = {};

    while(<$in>)
    {
	my $cref;
	my $sref;

	chomp $_;
	$_ =~ s:^[ ]+::;
	last if (m:^\\end\{ranking\*?\}:);

	if (m:^[ \t]*\\\\:)
	{
	    push(@{$ranking->{blocks}}, $block) if(defined($block));
	    $block = { lines => [] };
	    next;
	}
	next if (m:^[ \t]+$:);
	next if (m:^Total:);
	s/[ \t]*\\\\([ ]*\\hline)?$//;
	my ($name, $init, $sum, $em, $ep_raw, $ep, $time, $cost) = split(/[ \t]*&[ \t]*/, $_);
	$name =~ s/ +$//;
	next if (!length($name));
	next if ($name =~ /\\hline/);

	my $type = undef;
	$name =~ s/\\and/\&amp\;/;
	$name =~ s/\\GTN/GTN/;
	$name =~ s/\\ITN/ITN/;

	if ($name =~ /^\\sref\{([A-Z]+)\}\{([A-Z0-9-]+)\}(.*)/)
	{
	    $cref = $1;
	    $sref = $2;
	    $name = $3;
	    $type = "talent" if ($sref =~ /T-[0-9]+/);
	    $type = "spell" if ($sref =~ /[GS]-([0-9]+|([GS]C))/);
	    $type = "ritual" if ($sref =~ /[QR]-[0-9]+/);
	}
	elsif ($name =~ /^\\rt\{([a-z]+)\}(.*)/)
	{
	    $type = $1;
	    $name = $2;
	}
	elsif ($type = $opts->{_type_}->{lc($name)})
	{
	}
	else	    
	{
	    $type = "gtn" if ($name =~ /GTN$/);
	    $type = "itn" if ($name =~ /ITN$/);
	}

# --------------------
# Check matched ranking type
# --------------------

	if (!defined($type))
	{
	    printf STDERR "Cannot determine type of $name.\n";
	    exit(1);
	}
	
# --------------------
# Create line
# --------------------

	my $line = {};
	$line->{name} = $name;
	$line->{college} = $cref if (length($cref));
	$line->{ref} = $sref if (length($sref));

	if (defined($init) && $init =~ /upto/)
	{
	    my ($initial, $final) = split(/ ?\\upto ?/, $init);
	    $line->{initial} = $initial;
	    $line->{final} = $final;
	}
	else
	{
	    $line->{initial} = $init;
	}

	my $track;
	my $partial = 0;
	if (defined($time) && ($time =~ /(.*)\$\^\{?([0-9]+)(\\delta)?\}?\$/))
	{
	    $time = $1;
	    $track = $2;
	    $partial = 1 if (defined($3) && ($3 eq "\\delta"));

	}
	elsif (defined($time) && ($time =~ /(.*)\$\^\{?(\\delta)\}?\$/))
	{
	    $time = $1;
	    $track = 0;
	    $partial = 1 if ($2 eq "\\delta");
	}
	else
	{
	    $track = 0;
	}

	$time = undef if (defined($time) && ($time =~ m:no time:i));

	$line->{type} = $type;
	$line->{sum} = $sum if (length($sum));
	$line->{em} = $em if (length($em));
	$line->{ep_raw} = $ep_raw if (length($ep_raw));
	$line->{ep} = $ep if (length($ep));
	$line->{time} = $time if (length($time));
	$line->{cost} = $cost if (length($cost));
	$line->{track} = $track if (length($track));
	$line->{partial} = $partial if (length($partial));
	push(@{$block->{lines}}, $line);
    }
    push(@{$ranking->{blocks}}, $block);
    return $ranking;
}

# ----------------------------------------------------------------------
#
# Convert_Experience
#
# ----------------------------------------------------------------------

sub Convert_Experience {
    my ($in) = @_;
    
    if ($_ =~ m:\\experience\{(-?[0-9]+)\}\{(-?[0-9]+)\}\{([0-9]+)\}\{(-?[0-9]+)\}:)
    {
	my $exp = {};
	$exp->{gained} = length($1) ? int($1) : 0;
	$exp->{in} = length($2) ? int($2) : 0;
	$exp->{spent} = length($3) ? int($3) : 0;
	$exp->{out} =  length($4) ? int($4) : 0;
	return $exp;
    }
    else
    {
	printf("Experience match failing on $_\n");
	exit(1);
    }
}

# ----------------------------------------------------------------------
#
# Convert_Experience
#
# ----------------------------------------------------------------------

sub Convert_Notes {
    my ($in) = @_;
    my @lines;

    while(<$in>)
    {
	last if $_ =~ m:^\\end\{notes\}:;
	push(@lines, $_);
    }
    return join('', @lines);
}

# ----------------------------------------------------------------------
#
# Convert_Party
#
# ----------------------------------------------------------------------

sub Convert_Party {
    my ($in) = @_;

    my $party = {};

    while (<$in>)
    {
	chomp $_;
	return $party if (m:^\\end\{party\}:);
	s/[ ]?\\\\$//;
	my ($name, $college, $note) = split(/[ \t]+?\&[ ]?/, $_);
	$name =~ s:^[ \t]+::;
	my $member = {
	    name => $name,
	    college => $college
	};
	$member->{note} = $note if (length($note));
	push(@{$party->{members}}, $member);
    }
    return $party;
}

# ----------------------------------------------------------------------
#
# Convert_Adventure
#
# ----------------------------------------------------------------------

sub Convert_Adventure {
    my ($opts, $in) = @_;
    m/\\begin\{adventure(\*?)\}\{(.*)\}\{(.*)\}\{(.*)\}/;

    my $adventure = {};
    
    $adventure->{name} = $2;
    $adventure->{start} = $3;
    $adventure->{end} = $4;
    $adventure->{star} = 1 if(length($1));
   
    # --------------------
    # Date work
    # --------------------

    my $start = $adventure->{"start"};
    my $end = $adventure->{"end"};

    my $start_tick = Tick->new($start);
    
    $adventure->{start_tick} = Tick->new($start_tick);
    $adventure->{end_tick} = length($end) ? Tick->new($end) : Tick->new($start);
    
    while(<$in>)
    {
	chomp $_;
	if (m:^\\end\{adventure(\*?)\}:)
	{
 	    return $adventure;
	}

	if (m:^\\begin\{party\}:)
	{
	    my $party = &Convert_Party($in);
	    $adventure->{party} = $party;
	}

	if (m:^\\begin\{ranking\*?\}:)
	{
	    my $ranking = &Convert_Ranking($opts, $in);
	    push(@{$adventure->{ranking}}, $ranking) if ($ranking);
	}
	if (m:^\\experience:)
	{
	    my $exp = &Convert_Experience($in);
	    $adventure->{experience} = $exp;
	}
	if (m:^\\begin\{monies\}:)
	{
	    my $monies = &Convert_Monies($in) ;
	    push(@{$adventure->{monies}}, $monies) if (defined($monies));
	}
	if (m:^\\begin\{items\}:)
	{
	    push(@{$adventure->{items}}, &Convert_Items($in));
	}
	if (m:^\\begin\{notes\}:)
	{
	    $adventure->{notes} = &Convert_Notes($in);
	}
    }
    return undef;
}

# ----------------------------------------------------------------------
#
# jSON_Adventure
#
# ----------------------------------------------------------------------

sub JSON_Adventure {
    my ($adventure) = @_;

    my $a = {};

    # --------------------
    # adventure header
    # --------------------

    map {$a->{$_} = $adventure->{$_} if (exists($adventure->{$_}))} ('name', 'start', 'end', 'star', 'start_tick', 'end_tick');

    # --------------------
    # Party
    # --------------------
    
    if (my $p = $adventure->{party})
    {	
	for my $m (@{$p->{members}})
	{
	    my $t = {};
	    map {$t->{$_} = $m->{$_} if (exists($m->{$_}))} ('name', 'college', 'note');
 	    push(@{$a->{party}}, $t);
	}
    }

    # --------------------
    # Items
    # --------------------
    
    for my $i (@{$adventure->{items} || []})
    {
	my $items = {
	    description => $i->{description}
	};
	push(@{$a->{items}}, $items);
	for my $line (@{$i->{item} || []})
	{
	    push(@{$items->{lines}}, {
		description => $line,
		 });
	}
    }

    # --------------------
    # Monies
    # --------------------

    for my $m (@{$adventure->{monies} || []})
    {
	my $monies = {};
	push(@{$a->{monies}}, $monies);
	$monies->{in} = $m->{in};
	$monies->{out} = $m->{out};
	$monies->{date} = $m->{date};
	$monies->{tick} = $m->{tick}->{tick};
	$monies->{calendar} = $m->{tick}->{calendar};
	$monies->{ledger} = $m->{ledger} if (exists($monies->{ledger}));
	for my $l (@{$m->{lines} || []})
	{
	    my $line = {};
	    push(@{$monies->{lines}}, $line);
	    $line->{description} = $l->{description};
	    $line->{in} = $l->{in} if (exists($l->{in}));
	    $line->{out} = $l->{out} if (exists($l->{out}));
	}
    }
   
    # --------------------
    # Ranking
    # --------------------

    for my $r (@{$adventure->{ranking} || []})
    {
	my $ranking = {};
	push(@{$a->{ranking}}, $ranking);

	map { $ranking->{$_} = $r->{$_} if exists($r->{$_}) } ('description', 'start_tick', 'end_tick', 'start', 'end', 'time', 'days', 'ep');
	      
	for my $b (@{$r->{blocks}})
	{
	    my $block = {};
	    push(@{$ranking->{blocks}}, $block);
	    map {$block->{$_} = $b->{$_} if (exists($b->{$_}))} ('time', 'days', 'ep', 'start_tick', 'end_tick');
	    for my $l (@{$b->{lines} || []})
	    {
		my $line = {};
		push(@{$block->{lines}}, $line);
		map {$line->{$_} = $l->{$_} if (exists($l->{$_}) && defined($l->{$_}))} ('name', 'college', 'ref', 'initial', 'final', 'sum', 'em', 'ep_raw', 'ep', 'time', 'days', 'cost', 'track', 'partial', 'type');
	    }
	}  
    }

    # --------------------
    # Experience
    # --------------------
    
    if (my $e = $adventure->{experience})
    {
     	my $exp = $a->{experience} = {};
	map { $exp->{$_} = $e->{$_} if (exists($e->{$_})); } ('gained', 'in', 'spent', 'out')
    }

    # --------------------
    # Notes
    # --------------------

    if (my $notes = $adventure->{notes})
    {
	$a->{notes} = $notes;
    }

    return $a;
}

# ----------------------------------------------------------------------
#
# JSON_Character
#
# ----------------------------------------------------------------------

sub sort_name {
    my ($a, $b) = @_;
    return $a->{name} cmp $b->{name};
}

sub sort_rank {
    my ($a, $b) = @_;
    return $b->{rank} <=> $a->{rank};
}

sub sort_ref {
    my ($a, $b) = @_;
    my $ref_a = $a->{ref};
    my $ref_b = $b->{ref};
    my $ref_map = {
	T => 0,
	G => 1,
	Q => 2,
	S => 3,
	R => 4,
    };
    my $val_map = {
	GC => 98,
	SC => 99
    };
    
    $ref_a =~ m:([A-Z]+)-([A-Z0-9]+):;
    my $key_a = $ref_map->{$1};
    my $val_a = $val_map->{$2} // $2;

    $ref_b =~ m:([A-Z]+)-([0-9]+):;
    my $key_b = $ref_map->{$1};
    my $val_b = $val_map->{$2} // $2;

    return $a->{college} && $b->{college} ?
	($a->{college} cmp $b->{college} || $key_a <=> $key_b || $val_a <=> $val_b) :
	($key_a <=> $key_b || $val_a <=> $val_b);
}

# ----------------------------------------------------------------------
#
# JSON_Character
#
# ----------------------------------------------------------------------

sub JSON_Character {
    my ($opts, $character) = @_;

    my $state = $character->{_state_};
    my $map = $character->{_map_};

    my $res = {};

    # --------------------
    # Create basic details
    # --------------------
    
    my $basics = $res->{basics} = {};

    # --------------------
    # Copy over static details
    # --------------------
    
    for my $k ('charname', 'fullname', 'race', 'college', 'status', 'sex', 'height', 'weight', 'aspect', 'hand', 'birth', 'date', 'dateofbirth', 'picture')
    {
	$basics->{$k} = $character->{basics}->{$k} if ($character->{basics}->{$k});
    }

    # --------------------
    # Start updating the current values
    # --------------------
    
    $basics->{"ep_total"} = $state->{"ep_total"};
    $basics->{"ep"} = $state->{"ep"};

    my $tick = Tick->new($state->{tick});
    $basics->{tick} = $tick;
        
    # --------------------
    # Create current
    # --------------------

    my $current = $res->{current} = {};

    # --------------------
    # Copy current stats
    # --------------------
    
    my $stats = $current->{stats} = {};
    my $statmap = {
	PS	=> 'Physical Strength',
	MD	=> 'Manual Dexturity',
	AG	=> 'Agility',
	MA	=> 'Magical Aptitude',
	WP	=> 'Willpower',
	EN	=> 'Endurance',
	FT	=> 'Fatigue',
	PB	=> 'Physical Beauty',
	PC	=> 'Perception',
    };
    for my $i ('PS', 'MD', 'AG', 'MA', 'WP', 'EN', 'FT', 'PB', 'PC')
    {
	$stats->{$i} = $map->{'stat'}->{$statmap->{$i}}->{"rank"};
    }

    my $slw = {
	skill => {
	    parent	=> 'skills',
	    child	=> 'skill',
	},
	language => {
	    parent	=> 'languages',
	    child	=> 'language',
	},
	weapon => {
	    parent	=> 'weapons',
	    child	=> 'weapon',
	},
	talent => {
	    parent	=> 'talents',
	    child	=> 'talent',
	    sort	=> \&sort_ref,
	},
	spell => {
	    parent	=> 'spells',
	    child	=> 'spell',
	    sort	=> \&sort_ref,
	},
	ritual => {
	    parent	=> 'rituals',
	    child	=> 'ritual',
	    sort	=> \&sort_ref,
	},
	power => {
	    parent	=> 'powers',
	    child	=> 'power'
	},
	ability => {
	    parent	=> 'abilities',
	    child	=> 'ability',
	    sort	=> \&sort_name,
	},
    };
    
# --------------------
# Add current values
# --------------------

    for my $i (keys(%{$slw}))
    {
	my $xmap = $map->{$i};
	my $sort = $slw->{$i}->{sort} // \&sort_rank;

	my @list = sort({$sort->($xmap->{$a}, $xmap->{$b})} grep(!m:^_:, keys(%$xmap)));
	if (scalar(@list))
	{
	    my $key = $current->{$slw->{$i}->{parent}} = [];
	    for my $j (@list)
	    {
		next if ($j =~ m/^_/);
		my $v = {};
		push(@$key, $v);
		$v->{"type"} = $slw->{$i}->{child};
		$v->{"name"} = $j;
		$v->{"rank"} = $xmap->{$j}->{'rank'};
		$v->{"ref"} = $xmap->{$j}->{'ref'} if (exists $xmap->{$j}->{'ref'});
		$v->{"college"} = $xmap->{$j}->{'college'} if (exists $xmap->{$j}->{'college'});
	    }
 	}
    }

    # --------------------
    # Adventure
    # --------------------

    $res->{adventures} = [map{JSON_Adventure($_)} @{$character->{adventures}}];
    
    # --------------------
    # Write out result
    # --------------------

    if ($opts->{format} eq "yaml")
    {
	DumpFile($opts->{outfile}, $res);
    }
    else
    {
	my $stream;
	if ($opts->{outfile})
	{
	    if (!open($stream, ">", $opts->{outfile}))
	    {
		printf(STDERR "Cannot open %s fo writing.\n", $opts->{outfile});
		exit(1);
	    }
	}
	else
	{
	    $stream = \*STDOUT;
	}
	print $stream to_json($res, {pretty=>1, convert_blessed=>1});
	close($stream);
    }
}

# ----------------------------------------------------------------------
#
# Main
#
# ----------------------------------------------------------------------

sub Main {

    my $opts = {
	codepage => 'utf8',
	mapfile => '/locker/gaming/dq/characters/convert.js',
    };

    # --------------------
    # Get CLI options
    # --------------------
    
    GetOptions(
	'encoding=s' => \$opts->{'codepage'},
	'in=s' => \$opts->{'infile'},
	'out=s' => \$opts->{'outfile'},
	'format=s' => \$opts->{'format'},
	'map=s' => \$opts->{'mapfile'},
	);
    
    # --------------------
    # Load mapping configuration
    # --------------------
    
    if (!-f $opts->{mapfile})
    {
	print(STDERR "$0: cannot find mapfile %s\n", $opts->{mapfile});
	exit(1);
    }
    $opts->{_map_} = decode_json(slurp($opts->{mapfile}));
    
    while(my ($type, $v) = each(%{$opts->{_map_}}))
    {
	for my $name (keys(%{$v->{_keys_} || {}}))
	{
	    $opts->{_type_}->{lc($name)} = $type;
	}
    }

    # --------------------
    # make sure input and output files are specified
    # --------------------

    if (!($opts->{infile} && $opts->{outfile}))
    {
	printf(STDERR "%s: [-i infile] [-o outfile]\n", basename($0));
	exit(1);
    }
        
    # --------------------
    # load input file
    # --------------------
    
    my $codepage = $opts->{'codepage'};
    my ($in, $out);
    open($in, "<:encoding($codepage)", $opts->{"infile"}) || die "Cannot open file.";

    # --------------------
    # Base JS object
    # --------------------
    
    my $character = {};
    my $basics = $character->{basics} = {};

    # --------------------
    # Convert basics and adventures
    # --------------------
    
    while(<$in>)
    {
	chomp $_;
	$basics->{player} = $1 if (m:^\\player\{(.*)\}:);
	$basics->{charname} = $1 if (m:^\\charname\{(.*)\}:);
	$basics->{fullname} = $1 if (m:^\\fullname\{(.*)\}:);
	$basics->{race} = $1 if (m:^\\race\{(.*)\}:);
	$basics->{college} = $1 if (m:^\\college\{(.*)\}:);
	$basics->{status} = $1 if (m:^\\status\{(.*)\}:);
	$basics->{sex} = $1 if (m:^\\sex\{(.*)\}:);
	$basics->{height} = $1 if (m:^\\height\{(.*)\}:);
	$basics->{weight} = $1 if (m:^\\weight\{(.*)\}:);
	$basics->{aspect} = $1 if (m:^\\aspect\{(.*)\}:);
	$basics->{hand} = $1 if (m:^\\hand\{(.*)\}:);
	$basics->{birth} = $1 if (m:^\\birth\{(.*)\}:);
	$basics->{date} = $1 if (m:^\\date\{(.*)\}:);
	$basics->{dateofbirth} = $1 if (m:^\\dateofbirth\{(.*)\}:);
	$basics->{picture} = $1 if (m:^\\charpic\{(.*)\}:);

	if (exists($basics->{picture}))
	{
	    my $path = $basics->{picture};
	    my $in = $opts->{infile};
	    if (!file_name_is_absolute($path))
	    {
		my ($vol, $dirs, $file) = splitpath($in);
		$path = rel2abs(catdir($dirs, $path));
		$basics->{picture} = $path;
	    }
	}

	if (m:^\\begin\{adventure\*?\}:)
	{
	    my $adventure = &Convert_Adventure($opts, $in);
	    push(@{$character->{adventures}}, $adventure) if ($adventure);
	}
    }

    my $f_map = {
	json => \&JSON_Character,
	yaml => \&JSON_Character,
    };

    &Update_Character($opts, $character);
    
    if (defined($opts->{format}) && $f_map->{$opts->{'format'}})
    {
	$f_map->{$opts->{'format'}}->($opts, $character);
    }
}

&Main();
