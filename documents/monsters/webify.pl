#!/usr/bin/perl

use XML::LibXML;

# ----------------------------------------------------------------------
#
# ReadXmlFile
#
# ----------------------------------------------------------------------
sub ReadXmlFile {
    my ($parser, $filename) = @_;
    my $doc = $parser->parse_file($filename);
    return undef if (!defined($doc));

    my $root = $doc->getDocumentElement();
    return undef if (($root->getName() ne "dqmm") && ($root->getName() ne "demons"));

    my $dqmm = {};
    $dqmm->{"filename"} = $filename;
    $dqmm->{"doc"} = $doc;
    $dqmm->{"root"} = $root;
    return $dqmm;
}

# ----------------------------------------------------------------------
#
# BuildIndexMonsters
#
# ----------------------------------------------------------------------
sub BuildIndexMonsters {
    my ($obj, $parent) = @_;
    my @monsters = $obj->find("monster")->get_nodelist();

    return if (scalar(@monsters) == 0);

    my $ol = $parent->appendChild(XML::LibXML::Element->new("ol"));

    for my $i (0 .. $#monsters)
    {
	my $name = $monsters[$i]->getAttribute("name");
	$ol->appendTextChild("li", $name);
    } 
}

# ----------------------------------------------------------------------
#
# BuildIndexDemons
#
# ----------------------------------------------------------------------
sub BuildIndexDemons {
    my ($obj, $parent) = @_;
    my @monsters = $obj->find("demon")->get_nodelist();

    return if (scalar(@monsters) == 0);

    my $ol = $parent->appendChild(XML::LibXML::Element->new("ol"));

    for my $i (0 .. $#monsters)
    {
	my $name = $monsters[$i]->getAttribute("name");
	my $title = $monsters[$i]->getAttribute("title");
	$ol->appendTextChild("li", "$name \"$title\"");
    } 
}

# ----------------------------------------------------------------------
#
# BuildIndex
#
# ----------------------------------------------------------------------

sub BuildIndex {
    my ($obj, $ol) = @_;
    my @monsters = $obj->{"root"}->find("group")->get_nodelist();

# All files have exactly one DQMM node (since it is the root element).
# Monsters are split into groups and then classes.  However, not all
# groups have classes.

    for my $tmp (@monsters)
    {
	my $name = $tmp->getAttribute("name");

	my $file = lc($name) . ".htm";
	$file =~ tr/[ ,]/_/;

	my $li = $ol->appendChild(XML::LibXML::Element->new("li"));
	my $anchor = $li->appendChild(XML::LibXML::Element->new("a"));
	$anchor->appendText($name);
	$anchor->setAttribute("href", "$file");

	my @classes = $tmp->find("class")->get_nodelist();
	if (scalar(@classes))
	{
	    my $ol_class = $li->appendChild(XML::LibXML::Element->new("ol"));
	    for my $i (0 .. $#classes)
	    {
		my $name = $classes[$i]->getAttribute("name");
		my $li_class = $ol_class->appendChild(XML::LibXML::Element->new("li"));
		$li_class->appendText($name);

		&BuildIndexMonsters($classes[$i], $li_class);
		&BuildIndexDemons($classes[$i], $li_class);
	    }
	}
	else
	{
	    &BuildIndexMonsters($tmp, $li);
	}
    }
}

# ----------------------------------------------------------------------
#
# ProcessMonster
#
# ----------------------------------------------------------------------
sub ProcessMonster {
    my ($parser, $root, $node) = @_;

    my $div = $root->appendChild(XML::LibXML::Element->new("div"));

    my $name = $node->getAttribute("name");
    $name = ($name . " \"" . $node->getAttribute("title") . "\"") if
	($node->hasAttribute("title"));
    my $h2 = $div->appendTextChild("h3", $name);

    my $dl = $div->appendChild(XML::LibXML::Element->new("dl"));
    my $stats = undef;
    for my $i ($node->childNodes)
    {
	if ($i->getName() eq "stats")
	{
	    $stats = $i;
	    next;
	}
	my $dt = $dl->appendChild(XML::LibXML::Element->new("dt"));
	my $strong = XML::LibXML::Element->new("strong");
	$strong->appendText(ucfirst($i->getName) . ":");
	$dt->appendChild($strong);
	$dt->appendText($i->textContent);
    }
    my $table = $div->appendChild(XML::LibXML::Element->new("table"));
    my $tr = $table->appendChild(XML::LibXML::Element->new("tr"));
    if (defined $stats)
    {
	for my $i ($stats->childNodes)
	{
	    my $td = $tr->appendChild(XML::LibXML::Element->new("td"));
	    my $strong = XML::LibXML::Element->new("strong");
	    $strong->appendText(ucfirst($i->getName) . ":");
	    $td->appendChild($strong);
	    $td->appendText($i->textContent);
	}
    }
}

# ----------------------------------------------------------------------
#
# ProcessNode
#
# ----------------------------------------------------------------------
sub ProcessNode {
    my ($parser, $root, $node) = @_;

# The copy of the notes text is done by converting to a string and
# then back.  It may be better to do this by cloning the <notes> node.
# This way any imbedded tags will get copied.

    if ($node->getName() eq "notes")
    {
	my $p = $node->cloneNode(1);
	$p->setNodeName("p");
	$root->appendChild($p);
    }
# If there are any classes then add them as <h2> headers.
    
    if ($node->getName() eq "class")
    {
	my $h2 = $root->appendTextChild("h2", $node->getAttribute("name"));
	for my $tmp ($node->childNodes)
	{
	    &ProcessNode($parser, $root, $tmp);
	}
    }
    &ProcessMonster($parser, $root, $node) if ($node->getName() eq "monster");
    &ProcessMonster($parser, $root, $node) if ($node->getName() eq "demon");
}

# ----------------------------------------------------------------------
#
# BuildIndexFiles
#
# ----------------------------------------------------------------------
sub BuildIndexFiles {
    my ($parser, $obj) = @_;

    my @group = $obj->{"root"}->find("group")->get_nodelist();
    for my $group (@group)
    {
	my $name = $group->getAttribute("name");
	my $file = lc($name) . ".htm";
	$file =~ tr/[ ,]/_/;

	my $htmldoc = $parser->parse_html_string("<html/>");
	my $htmlroot = $htmldoc->getDocumentElement();
	my $head = $htmlroot->appendChild(XML::LibXML::Element->new("head"));

	$head->appendTextChild("title", $name);
	my $link = $head->appendChild(XML::LibXML::Element->new("link"));
	$link->setAttribute("href", "dqmm.css");
	$link->setAttribute("type", "text/css");
	$link->setAttribute("rel", "stylesheet");
	
	my $body = $htmlroot->appendChild(XML::LibXML::Element->new("body"));
	$body->appendTextChild("h1", $name);

	for my $node ($group->childNodes)
	{
	    &ProcessNode($parser, $body, $node);
	}
	open(OUT, ">$file");
	print OUT $htmldoc->toString(1);
	close(OUT);
    }
}

# ----------------------------------------------------------------------
#
# CreateIndexFile
#
# This function creates the file index.htm.  This contains a full
# index and references the individual group pages.
#
# ----------------------------------------------------------------------
sub CreateIndexFile {
    my ($parser, $list) = @_;

    my $htmldoc = $parser->parse_html_string("<html/>");
    my $htmlroot = $htmldoc->getDocumentElement();
    my $head = $htmlroot->appendChild(XML::LibXML::Element->new("head"));
    
    $head->appendTextChild("title", "DragonQuest Monster Manual");
    my $link = $head->appendChild(XML::LibXML::Element->new("link"));
    $link->setAttribute("href", "dqmm.css");
    $link->setAttribute("type", "text/css");
    $link->setAttribute("rel", "stylesheet");
    
    my $body = $htmlroot->appendChild(XML::LibXML::Element->new("body"));
    my $ol = $body->appendChild(XML::LibXML::Element->new("ol"));
    
    map { &BuildIndex($_, $ol) } @{$list};
    
    open(OUT, ">index.htm");
    print OUT $htmldoc->toString(1);
    close(OUT);
}

# ----------------------------------------------------------------------
#
# M A I N
#
# ----------------------------------------------------------------------

# Create new XML::LibXML parser object.

my $parser = XML::LibXML->new();

# Open the current directory and get a list of all .xml files.

opendir(DIR, ".") || die "Cannot open current directory.";
@files = sort(grep(/.xml$/, readdir(DIR)));
closedir(DIR);

# Process all the files to create a list of hash references.

my @manual;
for $_ (@files)
{
    my $tmp = &ReadXmlFile($parser, $_);
    push(@manual, $tmp) if (defined $tmp);
}

&CreateIndexFile($parser, \@manual);
map { &BuildIndexFiles($parser, $_) } @manual;
