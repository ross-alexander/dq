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
use XML::LibXML;
use Getopt::Long;
use Carp::Assert;
use Encode;
use dq;
use Tick;
use JSON;
use JSON::XS;
use Perl6::Slurp;
use Data::Dumper;
use Carp;
use YAML::PP qw(DumpFile);
use File::Spec::Functions qw(rel2abs splitpath file_name_is_absolute catdir);

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
	if ($ranking->{date})
	{
	    my $s = Tick->new($ranking->{date});
	    if (!$ranking->{star} && ($s < $tick))
	    {
		printf("Ranking for %s starts before end of the adventure\n", $ranking->{description});
		exit(1);
	    }
	    $ranking->{start} = Tick->new($s);
	}
	else
	{
	    $ranking->{start} = $ranking->{star} ? Tick->new($start) : Tick->new($tick);
	}
	
	printf("-- %s : %s%s\n\n", $ranking->{description}, $ranking->{start}, $ranking->{star} ? "*" : "");

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
			    say "!!!!! $ep";
			}
		    }
		}

		# --------------------
		# Process time
		# --------------------

		my $time_str = $line->{time} // '';
		$time_str =~ /([0-9]+) (day|days|week|weeks)/;
		my $time = $1 // 0;
		$time *= 7 if (defined($2) && (($2 eq "week") || ($2 eq "weeks")));
		my $track = $line->{track};
		$line->{day_equiv} = $time;
		$time[$track] += $time;
		$block_ep += $line->{ep} if (exists($line->{ep}));
		$ep = $ep // 0;
		$ep_raw = $ep_raw // 0;
		$final = $final // 0;
		$diff = $diff // 0.0;
		
		printf("%-30s (%3s..%3s) Raw EP = %d EP = %d Diff = %4.2f : Time = %s\n",
		       $name, $initial, $final,
		       $ep_raw, $ep, $diff, $time);
	    }
	    $block->{ep} = $block_ep;
	    $ep_total += $block_ep;

	    # --------------------
	    # sort the time tracks to get maximum
	    # --------------------

	    print "Track times = ", join(" : ", @time), "\n\n";
	    my @tsort = sort { $a <=> $b } @time;
	    $block->{start} = $tick;
	    $block->{time} =  $tsort[$#tsort];

	    $days += $tsort[$#tsort];
	}
	
	# Tick + integer doesn't work so work around it
	
	$ranking->{end} = Tick->new($ranking->{start});
	$ranking->{end} += $days;
	
	printf("-- %s : %s (%d)\n\n", $ranking->{description}, $ranking->{end}, $days);
	
	if (!$ranking->{star})
	{
	    $tick = Tick->new($ranking->{end});
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
    $state->{"tick"} = $tick;
    printf("Time: start %s - end %s - current %s (%s) [%d]\n", $start->CDate(), $end->CDate(), $tick->CDate(), $tick, $tick - $end);
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
#	say to_json($a, {convert_blessed=>1, pretty=>1});
#	say to_json($map, {convert_blessed=>1, pretty=>1});
#	say to_json($state, {convert_blessed=>1, pretty=>1});
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
	my ($name, $init, $sum, $em, $ep_raw, $ep, $time, $money) = split(/[ \t]*&[ \t]*/, $_);
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

	if ($init =~ /upto/)
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
	$line->{money} = $money if (length($money));
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
    my @items;
    my $count = 0;
    my $lcount = 0;

    do
    {
	for my $i (0 .. length($_) - 1)
	{
	    my $c = substr($_, $i, 1);
	    if ($c eq "{")
	    {
		$items[$count] .= $c if ($lcount);
		$lcount ++;
	    }
	    elsif ($c eq "}")
	    {
		$lcount--;
		$items[$count] .= $c if ($lcount);
		$count++ if ($lcount == 0);
	    }
	    elsif ($lcount > 0)
	    {
		$items[$count] .= $c;
	    }
	}
	$_ = <$in> if ($count < 5);
    } while($count < 5);

    my $exp = {};

    if (length($items[0]))
    {
	$exp->{gained} = $items[0] if ($items[0]);
	$exp->{in} = length($items[1]) ? int($items[1]) : 0;
	$exp->{spent} = $items[2] if ($items[2]);
	$exp->{out} =  length($items[3]) ? int($items[3]) : 0;
    }
    
    if (length($items[4]))
    {
	my $text = $items[4];
	$text =~ s/^\n//;
	$exp->{notes} = $text;
    }
    return $exp;
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
	if (m:^\\end\{adventure\}:)
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
    }
    return undef;
}

# ----------------------------------------------------------------------
#
# XML_Adventure
#
# Create XML from internal format
#
# ----------------------------------------------------------------------

sub XML_Adventure {
    my ($root, $adventure) = @_;
    
    my $node = $root->addNewChild('', 'adventure');

    for my $k ('name', 'start', 'end', 'star', 'start_tick', 'end_tick')
    {
	if (exists($adventure->{$k}))
	{
	    my $xk = $k;
	    $xk =~ s:_:-:g;
	    $node->setAttribute($xk, $adventure->{$k});
	}
    }

    # --------------------
    # Party
    # --------------------
    
    if (my $p = $adventure->{party})
    {
	my $party = $node->addNewChild('', 'party');
	for my $m (@{$p->{members}})
	{
	    assert($m->{name});
	    assert($m->{college});

	    my $member = $party->addNewChild('', 'member');
	    $member->setAttribute('name', $m->{name});
	    $member->setAttribute('college', $m->{college});
	    $member->setAttribute('note', $m->{note}) if ($m->{note});
	}
    }

    # --------------------
    # Items
    # --------------------
    
    for my $items (@{$adventure->{items} || []})
    {
	my $items_node = $node->addNewChild('', 'items');
	$items_node->setAttribute('desc', $items->{desc});
	for my $line (@{$items->{item} || []})
	{
	    my $line_node = $items_node->addNewChild('', 'line');
	    $line_node->setAttribute('desc', $line);
	}
    }

    # --------------------
    # Monies
    # --------------------

    for my $monies (@{$adventure->{monies} || []})
    {
	my $monies_node = $node->addNewChild('', 'monies');
	$monies_node->setAttribute('in', $monies->{in});
	$monies_node->setAttribute('out', $monies->{out});
	$monies_node->setAttribute('date', $monies->{date});
	$monies_node->setAttribute('tick', $monies->{tick}->{tick});
	$monies_node->setAttribute('calendar', $monies->{tick}->{calendar});
	$monies_node->setAttribute('ledger', $monies->{ledger}) if ($monies->{ledger});
	for my $line (@{$monies->{lines} || []})
	{
	    my $line_node = $monies_node->addNewChild('', 'line');
	    $line_node->setAttribute('description', $line->{description});
	    $line_node->setAttribute('in', $line->{in}) if ($line->{in});
	    $line_node->setAttribute('out', $line->{out}) if ($line->{out});
	}
    }

    
    # --------------------
    # Ranking
    # --------------------
	
    for my $r (@{$adventure->{ranking} || []})
    {
	my $ranking = $node->addNewChild('', 'ranking');

	$ranking->setAttribute("description", $r->{description});
	$ranking->setAttribute("star", "1") if ($r->{star});
	$ranking->setAttribute("start", $r->{start}->CDate()) if ($r->{start});
	$ranking->setAttribute("end", $r->{end}->CDate()) if ($r->{end});
	
	for my $b (@{$r->{blocks}})
	{
	    
	    my $block = $ranking->addNewChild('', 'block');
	    $block->setAttribute("time", $b->{time}) if ($b->{time});

# --------------------
# Create XML Node
# --------------------

	    for my $l (@{$b->{lines} || []})
	    {
		my $skill = $block->addNewChild('', $l->{type});
		$skill->setAttribute("name", $l->{name});

		$skill->setAttribute("college", $l->{college}) if ($l->{college});
		$skill->setAttribute("ref", $l->{sref}) if ($l->{sref});

		$skill->setAttribute("initial", $l->{initial});
		$skill->setAttribute("final", $l->{final}) if ($l->{final});

		$skill->setAttribute("sum", $l->{sum}) if ($l->{sum});
		$skill->setAttribute("em", $l->{em}) if ($l->{em});
		$skill->setAttribute("ep_raw", $l->{ep_raw}) if ($l->{ep_raw});
		$skill->setAttribute("ep", $l->{ep}) if ($l->{ep});
		$skill->setAttribute("time", $l->{time}) if ($l->{time});
		$skill->setAttribute("money", $l->{money}) if ($l->{money});
		$skill->setAttribute("track", $l->{track}) if ($l->{time}); # length($time) && !($time =~ /no time/i));
		$skill->setAttribute("partial", 1) if ($l->{partial});
	    }
	}  
    }

    if (my $e = $adventure->{experience})
    {
	my $exp = $node->addNewChild('', 'experience');
	$exp->setAttribute("gained", $e->{gained}) if ($e->{gained});
	$exp->setAttribute("in", $e->{in}) if ($e->{in});
	$exp->setAttribute("spent", $e->{spent}) if ($e->{spent});
	$exp->setAttribute("out", $e->{out}) if ($e->{out});
	$exp->setAttribute("notes", $e->{notes}) if ($e->{notes});
    }
}

# ----------------------------------------------------------------------
#
# XML_Character
#
# ----------------------------------------------------------------------

sub XML_Character {
    my ($conf, $character) = @_;

    my $state = $character->{_state_};
    my $map = $character->{_map_};
    
    # --------------------
    # Create XML document
    # --------------------
    
    my $doc = XML::LibXML::Document->new("1.0", "UTF-8");
    my $root = $doc->createElement("character");
    $doc->setDocumentElement($root);
    $root->setAttribute("system", "dq");

    # --------------------
    # Add basic details
    # --------------------

    my $basics = XML::LibXML::Element->new("basics"); $root->appendChild($basics);

    for my $k ('charname', 'fullname', 'race', 'college', 'status', 'sex', 'height', 'weight', 'aspect', 'hand', 'birth', 'date', 'dateofbirth', 'charpic')
    {
	$basics->setAttribute($k, $character->{basics}->{$k}) if ($character->{basics}->{$k});
    }

    # --------------------
    # Start updating the current values
    # --------------------
    
    $basics->setAttribute("ep_total", $state->{"ep_total"});
    $basics->setAttribute("ep", $state->{"ep"});

    my $tick = Tick->new($character->{basics}->{date});
    
    $basics->setAttribute("date", $state->{'tick'}->CDate());
    $basics->setAttribute("tick", $state->{'tick'}->{tick});
    $basics->setAttribute("calendar", $tick->{calendar});
    
    my $current = $root->addNewChild('', 'current');

    my $stats = $current->addNewChild('', 'stats');
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
	my $s = $stats->addNewChild('', 'stat');
	$s->setAttribute("name", $i);
	$s->setAttribute("value", $map->{'stat'}->{$statmap->{$i}}->{"rank"});
    }

    # --------------------
    # Do skills, languages and weapons
    # --------------------

    my $slw = {
	'skill' => {
	    'parent'	=> 'skills',
	    'child'	=> 'skill',
	},
	'language' => {
	    'parent'	=> 'languages',
	    'child'	=> 'language',
	},
	'weapon' => {
	    'parent'	=> 'weapons',
	    'child'	=> 'weapon',
	},
	'talent' => {
	    'parent'	=> 'talents',
	    'child'	=> 'talent',
	},
	'spell' => {
	    'parent'	=> 'spells',
	    'child'	=> 'spell',
	},
	'ritual' => {
	    'parent'	=> 'rituals',
	    'child'	=> 'ritual',
	},
    };

# --------------------
# Add current values
# --------------------

    for my $i (keys(%{$slw}))
    {
	my $xmap = $map->{$i};

	my @list = sort({$xmap->{$b}->{"rank"} <=> $xmap->{$a}->{"rank"}} grep(!m:^_:, keys(%$xmap)));

	if (scalar(@list))
	{
	    my $parent = $current->addNewChild('', $slw->{$i}->{'parent'});
	    for my $j (@list)
	    {
		next if ($j =~ m/^_/);
		my $child = $parent->addNewChild('', $slw->{$i}->{'child'});
		$child->setAttribute("name", $j);
		$child->setAttribute("rank", $xmap->{$j}->{'rank'});
		$child->setAttribute("ref", $xmap->{$j}->{'ref'}) if (exists $xmap->{$j}->{'ref'});
		$child->setAttribute("college", $xmap->{$j}->{'college'}) if (exists $xmap->{$j}->{'college'});
	    }
 	}
    }

    # --------------------
    # Iterate over adventures
    # --------------------

    for my $a (@{$character->{adventures}})
    {
	&XML_Adventure($root, $a);
    }
    
    # --------------------
    # Output XML
    # --------------------
    
    if ($conf->{outfile})
    {
	$doc->toFile($conf->{outfile}, 1);
    }
    else
    {
	print $doc->toString(1);
    }
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

    for my $k ('name', 'start', 'end', 'star', 'start_tick', 'end_tick')
    {
	if (exists($adventure->{$k}))
	{
	    $a->{$k} = $adventure->{$k};
	}
    }

    # --------------------
    # Party
    # --------------------
    
    if (my $p = $adventure->{party})
    {	
	for my $m (@{$p->{members}})
	{
	    my $t = {};
	    for my $k ('name', 'college', 'note')
	    {
		$t->{$k} = $m->{$k} if (exists($m->{$k}));
	    }
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

	printf("^^^ %s %s\n", $r->{start}, to_json($r->{start}, {convert_blessed => 1}));
	
	$ranking->{description} = $r->{description};
	$ranking->{star} = 1 if ($r->{star});
	$ranking->{start_tick} = $r->{start} if ($r->{start});
	$ranking->{end_tick} = $r->{end} if ($r->{end});
	$ranking->{start} = $r->{start}->CDate() if ($r->{start});
	$ranking->{end} = $r->{end}->CDate() if ($r->{end});
	
	for my $b (@{$r->{blocks}})
	{
	    my $block = {};
	    push(@{$ranking->{blocks}}, $block);
	    $block->{time} = $b->{time} if ($b->{time});
	    
	    for my $l (@{$b->{lines} || []})
	    {
		my $line = {};
		push(@{$block->{lines}}, $line);

		for my $k ('name', 'college', 'ref', 'initial', 'final', 'sum', 'em', 'ep_raw', 'ep', 'time', 'money', 'track', 'partial', 'type')
		{
		    $line->{$k} = $l->{$k} if (exists($l->{$k}));
		}
	    }
	}  
    }

    # --------------------
    # Experience
    # --------------------
    
    if (my $e = $adventure->{experience})
    {
     	my $exp = $a->{experience} = {};
	for my $k ('gained', 'in', 'spent', 'out', 'notes')
	{
	    $exp->{$k} = $e->{$k} if (exists($e->{$k}));
	}
    }

    return $a;
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
    
    for my $k ('charname', 'fullname', 'race', 'college', 'status', 'sex', 'height', 'weight', 'aspect', 'hand', 'birth', 'date', 'dateofbirth', 'charpic')
    {
	$basics->{$k} = $character->{basics}->{$k} if ($character->{basics}->{$k});
    }

    # --------------------
    # Start updating the current values
    # --------------------
    
    $basics->{"ep_total"} = $state->{"ep_total"};
    $basics->{"ep"} = $state->{"ep"};

    my $tick = Tick->new($character->{basics}->{date});
    
    $basics->{"date"} = $state->{'tick'}->CDate();
    $basics->{"tick"} = $state->{'tick'}->{tick};
    $basics->{"calendar"} =  $tick->{calendar};
    
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
	},
	spell => {
	    parent	=> 'spells',
	    child	=> 'spell',
	},
	ritual => {
	    parent	=> 'rituals',
	    child	=> 'ritual',
	},
	power => {
	    parent	=> 'powers',
	    child	=> 'power'
	},
    };

# --------------------
# Add current values
# --------------------

    for my $i (keys(%{$slw}))
    {
	my $xmap = $map->{$i};
	my @list = sort({$xmap->{$b}->{"rank"} <=> $xmap->{$a}->{"rank"}} grep(!m:^_:, keys(%$xmap)));
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

    for my $adventure (@{$character->{adventures}})
    {
	push(@{$res->{adventures}}, JSON_Adventure($adventure));
    }
    
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
    # load input file
    # --------------------
    
    my $codepage = $opts->{'codepage'};
    my ($in, $out);
    if ($opts->{"infile"})
    {
	open($in, "<:encoding($codepage)", $opts->{"infile"}) || die "Cannot open file.";
    }
    else
    {
	$in = \*STDIN;
    }

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
	$basics->{charpic} = $1 if (m:^\\charpic\{(.*)\}:);

	if (exists($basics->{charpic}))
	{
	    my $path = $basics->{charpic};
	    my $in = $opts->{infile};
	    if (!file_name_is_absolute($path))
	    {
		my ($vol, $dirs, $file) = splitpath($in);
		$path = rel2abs(catdir($dirs, $path));
#		say $vol, $dirs, " -- ", $file, " ++ ", $path;
		$basics->{charpic} = $path;
	    }
	}

	if (m:^\\begin\{adventure\*?\}:)
	{
	    my $adventure = &Convert_Adventure($opts, $in);
	    push(@{$character->{adventures}}, $adventure) if ($adventure);
	}
    }

    my $f_map = {
	xml => \&XML_Character,
	json => \&JSON_Character,
	yaml => \&JSON_Character,
	plain =>\&Plain_Chacter,
    };

    &Update_Character($opts, $character);
    
    if (defined($opts->{format}) && $f_map->{$opts->{'format'}})
    {
	$f_map->{$opts->{'format'}}->($opts, $character);
    }
}

&Main();
