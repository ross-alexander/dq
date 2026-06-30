#!/usr/bin/python3

# ----------------------------------------------------------------------
#
# Create PDF calendar via LuaLaTeX and tabularray.
#
# ----------------------------------------------------------------------

import os
import sys
import json
import argparse
from dqtick import Tick

def day_content(day):
    if day['empty']:
        return ' & '
    parts = ['', '']
    if 'calendar' in day:
        names = [i['name'] for i in day['calendar']['track'].values()]
        parts[1] = "{%s}" % "\\\\".join(names)
    parts[0] = str(day['day'])
    return " & ".join(parts)


def cal_tex(opts, src, dst):

    with open(src, "r") as stream:
        result = json.load(stream)

    res = []
    res.append('\\documentclass{article}')
    res.append('\\usepackage{dqcal}')
    res.append('\\begin{document}')

    moons = ['full', 'waning', 'new', 'waxing']

    for year in result:
        for month in year['months']:
            res.append('\\begin{caltblr}{}')
            day_map = {}
            tick = Tick(month['tick'])
            s = tick.struct()
            res.append(f"{s['month_name']} {s['year']}\\\\")
            table = []
            for week in range(0, 5):
                table.insert(week, [])
                for day in range(0, 7):
                    table[week].insert(day, {'empty':True})

            for day in range(month['start'], month['end']+1):
                week_day = day + month['week_day'] - (0 if month['start'] == 0 else 1)
                week = int(week_day/7)
                day_ref = table[week][week_day%7] = {'empty':False, 'day':day}
                day_map[int(day)] = day_ref

            for week in month['weeks']:
                for day in week['days']:
                    day_map[int(day['day'])]['calendar'] = day
            
            for week in table:
                days = [day_content(x) for x in week]
                res.append(' & '.join(days))
                res.append('\\\\')
            res.append('\\end{caltblr}')
            res.append('')
            res.append('\\bigskip')
            res.append('')

    res.append('\\end{document}')
    with open(dst, "w") as stream:
        print("\n".join(res), file=stream)


# ----------------------------------------------------------------------
#
# M A I N
#
# ----------------------------------------------------------------------

opts = {}

parser = argparse.ArgumentParser(description='Format character calendar file to LuaLaTeX')
parser.add_argument("-i", "--in", action='store', type=str, required=True, help="Input file", dest="inpath")
parser.add_argument("-o", "--out", action='store', type=str, required=True, help="Output file", dest="outpath")
args = parser.parse_args()

cal_tex(opts, args.inpath, args.outpath)
