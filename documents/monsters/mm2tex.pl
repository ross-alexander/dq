#!/usr/local/bin/perl

$tmpfile = "perl.tmp.$$";

sub Monster() {
    if (length($monster{habitat}) ||
	length($monster{frequency}) ||
	length($monster{number}) ||
	length($monster{talents}) ||
	length($monster{movement}))
    {
	print OUT "\\begin{description}\n";
	print OUT "\\setlength\\itemsep{0pt}\n";
	if (length($monster{habitat})) {
	    print OUT "\\item[Habibat] $monster{habitat}\n";
	    $monster{habitat} = "";
	} 
	if (length($monster{freq})) {
	    print OUT "\\item[Frequency] $monster{freq}\n";
	    $monster{frequency} = "";
	}
	if (length($monster{number})) {
	    print OUT "\\item[Number] $monster{number}\n";
	    $monster{number} = "";
	}
	if (length($monster{desc})) {
	    print OUT "\\item[Description] $monster{desc}\n";
	    $monster{description} = "";
	}
	if (length($monster{talents})) {
	    print OUT "\\item[Talents, Skills, and Magic] $monster{talents}\n";
	    $monster{talents} = "";
	}
	
	if (length($monster{movement})) {
	    print OUT "\\item[Movement] $monster{movement}\n";
	    $monster{movement} = "";
	}
	print OUT "\\end{description}\n";
    }
    print OUT "{\\small\n";
    print OUT "\\begin{tabularx}{\\linewidth}{\@{}X\@{\\hspace{0.5em}}X\@{\\hspace{0.5em}}X\@{\\hspace{0.5em}}X\@{}}\n";
    print OUT "\\textbf{PS}: $monster{PS} & "; $monster{PS} = "";
    print OUT "\\textbf{MD}: $monster{MD} & "; $monster{MD} = "";
    print OUT "\\textbf{AG}: $monster{AG} & "; $monster{AG} = "";
    print OUT "\\textbf{MA}: $monster{MA} \\\\\n"; $monster{MA} = "";
    print OUT "\\textbf{EN}: $monster{EN} & "; $monster{EN} = "";
    print OUT "\\textbf{FT}: $monster{FT} &"; $monster{FT} = "";
    print OUT "\\textbf{WP}: $monster{WP} & "; $monster{WP} = "";
    print OUT "\\textbf{PC}: $monster{PC} \\\\\n "; $monster{PC} = "";
    print OUT "\\textbf{PB}: $monster{PB} &"; $monster{PB} = "";
    print OUT "\\textbf{TMR}: $monster{TMR} & "; $monster{TMR} = "";
    print OUT "\\multicolumn{2}{\@{}l\@{}}{\\textbf{NA}: $monster{NA}} \\\\\n"; $monster{NA} = "";
    print OUT "\\end{tabularx}}\n";
    
    
    print OUT "\\begin{description}\n";
    if (length($monster{weapons})) {
	print OUT "\\item[Weapons] $monster{weapons}\n";
	$monster{weapons} = "";
    }
    if (length($monster{comments})) {
	print OUT "\\item[Comments] $monster{comments}\n";
	$monster{comments} = "";
    }
    print OUT "\\end{description}\n";
}

while(@ARGV) {
    $file = shift @ARGV;
    open(IN, $file);
    open(OUT, ">$tmpfile");

    while (<IN>)
    {
	s/<![^>]*>//;
	s/\&/\\&/;
	s/\%/\\%/;
	s/<itemize>/\begin{itemize}/;
	s/<\\itemize>/\end{itemize}/;
	s/<item>/\item/;
	s/<notes>//;	
	if (/^<group>.*/) {
	    s/^<group>//;
	    chop;
	    print OUT "\\section{", $_, "}\n\\begin{multicols}{2}\n";
	    print OUT "\\setlength\\columnseprule{0.4mm}\n";
	}
	elsif (/^<class>(.*)/) {
	    print OUT "\\subsection{", $1, "}\n";
	}
	elsif (/<\/group>/) {
	    print OUT "\\end{multicols}\n";
	}
	elsif (/^<monster>.*/)
	{
	    s/^<monster>//;
	    chop;
	    print OUT "\\subsubsection{", $_, "}\n\n";
	    $blk = "";
	    $cur = "";
	    while (<IN>) {
		s/\&/\\&/;
		s/\%/\\%/;
		s/<itemize>/\\begin{itemize}/;
		s/<\/itemize>/\\end{itemize}/;
		s/<item>/\\item/;
		if (/<\/monster>/)
		{
		    if($cur) {
			$tmp = $blk;
			$tmp =~ s/\n/ /g;
			$tmp =~ s/[ ]+$//g;
			$monster{$cur} = "$tmp\n";
		    }
		    &Monster;
		    last;
		}
		elsif (/^<(.*)>/)
		{
		    $tmp = $blk;
		    $new = $1;
		    $blk = $';
		    $tmp =~ s/[ \n]+$//g;
		    if($cur) {
			$monster{$cur} = $tmp;
		    }
		    $cur = $new;
		}
		else {
		    $blk = "$blk $_";
		}
	    }
	}
	elsif (/^<\/.*>/) {}
	else {print OUT;}
    }
    close(IN);
    close(OUT);
    $_ = $file;
    s/\..*$/.tex/;
    rename("$tmpfile", $_);
}
