#!/usr/bin/env python3
"""Embed compiled package assets as portable C arrays (no runtime file I/O)."""
import json
from pathlib import Path
import sys

def embed(manifest, output):
    data = json.loads(Path(manifest).read_text())
    name, factory = data['name'], data['factory']
    output = Path(output)
    text = '/* Generated shader assets. */\n'
    sizes = []
    for i, ext in enumerate(('metal', 'frag.spv', 'dxbc')):
        blob = (output / (name + '.' + ext)).read_bytes()
        sizes.append(len(blob))
        text += f'static const unsigned char asset{i}[] = {{\n'
        text += '\n'.join(','.join(str(v) for v in blob[j:j+24])+',' for j in range(0,len(blob),24))
        text += '\n};\n'
    text += 'static const unsigned char *assets[] = {asset0,asset1,asset2};\n'
    text += 'static const int sizes[] = {'+','.join(map(str,sizes))+'};\n'
    text += f'const unsigned char *{factory}Asset(int i) {{ return i>=0 && i<3?assets[i]:0; }}\n'
    text += f'int {factory}Size(int i) {{ return i>=0 && i<3?sizes[i]:0; }}\n'
    (output / (name + '_assets.c')).write_text(text)

if __name__ == '__main__':
    embed(*sys.argv[1:])
