#!/usr/bin/perl -I/locker/gaming/dq/characters/scripts

# ----------------------------------------------------------------------
#
# format.pl
#
# Take XML version of character sheet and format back into LaTeX.

# 2024-04-16: Ross Alexander
#   Convert table to tblr
#
# 2021-10-26: Ross Alexander
#   Add languages to TeX output.
#   Add support for JSON import.

# 2021-10-25: Ross Alexander
#   Change to Getopts::Long
#
# 2020-06-13: Ross Alexander
#   Force version to 5.30.2
#
# ----------------------------------------------------------------------

use 5.40.0;
use IO::Handle;
use XML::LibXML;
use Encode;
use POSIX qw(strftime);
use Time::localtime;
use Cairo;
use Tick;
use Getopt::Long;
use Carp::Assert;
use XML::Simple;
use XML::LibXML::Simple;
use Perl6::Slurp;
use JSON;
use YAML;
use File::Basename;

# ----------------------------------------------------------------------
#
# Cal_Character
#
# ----------------------------------------------------------------------
sub Cal_Character {

    my ($doc, $map, $path) = @_;

    my $out;
    $out = \*STDOUT;

# --------------------
# @track_list is track list, holds all the ranking track information
# --------------------

    my @track_list;

    for my $a (@{$map->{adventures}})
    {
	my $advtrack = {};

	if (!(($a->{"star"}//0) > 0))
	{
	    my $t = {};
	    $t->{type} = "a";
	    $t->{start_tick} = $a->{"start_tick"};
	    $t->{end_tick} = $a->{"end_tick"};
	    $t->{name} = $a->{"name"};
	    $t->{track} = 0;
	    push(@track_list, $t);
	}
	printf($out "\n# adventure %s %s %s\n", $a->{"start_tick"}->{date}, $a->{"end_tick"}->{date}, $a->{"name"});

	for my $r (@{$a->{"ranking"}})
	{
	     my $s = $r->{start_tick};
	     my $e = $r->{end_tick};

	     if (($e->{tick} - $s->{tick}) > 0)
	     {
		 printf($out "\n## ranking %d %d %s\n", $s->{tick}, $e->{tick}, $r->{description});
		 for my $b (@{$r->{blocks}})
		 {
		     printf($out "\n");
		     my $s = $b->{start_tick};
		     my @s = (Tick->new($s), Tick->new($s), Tick->new($s), Tick->new($s));

		     for my $line (@{$b->{lines}})
		     {
			 if ($line->{days})
			 {
			     my $t = {
				 type => 'r'
			     };
			     my $track = $t->{track} = $line->{track};
			     $t->{start_tick} = Tick->new($s[$track]);
			     $t->{end_tick} = Tick->new($s[$track]) + ($line->{days} - 1);
			     $t->{name} = $line->{name};
			     push(@track_list, $t);
			     $s[$track] += $line->{days};
			 }
			 printf($out "### line %3d %d %s\n", $line->{days}, $line->{track}, $line->{name});
		     }
		 }
	     }
	}
    }
    
# --------------------
# Map over the track list
# --------------------

    my $year_map = {};
    printf($out "\n");
    map {
	printf($out "# track %2d %5d %5d %s\n", $_->{'track'}, $_->{'start_tick'}->{tick}, $_->{'end_tick'}->{tick}, $_->{'name'});
	
	for my $i ($_->{start_tick}->{tick} .. $_->{end_tick}->{tick})
	{
	
# --------------------
# TickToTM returns (d,m,y,wd,yd)
# --------------------
	    my $tick = Tick->new({tick => $i, calendar => 'WK'});
	    my ($day, $month, $year, $week_day, $year_day);
	    ($day, $month, $year, $week_day, $year_day) = Tick::TickToTM($tick);
	    
# --------------------
# Create year (d,m,y,wd,yd)
# --------------------

	    $year_map->{years}->{$year} = {} if (!exists($year_map->{years}->{$year}));
	    my $year_ref = $year_map->{years}->{$year};

# --------------------
# Create month (d,m,y,wd,yd)
# --------------------

	    if (!exists($year_ref->{months}->{$month}))
	    {
		my $month_ref = $year_ref->{months}->{$month} = {};

# --------------------
# Get start of month date, if day != 0 then add 1 to get first of the month
# --------------------

		my $month_start = $tick - ($day - (($month%3 != 0) ? 1:0));
#		say "^^^ ", $month_start;
		my @month_start_bits = Tick::TickToTM($month_start);

# --------------------
# Get end of month, which will day 30
# --------------------

		my $j = $tick + (30 - $day);
		my @month_end_bits = Tick::TickToTM($j);

		$month_ref->{'_start_'} = $month_start_bits[0];
		$month_ref->{'_end_'} = $month_end_bits[0];
		$month_ref->{'_wday_'} = $month_start_bits[3];
		$month_ref->{_tick_} = Tick->new($tick);
	    }
	    my $month_ref = $year_ref->{months}->{$month};
	    $month_ref->{days}->{$day} = {} if (!exists($month_ref->{days}->{$day}));

	    # --------------------
	    # Add day to month
	    # --------------------
	    
	    my $day_ref = $month_ref->{days}->{$day};
	    $day_ref->{tracks}->{$_->{track}} = $_;
	    $day_ref->{week_day} = $week_day;
	    $day_ref->{wk} = Tick->new({tick => $i, calendar => 'WK'});
	}
    } @track_list;

    
# --------------------
# Add weeks
# --------------------

    for my $year (sort({$a <=> $b} keys(%{$year_map->{years}})))
    {
	my $months_ref = $year_map->{years}->{$year}->{months};
	for my $month (sort({$a <=> $b} keys(%$months_ref)))
	{
	    my $month_ref = $months_ref->{$month};
	    my $wday = $month_ref->{_wday_};
	    my $weeks = {};
	    for my $day (sort({$a <=> $b} keys(%{$month_ref->{days}})))
	    {
		my $week = int(($wday + $day) / 7);	    
		$weeks->{$week} = {} if (!exists($weeks->{$week}));
		$weeks->{$week}->{$day} = $month_ref->{days}->{$day};
	    }
	    while ((my ($k, $v) = each(%$weeks)))
	    {
		$month_ref->{weeks}->{$k} = $v;
	    }
	}
    }
    
# --------------------
# Do output
# --------------------

    my $cal_js = [];

    for my $year (sort({$a <=> $b} keys(%{$year_map->{years}})))
    {
	printf($out "\n----------------------------------------------------------------------\n");
	printf($out "Year\t%d\n", $year);
	printf($out "----------------------------------------------------------------------\n");

	my $year_js = {
	    year => sprintf("%d WK", $year),
	};
	push(@$cal_js, $year_js);
	
	my $months = $year_map->{years}->{$year}->{months};
	for my $month (sort({$a <=> $b} keys(%$months)))
	{
	    my $month_ref = $months->{$month};

	    my $month_js = {
		month => $month,
		start => $month_ref->{_start_},
		end => $month_ref->{_end_},
		week_day => $month_ref->{_wday_},
		tick => $month_ref->{_tick_},
	    };
	    push(@{$year_js->{months}}, $month_js);
	    
	    printf($out "\n--- Month\t%d\tstart:%d\tend:%d\tweek_day:%d\n\n", $month,
		$month_ref->{'_start_'}, $month_ref->{'_end_'}, $month_ref->{'_wday_'});
	    
	    for my $week (sort({$a <=> $b} keys(%{$month_ref->{weeks}})))
	    {
		my $week_ref = $month_ref->{weeks}->{$week};
		
		my $week_js = {};
		push(@{$month_js->{weeks}}, $week_js);
		for my $day (sort({$a <=> $b} keys(%$week_ref)))
		{			
		    my $day_ref = $week_ref->{$day};
		    my $day_js = {
			day => $day,
			date => $day_ref->{wk},
		    };
		    push(@{$week_js->{days}}, $day_js);
		    printf($out "Day\t%d\t%d\t%-20s", $day, $day_ref->{week_day}, $day_ref->{'wk'});
		    for my $t (0, 1, 2, 3)
		    {
		     	if (exists($day_ref->{tracks}->{$t}))
		     	{
		     	    $day_js->{track}->{$t} = {
		     		track => $t,
		     		name => $day_ref->{tracks}->{$t}->{name},
		     	    };
		    	    printf($out "\t%d\t%s", $t, $day_ref->{tracks}->{$t}->{'name'});
		     	}
		    }
		    printf($out "\n");
		}
	    }
	}
    }
    close($out);

    open($out, ">", $path) || die;
    print($out to_json($cal_js, {pretty=>1, convert_blessed=>1}));
    close($out);
}

# ----------------------------------------------------------------------
#
# HTML_Adventure
#
# ----------------------------------------------------------------------

sub HTML_Adventure {
    my ($in, $out, $body, $adventure) = @_;

    my $h2 = $body->appendTextChild("h2", $adventure->getAttribute("name"));
    my $ep_total = 0;
    
    for my $ranking ($adventure->findnodes("ranking")->get_nodelist)
    {
	my $h3 = $body->appendChild($out->createElement("h3"));
	$h3->appendText($ranking->getAttribute("desc"));

	my $blocks = $ranking->findnodes("block");
	for my $block ($blocks->get_nodelist)
	{
	    my $table = $body->appendChild($out->createElement("table"));
	    $table->setAttribute("class", "ranking");
	    for my $node ($block->findnodes("*")->get_nodelist)
	    {
		my $type = $node->getName();
		my $name = $node->getAttribute("name");
		my $initial = $node->getAttribute("initial");

		my $tr = $table->appendChild($out->createElement("tr"));
		my $td_name = $tr->appendChild($out->createElement("td"));
		$td_name->setAttribute("class", $type);
		
		if ($node->hasAttribute("final"))
		{
		    $td_name->appendText($name);
		    my $final = $node->getAttribute("final");
		    
		    my $td_rank = $tr->appendChild($out->createElement("td"));
		    my $cdata = $out->createCDATASection("$initial &hellip; $final");
		    $td_rank->appendChild($cdata);
		    $td_rank->setAttribute("class", "rank");

		    my $sum = $node->getAttribute("sum");
		    
		    my $td_sum = $out->createElement("td");
		    $td_sum->appendText($sum);
		    $td_sum->setAttribute("class", "value");
		    $tr->appendChild($td_sum);

		    my $raw_ep = $node->getAttribute("raw-ep");
		    $ep_total += $raw_ep;
		    my $td_raw = $tr->appendChild($out->createElement("td"));
		    $td_raw->setAttribute("class", "value");
		    $td_raw->appendText($raw_ep);

		    my $td_time = $out->createElement("td");
		    if ((my $num = $node->getAttribute("day-equiv")) > 0)
		    {
			$td_time->appendText($num == 1 ? "1 day" : "$num days");
		    }
		    $td_time->setAttribute("class", "time");
		    $tr->appendChild($td_time);

		    my $td_track = $out->createElement("td");
		    my $track = $node->getAttribute("track");
		    if ($node->hasAttribute("partial") && $node->getAttribute("partial") > 0)
		    {
			$td_track->appendChild($out->createCDATASection("$track &delta;"));
		    }
		    else
		    {
			$td_track->appendText($track) if ($track);
		    }
		    $td_rank->appendChild($cdata);

		    $td_track->setAttribute("class", "track");

		    $tr->setAttribute("style", "background-color: #C0C0C0") if ($track == 1);
		    $tr->setAttribute("style", "background-color: #A0A0A0") if ($track == 2);

		    $tr->appendChild($td_track);
		}
# --------------------
		else
		{
		    my $verb;
		    $verb = "Initial" if ($type eq "stat");
		    $verb = "Learn" if ($type eq "skill");

		    $td_name->appendText(join(" ", ($verb, $name)));		    
		    my $td_ini = $tr->appendChild($out->createElement("td"));
		    $td_ini->appendText($initial);
		    $td_ini->setAttribute("class", "value");
		}
	    }

# --------------------
# Add total line if necessary
# --------------------

	    if (($block->getAttribute("time") > 0) || ($block->getAttribute("ep") > 0))
	    {
		my $total_tr = $table->appendChild($out->createElement("tr"));
		my $total_td = $total_tr->appendChild($out->createElement("th"));
		$total_td->appendText("Total");
		$total_td->setAttribute("colspan", 3);

		my $ep_td = $total_tr->appendChild($out->createElement("td"));
		$ep_td->setAttribute("class", "value");
		$ep_td->appendText($block->getAttribute("ep")) if ($block->getAttribute("ep") > 0);

		my $time_td = $total_tr->appendChild($out->createElement("td"));
		$time_td->appendText($block->getAttribute("time") . ($block->getAttribute("time") == 0 ? " day" : " days")) if ($block->getAttribute("time") > 0);
		$time_td->setAttribute("colspan", 2);
	    }
	}
    }
}

# ----------------------------------------------------------------------
#
# HTML_Process
#
# ----------------------------------------------------------------------

sub HTML_Character {
    my ($in, $file) = @_;

    my $out = XML::LibXML::Document->new("1.0", "utf8");
    my $html = $out->createElement("html");
    $out->setDocumentElement($html);
    $out->createInternalSubset("html", "-//W3C//DTD HTML 4.01//EN", "http://www.w3.org/TR/html4/strict.dtd");

# Get document element (root elements)

    my $character = $in->getDocumentElement();

# Create HTML document elements
    
    my $head = $html->appendChild($out->createElement("head"));
    my $body = $html->appendChild($out->createElement("body"));

# Set HTML title

    my $title = $head->appendTextChild("title", $character->find('basics/@name'));

# Add CSS link

    my $link = $head->appendChild($out->createElement("link"));
    $link->setAttribute("rel", "stylesheet");
    $link->setAttribute("href", "dq.css");
    $link->setAttribute("type", "text/css");

# Add header

    $body->appendTextChild("h1", $character->find('basics/@name'));

# Iterate over all adventures.

    for my $adventure ($character->findnodes("adventure")->get_nodelist)
    {
	&HTML_Adventure($in, $out, $body, $adventure);
    }
    my $stream;
    open($stream, ">$file");
    $stream->print($out->toStringHTML());
    close($stream);
}


# ----------------------------------------------------------------------
#
# Cairo_Character
#
# ----------------------------------------------------------------------

sub Cairo_Bits {
    my ($conf, $cr, $list, $boxes)  = @_;

    my $len = scalar(@$list);
    return 0 if ($len == 0);
    
    my $height = 14;
    my $maxx;

    $cr->set_line_width(0.3);
    $cr->set_font_size(8);

    $cr->select_font_face($conf->{'fonts'}->{'sans'}, 'normal', 'bold');
    my $x = 0;
    for my $k (0 .. scalar(@$boxes) - 1)
    {
	my $box = $boxes->[$k];
	my $size = $box->{'len'};
	my $title = $box->{'title'};
	my $align = $box->{'align'} // 'l';
	$cr->rectangle($x, 0, $size, $height);
	$cr->set_source_rgb(@{$conf->{colours}->{rank_bg}});
	$cr->fill_preserve();
	$cr->set_source_rgb(@{$conf->{colours}->{line}});
	$cr->stroke();
	my $extents = $cr->text_extents($title);
	$cr->move_to($x + ($size - $extents->{'width'})/2, $height - 2);
	$cr->set_source_rgb(@{$conf->{colours}->{font}});
 	$cr->show_text($title);
	$x += $size;
    }
    $cr->select_font_face($conf->{'fonts'}->{'sans'}, 'normal', 'normal');

    for my $i (0 .. $len-1)
    {
	my $j = $list->[$i];
	my $x = 0;
	for my $k (0 .. scalar(@$boxes) - 1)
	{
	    my $box = $boxes->[$k];
	    my $id = $box->{'id'};
	    my $size = $box->{'len'};
	    my $align = $box->{'align'} // 'l';
	    my $text = $j->{$id} // '';

	    $cr->rectangle($x, ($i+1) * $height, $size, $height);
	    $cr->set_source_rgb(@{$conf->{colours}->{rank_bg}});
	    $cr->fill_preserve();
	    $cr->set_source_rgb(@{$conf->{colours}->{line}});
	    $cr->stroke();
	    my $extents = $cr->text_extents($text);
	    if ($align eq "r")
	    {
		$cr->move_to($x + $size - $extents->{'x_advance'} - 2, ($i+2) * $height - 2);
	    }
	    else
	    {
		$cr->move_to($x + 2, ($i+2) * $height - 2);
	    }
	    $cr->set_source_rgb(@{$conf->{colours}->{font}});
	    $cr->show_text($text);
	    $x += $size;
	}
	$maxx = $x;
    }
    $len++;

    $cr->set_line_width(1.0);
    $cr->set_source_rgb(@{$conf->{colours}->{line}});
    $cr->rectangle(0, 0, $maxx, $len * $height);
    $cr->stroke();
    return $len * $height;
}

# ----------------------------------------------------------------------
#
# Cairo_TopBoxes
#
# ----------------------------------------------------------------------

sub Cairo_TopBoxes {
    my ($conf, $cr, $y, $height, $boxes) = @_;
    my $x = 0;
    map {
	my $size = $_->[0];
	my $label = $_->[1];
	my $text = $_->[2];

	$cr->rectangle($x, $y, $size, $height);
	$cr->set_source_rgb(@{$conf->{colours}->{stats_bg}});
	$cr->fill_preserve();
	$cr->set_source_rgb(@{$conf->{colours}->{line}});
	$cr->stroke();
	$cr->set_font_size(6);
	$cr->select_font_face($conf->{'fonts'}->{'sans'}, 'normal', 'bold');
	$cr->set_source_rgb(@{$conf->{colours}->{font}});
	my $extents = $cr->text_extents($label);
	$cr->move_to($x + 1, $y + 6);
	$cr->show_text($label);
	$cr->move_to($x + $extents->{'width'} + 1, $y + $height - 3);
	$cr->set_font_size(10);
	$cr->select_font_face($conf->{'fonts'}->{'serif'}, 'normal', 'normal');
	$cr->show_text($text);
	$x += $size;
    } @$boxes;
}

# ----------------------------------------------------------------------
#
# Cairo_Character
#
# ----------------------------------------------------------------------

sub Cairo_Character {
    my ($conf, $map, $path) = @_;

    # --------------------
    # Shortcut variables
    # --------------------
    
    my $basics = $map->{basics} || die;
    my $current = $map->{current} || die;
    my $stats = $current->{stats} || die;

    # --------------------
    # Create surface with A4 dimensions (in printer points ie 1/72 of an inch)
    # --------------------
    
    my $surface = Cairo::PdfSurface->create($path, 595.28, 841.89);
    my $cr = Cairo::Context->create($surface);

    # --------------------
    # Select default sans font
    # --------------------
    
    $cr->select_font_face ($conf->{'fonts'}->{'sans'}, 'normal', 'normal');

    # --------------------
    # Offset page by (20,20)
    # --------------------
    
    $cr->translate(40, 20);
    $cr->save();

    # --------------------
    # Nice thin lines
    # --------------------
    
    $cr->set_line_width(0.3);

    # --------------------
    # Four stats boxes stacked
    # --------------------
    
    Cairo_TopBoxes($conf, $cr, 0, 20, [
		       [220, "Name", $basics->{'fullname'}],
		       [50, "PS", $stats->{'PS'}],
		       [50, "MD", $stats->{'MD'}],
		       [50, "AG", $stats->{'AG'}],
		       [50, "MA", $stats->{'MA'}],
		       [50, "WP", $stats->{'WP'}],
		       [50, "EN", $stats->{'EN'}],
		   ]);

    Cairo_TopBoxes($conf, $cr, 20, 20, [
		       [220, "Race", $basics->{'race'}],
		       [50, "Sex", $basics->{'sex'}],
		       [50, "PB", $stats->{'PB'}],
		       [50, "HT", $basics->{'height'}],
		       [50, "WT", $basics->{'weight'}],
		       [50, "PC", $stats->{'PC'}],
		       [50, "FT", $stats->{'FT'}],
		   ]);

    Cairo_TopBoxes($conf, $cr, 40, 20, [
		       [220, "Aspect", $basics->{"aspect"}],
		       [100, "Birth",  $basics->{"birth"}],
		       [200, "Date",   $basics->{'date'}." [".$map->{'now'}."]"],
		   ]);
    
    my $ep = $basics->{ep_total} ? sprintf("%d (%d)", $basics->{"ep_total"}, $basics->{"ep"}) : sprintf("%d", $basics->{"ep"});

    Cairo_TopBoxes($conf, $cr, 60, 20, [
		       [220, "S.Status", $basics->{"status"}],
		       [100, "Hand",     $basics->{"hand"}],
 		       [100, "College",  $basics->{"college"}],
 		       [100, "EP",       $ep],
		   ]);

    # --------------------
    # Frame stats boxes
    # --------------------
    
    $cr->set_line_width(1.0);
    $cr->set_source_rgb(@{$conf->{colours}->{line}});
    $cr->rectangle(0, 0, 520, 80);
    $cr->stroke();
    $cr->restore();

    # --------------------
    # Skill boxes
    # --------------------
    
    $cr->save();
    $cr->translate(0, 80);
    $cr->translate(0, Cairo_Bits($conf, $cr,
				 [sort({$b->{'rank'} <=> $a->{'rank'}} grep(!exists($map->{"ignore"}), @{$current->{'weapons'}}))],
				 [
				  {'id' => 'rank', 'len' => 20, 'title' => 'RK', 'align' => 'r'},
				  {'id' => 'name', 'len' => 100, 'title' => 'Weapon'},
				  {'id' => 'iv', 'len' => 20, 'title' => 'IV'},
				  {'id' => 'sc', 'len' => 20, 'title' => 'SC'},
				  {'id' => 'dm', 'len' => 20, 'title' => 'DM'},
				  {'id' => 'cl', 'len' => 20, 'title' => 'CL'},
				  {'id' => 'rg', 'len' => 20, 'title' => 'RG'},
				  {'id' => 'use', 'len' => 20, 'title' => 'USE'},
				  {'id' => 'wt', 'len' => 20, 'title' => 'WT'},
				 ]));
    $cr->translate(0, Cairo_Bits($conf, $cr,
				 [sort({$b->{'rank'} <=> $a->{'rank'}} grep(!exists($map->{"ignore"}), @{$current->{'skills'}}))],
				 [
				  {'id' => 'rank', 'len' => 20, 'title' => 'RK', 'align' => 'r'},
				  {'id' => 'name', 'len' => 240, 'title' => 'Skill'},
				 ]));

    $cr->translate(0, Cairo_Bits($conf, $cr,
				 [sort({$b->{'rank'} <=> $a->{'rank'}} grep(!exists($map->{"ignore"}), @{$current->{'languages'}}))],
				 [
				  {'id' => 'rank', 'len' => 20, 'title' => 'RK', 'align' => 'r'},
				  {'id' => 'name', 'len' => 240, 'title' => 'Language'},
				 ]));
    $cr->restore();

# --------------------
# Talents, spells & rituals
# --------------------

    $cr->save();
    $cr->translate(260, 80);
    foreach ("talents", "spells", "rituals")
    {
	$cr->translate(0, Cairo_Bits($conf, $cr,
				     [sort(
					  {
					      my ($ar, $an) = split(/\-/, $a->{'ref'});
					      my ($br, $bn) = split(/\-/, $b->{'ref'});
					      $an = 98 if ($an eq "GC");
					      $an = 99 if ($an eq "SC");
					      $bn = 98 if ($bn eq "GC");
					      $bn = 99 if ($bn eq "SC");
					      $ar cmp $br || $an <=> $bn;
					  } grep(!exists($map->{"ignore"}), @{$current->{$_}}))],
				     [
				      {'id' => 'rank', 'len' => 20, 'title' => 'RK', 'align' => 'r'},
				      {'id' => 'ref', 'len' => 30, 'title' => 'Ref'},
				      {'id' => 'name', 'len' => 190, 'title' => ucfirst($_)},
				      {'id' => 'bc', 'len' => 20, 'title' => 'BC', 'align' => 'r'},
				     ]));
    }
    $cr->restore();
    $cr->show_page;
}


# ----------------------------------------------------------------------
#
# TeX_Ranking
#
# ----------------------------------------------------------------------

sub TeX_Ranking {
    my ($map, $ranking, $stream) = @_;

    my $desc = $ranking->{"description"};
    my $ep = 0;
    my @block;
    my $rank_time;
    my $cal = $map->{calandar};

    for my $block (@{$ranking->{blocks}})
    {
	my $res = [];
	for my $line (@{$block->{lines}})
	{
	    my @res;

	    push(@res, $line->{name});
	    push(@res, $line->{final} ? $line->{initial} . "\\upto " .$line->{final} : $line->{initial});
	    map {
		push (@res, $line->{$_} // "");
	    } qw(sum em ep_raw ep time cost);

# --------------------
# Process Time stuff
# --------------------

	    if ($line->{"time"} && ($line->{"time"} ne "No time"))
	    {
		my $time = $line->{"time"};
		my $track = $line->{"track"};
		if ($line->{"partial"} && $line->{"partial"} > 0)
		{
	     	    $res[6] .= "\$^{$track\\delta}\$";
	     	}
	     	else
	     	{
		    $res[6] .= "\$^{$track}\$";
	     	}
	    }
	    push(@$res, sprintf("%s %s", join("\t& ", @res), "\\\\\n"));
	    $ep += $line->{"ep"};
	}
	$rank_time += $block->{"days"};
	push(@block, join("", @$res));
    }

    my $start = Tick->new($ranking->{"start"});
    my $end = Tick->new($ranking->{"end"});

    my $period = ($start == $end) ? $start->CDate() : sprintf("%s -- %s", $start->CDate(), $end->CDate());

    my $duration = $ranking->{time};
    my $text = join("\\\\\n", @block);

    $text =~ s/\&amp;/\\& /g;
    my $environment = $ranking->{star} ? "ranking*" : "ranking";
    $stream->print("\\begin{$environment}{$desc}{$period}\n");
    $stream->print($text);
    $stream->printf("\\hline\n");
    $stream->printf("Total \& \& \& \& \& $ep \& \\multicolumn{2}{l}{\\rankingtt $duration} \\\\\n") if ($ep);
    $stream->print("\\end{$environment}\n");
}


# ----------------------------------------------------------------------
#
# TeX_Adventure
#
# ----------------------------------------------------------------------

sub TeX_Adventure {
    my ($map, $adventure, $stream) = @_;

    my $name = $adventure->{name};
    my $start = $adventure->{start};
    my $end = $adventure->{end};
    
    my $startTick = Tick->new($start);
    my $endTick = Tick->new($end);

    # --------------------
    # Put calandar into map for TeX_Ranking to use
    # --------------------

    $map->{calandar} = $startTick->{calendar};
    
    $stream->printf("\\begin{adventure}{$name}{$start [%s]}{$end [%s]}\n", $startTick->CDate(), $endTick->CDate());

# --------------------
# Do party
# --------------------

    if (my $party = $adventure->{party})
    {
	$stream->printf("\\begin{party}\n");
     	for my $m (@$party)
	{
	    $stream->printf("%s & %s & %s \\\\\n",
     			    $m->{'name'},
     			    $m->{'college'},
     			    $m->{'note'});
     	}
	$stream->printf("\\end{party}\n");
    }

    # --------------------
    # Items
    # --------------------

    for my $items (@{$adventure->{items} || []})
    {
	$stream->printf("\\begin{items}{%s}\n", $items->{"description"});
	for my $item (@{$items->{lines}})
  	{
	    $stream->printf("%s \\\\\n", $item->{"description"});
	}
	$stream->printf("\\end{items}\n\n");
    }
    
# --------------------
# Do monies
# --------------------

    for my $monies (@{$adventure->{monies} || []})
    {
    
    # my @lines = $adventure->findnodes("monies/line")->get_nodelist();
    # if (scalar(@lines))
    # {
    # 	my $monies = $lines[0]->parentNode();
	$stream->printf("\\begin{monies}%s{%d}{%d}{%s}\n",
			$monies->{ledger} ? sprintf("[%s]", $monies->{ledger}) : "",
			$monies->{in},
			$monies->{out},
			$monies->{date});
	for my $line (@{$monies->{lines}})
	{
 	    $stream->printf("%s & %s & %s \\\\\n",
			    $line->{description},
			    $line->{out},
			    $line->{in});
	}
	$stream->printf("\\end{monies}\n");
    }

# --------------------
# Define variable to sum spend EP
# --------------------

    my $ep_spend = 0;

# --------------------
# Iterate over ranking blocks
# --------------------

    for my $ranking (@{$adventure->{ranking}})
    {
	&TeX_Ranking($map, $ranking, $stream);
    }

# --------------------
# Do EP if necessary
# --------------------

    if (my $exp = $adventure->{"experience"})
    {
	$stream->printf("\\experience{%d}{%d}{%d}{%d}{%s}\n", $exp->{gained}, $exp->{in}, $exp->{spent}, $exp->{out}, $exp->{notes});
    }
    $stream->print("\\end{adventure}\n");
}

# ----------------------------------------------------------------------
#
# TeX_Character
#
# ----------------------------------------------------------------------
sub TeX_Character {
    my ($conf, $map, $file) = @_;

    my $stream;
    open($stream, ">:encoding(utf-8)", "$file") || die;

    # --------------------
    # Shortcut variables
    # --------------------
    
    my $basics = $map->{basics};
    my $current = $map->{current};
    my $stats = $current->{stats};

# --------------------
# Get the TeX headers over and done with
# --------------------

    $stream->print("\\documentclass[a4paper]{article}\n");
    $stream->print("\\usepackage{ranking}\n");
    $stream->print("\\begin{document}\n");

# --------------------
# Create TeX header
# --------------------

    $stream->printf("\\charname{%s}\n", $basics->{'charname'});
    $stream->printf("\\fullname{%s}\n", $basics->{'fullname'});
    $stream->printf("\\race{%s}\n", $basics->{'race'});
    $stream->printf("\\dateofbirth{%s}\n", $basics->{'dateofbirth'});
    $stream->printf("\\aspect{%s}\n", $basics->{'aspect'});
    $stream->printf("\\birth{%s}\n", $basics->{'birth'});
    $stream->printf("\\status{%s}\n", $basics->{'status'});
    $stream->printf("\\college{%s}\n", $basics->{'college'});
    $stream->printf("\\charpic{%s}\n", $basics->{'picture'}) if (exists($basics->{'picture'}));

# --------------------
# Do title
# --------------------

    $stream->print("\\chardesc\n");

# --------------------
# Create TeX table
# --------------------

    $stream->printf("\\begin{frontcover}\n\n");

    $stream->printf("\\begin{dqtblr}{colspec={Q[l,t,40mm]XXXXXX},");
    $stream->printf("cell{3}{1}={c=2}{l},cell{3}{3}={c=3}{l},cell{3}{6}={c=2}{l},");
    $stream->printf("cell{4}{2,4,6}={c=2}{l}}");
    $stream->printf("\\textsuperscript{Name}%s \&\n", $basics->{'charname'});
    $stream->printf("\\textsuperscript{PS} %s \&\n", $stats->{'PS'});
    $stream->printf("\\textsuperscript{MD} %s \&\n", $stats->{'MD'});
    $stream->printf("\\textsuperscript{AG} %s \&\n", $stats->{'AG'});
    $stream->printf("\\textsuperscript{MA} %s \&\n", $stats->{'MA'});
    $stream->printf("\\textsuperscript{WP} %s \&\n", $stats->{'WP'});
    $stream->printf("\\textsuperscript{EN} %s \\\\\n", $stats->{'EN'});

    $stream->printf("\\textsuperscript{Race} %s \&\n", $basics->{'race'});
    $stream->printf("\\textsuperscript{Sex} %s \&\n", $basics->{'sex'});
    $stream->printf("\\textsuperscript{HT} %s \&\n", $basics->{'height'});
    $stream->printf("\\textsuperscript{WT} %s \&\n", $basics->{'weight'});
    $stream->printf("\\textsuperscript{PB} %s \&\n", $stats->{'PB'});
    $stream->printf("\\textsuperscript{PC} %s \&\n", $stats->{'PC'});
    $stream->printf("\\textsuperscript{FT} %s \\\\\n", $stats->{'FT'});

    $stream->printf("\\textsuperscript{Aspect}%s \& \& \n", $basics->{'aspect'});
    $stream->printf("\\textsuperscript{Birth} %s \& \& \& \n", $basics->{'birth'});
    $stream->printf("\\textsuperscript{Date} %s \& \\\\\n", $basics->{'date'});

    $stream->printf("\\textsuperscript{S.Status} %s \&\n", $basics->{'status'});
    $stream->printf("\\textsuperscript{Hand} %s \& \&\n", $basics->{'hand'});
    $stream->printf("\\textsuperscript{Coll.} %s \& \& \n", $basics->{'college'});
    $stream->printf("\\textsuperscript{EP} %s [%s] \& \\\\\n", $basics->{'ep_total'}, $basics->{'ep'});    
    $stream->printf("\\end{dqtblr}\n\n");
    
    # --------------------
    # Do the skills, weapons & spells
    # --------------------


    $stream->printf("\\begin{multicols}{2}\n\\raggedcolumns\n\n");

    # --------------------
    # Start skills table
    # --------------------

    $stream->printf("\\begin{ranktblr}{colspec={rX}}\n");
    
    $stream->printf("Rk &Skill \\\\\n");
    
    for my $s (sort {$b->{"rank"} <=> $a->{"rank"}} @{$current->{'skills'}})
    {
	
	next if ($s->{'name'} =~ m/^__/);
	my $t = sprintf "\\hbox to 2.0em{\\hfil %d} \& %s \\\\\n", $s->{"rank"}, $s->{'name'};
	$t =~ s/\&amp;/\\& /;
	$stream->print($t);
    }
    $stream->printf("\\end{ranktblr}\n");
    $stream->printf("\n\n");

    # --------------------
    # Languages
    # --------------------
    
    $stream->printf("\\begin{ranktblr}{colspec={rX}}\n");
    $stream->printf("Rk & Language \\\\\n");

    for my $s (sort {$b->{"rank"} <=> $a->{"rank"}} @{$current->{'languages'}})
    {
	
	next if ($s->{'name'} =~ m/^__/);
	my $t = sprintf "\\hbox to 2.0em{\\hfil %d} \& %s \\\\\n", $s->{"rank"}, $s->{'name'};
	$t =~ s/\&amp;/\\& /;
	$stream->print($t);
    }
    $stream->printf("\\end{ranktblr}\n");
    $stream->printf("\n\n");

    # --------------------
    # Start weapons table
    # --------------------
    
    $stream->printf("\\begin{ranktblr}{colspec={rX}}\n");
    $stream->printf("Rk & Weapon\\\\\n");
    
    for my $s (sort {$b->{"rank"} <=> $a->{"rank"}} @{$current->{'weapons'}})
    {
	next if ($s->{'name'} =~ m/^__/);
	my $t = sprintf "\\hbox to 2.0em{\\hfil %d} \& %s \\\\\n", $s->{"rank"}, $s->{'name'};
	$t =~ s/\&amp;/\\& /;
	$stream->print($t);
    }
    $stream->print("\\end{ranktblr}\n");
    $stream->print("\n");
    
    # Insert the intercolumn break

    # --------------------
    # And now do spells
    # --------------------
    
    for my $t ("talents", "spells", "rituals")
    {
    
	my @list = sort {
	    my $aref = $a->{"ref"};
	    my $bref = $b->{"ref"};
	    my ($atype, $aval) = split(/-/, $aref);
	    my ($btype, $bval) = split(/-/, $bref);
	    $b->{"college"} cmp $a->{"college"} || $atype cmp $btype || $aval <=> $bval
	} @{$current->{$t}};
		 
	if (scalar(@list))
	{
	    $stream->printf("\\begin{ranktblr}{colspec={rX}} \n");
	    $stream->printf("\\textbf{Rk} & \\textbf{%s} \\\\ \n", ucfirst($t));
	    
	    for my $s (@list)
	    {
		next if ($s =~ m/^__/);
		my $t = sprintf("%d \& %s (%s) \\\\\n",
				$s->{"rank"},
				$s->{"name"},
				$s->{"ref"}
		    );
		$t =~ s/\&amp;/\\& /;
		$stream->print($t);
	    }
	    $stream->printf("\\end{ranktblr}\n\n");
	}
    }
    $stream->printf("\\end{multicols}\n\n");
		     
# --------------------
# Reset normal font back to serif
# --------------------
    
    $stream->printf("\\end{frontcover}\n\n");

# --------------------
# Iterate over the adventures
# --------------------

    map {
	&TeX_Adventure($map, $_, $stream);
    } @{$map->{adventures}};
    
    $stream->print("\\end{document}\n");
    close($stream);
}


# ----------------------------------------------------------------------
#
# Text_Character
#
# ----------------------------------------------------------------------

sub Text_Character {
    my ($conf, $map, $opts) = @_;
    for my $a (@{$map->{adventures}})
    {
	printf("%s\n", $a->{name});
	for my $ranking (@{$a->{ranking}})
	{
	    printf(" - %s\n", $ranking->{desc});
	    for my $block (@{$ranking->{block}})
	    {
		printf("    - \n");
		for my $line (@$block)
		{
		    printf("      - %s\n", $line->{name});
		}
	    }
	}
    }
}

# ----------------------------------------------------------------------
#
# JSON_File
#
# ----------------------------------------------------------------------

sub JSON_File {
    my ($conf, $opts) = @_;

    return decode_json(slurp($opts->{i}));
}

# ----------------------------------------------------------------------
#
# YAML_File
#
# ----------------------------------------------------------------------

sub YAML_File {
    my ($conf, $opts) = @_;

    return YAML::LoadFile($opts->{i});
}


# ----------------------------------------------------------------------
#
# Main
#
# ----------------------------------------------------------------------

sub Main {

    # --------------------
    # Configuration
    # --------------------

    my $conf = {
	colours => {
	    font => [0.0, 0.0, 0.0],
	    line => [0.0, 0.0, 1.0],
	    stats_bg => [0.9, 0.9, 0.9],
	    rank_bg => [1.0, 1.0, 1.0],
	},
	fonts => {
	    serif => 'Nimbus Roman',
	    sans => 'Nimbus Sans',
	},
	formats => {
	    tex => {
		function => \&TeX_Character,
		description => 'LaTeX for XeLaTeX',
	    },
	    cairo => {
		function => \&Cairo_Character,
		description => 'PDF character sheet via cairo',
	    },
	    plain => {
		function => \&Text_Character,
		description => 'Text output for debugging',
	    },
	    cal => {
		function => \&Cal_Character,
		description => 'Create calendar',
	    },
	},
    };

    # --------------------
    # Load file
    # --------------------

    my $parser_dispatch = {
	json => \&JSON_File,
	yaml => \&YAML_File,
    };
    

    # --------------------
    # Process opts
    # --------------------
    
    my $opts = {
    };
    GetOptions(
	'i=s' => \$opts->{i},
	'o=s' => \$opts->{o},
	'f=s' => \$opts->{f},
	't=s' => \$opts->{t},
	'p=s' => \$opts->{p},
	);
    
    # --------------------
    # Give useful errors
    # --------------------
    
    if (!exists($opts->{i}) || !$opts->{i})
    {
	printf(STDERR "$0: [-i input.PARSER]\n");
	exit(1);
    }

    if (!exists($opts->{o}) || !$opts->{o})
    {
	printf(STDERR "$0: [-o output.FORMAT]\n");
	exit(1);
    }

    if (!exists($opts->{f}) || !$opts->{f})
    {
	printf(STDERR "$0: [-f %s]\n", join("|", keys(%{$conf->{formats}})));
	exit(1);
    }
    if (!exists($opts->{p}) || !$opts->{p})
    {
	printf(STDERR "$0: [-p %s]\n", join("|", keys(%{$parser_dispatch})));
	exit(1);
    }
    
    if (!exists($parser_dispatch->{$opts->{p}}))
    {
	printf("%s: input parser %s not implemented\n", basename($0), $opts->{p});
	exit(1);
    }

    my $parser = $parser_dispatch->{$opts->{p}};
    my $character = $parser->($conf, $opts);

    # --------------------
    # Add now
    # --------------------
    
    $character->{'now'} = strftime("%d %b %Y", @{localtime(time())});

    # --------------------
    # Create output documents
    # --------------------

    if (!exists($conf->{formats}->{$opts->{'f'}}->{function}))
    {
	printf STDERR "$0: Cannot find function for format %s\n", $opts->{f};
	exit(1);
    }
    my $format_function = $conf->{formats}->{$opts->{f}}->{function};
    $format_function->($conf, $character, $opts->{o});
}

&Main();
