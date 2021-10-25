#!/usr/bin/perl


sub Month {
    my ($text, $year, $landscape) = @_;
    my @week;

    $text->[0] =~ m:(Month)\t([0-9]+)\t([0-9]+)\t([0-9]+)\t([0-9]+):;

    my $mon_mon = $2;
    my $mon_start = $3;
    my $mon_end = $4;
    my $mon_wday = $5;
    my $mon_days = $4 - $3 + 1;
    my $mon_asize = $mon_days + $mon_wday;
    $mon_asize += (7 - $mon_asize%7)%7;

    my $boxsize = $landscape ? "35mm" : "30mm";

# --------------------
# Create structure
# --------------------

    my @month;
    for my $i (0 .. $mon_asize - 1)
    {
	$month[$i] = "\\parbox[c]{$boxsize}{\\hfill \\vspace{2em}}";
    }

    shift(@$text);

    my @daylist;

    while(scalar(@$text) && ($text->[0] =~ /^Day/))
    {
	my $line = $text->[0];
	chomp $line;
	push(@daylist, $line);
	shift(@$text);
    }

    for my $line (@daylist)
    {
	my (@bits) = split(/\t/, $line);
	my ($segnam, $day, $wday, $title) = @bits;
	my (@boxbits) = ("\\vspace{1mm} {\\hfill \\small $title \\hfill}");
	my $i = 4;

	while ($i < $#bits)
	{
	    my $tmp = sprintf("\$^%d\$ %s", $bits[$i], $bits[$i+1]);
	    push(@boxbits, $tmp);
	    $i += 2;
	}
	push(@boxbits);
	my $cell = sprintf("\\parbox[c]{$boxsize}{%s \\vspace{1mm}}", join(" \\\\ ", @boxbits));
	$week[$wday] = $cell;

# --------------------
# Set month entry
# --------------------

	$month[$day - $mon_start + $mon_wday] = $cell;
    }

# --------------------
# Use month to check result
# --------------------

    if ($landscape)
    {
	printf("\\noindent \\begin{tabular}{|l|l|l|l|l|l|l|} \\hline\n");
	printf("\\multicolumn{7}{|c|}{\\textbf{%d %d}} \\\\ \\hline\n", $mon_mon + 1, $year + 770);
	for my $j (0 .. $mon_asize - 1)
	{
	    printf("%s %s\n", $month[$j], ($j+1) % 7 ? " &" : " \\\\ \\hline");
	}
	printf("\\end{tabular}\n\n\\bigskip\n\n");
    }
    else
    {
	my $k = scalar(@month) / 7;
	printf("\\noindent \\begin{tabular}{|%s} \\hline\n", "l|" x $k);
	for my $j (0 .. 6)
	{
	    for my $i (0 .. $k-1)
	    {
		print $month[$i * 7 + $j];
		print $i == $k-1 ? "\\\\ \\hline" : " &";
		print "\n";
	    }
	}
	printf("\\end{tabular}\n\n\\bigskip\n\n");
    }
    return;
}

my $landscape = 1;
if ($landscape)
{
    printf("\\documentclass[a4paper,landscape]{article}\n");
}
else
{
    printf("\\documentclass[a4paper]{article}\n");
}
printf("\\usepackage{tabularx}\n");
printf("\\usepackage[dvips]{geometry}\n");
if ($landscape)
{
    printf("\\addtolength\\textwidth{80mm}\n");
    printf("\\addtolength\\oddsidemargin{-40mm}\n");
    printf("\\addtolength\\evensidemargin{-40mm}\n");
}
else
{
    printf("\\addtolength\\textwidth{60mm}\n");
    printf("\\addtolength\\oddsidemargin{-20mm}\n");
    printf("\\addtolength\\evensidemargin{-20mm}\n")
}
printf("\\addtolength\\textheight{40mm}\n");
printf("\\addtolength\\topmargin{-20mm}\n");

printf("\\renewcommand{\\rmdefault}{ptm}\n");
printf("\\renewcommand{\\sfdefault}{phv}\n");
printf("\\renewcommand{\\scriptsize}{\\fontencoding{T1}\\fontfamily{\\rmdefault}\\fontsize{6}{7pt}\\selectfont}\n");
printf("\\renewcommand{\\small}{\\fontencoding{T1}\\fontfamily{\\sfdefault}\\fontsize{5}{6pt}\\selectfont}\n");
printf("\\renewcommand{\\normalsize}{\\fontencoding{T1}\\fontfamily{\\sfdefault}\\fontsize{7}{8.0pt}\\selectfont}\n");

printf("\\begin{document}\n\n");
# printf("\\renewcommand{\\arraystretch}{2.0}\n");

my @text = <>;

while(scalar(@text))
{
    $_ = $text[0];
    if (/^Year\t([0-9]+)/)
    {
	$year = $1;
    }
    if (/^Month/)
    {
	&Month(\@text, $year, $landscape);
    }
    else
    {
	shift(@text);
    }
}

printf("\\end{document}\n");
