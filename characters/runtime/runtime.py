#!/usr/bin/python3

import sys
import os
from yaml import load
try:
    from yaml import CLoader as Loader, CDumper as Dumper
except ImportError:
    from yaml import Loader, Dumper

import re
import jinja2

# ----------------------------------------------------------------------
#
# Weight
#
# ----------------------------------------------------------------------

class Weight:
    def __init__(self, weight):
        self.oz = 0
        self.lb = 0
        if isinstance(weight, int):
            self.oz = weight
        if isinstance(weight, float):
            self.lb = int(weight)
            self.oz = int((weight - self.lb) * 16)
        if isinstance(weight, str):
            rx = re.compile('([0-9]+)[ ]*([a-z]+)')
            m = rx.match(weight)
            self.oz = 0
            if m[2] == 'oz':
                self.oz = int(m[1])
            elif m[2] == 'lb':
                self.oz = int(m[1]) * 16
            self.lb = self.oz // 16
            self.oz = self.oz % 16
        if isinstance(weight, dict):
            if 'oz' in weight:
                self.oz = weight['oz']
            if 'lb' in weight:
                self.lb = weight['lb']
        if isinstance(weight, Weight):
            self.oz = weight.oz
            self.lb = weight.lb
        oz = self.oz + self.lb*16
        self.oz = oz % 16
        self.lb = oz // 16

    def __str__(self):
        return "%d lb, %d oz" % (self.lb, self.oz)

    def __mul__(self, quantity):
        return Weight((self.oz + self.lb*16) * quantity)

    def __add__(self, weight):
        return Weight(self.oz + self.lb*16 + weight.oz + weight.lb*16)
        

# ----------------------------------------------------------------------
#
# proc_character
#
# ----------------------------------------------------------------------
    
def proc_character(name, character):

    # --------------------
    # Get stat details from ranking
    # --------------------

    if not 'ranking' in character:
        print("Missing 'ranking' entry")
        exit(1)

    with open(character['ranking'], 'r') as stream:
        ranking = load(stream, Loader=Loader)

    stats = ranking['current']['stats']
    
    categories = ['weapon', 'shield', 'armour', 'item']
    locations = {}
    total_weight = Weight(0)

    for category in categories:
        if category in character:
            for item in character[category]:
                quantity = 1
                if 'quantity' in item:
                    quantity = item['quantity']
                if 'weight' in item:
                    item['_weight'] = Weight(item['weight']) * quantity
                else:
                    item['_weight'] = Weight(0)
                if quantity > 1:
                    item['_name'] = "%s (×%d)" % (item['name'], quantity)
                else:
                    item['_name'] = item['name']
                if 'location' in item:
                    location = item['location']
                else:
                    location = 'backpack'
                item['_category'] = category
                if not location in locations:
                    locations[location] = {'_items':[]}
                locations[location]['_items'].append(item)

    char_block = {
        'name': name,
        'locations': [],
    }
    
    for location in ['worn', 'backpack']:
        if location in locations:
            locations[location]['_name'] = location
            sum_weight = Weight(0)
            for item in locations[location]['_items']:
                sum_weight = sum_weight + item['_weight']
                locations[location]['_weight'] = sum_weight
            total_weight = total_weight + sum_weight
            char_block['locations'].append(locations[location])

    print(total_weight)

    ps_table = [
    {
        'lower': 3,
        'upper': 5,
        'lb': [0, 0, 5, 15, 21, 30, 37, 45, 50],
    },
    {
        'lower': 6,
        'upper': 8,
        'lb':[ 0 , 5 , 12 , 17 , 25, 40, 55, 67, 75 ],
    },
    {
        'lower': 8,
        'upper' : 12,
        'lb': [ 5, 12, 17, 25, 40, 60, 75, 90, 100 ],
    },
    {
        'lower': 13,
        'upper': 17,
        'lb': [ 12, 17, 25, 50, 60, 80, 95, 112, 125 ],
    },
    {
        'lower': 18,
        'upper': 20,
        'lb': [ 17, 25, 35, 50, 75, 105, 125, 140, 150 ],
    },
    {
        'lower': 21,
        'upper': 23,
        'lb': [ 25, 40, 55, 70, 100, 140, 165, 185, 200 ],
    },
    {
        'lower': 24,
        'upper': 27,
        'lb': [35, 50, 65, 85, 120, 160, 185, 202, 225 ],
    },
    {
        'lower': 28,
        'upper': 32,
        'lb': [45, 65, 85, 105, 140, 180, 205, 230, 250 ],
    },
    {
        'lower': 33,
        'upper': 36,
        'lb': [55, 80, 110, 140, 180, 220, 245, 262, 275 ],
    },
    {
        'lower': 37,
        'upper': 40,
        'lb': [ 65, 85, 135, 170, 207, 247, 280, 307, 325 ],
    },
    ]

    exercise_table = [
        {
            'rate': 'light',
            'loss': [ 0, 0, 0, 1/2, 1/2, 1, 2, 3, 5 ],
        },
        {
            'rate': 'medium',
            'loss': [ 0, 0, 1/2, 1/2, 1, 1, 3, 4, 6 ],
        },
        {
            'rate': 'hard',
            'loss': [1/2, 1/2, 1, 1, 2, 3, 5, 6, 8 ],
        },
        {
            'rate': 'strenuous',
            'loss': [ 2, 2, 3, 3, 4, 5, 6, 7, 9 ],
        }
    ]
    ag_loss_table = [0, 1, 2, 3, 5, 7, 9, 10, 12 ]

    # --------------------
    # Calculate encumbrance
    # --------------------

    PS = int(stats['PS'])
    ps_entry = None
    ps_entry_index = None
    ps_entry_count = 1
    for entry in ps_table:
        if PS >= entry['lower'] and PS <= entry['upper']:
            ps_entry = entry
            ps_entry_index = ps_entry_count
        ps_entry_count += 1
    if ps_entry is None:
        print("Entry for PS %d not found" % (PS))
        exit(1)

    ps_category = None
    lb = total_weight.lb + (1 if total_weight.oz > 0 else 0)
    for i in range(len(ps_entry['lb']) - 1, 0, -1):
        if lb <= ps_entry['lb'][i]:
            ps_category = i
    if ps_category is None:
        print("Weight of %d lb exceeds maximum carrying capacity" % lb)
        exit(1)

    exercise = [ {t['rate']:t['loss'][ps_category]} for t in exercise_table ]
    ag_loss = ag_loss_table[ps_category]

    # --------------------
    # Calculate modified AG hence TMR
    # --------------------
    
    AG = int(stats['AG'])

    ag_table = [
        {'Base Agilisys': AG},
        {'Encumbrance': -ag_loss},
    ]

    for i in locations['worn']['_items']:
        if i['_category'] == 'armour':
            if 'modifiers' in i and 'AG' in i['modifiers']:
                ag_mod = i['modifiers']['AG']
            else:
                ag_mod = 0
            ag_table.append({i['_name']:ag_mod})

    ag_mod = sum([list(i.items())[0][1] for i in ag_table])

    tmr_table = [
        {
            'lower': -sys.maxsize,
            'upper': 0,
            'tmr': 0,
        },
        {
            'lower': 1,
            'upper': 2,
            'tmr': 1,
        },
        {
            'lower': 3,
            'upper': 4,
            'tmr': 2,
        },
        {
            'lower': 5,
            'upper': 8,
            'tmr': 3,
        },
        {
            'lower': 9,
            'upper': 12,
            'tmr': 4,
        },
        {
            'lower': 13,
            'upper': 17,
            'tmr': 5,
        },
        {
            'lower': 18,
            'upper': 21,
            'tmr': 6,
        },
        {
            'lower': 22,
            'upper': 25,
            'tmr': 7
        },
        {
            'lower': 26,
            'upper': 27,
            'tmr': 8
        },
    ]

    # --------------------
    # Calculate modified Agility and hence TMR
    # --------------------
    
    tmr = None
    print("ag_mod", ag_mod)
    for i in range(len(tmr_table)-1, 0, -1):
        entry = tmr_table[i]
        if ag_mod <= entry['upper'] and ag_mod >= entry['lower']:
            tmr = entry
    
    ag_table.append({"Modified Agility": ag_mod})
    ag_table.append({"TMR for %d ≤ AG ≤ %d" % (tmr['lower'], tmr['upper']) : tmr['tmr']})


    # --------------------
    # Add tables to template structure
    # --------------------
    
    char_block['encumbrance'] = {'ps': ps_table,
                                 'ft': exercise_table,
                                 'ag': ag_loss_table,
                                 'index': ps_entry_index+1,
                                 'category': ps_category+2
                                 }


    char_block['agility'] = ag_table

    if 'defence' in character:
        char_block['defence'] = character['defence']
        def_sum = 0
        for l in char_block['defence']:
            def_sum += l['value']
            l['sum'] = def_sum
   
    return char_block
        


# ----------------------------------------------------------------------
#
# M A I N
#
# ----------------------------------------------------------------------

# [ proc_character(k, v) for k,v in runtime.items() ]

with open("runtime.yaml", "r") as stream:
    runtime = load(stream, Loader=Loader)


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

template = latex_jinja_env.get_template('runtime.j2')

# text = []
# text.append(template.render(header = True))
# text.append(template.render(character = char_block))
# return text

blocks = [ proc_character(k, v) for k, v in runtime.items() ]
text = template.render(characters = blocks)

# text.append(template.render(trailer = True))

with open("runtime.tex", "w") as stream:
    print(text, file=stream)
