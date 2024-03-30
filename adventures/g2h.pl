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

# ----------------------------------------------------------------------
#
# GameProcess
#
# Returns reference to hash containing the game start date and XML fragment.
#
# ----------------------------------------------------------------------

sub game_check_valid {
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

    $in->{'start_tick'} = new Tick($start);
    $in->{'end_tick'} =  new Tick($end);

    $in->{'valid'} = 1;
    return $in;

# --------------------
# Create game details table
# --------------------

    my $game = {};
    my $div = $game->{'html'} = $out->createElement("div");
    $div->setAttribute("class", "game");
    $div->appendTextChild("h1", $name);

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
# html_table_create
#
# ----------------------------------------------------------------------

sub html_table_create {
    my ($games) = @_;

    my $html_doc = XML::LibXML::Document->new("1.0", "utf8");

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

    my $body = $html_root->appendChild($html_doc->createElement("body"));
    my $table = $body->addNewChild("", "table");
    $table->setAttribute("class", "games");
    
    my $tr_h1 = $table->addNewChild("", "tr");
    $tr_h1->appendTextChild("th", "Game");
    $tr_h1->appendTextChild("th", "Start");
    $tr_h1->appendTextChild("th", "Finish");
    $tr_h1->appendTextChild("th", "Scribe Notes");
    $tr_h1->appendTextChild("th", "EP");
    $tr_h1->appendTextChild("th", "Items");
    $tr_h1->appendTextChild("th", "GM Notes");
        
    map {
	printf "Game: %s", $_->{name};

	my $tr = $table->addNewChild("", "tr");
	my $td_name = $tr->appendTextChild("td", $_->{name});
	my $td_start = $tr->appendTextChild("td", $_->{start_tick}->CDate());
	my $td_end = $tr->appendTextChild("td", $_->{end_tick}->CDate());

	for my $t ("scribe_notes", "ep_notes", "item_notes", "gm_notes")
	{
	    my $td = $tr->addNewChild("", "td");
	    my $break = 0;
	    for my $f ("md", "tex", "pdf")
	    {
		if (exists($_->{$t}) && (ref($_->{$t}) eq "HASH") && exists($_->{$t}->{$f}))
		{
		    my $path = $_->{$t}->{$f};
		    if (-f $path)
		    {
			$td->appendText(" | ") if ($break);
			my $a = $td->addNewChild("", "a");
			$a->appendText(uc($f));
			$a->setAttribute("href", $path);
			$break = 1;
			printf(" [%s]", $path);
		    }
		}
	    }
	}
	printf("\n");
#	$body->appendChild($_->{"html"});
    } sort {$a->{'start_tick'}->tick() <=> $b->{'start_tick'}->tick()} @$games;

    $html_doc->toFile("games.html", 1);
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

    
    my $yaml = LoadFile("games.yaml");
    my @games;
    for my $game (@{$yaml->{games}})
    {
	my $ref = &game_check_valid($game);
	push(@games, $ref) if (defined $ref);
    }
    html_table_create(\@games);
}

&Main();
