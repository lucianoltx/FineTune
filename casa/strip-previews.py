#!/usr/bin/env python3
"""Remove blocos `#Preview ... { ... }` de fontes Swift.

Por quê: o macro #Preview precisa do plugin PreviewsMacros, que só existe no Xcode.
Com Command Line Tools o compilador falha ("plugin for module 'PreviewsMacros' not found").
Previews não fazem parte do app, então removê-los antes de compilar não muda o binário.
Uso: strip-previews.py <dir> [<dir>...]  (edita no lugar, idempotente)
"""
import re, sys, pathlib

def strip(src: str) -> tuple[str, int]:
    out, i, n = [], 0, 0
    while True:
        m = re.search(r'^[ \t]*#Preview\b', src[i:], re.M)
        if not m:
            out.append(src[i:]); break
        start = i + m.start()
        j = src.find('{', i + m.end())
        if j == -1:
            out.append(src[i:]); break
        depth, k, in_str = 0, j, False
        while k < len(src):
            c = src[k]
            if in_str:
                if c == '\\': k += 1
                elif c == '"': in_str = False
            elif c == '"': in_str = True
            elif c == '/' and src[k:k+2] == '//':
                k = src.find('\n', k); k = len(src) if k == -1 else k; continue
            elif c == '{': depth += 1
            elif c == '}':
                depth -= 1
                if depth == 0: break
            k += 1
        end = src.find('\n', k); end = len(src) if end == -1 else end + 1
        out.append(src[i:start]); n += 1; i = end
    return ''.join(out), n

total = 0
for d in sys.argv[1:]:
    for p in pathlib.Path(d).rglob('*.swift'):
        s = p.read_text()
        if '#Preview' not in s: continue
        new, n = strip(s)
        if n: p.write_text(new); total += n
print(f'#Preview removidos: {total}')
