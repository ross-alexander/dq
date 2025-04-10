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
    struct = cal_struct(c)
    if c['calendar'] == 'WK':
        year = struct['year']
        month = struct['month'] - 1
        day = struct['day']
        if struct['day'] == 0:
            quarter = int(month/4)
            inter_cal_days = ('Beltane', 'Lugnasad', 'Samhain', 'Candlemansa')
            res = "%s %d WK" % (inter_cal_days[quarter], year)
        else:
            months = ('Meadow', 'Heat', 'Breeze', 'Fruit', 'Harvest', 'Vintage', 'Frost', 'Snow', 'Ice', 'Thaw', 'Seedtime', 'Blossom');
            res = "%s %d, %d WK" % (months[month], day, year);
    if c['calendar'] == 'AP':
        year = struct['year']
        month = struct['month'] - 1
        day = struct['day']
        month_name = ('January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December')
        res = "%s %d, %d AP" % (month_name[month], day, year)
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

    # --------------------
    # Loop over ranking
    # --------------------
    
    for ranking in (adventure['ranking'] if 'ranking' in adventure else []):
        start = ranking['start_tick']
        end = ranking['end_tick']

        # --------------------
        # Add ranking (subsection) heading
        #
        # Put tables side ranking rather than complicate the \ranking environment
        # --------------------
        
        dates = "%s -- %s" % (cal_cdate(start), cal_cdate(end)) if end['tick'] > start['tick'] else "%s" % (cal_cdate(start))
        res.extend(['\\begin{ranking}{%s}{%s}' % (ranking['description'], dates)])

        for b in ranking['blocks']:
            res.append('\\begin{blocktblr}{}')
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
            res.extend(['\\end{blocktblr}', ''])
        # --------------------
        # Add total line if required
        # --------------------
        if (ranking['ep'] or ranking['days']):
            res.extend(['\\begin{blocktblr}{cell{1}{7}{c=2}{l,font=\\rankingsf\\bfseries},cell{1}{1}={font=\\rankingsf\\bfseries}}',
                       '%s & & & & & %d & %s & ' % ('Total', ranking['ep'], ranking['time']),
                       '\\end{blocktblr}'])
        res.extend(['\\end{ranking}', ''])

    # --------------------
    # Add experience block if necessary
    # --------------------
        
    if 'experience' in adventure:
        exp = adventure['experience']
        res.append("\\experience{%d}{%d}{%d}{%d}{%s}" % (exp['gained'], exp['in'], exp['spent'], exp['out'], exp['notes']))
        
    res.extend(['\\end{adventure}', ''])
    return res

# ----------------------------------------------------------------------
#
# format_document
#
# ----------------------------------------------------------------------

def format_document(opts, ranking):
    res = ['\\documentclass{article}', '', '\\RequirePackage{ranking-v2}', '', '\\begin{document}', '']

    # --------------------
    # Get sub dictionaries
    # --------------------
    
    basics = ranking['basics']
    current = ranking['current']
    stats = current['stats']

    # --------------------
    # Set basic details with \character command
    # --------------------
    
    res.extend(['\\character[name=%s,fullname=%s,date={%s},picture={%s}]' % (basics['charname'], basics['fullname'], cal_cdate(basics['tick']), basics['picture']), ''])

    # --------------------
    # Use frontcover environment
    # --------------------

    res.extend(['\\begin{frontcover}', ''])
    
    # --------------------
    # Stats table
    # --------------------

    res.append("\\begin{stattblr}{colspec={Q[l,t,40mm]XXXXXX},")
    res.append("cell{3}{1}={c=2}{l},cell{3}{3}={c=3}{l},cell{3}{6}={c=2}{l},")
    res.append("cell{4}{2,4,6}={c=2}{l}}")
    res.append("\\textsuperscript{Name}%s &" % basics['charname'])
    res.append("\\textsuperscript{PS} %s &" % stats['PS'])
    res.append("\\textsuperscript{MD} %s &" % stats['MD'])
    res.append("\\textsuperscript{AG} %s & " % stats['AG'])
    res.append("\\textsuperscript{MA} %s & " % stats['MA'])
    res.append("\\textsuperscript{WP} %s & " % stats['WP'])
    res.append("\\textsuperscript{EN} %s \\\\" % stats['EN'])

    res.append("\\textsuperscript{Race} %s & " % basics['race'])
    res.append("\\textsuperscript{Sex} %s & " % basics['sex'])
    res.append("\\textsuperscript{HT} %s & " % basics['height'])
    res.append("\\textsuperscript{WT} %s & " % basics['weight'])
    res.append("\\textsuperscript{PB} %s & " % stats['PB'])
    res.append("\\textsuperscript{PC} %s & " % stats['PC'])
    res.append("\\textsuperscript{FT} %s \\\\" % stats['FT'])

    res.append("\\textsuperscript{Aspect}%s & & " % basics['aspect'])
    res.append("\\textsuperscript{Birth} %s & & & " % basics['birth'])
    res.append("\\textsuperscript{Date} %s & \\\\" % basics['date'])

    res.append("\\textsuperscript{S.Status} %s &" % basics['status'])
    res.append("\\textsuperscript{Hand} %s & &" % basics['hand'])
    res.append("\\textsuperscript{Coll.} %s & & " % basics['college'])
    res.append("\\textsuperscript{EP} %s [%s] & \\\\" % (basics['ep_total'], basics['ep']))
    res.append("\\end{stattblr}")


    # --------------------
    # Do the skills, weapons & spells
    # --------------------

    res.extend(['\\begin{multicols}{2}', '\\raggedcolumns', ''])

    # --------------------
    # Start skills table
    # --------------------

    skills = current['skills'] # sorted(current['skills'], key=lambda k: k['rank'])    

    res.append("\\begin{covertblr}{colspec={rX}}")
    res.append("Rk & Skill \\\\")
    for skill in skills:
        res.append('%s & %s \\\\' % (skill['rank'], skill['name']))
    res.extend(['\\end{covertblr}', ''])

    # --------------------
    # Languages
    # --------------------

    languages = current['languages'] # sorted(current['languages'], key=lambda k: k['rank'])
    
    res.append("\\begin{covertblr}{colspec={rX}}")
    res.append("Rk & Language \\\\")

    for language in languages:
        res.append('%s & %s \\\\' % (language['rank'], language['name']))
    res.extend(['\\end{covertblr}', ''])

    # --------------------
    # Weapons table
    # --------------------

    weapons = current['weapons'] # sorted(current['weapons'], key=lambda k: k['rank'])

    res.append("\\begin{covertblr}{colspec={rX}}")
    res.append("Rk & Weapon \\\\")
    for weapon in weapons:
        res.append('%s & %s \\\\' % (weapon['rank'], weapon['name']))
    res.extend(['\\end{covertblr}', ''])

    # --------------------
    # And now do spells
    # --------------------

    for magic in ("talents", "spells", "rituals"):
        items = current[magic] # sorted(current[magic], key=lambda k: (k['ref']))
        if len(items):
            res.append("\\begin{covertblr}{colspec={rXl},column{1}={wd=4mm},column{3}={wd=8mm}}")
            res.append("Rk & %s & Ref \\\\" % magic.title())
            for item in items:
                res.append('%s & %s & %s \\\\' % (item['rank'], item['name'], item['ref']))
            res.extend(['\\end{covertblr}', ''])
    
    res.extend(['\\end{multicols}', ''])    
    res.extend(['\\end{frontcover}', ''])
    
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
