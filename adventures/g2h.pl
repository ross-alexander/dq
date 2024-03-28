#!/usr/bin/perl -I/locker/gaming/dq/characters/scripts

use Tick;

# ----------------------------------------------------------------------
#
# games2html
#
# 2024-03-25: Convert from XML to YAML
#
# ----------------------------------------------------------------------

use XML::LibXML;
use YAML qw(LoadFile);
use 5.34.0;

sub EpochDiff {
    my ($s, $e) = @_;
    my $d = $e - $s + 1;
    return sprintf("%d %s", $d, $d == 1 ? "day" : "days");
}

sub Date2Epoch {
    my ($in) = @_;
    my ($mday, $mon, $year) = split(m:/:, $in);
    my $date = $year * 364;

    $date += ($mon-1) * 30 + int(($mon-1) / 3) + $mday;
    return $date;
}

sub Epoch2Date {
    my ($epoch) = @_;

    my $year = int($epoch / 364);
    $epoch -= 364 * $year;
    my $q = int($epoch / 91);
    $epoch -= 91*$q;
    my $mon = int(($epoch-2)/30);
    $epoch -= $mon * 30;
    my $mday = $epoch;

    my $mmap = {
	0 => 'Meadow',
	1 => 'Heat',
	2 => 'Breeze',
	3 => 'Fruit',
	4 => 'Harvest',
	5 => 'Vintage',
	6 => 'Frost',
	7 => 'Snow',
	8 => 'Ice',
	9 => 'Thaw',
	10 => 'Seedtime',
	11 => 'Blossom' };

    $mon = $q*3+$mon;
    
    return sprintf("%s %d, %d WK (%02d/%02d/%03d)",
		   $mmap->{$mon}, $mday, $year,
		   $mday, $mon+1, $year);
}

# ----------------------------------------------------------------------
#
# GameProcess
#
# Returns reference to hash containing the game start date and XML fragment.
#
# ----------------------------------------------------------------------

sub GameProcess {
    my ($in, $out) = @_;

    my $name = $in->{"name"};
    if (!$name)
    {
	print STDERR "<game> must have a <name>.\n";
	return undef;
    }

    my $start = $in->{"start_date"};
    if (!$start)
    {
	printf(STDERR "<game '%s'> must have a <start-date>.\n", $name);
	return undef;
    }

    my $end = $in->{"end_date"};
    if (!$end)
    {
	printf(STDERR "<game '%s'> must have a <end-date>.\n", $name);
	return undef;
    }

# --------------------
# Create hash reference
# --------------------

    my $game = {};
    $game->{name} = $name;
    $game->{'start'} = new Tick($start);
    $game->{'end'} =  new Tick($end);
    
    if ($in->{scribe_notes} && (ref($in->{scribe_notes}) eq "HASH") && $in->{scribe_notes}->{pdf})
    {
	my $pdf = $in->{scribe_notes}->{pdf};
	$game->{scribe_notes_pdf} = $pdf if (-f $pdf);
    }

    my $div = $game->{'html'} = $out->createElement("div");
    $div->setAttribute("class", "game");
    $div->appendTextChild("h1", $name);

# --------------------
# Create game details table
# --------------------

    return $game;
    
    my $t1 = $div->appendChild($out->createElement("table"));
    my $t1_r1 = $t1->appendChild($out->createElement("tr"));
    $t1_r1->appendTextChild("th", "Start Date:");
    $t1_r1->appendTextChild("td", Epoch2Date($game->{'start'}));
    $t1_r1->appendTextChild("th", "Finish Date:");
    $t1_r1->appendTextChild("td", Epoch2Date($game->{'end'}));
    $t1_r1->appendTextChild("th", "Duration:");
    $t1_r1->appendTextChild("td", EpochDiff($game->{'start'}, $game->{'end'}));

    my $ul1 = $div->appendChild($out->createElement("ul"));
    if (my $s = $in->find("scribe-notes"))
    {
	my $ul1_li1 = $ul1->appendChild($out->createElement("li"));
	$ul1_li1->appendTextChild("strong", "Scribe Notes: ");
	my $ul1_li1_a = $ul1_li1->appendChild($out->createElement("a"));
	$ul1_li1_a->appendText($s);
	$ul1_li1_a->setAttribute("href", $s);
    }

    if (my $g = $in->find("gm-notes"))
    {
	my $ul1_li1 = $ul1->appendChild($out->createElement("li"));
	$ul1_li1->appendTextChild("strong", "GM Notes: ");
	my $ul1_li1_a = $ul1_li1->appendChild($out->createElement("a"));
	$ul1_li1_a->appendText($g);
	$ul1_li1_a->setAttribute("href", $g);
    }

# --------------------
# Create pc table
# --------------------

    my $t2 = $div->appendChild($out->createElement("table"));
    $t2->setAttribute("class", "pc");

    for my $pc ($in->findnodes("pc"))
    {
	my $tr = $t2->appendChild($out->createElement("tr"));
	$tr->appendTextChild("td", $pc->find("string(.)"));
	my $td_ep = $tr->appendChild($out->createElement("td"));
	$td_ep->setAttribute("class", "r");
	$td_ep->appendText($pc->hasAttribute("ep") ? $pc->getAttribute("ep") : "");
    }

    return $game;
}

# ----------------------------------------------------------------------
#
# Main
#
# ----------------------------------------------------------------------

sub Main {

# --------------------
# Define input and output docs
# --------------------

    my $html_doc = XML::LibXML::Document->new("1.0", "utf8");
    
    my $yaml = LoadFile("games.yaml");
    
    print "HTML: <head>\n";

# --------------------
# Construct HTML headers and body container
# --------------------
    my $html_root = $html_doc->createElement("html");
    $html_doc->setDocumentElement($html_root);
    $html_doc->createInternalSubset("html", "-//W3C//DTD HTML 4.01//EN", "http://www.w3.org/TR/html4/strict.dtd");

# --------------------
# Create head and children
# --------------------

    my $head = $html_root->appendChild($html_doc->createElement("head"));
    $head->appendTextChild("title", "Recent DQ Games");
    my $link = $head->appendChild($html_doc->createElement("link"));
    $link->setAttribute("rel", "stylesheet");
    $link->setAttribute("type", "text/css");
    $link->setAttribute("href", "games.css");

    print "HTML: <body>\n";
    my @games;

    for my $game (@{$yaml->{games}})
    {
	my $ref = &GameProcess($game, $html_doc);
	push(@games, $ref) if (defined $ref);
    }

    my $body = $html_root->appendChild($html_doc->createElement("body"));
    my $table = $body->addNewChild("", "table");
    $table->setAttribute("class", "games");
    
    map {
	printf "Game: %s", $_->{name};

	my $tr = $table->addNewChild("", "tr");
	my $td_name = $tr->appendTextChild("td", $_->{name});
	my $td_start = $tr->appendTextChild("td", $_->{start}->CDate());
	my $td_end = $tr->appendTextChild("td", $_->{end}->CDate());
	my $td_pdf = $tr->addNewChild("", "td");
	if ($_->{scribe_notes_pdf})
	{
	    my $a = $td_pdf->addNewChild("", "a");
	    $a->appendText("Scribe Notes");
	    $a->setAttribute("href", $_->{scribe_notes_pdf});
	    printf(" [%s]", $_->{scribe_notes_pdf});	    
	}
	printf("\n");
#	$body->appendChild($_->{"html"});
    } sort {$a->{'start'}->tick() <=> $b->{'start'}->tick()} @games;

    print "HTML: </html>\n";
    $html_doc->toFile("games.htm", 1);
}

&Main();
