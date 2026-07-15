#!/usr/bin/python3

# ----------------------------------------------------------------------
#
# Convert YAML to LuaLaTeX via jinja template
#
# 2026-01-18: Copy script from GURPS
#
# ----------------------------------------------------------------------

import os
import sys
import json
import argparse
from yaml import load, dump
try:
    from yaml import CLoader as Loader, CDumper as Dumper
except ImportError:
    from yaml import Loader, Dumper
import jinja2
import re

# ----------------------------------------------------------------------
#
# texify
#
# ----------------------------------------------------------------------

def texify(s):
    s = re.sub('%', "\\%", s)
    return s

# ----------------------------------------------------------------------
#
# format_yaml_jinja
#
# ----------------------------------------------------------------------

def format_yaml_jinja(opts):

    with open(opts['inpath'], encoding='utf-8') as stream:
        npc_list = load(stream, Loader=Loader)

    latex_jinja_env = jinja2.Environment(
        block_start_string = '\\BLOCK{',
        block_end_string = '}',
        variable_start_string = '\\VAR{',
        variable_end_string = '}',
        comment_start_string = '\\#{',
        comment_end_string = '}',
        line_statement_prefix = '%%',
        line_comment_prefix = '%#',
        trim_blocks = True,
        autoescape = False,
        loader = jinja2.FileSystemLoader(os.path.abspath('.'))
    )

    latex_jinja_env.filters['texify'] = texify
    template = latex_jinja_env.get_template(opts['template'])

    
    # --------------------
    # Create output list
    # --------------------

    out_list = []
    
    # --------------------
    # process each NPC
    # --------------------

    for npc in npc_list['npc']:
        out = {}
        out['name'] = npc['name']
        out['description'] = npc['description'] if 'description' in npc else 'No description'
        if 'image' in npc:
            out['image'] = npc['image']
        
        stat_list = ['PS', 'MD', 'AG', 'MA', 'WP', 'EN', 'FT', 'PC', 'PB']
        out['stats'] = {
            'name': stat_list,
            'stat': [ npc['stats'][k] for k in stat_list ]
        }

        for k in ['skills','weapons','armour','abilities']:
            if k in npc:
                out[k] = npc[k]

        print("%s: %s" % (npc['name'], " ".join(out.keys())))
        out_list.append(out)
        
    with open(opts['outpath'], "w") as stream:
        print(template.render(npc_list = out_list), file=stream)

# ----------------------------------------------------------------------
#
# M A I N
#
# ----------------------------------------------------------------------
        
parser = argparse.ArgumentParser(description='Format character YAML file to LuaLaTeX')
parser.add_argument("-t", "--template", action='store', type=str, required=True, help="Input file", dest="template")
parser.add_argument("-i", "--in", action='store', type=str, required=True, help="Input file", dest="inpath")
parser.add_argument("-o", "--out", action='store', type=str, required=True, help="Output file", dest="outpath")
args = parser.parse_args()

opts = {}

opts['template'] = args.template
opts['inpath'] = args.inpath
opts['outpath'] = args.outpath

format_yaml_jinja(opts)
