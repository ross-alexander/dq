#!/usr/bin/perl

use XML::LibXML;

sub TeXFileProcess {
    my ($doc, $filename) = @_;

    my $dq = $doc->getDocumentElement();

    open(IN, "$filename") || return 0;

    my $college = undef;
    my $section = undef;
    my $entry = undef;

    my ($ta, $gs, $gr, $ss, $sr);

    while(<IN>)
    {
	chomp $_;
	if(/\\begin{college}\[([0-9]+\.[0-9]+)\]\{([a-z]+)\}\{([A-Za-z ]+)\}\{([A-Z]+)\}/)
	{
	    $college = $doc->createElement("college");
	    $college->setAttribute("abbrev", $4);
	    $college->setAttribute("short", $2);
	    $college->setAttribute("long", $3);
	    $college->setAttribute("version", $1);
	    $dq->appendChild($college);

	    $ta = $doc->createElement("talents");
	    $gs = $doc->createElement("general-spells");
	    $gr = $doc->createElement("general-rituals");
	    $ss = $doc->createElement("special-spells");
	    $sr = $doc->createElement("special-rituals");

	    $college->appendChild($ta);
	    $college->appendChild($gs);
	    $college->appendChild($gr);
	    $college->appendChild($ss);
	    $college->appendChild($sr);

	}
	if (defined $college)
	{
	    if (/\\subsection{Talents}/)
	    {
		$section = $ta;
	    }
	    if (/\\subsection{General Knowledge Spells}/)
	    {
		$section = $gs;
	    }
	    if (/\\subsection{Special Knowledge Spells}/)
	    {
		$section = $ss;
	    }
	    if (/\\subsection{General Knowledge Rituals}/)
	    {
		$section = $gr;
	    }
	    if (/\\subsection{Special Knowledge Rituals}/)
	    {
		$section = $sr;
	    }
	    if (defined ($section))
		{
		    if (/\\begin{talent}\[(T-[0-9]+)\]\{([A-Za-z\/\' ]+)\}/)
		    {
			my $talent = $doc->createElement("talent");
			$talent->setAttribute("abbrev", $1);
			$talent->setAttribute("name", $2);
			$section->appendChild($talent);
			$entry = $talent;
		    }
		    if (/\\begin{spell}\[([GS]-[0-9]+)\]\{([A-Za-z\/\' ]+)\}/)
		    {
			my $spell = $doc->createElement("spell");
			$spell->setAttribute("abbrev", $1);
			$spell->setAttribute("name", $2);
			$section->appendChild($spell);
			$entry = $spell;
		    }
		    if (/\\begin{ritual}\[([QR]-[0-9]+)\]\{([A-Za-z\/\' ]+)\}/)
		    {
			my $ritual = $doc->createElement("ritual");
			$ritual->setAttribute("abbrev", $1);
			$ritual->setAttribute("name", $2);
			$section->appendChild($ritual);
			$entry = $ritual;
		    }
		}
	    if (defined($entry))
	    {
		if (m:\\range{([A-Za-z0-9/ +]+)}:)
		{
		    my $range = $doc->createElement("range");
		    $range->appendTextNode($1);
		    $entry->appendChild($range);
		}
		if (m:\\basechance{([A-Za-z0-9/\\% +]+)}:)
		{
		    my $t = $1;
		    $t =~ s:\\x:*:g;
		    $t =~ s:\\%::g;
		    my $bc = $doc->createElement("bc");
		    $bc->appendTextNode($t);
		    $entry->appendChild($bc);
		    $t =~ s: ::g;
		    my ($base, $rank) = split(/\+/, $t);
		    $bc->setAttribute("base", $base) if (length($base));
		    $rank =~ s:/Rank::;
		    $bc->setAttribute("rank", $rank) if (length($rank));
		}
		if (m:\\multiple{([A-Za-z0-9/ +]+)}:)
		{
		    my $multiple = $doc->createElement("multiple");
		    $multiple->appendTextNode($1);
		    $entry->appendChild($multiple);
		}
	    }
	}
    }
    close(IN);
}


my $doc = XML::LibXML::Document->new("1.0", "iso-8859-1");
my $root = $doc->createElement("dq");
$doc->setDocumentElement($root);

map {
    &TeXFileProcess($doc, $_);
} @ARGV;

my $namer = $root->findnodes('college[@abbrev="NA"]/general-spells')->[0];

for my $c ($root->findnodes("college"))
{
    print $c->getAttribute("long"), "\n";

    my $a = $c->getAttribute("abbrev");
    my $s = ucfirst($c->getAttribute("short"));

    my $gs = $c->findnodes("general-spells")->[0];

    my $gcs = $doc->createElement("spell");
    $gcs->setAttribute("abbrev", "G-GC");
    $gcs->setAttribute("name", "$s General Counterspell");
    my $gcsbc = $doc->createElement("bc");
    $gcsbc->appendTextNode("40");
    $gcs->appendChild($gcsbc);

    my $scs = $doc->createElement("spell");
    $scs->setAttribute("abbrev", "G-SC");
    $scs->setAttribute("name", "$s Special Counterspell");
    my $scsbc = $doc->createElement("bc");
    $scsbc->appendTextNode("40");
    $scs->appendChild($scsbc);

    $gs->appendChild($gcs);
    $gs->appendChild($scs);

    if (defined $namer)
    {
	my $na_gcs = $gcs->cloneNode(1);
	$na_gcs->setAttribute("college", $a);
	my $na_scs = $scs->cloneNode(1);
	$na_scs->setAttribute("college", $a);

	$namer->appendChild($na_gcs);
	$namer->appendChild($na_scs);
    }
}

$doc->toFile("spells.xml", 1);
