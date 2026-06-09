import os

def generate_skeleton_index():
    output = [
        "# REPOSITORY STRUCTURE MAP\n",
        "> This index outlines structural signatures. Refer to specific line scopes when modifying code.\n"
    ]
    
    target_files = ['oxybelis.py', 'compiler.ox', 'ox_lsp.py', 'ox_fmt.py', 'ox_diag.py']
    
    for filename in target_files:
        if not os.path.exists(filename):
            continue
            
        output.append(f"## File: `{filename}`")
        with open(filename, 'r', encoding='utf-8') as f:
            lines = f.readlines()
        
        for idx, line in enumerate(lines):
            stripped = line.strip()
            # Track class and function blueprints for python and custom .ox files
            if stripped.startswith(('def ', 'class ', 'struct ')):
                output.append(f"- Line {idx + 1}: `{stripped}`")
            elif filename.endswith('.ox') and stripped.startswith('fn '):
                output.append(f"- Line {idx + 1}: `{stripped}`")
        output.append("\n" + "-" * 20 + "\n")
        
    with open('REPO_MAP.md', 'w', encoding='utf-8') as f:
        f.write('\n'.join(output))
    print("✓ REPO_MAP.md built successfully!")

if __name__ == '__main__':
    generate_skeleton_index()
