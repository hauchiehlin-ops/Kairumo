import re
import sys

def fix_file(path):
    with open(path, 'r') as f:
        content = f.read()

    # Find the chained alerts block
    pattern = r'(\.alert\(.*?\n\s*\})'
    
    # We will just replace `.alert(` with `.background(Color.clear.alert(`
    # and then we need to add `)` at the end of the alert block.
    # It's tricky because some alerts have `message:` blocks.

