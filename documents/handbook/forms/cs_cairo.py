#!/usr/bin/python3.14

import cairo
import argparse

# ----------------------------------------------------------------------
#
# DQ character sheet
#
# Use cairo to create both SVG & PDF output
#
# 2026-08-06: Create first page
#
# ----------------------------------------------------------------------



# ----------------------------------------------------------------------
#
# Cairo_Box
#
# ----------------------------------------------------------------------

def Cairo_Box(conf, cr, x, y, width, height, stroke, fill):
    context.rectangle(x, y, width, height)
    if not fill is None:
        context.set_source_rgb(*conf['colours'][fill]);
        context.fill_preserve();
    if not stroke is None:
        context.set_source_rgb(*conf['colours']['stroke'])
        context.set_line_width(stroke)
        context.stroke();
    

# ----------------------------------------------------------------------
#
# Cairo_TopBoxes
#
# ----------------------------------------------------------------------

def Cairo_TopBoxes(conf, context, x, y, height, boxes):
    for box in boxes:
        size = box[0];
        label = box[1];
        text = box[2]

        font = conf['font']['top']

        context.rectangle(x, y, size, height);
        context.set_source_rgb(*conf['colours']['fill']);
        context.fill_preserve();
        context.set_source_rgb(*conf['colours']['stroke'])
        context.stroke();
        offset = 0
        if not label is None:
            if 'colour' in font:
                context.set_source_rgb(*font['colour'])
            else:
                context.set_source_rgb(*conf['colours']['text'])
                
            context.select_font_face(font['face'], cairo.FontSlant.NORMAL, font['weight'])
            context.set_font_size(font['size']);
            extents = context.text_extents(label);
            context.move_to(x + 2, y + 2 - extents.y_bearing);
            context.show_text(label);
            offset = extents.width + 2

        offset += 2

        if not text is None:
            font = conf['font']['content']
            text = str(text)
            if 'colour' in font:
                context.set_source_rgb(*font['colour'])
            else:
                context.set_source_rgb(*conf['colours']['text'])

            context.select_font_face(font['face'], cairo.FontSlant.NORMAL, font['weight'])
            context.set_font_size(font['size']);
            extents = context.text_extents(text);
            context.move_to(x + offset, y + (height/2) - (extents.height / 2 + extents.y_bearing))
            context.show_text(text);
        x += size;

# ----------------------------------------------------------------------
#
# Cairo_TopBoxes
#
# ----------------------------------------------------------------------

def Cairo_CenterText(conf, cr, x, y, height, boxes):
    for box in boxes:
        size = box[0]
        text = box[1]
        features = box[2]

        if 'font' in features:
            font = features['font']
        else:
            font = conf['default']['font']

        if 'weight' in features:
            weight = features['weight']
        else:
            weight = conf['font'][font]['weight']

        if 'size' in features:
            font_size = features['size']
        else:
            font_size = conf['font'][font]['size']

        context.set_font_size(font_size);
        context.select_font_face(conf['font'][font]['face'], cairo.FontSlant.NORMAL, weight);
        context.set_source_rgb(*conf['colours']['text'])

        # Handle multiline text split by \

        lines = text.split('\\')
        if len(lines) > 0:
            num = len(lines)
            total = 0.0
            for l in lines:
                extents = context.text_extents(l)
                total += extents.height + 1
            count = 0
            for l in lines:
                extents = context.text_extents(l)
                tx = x + size/2 - (extents.width / 2 + extents.x_bearing)
                ty = (height/2) - (extents.height / 2 + extents.y_bearing) + ((1-num)/2 + count) * (total/num)
                context.move_to(tx, ty)
                context.show_text(l)
                count += 1
                
        # else:
        #     extents = context.text_extents(text);
        #     context.move_to(x + size/2 - (extents.width / 2 + extents.x_bearing), (height/2) - (extents.height / 2 + extents.y_bearing))
        #     context.show_text(text);
        x += size;

    
# ----------------------------------------------------------------------
#
# FrontPage
#
# ----------------------------------------------------------------------

def FrontPage(conf, context, character):

    # --------------------
    # Clear page to white
    # --------------------

    context.set_source_rgb(1.0, 1.0, 1.0)
    context.rectangle(0.0, 0.0, conf['paper']['width'], conf['paper']['height'])
    context.fill()
    context.set_source_rgb(0.0, 0.0, 0.0)

    context.set_line_width(conf['default']['line_width'])

    context.save()
    context.translate(40, 40)
    
    context.move_to(10, -10)
    context.select_font_face('Z003', cairo.FontSlant.NORMAL, cairo.FontWeight.NORMAL)
    context.set_font_size(28.0)
    context.show_text('DragonQuest')

    context.select_font_face('Nimbus Sans', cairo.FontSlant.NORMAL, cairo.FontWeight.BOLD)
    context.set_font_size(14.0)
    extents = context.text_extents('CHARACTER SHEET')
    context.move_to(520 - extents.width, -10)
    context.show_text('CHARACTER SHEET')

    # --------------------
    # Stats box
    # --------------------

    context.save()

    if not 'stats' in character:
        character['stats'] = {}

    if not 'details' in character:
        character['details'] = {}

    details = character['details']
        
    for d in ['name', 'race', 'aspects', 'sex', 'hand', 'wt', 'ht', 'status', 'college', 'birth', 'date']:
        if not d in details:
            details[d] = None
        
    stat_list = ['PS', 'MD', 'AG', 'MA', 'WP', 'EN']
    stat_boxes = [[50, i, character['stats'][i] if i in character['stats'] else None] for i in stat_list ]
    Cairo_TopBoxes(conf, context, 220, 0, 40, stat_boxes)
    
    Cairo_TopBoxes(conf, context, 0, 0, 20, [[220, "Name", details['name']]])
    Cairo_TopBoxes(conf, context, 0, 20, 20, [[220, "Race", details['race']]])
    Cairo_TopBoxes(conf, context, 0, 40, 20, [[320, "Aspects", details['aspects']], [50, "WT", details['wt']]])
    Cairo_TopBoxes(conf, context, 0, 60, 20, [[50, 'Sex', details['sex']], [50, 'Hand', details['hand']],
                                              [220, 'S. Status', details['status']], [50, "HT", details['ht']]])

    stat_list = ['PB', 'PC', 'FT']
    stat_boxes = [[50, i, character['stats'][i] if i in character['stats'] else None] for i in stat_list ]

    Cairo_TopBoxes(conf, context, 370, 40, 40, stat_boxes)
    
    Cairo_TopBoxes(conf, context, 0, 80, 20, [
        [220, 'College', details['college']],
        [200, 'Birth', details['birth']],
        [100, 'Date', details['date']]])

    Cairo_Box(conf, context, 0, 0, 520, 100, 1.0, None)
    context.restore()
    
    # --------------------
    # Set rowheight to 15
    # --------------------

    row_height = 15

    # --------------------
    # Weapons
    # --------------------

    context.save()
    context.translate(0, 100)
    
    Cairo_TopBoxes(conf, context, 0, 0, row_height, [[ 320, None, None ]])

    Cairo_CenterText(conf, context, 0, 0, row_height, [
        [20, 'RK', {}],
        [180, 'Weapon', {'font': 'title'}],
        [20, 'IV', {}],
        [20, 'SC', {}],
        [20, 'DM', {}],
        [20, 'CL', {}],
        [20, 'RG', {}],
        [20, 'USE', {}]])

    for i in range(1, 10):
        if 'weapons' in character and i <= len(character['weapons']):
            weapon = character['weapons'][i-1]
        else:
            weapon = {
                'rank': None,
                'name': None,
                'iv': None,
                'dm': None,
                'sc': None,
                'class': None,
                'range': None,
                'use': None
                }
        Cairo_TopBoxes(conf, context, 0, 0 + row_height * i, row_height, [
            [ 20, None, weapon['rank'] ],
            [ 180, None, weapon['name'] ],
            [ 20, None, weapon['iv'] ],
            [ 20, None, weapon['sc'] ],
            [ 20, None, weapon['dm'] ],
            [ 20, None, weapon['class'] ],
            [ 20, None, weapon['range'] ],
            [ 20, None, weapon['use'] ],
        ])

    Cairo_Box(conf, context, 0, 0, 320, 10 * row_height, 1.0, None)
    context.restore()

    # --------------------
    # Armour
    # --------------------

    context.save()
    context.translate(320, 100)
    
    Cairo_TopBoxes(conf, context, 0, 0, row_height, [[ 200, None, None ]])

    for i in range(1, 5):
        Cairo_TopBoxes(conf, context, 0, 0 + row_height * i, row_height, [
            [ 140, None, None ],
            [ 30, None, None ],
            [ 30, None, None ],
            ])
            
    Cairo_CenterText(conf, context, 0, 0, row_height, [
        [140, 'Armour', {'font': 'title'}],
        [30, 'PROT', {}],
        [30, 'AG\\MOD', {}],
    ])
    
    Cairo_Box(conf, context, 0, 0, 200, 5 * row_height, 1.0, None)
    context.restore()

    # --------------------
    # Shield
    # --------------------

    context.save()
    context.translate(320, 100 + 5 * row_height)
    
    Cairo_TopBoxes(conf, context, 0, 0, row_height, [[200, None, None]])
    
    Cairo_CenterText(conf, context, 0, 0, row_height, [
        [20, 'RK', {}],
        [120, 'Shield', {'font': 'title'}],
        [30, 'DEF', {}],
        [30, 'MD\\MOD', {}],
    ])

    for i in range(1, 5):
        Cairo_TopBoxes(conf, context, 0, 0 + row_height * i, row_height, [
            [ 20, None, None ],
            [ 120, None, None ],
            [ 30, None, None ],
            [ 30, None, None ],
            ])
    Cairo_Box(conf, context, 0, 0, 200, 5 * row_height, 1.0, None)
    context.restore()

    # --------------------
    # Skills
    # --------------------

    context.save()
    context.translate(0, 100 + 10 * row_height)
    Cairo_TopBoxes(conf, context, 0, 0, row_height, [[260, None, None]])

    Cairo_CenterText(conf, context, 0, 0, row_height, [
        [200, 'Skills', {'font': 'title'}],
        [20, 'RK', {}],
        [40, 'BC', {}],
    ])
    for i in range(1, 35):
        Cairo_TopBoxes(conf, context, 0, 0 + row_height * i, row_height, [
            [ 200, None, None ],
            [ 20, None, None ],
            [ 40, None, None ],
            ])
    Cairo_Box(conf, context, 0, 0, 260, 35 * row_height, 1.0, None)
    context.restore()

    # --------------------
    # Items
    # --------------------

    context.save()
    context.translate(260, 100 + 10 * row_height)
    Cairo_TopBoxes(conf, context, 0, 0, row_height, [[260, None, None]])

    Cairo_CenterText(conf, context, 0, 0, row_height, [
        [200, 'Items', {'font': 'title'}],
        [30, 'Locn', {}],
        [30, 'WT', {}],
    ])
    for i in range(1, 35):
        Cairo_TopBoxes(conf, context, 0, 0 + row_height * i, row_height, [
            [ 200, None, None ],
            [ 30, None, None ],
            [ 30, None, None ],
            ])
    Cairo_Box(conf, context, 0, 0, 260, 35 * row_height, 1.0, None)
    context.restore()

    # Pop saved context
    
    context.restore()
    

# ----------------------------------------------------------------------
#
# M A I N
#
# ----------------------------------------------------------------------

# ----------------------------------------------------------------------
#
# Default details
#
# ----------------------------------------------------------------------
        
details = {
    'paper': {
        'size': 'a4',
        'width': 595.28,
        'height': 841.89
        },
    'colours': {
        'fill': [1.0, 1.0, 1.0],
        'stroke': [0.0, 0.0, 0.0],
        'text': [0.0, 0.0, 0.0],
        },
    'font': {
        'sans':
        {
            'face': 'Nimbus Sans',
            'size': 7,
            'weight': cairo.FontWeight.NORMAL,
        },
        'top':
        {
            'face': 'Nimbus Sans',
            'size': 7,
            'weight': cairo.FontWeight.NORMAL,
        },
        'title':
        {
            'face': 'Nimbus Sans',
            'size': 8,
            'weight': cairo.FontWeight.BOLD,
        },
        'content':
        {
            'face': 'Palatino',
            'size': 8,
            'weight': cairo.FontWeight.NORMAL,
            'colour': [1.0, 0.0, 0.0]
        },            
    },
    'default': {
        'font': 'sans',
        'line_width': 0.4,
    }
}

# ----------------------------------------------------------------------
#
# Test character
#
# ----------------------------------------------------------------------
test_char = {
    'stats': {
        'PS': 12,
        'AG': 15,
        'MD': 20,
        'MA': 18,
        'WP': 20,
        'EN': 21,
        'FT': 22,
        'PC': 15,
        'PB': 14
        },
    'details': {
        'name': 'Pips Longbottom',
        'race': 'Hobbit',
        'aspects': 'Autumn Stars Fire',
        'college': 'Wiccan',
        'hand': 'Right',
        'sex': 'Female',
        'wt': '80 lb',
        'ht': "4' 8''",
        'birth': '2nd of 6',
        'date': '10 Ice, 826 WK',
        'status': 'Military',
        },
    'weapons': [
        {
            'name': 'Dagger',
            'rank': 5,
            'iv': 23,
            'sc': 80,
            'dm': 2,
            'class': 'A',
            'range': '',
            'use': 'CMR',
        },
    ],
}


parser = argparse.ArgumentParser(description='Format character YAML file to LuaLaTeX')
parser.add_argument("-f", "--format", action='store', type=str, required=True, help="Output format", dest="outformat")
parser.add_argument("-o", "--out", action='store', type=str, required=True, help="Output file", dest="outpath")
args = parser.parse_args()

character = test_char

if args.outformat == 'svg':
    with cairo.SVGSurface(args.outpath, details['paper']['width'], details['paper']['height']) as surface:
        context = cairo.Context(surface)
        FrontPage(details, context, {})

if args.outformat == 'pdf':
    with cairo.PDFSurface(args.outpath, details['paper']['width'], details['paper']['height']) as surface:
        context = cairo.Context(surface)
        FrontPage(details, context, character)
