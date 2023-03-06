# Playground for working through scanline decomposition algorithm

# 1. Shadow Off
# 2. Draw Playfield (sprite OR overlay) AND NOT solid_overlay
# 3. Draw sprites

sprites = [
    { 'top': 10, 'bottom': 17 },
    { 'top': 14, 'bottom': 29 }
]

overlays = [
    { 'top': 0, 'bottom': 7 }
]

MAX_HEIGHT = 199

# Combine a list on ranges into a minimal list by merging overlapping ranges
def simplify(a):
    b = []
    if len(a) > 0:
        last = a[0]
        start = last['top']
        for r in a[1:]:
            if r['top'] <= last['bottom']:
                last = r
                continue

            b.append([start, last['bottom']])
            last = r
            start = r['top']
        
        b.append([start, last['bottom']])

    return b

# Given two sorted lists, merge them together into a minimal set of ranges.  This could
# be done as a list merge and then a combine step, but we want to be more efficient and
# do the merge-and-combine at the same time
def merge(a, b):
    if len(a) == 0:
        return simplify(b)
    
    if len(b) == 0:
        return simplify(a)

    c = []
    i = j = 0

    while i < len(a) and j < len(b):
        if a[i]['top'] <= b[j]['top']:
            c.append(a[i])
            i += 1
        else:
            c.append(b[j])
            j += 1

    if i < len(a):
        c.extend(a[i:])

    if j < len(b):
        c.extend(b[j:])

    return simplify(c)

# Find the lines that need to be drawn with shadowing off
def get_shadow_off_bg(sprites):
    ranges = []

    if len(sprites) > 0:
        last = sprites[0]
        start = last['top']

        for sprite in sprites[1:]:
            if sprite['top'] <= last['bottom']:
                last = sprite
                continue

            ranges.push([start, last['bottom']])
            start = sprite['top']
            last = sprite
        
        ranges.append([start, last['bottom']])

    return ranges

def complement(ranges):
    comp = []
    if len(ranges) > 0:
        if ranges[0][0] > 0:
            comp.append([0, ranges[0][0]])
        for i in range(1, len(ranges)):
            comp.append([ranges[i-1][1]+1, ranges[i][0]])
        last = ranges[len(ranges)-1]
        if last[1] < MAX_HEIGHT:
            comp.append([last[1]+1, MAX_HEIGHT])
        return comp
    else:
        return [0, MAX_HEIGHT]

r = get_shadow_off_bg(sprites)
print(r)
print(complement(r))

print(merge(sprites, overlays))