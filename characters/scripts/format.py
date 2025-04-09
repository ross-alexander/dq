#!/usr/bin/python

import os
import sys
from yaml import load, CLoader as Loader

# ----------------------------------------------------------------------
#
# cal_cdate
#
# Code taken from Tick.pm but fix handling of old AP dates
#
# ----------------------------------------------------------------------

def cal_struct(c):
    tick = c['tick']
    if c['calendar'] == 'WK':
        year = int(tick/364)
        tick = tick - year * 364
        quarter = int(tick/91)
        tick = tick - quarter * 91
        month = quarter*3 + int((tick-1)/30)
        day = tick - (month%3)*30
        res = {
            'calendar': c['calendar'],
            'year': year + 770,
            'month': month+1,
            'day': day,
        }
    if c['calendar'] == 'AP':
        tick = tick - 273
        year = int(tick/364)
        tick = tick - year*364
        month_day = (0, 31, 59, 89, 120, 151, 181, 212, 243, 273, 304, 334)
        for m in range(0, 12):
            if tick >= month_day[11 - m]:
                month = 11 - m
                break
        day = tick - month_day[month]
        res = {
            'calendar': c['calendar'],
            'year': year + 1970,
            'month': month+1,
            'day': day+1
        }
    return res

def cal_mdate(c):
    sep = "."
    struct = cal_struct(c)
    return "%s%s%s%s%s %s" % (struct['day'], sep, struct['month'], sep, struct['year'], struct['calendar'])
            
def cal_cdate(c):
    tick = c['tick']
    if c['calendar'] == 'WK':
        year = int(tick/364)
        tick = tick - year * 364
        quarter = int(tick/91)
        tick = tick - quarter * 91
        month = quarter*3 + int((tick-1)/30)
        day = tick - (month%3)*30
        if day == 0:
            inter_cal_days = ('Beltane', 'Lugnasad', 'Samhain', 'Candlemansa')
            res = "%s %d WK" % (inter_cal_days[quarter], year + 770)
        else:
            months = ('Meadow', 'Heat', 'Breeze', 'Fruit', 'Harvest', 'Vintage', 'Frost', 'Snow', 'Ice', 'Thaw', 'Seedtime', 'Blossom');
            res = "%s %d %d WK" % (months[month], day, year + 770);
    if c['calendar'] == 'AP':
        tick = tick - 273
        year = int(tick/364)
        tick = tick - year*364
        month_day = (0, 31, 59, 89, 120, 151, 181, 212, 243, 273, 304, 334)
        for m in range(0, 12):
            print(f"^ {m} {month_day[11 - m]}")
            if tick >= month_day[11 - m]:
                month = 11 - m
                break
        day = tick - month_day[month]
        month_name = ('January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December')
        res = "%s %d, %d AP" % (month_name[month], day+1, year + 1970)
    return res


# ----------------------------------------------------------------------
#
# format_adventure
#
# ----------------------------------------------------------------------

def format_adventure(opts, adventure):
    name = adventure['name']
    res = ['% ----------------------------------------------------------------------',
           '%',
           '%% %s' % name,
           '%',
           '% ----------------------------------------------------------------------',
           '',
           '\\begin{adventure}{%s}{%s [%s]}{%s [%s]}' % (adventure['name'],
                                                         cal_cdate(adventure['start_tick']),
                                                         cal_mdate(adventure['start_tick']),
                                                         cal_cdate(adventure['end_tick']),
                                                         cal_mdate(adventure['end_tick'])),
           '']
    if 'ranking' in adventure:
        for ranking in adventure['ranking']:
            start = ranking['start_tick']
            end = ranking['end_tick']
            dates = "%s -- %s" % (cal_cdate(start), cal_cdate(end)) if end['tick'] > start['tick'] else "%s" % (cal_cdate(start))
            res.extend(['\\begin{ranking}{%s}{%s}' % (ranking['description'], dates)])
            for b in ranking['blocks']:
                for line in b['lines']:
                    name = line['name']
                    rank_range = ""
                    if 'initial' in line:
                        rank_range = f"{line['initial']} $\\ldots$ {line['final']}" if 'final' in line else f"{line['initial']}"
                    sum = line['sum'] if 'sum' in line else ''
                    em = line['em'] if 'em' in line else ''
                    raw = line['ep_raw'] if 'ep_raw' in line else ''
                    ep = line['ep'] if 'ep' in line else ''
                    time = "%s$^%s$" % (line['time'], line['track']) if 'time' in line else ''
                    cost = line['cost'] if 'cost' in line else ''
                    res.append(f"{name}\t& {rank_range}\t& {sum}\t& {em}\t& {raw}\t& {ep}\t& {time}\t& {cost} \\\\")
                    print(line)
            res.extend(['\\end{ranking}', ''])
    res.extend(['\\end{adventure}', ''])
    return res

# ----------------------------------------------------------------------
#
# format_document
#
# ----------------------------------------------------------------------

def format_document(opts, ranking):
    res = ['\\documentclass{article}', '', '\\RequirePackage{ranking-v2}', '', '\\begin{document}', '']

    basics = ranking['basics']
    print(basics)
    
    res.extend(['\\character[name=%s,fullname=%s,date=%s]' % (basics['charname'], basics['fullname'], cal_cdate(basics['tick'])), ''])
    
    [res.extend(format_adventure(opts, a)) for a in ranking['adventures']]
    res.extend(['\\end{document}', ''])
    return "\n".join(res)


# ----------------------------------------------------------------------
#
# format_yaml
#
# ----------------------------------------------------------------------

def format_yaml(opts, src_path, dst_path):
    ranking = load(open(src_path), Loader=Loader)

    if not 'adventures' in ranking:
        print(f"Key 'adventures' missing from {path}", file=sys.stderr)
        exit(1)

    res = format_document(opts, ranking)
    with open(dst_path, "w") as stream:
        stream.write(res)

opts = {}
format_yaml(opts, "../ranking/thinknottle.yaml", "thinknottle.ltx")
format_yaml(opts, "../ranking/callas.yaml", "callas.ltx")
