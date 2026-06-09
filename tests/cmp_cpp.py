import sys
sys.path.insert(0, 'D:\\Projects\\oxybelis')
with open('D:\\Projects\\oxybelis\\compiler.cpp') as f:
    c1 = f.read()
with open('D:\\Projects\\oxybelis\\compiler2.cpp') as f:
    c2 = f.read()
c1_lines = c1.split('\n')
c2_lines = c2.split('\n')
print(f'Python compiler output: {len(c1_lines)} lines')
print(f'Self-hosted compiler output: {len(c2_lines)} lines')
import difflib
diff = list(difflib.unified_diff(c1_lines, c2_lines, fromfile='compiler.py.cpp', tofile='compiler2.cpp', n=3))
print(f'Differences: {len(diff)} lines')
for d in diff[:200]:
    print(d)
