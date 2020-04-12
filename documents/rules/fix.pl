while(<>)
{
    s/G([0-9]+)\.( |\t)+(.*)/\\begin{spell}[G-$1]{$3}/;
    s/S([0-9]+)\.( |\t)+(.*)/\\begin{spell}[S-$1]{$3}/;
    s/Q([0-9]+)\.( |\t)+(.*)/\\begin{ritual}[Q-$1]{$3}/;
    s/^Range: (.*)/\\range{$1}/;
    s/^Experience multiple: (.*)/\\multiple{$1}/i;
    s/^Base Chance: (.*)/\\basechance{$1}/i;
    s/^Resist: (.*)/\\resist{$1}/i;
    s/^Target: (.*)/\\target{$1}/i;
    s/^Storage: (.*)/\\storage{$1}/i;
    s/^Duration: (.*)/\\duration{$1}/i;
    print $_;
}
