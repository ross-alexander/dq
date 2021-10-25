#!/usr/bin/perl

open(IN, "calender.txt");
my @text = <IN>;
close(IN);


print "{| style=\"border-collapse:collapse;\"\n";

my $cnt = 0;
my @cols = ("skyblue", "lime");

map {
    chomp $_;
    if (/^\#/ || (length($_) == 0))
    {
    }
    elsif (/^\!/)
    {
	my $t = $_;
	$t =~ s/^\![ ]+//;

	print "|- style=\"height:30pt;\"\n";
	my @bits = split(/\t/, $_);
	map {
	    printf "! style=\"background:blue;\" | %s\n", $_;
	} @bits;
    }
    else
    {
	print "|-\n";
	my @bits;
	if (/^\t/)
	{
	    $_ =~ s/^\t+//;
	    @bits = ("", "", $_);
	}
	else
	{
	    $cnt++;
	    @bits = split(/\t+/, $_);
	    push(@bits, "") if (scalar(@bits) == 2);
	}
	my $c = $cols[$cnt % scalar(@cols)];
	map {
	    printf "| style=\"padding-left:5pt;padding-right:5pt;border-bottom:1pt solid black;background:%s;\" | %s\n", $c, $_;
	} @bits;
    }
} @text;
print "|}\n";
