#!/usr/bin/python3

# ----------------------------------------------------------------------
#
# 2026-07-28: Create table for EM multiplier
#
# ----------------------------------------------------------------------

# Collect results into list

rows = []

# Each row is a list of values

values = []

# The cell{1}{1} is blnak

values.append('')

# Add to_rank as header

for to_rank in range(1, 21):
    values.append(to_rank)

# Clone values to create the first row (header row)

rows.append(values.copy())

# Loop over 0 to 19 for the from rank

for rank_from in range(0, 20):
    values = []

    # First column is a header column with the from_rank
    
    values.append(rank_from)

    # Put blank there from >= to
    
    for rank_to in range(0, rank_from):
        values.append('')

    # Set the value to be t*(t+1) div 2 - f*(f+1) div 2 = (t*(t+1) - f*(f+1)) div 2
        
    for rank_to in range(rank_from + 1, 21):
        values.append(((rank_to * (rank_to + 1)) - ((rank_from * (rank_from + 1)))) // 2)
    rows.append(values.copy())

# Output result using join with list comprehension

for row in rows:
    print("%s \\\\" % " & ".join(["%-5s" % i for i in row]))
