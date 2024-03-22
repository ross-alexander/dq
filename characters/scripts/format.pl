#!/usr/bin/perl -I/locker/gaming/dq/characters/scripts

# ----------------------------------------------------------------------
#
# format.pl
#
# Take XML version of character sheet and format back into LaTeX.
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

use 5.34.0;
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

# ----------------------------------------------------------------------
#
# Cal_Character
#
# ----------------------------------------------------------------------
sub Cal_Character {

    my ($doc, $map, $file) = @_;

    my $cal_doc = XML::LibXML::Document->new("1.0", "utf8");
    my $cal_root = $cal_doc->createElement("cal");
    $cal_doc->setDocumentElement($cal_root);

    my $out;
    open($out, ">", $file);

# --------------------
# @tl is track list, holds all the ranking track information
# --------------------

    my @tl;

    for my $a ($doc->findnodes("/character/adventure")->get_nodelist)
    {
	my $advtrack = {};

	if (!(($a->hasAttribute("star")) && ($a->getAttribute("star") > 0)))
	{
	    my $t = {};
	    $t->{'type'} = "a";
	    $t->{'start'} = $a->getAttribute("start-tick");
	    $t->{'end'} = $a->getAttribute("end-tick");
	    $t->{'name'} = $a->getAttribute("name");
	    $t->{'track'} = 0;
	    push(@tl, $t);
	}
	printf $out "# adventure %d %d %s\n", $a->getAttribute("start-tick"), $a->getAttribute("end-tick"), $a->getAttribute("name"), "\n";
	for my $r ($a->findnodes("ranking")->get_nodelist)
	{
	    my $s = $r->getAttribute("start");
	    my $e = $r->getAttribute("end");
	    if ((!($a->hasAttribute("star")) || ($a->getAttribute("star") > 0)) &&
		(($e - $s) > 0))
	    {
		printf $out "# ranking %d %d %s\n", $r->getAttribute("start"), $r->getAttribute("end"), $r->getAttribute("desc");
		for my $b ($r->findnodes("block")->get_nodelist)
		{
		    my $s = $b->getAttribute("start");
		    my @s = ($s, $s, $s, $s);
		    for my $i ($b->findnodes("*")->get_nodelist)
		    {
			if ($i->getAttribute("day-equiv"))
			{
			    my $t = {};
			    my $tn;
			    $t->{'type'} = "r";
			    $t->{'track'} = $tn = $i->getAttribute("track");
			    $t->{'start'} = $s[$tn];
			    $t->{'end'} = $s[$tn] + $i->getAttribute("day-equiv") - 1;
			    $t->{'name'} = $i->getAttribute("name");
			    push(@tl, $t);
			    $s[$tn] += $i->getAttribute("day-equiv");
			}
			printf $out "# line %d %d %s\n", $i->getAttribute("day-equiv"), $i->getAttribute("track"), $i->getAttribute("name");
		    }
		}
	    }
	}
    }

# --------------------
# Map over the track list
# --------------------

    my $ym = {};
    my $om = {};
    map {
	printf $out "# track %s %d %d %d\n", $_->{'name'}, $_->{'track'}, $_->{'start'}, $_->{'end'};

	my $i = 0;
	do {
	    if (!exists($om->{$i}))
	    {
		$om->{$i} = $_;
		$_->{'ref'} = $i;
	    }
	    $i++;
	} while (!exists($_->{'ref'}));

	for $i ($_->{'start'} .. $_->{'end'})
	{
	
# --------------------
# TickToTM returns (d,m,y,wd,yd)
# --------------------

	    my @bits = TickToTM($i);

# --------------------
# Create year (d,m,y,wd,yd)
# --------------------

	    $ym->{$bits[2]} = {} if (!exists($ym->{$bits[2]}));

# --------------------
# Create month (d,m,y,wd,yd)
# --------------------

	    if (!exists($ym->{$bits[2]}->{$bits[1]}))
	    {
		my $monthmap = {};
		$ym->{$bits[2]}->{$bits[1]} = $monthmap;

# --------------------
# Get start of month date
# --------------------

		my @monbits = TickToTM($i - $bits[0]);
		@monbits = TickToTM($i - $bits[0] + 1) if($monbits[0]);

# --------------------
# Get end of month
# Add enough days to get next month then work backward
# --------------------

		my $j = $i + 31;
		my @mon2bits  = TickToTM($j);
		$j -= $mon2bits[0];
		@mon2bits = TickToTM($j);
		$j -= 1 if ($mon2bits[1] != $monbits[1]);
		@mon2bits = TickToTM($j);

		$monthmap->{'_start_'} = $monbits[0];
		$monthmap->{'_end_'} = $mon2bits[0];
		$monthmap->{'_wday_'} = $monbits[3];
		
#		printf STDERR "Got month %d start %d end %d wday %d\n", $monbits[1], $monbits[0], $mon2bits[0], $monbits[3];
	    }
	    if (!exists($ym->{$bits[2]}->{$bits[1]}->{$bits[0]}))
	    {
		$ym->{$bits[2]}->{$bits[1]}->{$bits[0]} = {};
	    }
	    my $d = $ym->{$bits[2]}->{$bits[1]}->{$bits[0]};
	    $d->{$_->{'track'}} = $_;
	    $d->{'mday'} = $bits[3];
	    $d->{'wk'} = TickToWK($i);
	}
    } @tl;

# --------------------
# Add weeks
# --------------------

    while (my ($year, $ydata) = each(%$ym))
    {
	while (my ($month, $mdata) = each(%$ydata))
	{
	    my $wday = $mdata->{'_wday_'};
	    my $wks = {};
	    while (my ($day, $ddata) = each(%$mdata))
	    {
		next if (!($day =~ /\d+/));
		my $wk = int(($wday + $day) / 7);
		$wks->{$wk} = {} if (!exists($wks->{$wk}));
		$wks->{$wk}->{$day} = $ddata;
		delete $mdata->{$day};
	    }
	    while ((my ($k, $v) = each(%$wks)))
	    {
		$mdata->{$k} = $v;
	    }
	}
    }

# --------------------
# Do output
# --------------------

    for my $y (sort({$a <=> $b} keys(%$ym)))
    {
	my $y_node = $cal_root->addNewChild("", "year");
	$y_node->setAttribute("year", $y);
	printf $out "Year\t%d\n", $y;
	my $ykey = $ym->{$y};
	for my $m (sort({$a <=> $b} keys(%$ykey)))
	{
	    my $mkey = $ykey->{$m};

	    my $m_node = $y_node->addNewChild("", "month");
	    $m_node->setAttribute("month", $m);
	    $m_node->setAttribute("start", $mkey->{'_start_'});
	    $m_node->setAttribute("end", $mkey->{'_end_'});
	    $m_node->setAttribute("wday", $mkey->{'_wday_'});

	    printf $out "Month\t%d\t%d\t%d\t%d\n", $m, $mkey->{'_start_'}, $mkey->{'_end_'}, $mkey->{'_wday_'};
	    for my $w (sort({$a <=> $b} keys(%$mkey)))
	    {
		my $week = $mkey->{$w};
		if ($w =~ m:^[0-9]+$:)
		{
		    my $w_node = $m_node->addNewChild("", "week");
		    my $week = $mkey->{$w};
		    for my $d (sort({$a <=> $b} keys(%$week)))
		    {
			my $day = $week->{$d};
			my $d_node = $w_node->addNewChild("", "day");
			$d_node->setAttribute("day", $d);
			$d_node->setAttribute("date", $day->{'wk'});
			printf $out "Day\t%d\t%d\t%s", $d, $day->{'mday'}, $day->{'wk'};
			for my $t (0, 1, 2, 3)
			{
			    if (exists($day->{$t}))
			    {
				my $t_node = $d_node->addNewChild("", "track");
				$t_node->setAttribute("track", $t);
				$t_node->setAttribute("name", $day->{$t}->{'name'});

				printf $out "\t%d\t%s", $t, $day->{$t}->{'name'};
			    }
			}
			printf $out "\n";
		    }
		}
	    }
	}
    }
    close($out);
    $cal_doc->toFile("$file".".xml", 1);
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

sub Cairo_FrameLeftTopTextBox {
    my ($conf, $cr, $x, $y, $w, $h, $label, $text) = @_;
    $cr->rectangle($x, $y, $w, $h);
    $cr->stroke();
    $cr->set_font_size(6);
    $cr->select_font_face($conf->{'fonts'}->{'sans'}, 'normal', 'normal');
    my $extents = $cr->text_extents($label);
    $cr->move_to($x + 1, $y + 6);
    $cr->show_text($label);
    $cr->move_to($x + $extents->{'width'} + 1, $y + $h - 2);
    $cr->set_font_size(10);
    $cr->select_font_face($conf->{'fonts'}->{'sans'}, 'normal', 'normal');
    $cr->show_text($text);
}

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
	my $align = $box->{'align'};
	$cr->rectangle($x, 0, $size, $height);
	$cr->stroke();
	my $extents = $cr->text_extents($title);
	$cr->move_to($x + ($size - $extents->{'width'})/2, $height - 2);
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
	    my $align = $box->{'align'};
	    my $text = $j->{$id};

	    $cr->rectangle($x, ($i+1) * $height, $size, $height);
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
	    $cr->show_text($text);
	    $x += $size;
	}
	$maxx = $x;
    }
    $len++;

    $cr->set_line_width(1.0);
    $cr->rectangle(0, 0, $maxx, $len * $height);
    $cr->stroke();
    return $len * $height;
}

sub Cairo_TopBoxes {
    my ($conf, $cr, $y, $height, $boxes) = @_;
    my $x = 0;
    map {
	my $size = $_->[0];
	my $label = $_->[1];
	my $text = $_->[2];

	$cr->rectangle($x, $y, $size, $height);
	$cr->set_source_rgb(0.9, 0.9, 0.9);
	$cr->fill_preserve();
	$cr->set_source_rgb(0.0, 0.0, 0.0);
	$cr->stroke();
	$cr->set_font_size(6);
	$cr->select_font_face($conf->{'fonts'}->{'sans'}, 'normal', 'bold');
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
    my $ep;
    if ($basics->{"ep"})
    {
	$ep = sprintf("%d (%d)", $basics->{"ep-total"}, $basics->{"ep"});
    }
    else
    {
	$ep = sprintf("%d", $basics->{"ep"});
    }

    Cairo_TopBoxes($conf, $cr, 60, 20, [
		       [220, "S.Status", $basics->{"status"}],
		       [100, "Hand",     $basics->{"hand"}],
 		       [100, "College",  $basics->{"college"}],
 		       [100, "EP",       $ep],
		   ]);

    $cr->set_line_width(1.0);
    $cr->rectangle(0, 0, 520, 80);
    $cr->stroke();
    $cr->restore();
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

    my $desc = $ranking->{"desc"};
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

	    push(@res, $line->{"name"});
	    push(@res, $line->{"final"} ? $line->{"initial"} . "\\upto " .$line->{"final"} : $line->{"initial"});
	    map {
		push (@res, $line->{$_} // "");
	    } qw(sum em ep_raw ep time money);

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
	$rank_time += $block->{"time"};
	push(@block, join("", @$res));
    }

    my $start = new Tick($ranking->{"start"});
    my $end = new Tick($ranking->{"end"});

    my $period = ($start == $end) ? $start->CDate() : sprintf("%s -- %s", $start->CDate(), $end->CDate());

    my $weeks_text;
    my $days_text;
    if ($rank_time > 0)
    {
	my $weeks = int($rank_time / 7);
	my $days = $rank_time - ($weeks * 7);
	if ($weeks > 0)
	{
	    $weeks_text = ($weeks == 1) ? "1 week" : "$weeks weeks";
	}
	if ($days > 0)
	{
	    $days_text .= (($days == 1) ? "1 day" : "$days days");
	}
    }
    else
    {
	$weeks_text = "No time";
    }

    my $text = join("\\\\\n", @block);

    $text =~ s/\&amp;/\\& /g;
    $stream->print("\\begin{ranking}{$desc}{$period}\n");
    $stream->print($text);
    $stream->printf("\\hline\\textbf{Total} \& \& \& \& \& \\textbf{$ep} \& \\multicolumn{2}{l}{\\rankingtt \\textbf{$weeks_text $days_text}} \\\\\n") if ($ep);
    $stream->print("\\end{ranking}\n");
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
    
    my $startTick = new Tick($start);
    my $endTick = new Tick($end);

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
	$stream->printf("\\begin{items}{%s}\n", $items->{"desc"});
	for my $item (@{$items->{lines}})
  	{
	    $stream->printf("%s \\\\\n", $item->{"desc"});
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
			    $line->{desc},
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

# --------------------
# Do title
# --------------------

    $stream->print("\\chardesc\n");

# --------------------
# Create TeX table
# --------------------

    $stream->printf("\\begin{frontcover}\n");

    $stream->printf("\\begin{dqtblr}{colspec={Q[l,t,40mm]XXXXXX},");
    $stream->printf("cell{3}{2}={c=3}{l},cell{3}{5}={c=3}{l},");
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

    $stream->printf("\\textsuperscript{Aspect}%s \&\n", $basics->{'aspect'});
    $stream->printf("\\textsuperscript{Birth} %s \& \& \& \n", $basics->{'birth'});
    $stream->printf("\\textsuperscript{Date} %s  \& \& \\\\\n", $basics->{'date'});

    $stream->printf("\\textsuperscript{S.Status} %s \&\n", $basics->{'status'});
    $stream->printf("\\textsuperscript{Hand} %s \& \&\n", $basics->{'hand'});
    $stream->printf("\\textsuperscript{Coll.} %s \& \& \n", $basics->{'college'});
    $stream->printf("\\textsuperscript{EP} %s [%s] \& \\\\\n", $basics->{'ep-total'}, $basics->{'ep'});    
    $stream->printf("\\end{dqtblr}\n\n");
    
    # $stream->printf("\\begin{tabularx}{\\linewidth}{|l|X|X|X|X|X|X|} \\hline\n");
    # $stream->printf("\\makebox[4cm][l]{\\textsuperscript{Name}%s} \&\n", $basics->{'charname'});
    # $stream->printf("\\textsuperscript{PS} %s \&\n", $stats->{'PS'});
    # $stream->printf("\\textsuperscript{MD} %s \&\n", $stats->{'MD'});
    # $stream->printf("\\textsuperscript{AG} %s \&\n", $stats->{'AG'});
    # $stream->printf("\\textsuperscript{MA} %s \&\n", $stats->{'MA'});
    # $stream->printf("\\textsuperscript{WP} %s \&\n", $stats->{'WP'});
    # $stream->printf("\\textsuperscript{EN} %s \\\\\n", $stats->{'EN'});
    # $stream->printf("\\hline\n");

    # $stream->printf("\\textsuperscript{Race} %s \&\n", $basics->{'race'});
    # $stream->printf("\\textsuperscript{Sex} %s \&\n", $basics->{'sex'});
    # $stream->printf("\\textsuperscript{HT} %s \&\n", $basics->{'height'});
    # $stream->printf("\\textsuperscript{WT} %s \&\n", $basics->{'weight'});
    # $stream->printf("\\textsuperscript{PB} %s \&\n", $stats->{'PB'});
    # $stream->printf("\\textsuperscript{PC} %s \&\n", $stats->{'PC'});
    # $stream->printf("\\textsuperscript{FT} %s \\\\\n", $stats->{'FT'});
    # $stream->printf("\\hline\n");

    # $stream->printf("\\textsuperscript{Aspect}%s \&\n", $basics->{'aspect'});
    # $stream->printf("\\multicolumn{3}{l|}{\\textsuperscript{Birth} %s} \&\n", $basics->{'birth'});
    # $stream->printf("\\multicolumn{3}{l|}{\\textsuperscript{Date} %s} \\\\\n", $basics->{'date'});
    # $stream->printf("\\hline\n");
    
    # $stream->printf("\\textsuperscript{S.Status} %s \&\n", $basics->{'status'});
    # $stream->printf("\\multicolumn{2}{l|}{\\textsuperscript{Hand} %s} \&\n", $basics->{'hand'});
    # $stream->printf("\\multicolumn{2}{l|}{\\textsuperscript{Coll.} %s} \& \n", $basics->{'college'});
    # $stream->printf("\\multicolumn{2}{l|}{\\textsuperscript{EP} %s [%s]} \\\\\n", $basics->{'ep-total'}, $basics->{'ep'});
    # $stream->printf("\\hline\n");

    # $stream->printf("\\end{tabularx}\n\n");

    # --------------------
    # Do the skills, weapons & spells
    # --------------------

    #    $stream->printf("\\begin{tabular}[t]{\@{}p{0.5\\linewidth}\@{}p{0.5\\linewidth}\@{}}\n");

    $stream->printf("\\begin{multicols}{2}\n\\raggedcolumns\n\n");

    # Start skills table

#    $stream->printf("\\begin{tabularx}{0.49\\columnwidth}[t]{|r|X|} \\hline \n");
#    $stream->printf("\\textbf{Rk} & \\hfil \\textbf{Skill} \\hfil \\\\ \\hline\n");

    $stream->printf("\\begin{ranktblr}{colspec={rX}}\n");
    
    $stream->printf("Rk &Skill \\\\\n");
    
    for my $s (sort {$b->{"rank"} <=> $a->{"rank"}} @{$current->{'skills'}})
    {
	
	next if ($s->{'name'} =~ m/^__/);
	my $t = sprintf "\\hbox to 2.0em{\\hfil %d} \& %s \\\\\n", $s->{"rank"}, $s->{'name'};
	$t =~ s/\&amp;/\\& /;
	$stream->print($t);
    }
#    $stream->printf("\\hline\n");
#    $stream->printf("\\end{tabularx}\n");
    $stream->printf("\\end{ranktblr}\n");
    $stream->printf("\n\n");

    # Languages

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

    # Start weapons table

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

#    $stream->printf("\&\n");

    # And now do spells

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
	    $stream->printf("\\textbf{Rk} & \\hfil \\textbf{%s} \\hfil \\\\ \n", ucfirst($t));
	    
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
#    $stream->printf("\\end{tabular}\n");
		     
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
	for my $r (@{$a->{ranking}})
	{
	    printf(" - %s\n", $r->{desc});
	    for my $block (@{$r->{blocks}})
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
# XML_Adventure
#
# ----------------------------------------------------------------------

sub XML_Adventure {
    my ($node) = @_;
    my $adventure = 
	+{
	    name => $node->{name},
	    start => $node->{start},
	    end => $node->{end},
	    ranking => [
		map {
		    +{
			desc => $_->{desc},
			start => $_->{start},
			end => $_->{end},
			star => $_->{star},
			blocks => [
			    map {
				+{
				    lines => [
					map {
					    +{
						type => $_->getName(),
						name => $_->{name},
						initial => $_->{initial},
						final => $_->{final},
						sum => $_->{sum} // undef,
						em => $_->{em} // undef,
						ep => $_->{ep},
						ep_raw => $_->{ep_raw} // undef,
						time => $_->{time},
						track => $_->{track},
						partial => $_->{partial} // undef,
						money => $_->{money} // undef
					    }
					} $_->findnodes("*")
					],
				    time => $_->{time} // undef,
				}
			    } $_->findnodes("block")
			    ],
		    }
		} $node->findnodes("ranking") ],
    };

    # --------------------
    # Party members
    # --------------------
    $adventure->{party} = [
	map {
	    +{
		name => $_->{name},
		college => $_->{college},
		note => $_->{note}
	    }
	} $node->findnodes("party/member")
	];

    delete $adventure->{party} if (scalar(@{$adventure->{party}}) == 0);
    
    # --------------------
    # Items
    # --------------------

    $adventure->{items} = [
	map {
	    +{
		desc => $_->{desc},
		lines => [
		    map {
			+{
			    desc => $_->{desc}
			}
		    } $_->findnodes("line")
		    ],
	    }
	} $node->findnodes("items")
	];

    # --------------------
    # Monies
    # --------------------

    $adventure->{monies} = [
	map {
	    + {
		in => $_->{in},
		out => $_->{out},
		date => $_->{date},
		ledger => $_->{ledger} // undef,
		lines => [
		    map {
			+{
			    desc => $_->{desc},
			    in => $_->{in} // undef,
			    out => $_->{out} // undef
			}
		    } $_->findnodes("line")
		    ],
	    }
	} $node->findnodes("monies")
	];
	
    
    # --------------------
    # Experience
    # --------------------
    
    map {
	$adventure->{experience}->{gained} = $_->{gained};
	$adventure->{experience}->{spent} = $_->{spent};
	$adventure->{experience}->{in} = $_->{in};
	$adventure->{experience}->{out} = $_->{out};
	$adventure->{experience}->{notes} = $_->{notes};
    } $node->findnodes("experience");
    return $adventure;
}
    
# ----------------------------------------------------------------------
#
# XML_File
#
# ----------------------------------------------------------------------

sub XML_File {
    my ($conf, $opts) = @_;

    # --------------------
    # Sanity check input
    # --------------------
    
    my $path = $opts->{i};
    if (!-f $path)
    {
	printf(STDERR "$0: cannot find input file %s\n", $path);
	exit(1);
    }

    my $xml_in = slurp($path);
    
# --------------------
# Create map to hold state
# --------------------

    my $map = {};
    
# --------------------
# Get basics
# --------------------

    my $doc = $conf->{'parser'}->parse_string($xml_in);
    for my $i ($doc->findnodes("/character/basics")->[0]->getAttributes())
    {
	my $key = $i->getName();
	my $data = $i->getValue();
	$map->{basics}->{$key} = $data;
    }
    
# --------------------
# Get stats
# --------------------

    for my $s ($doc->findnodes("/character/current/stats/stat")->get_nodelist)
    {
	my $key = $s->getAttribute("name");
	my $data = $s->getAttribute("value");
	$map->{current}->{stats}->{$key} = $data;
    }

# --------------------
# Get skills, languages & weapons
# --------------------

    for my $k ("/character/current/skills/skill", "/character/current/languages/language", "/character/current/weapons/weapon")
    {
	my @bits = split(m:/:, $k);
	$map->{current}->{$bits[3]} = [
	    map {
		+{
		    name => $_->getAttribute('name'),
		    rank => $_->getAttribute('rank'),
		    type => $_->getName()
		}
	    } $doc->findnodes($k)->get_nodelist];
    }

    # --------------------
    # Magic
    # --------------------

    for my $k ("/character/current/talents/talent", "/character/current/spells/spell", "/character/current/rituals/ritual")
    {
	my @bits = split(m:/:, $k);
	$map->{current}->{$bits[3]} = [
	    map {
		+{
		    name => $_->getAttribute('name'),
		    rank => $_->getAttribute('rank'),
		    ref => $_->getAttribute('ref'),
		    college => $_->getAttribute('college')
		};
	    } $doc->findnodes($k)->get_nodelist];
    }

    # --------------------
    # Adventures
    # --------------------

    $map->{adventures} = [
	map
	{
	    &XML_Adventure($_);
	} ($doc->findnodes("/character/adventure"))
	];

    return $map;
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
	fonts => {
	    sans => 'Helvetica',
	    serif => 'Times',
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
	},
    };

    # --------------------
    # Get spells (not really implemented currently [25.10.2021]
    # --------------------
    
    my $parser = XML::LibXML->new();
    $conf->{'parser'} = $parser;
    if (-f "spells.xml")
    {
	$conf->{"spells"} = $parser->parse_file("spells.xml");
    }

    # --------------------
    # Process opts
    # --------------------
    
    my $opts = {
	parser => 'xml',
    };
    GetOptions(
	'i=s' => \$opts->{i},
	'o=s' => \$opts->{o},
	'f=s' => \$opts->{f},
	't=s' => \$opts->{t},
	'p=s' => \$opts->{parser},
	);
    
    # --------------------
    # Give useful errors
    # --------------------
    
    if (!exists($opts->{i}) || !$opts->{i})
    {
	printf(stderr "$0: [-i input.PARSER]\n");
	exit(1);
    }

    if (!exists($opts->{o}) || !$opts->{o})
    {
	printf(stderr "$0: [-o output.FORMAT]\n");
	exit(1);
    }

    if (!exists($opts->{f}) || !$opts->{f})
    {
	printf(stderr "$0: [-f %s]\n", join("|", keys(%{$conf->{formats}})));
	exit(1);
    }

    # --------------------
    # Load file
    # --------------------

    my $parser_dispatch = {
	json => \&JSON_File,
	yaml => \&YAML_File,
	xml => \&XML_File,
    };
    
    if (!exists($parser_dispatch->{$opts->{parser}}))
    {
	printf("%s: input parser %s not implemented\n", basename($0), $opts->{parser});
	exit(1);
    }

    my $parser = $parser_dispatch->{$opts->{parser}};
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
