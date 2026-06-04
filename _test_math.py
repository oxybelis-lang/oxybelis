import sys, os
sys.path.insert(0, '.')
import oxybelis as ox

# Test module resolution
r = ox.ModuleResolver('examples/math.ox')
print("Search paths:", r._search_paths)
try:
    src, path = r.resolve(['math'])
    print("Found at:", path)
except Exception as e:
    print("Error:", e)
