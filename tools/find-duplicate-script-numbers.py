#!/usr/bin/env python3
#
# Find scripts with duplicate numbers within each stage
#
# This script searches for all scripts in usr/share/rear that start with a number
# and groups them by stage and number. It outputs markdown showing only numbers
# that have more than one script within the same stage.
#
# Usage:
#   ./find-duplicate-script-numbers.py
#
# Output: Markdown formatted list to stdout

import os
import re
import sys
from collections import defaultdict
from pathlib import Path


def find_scripts(base_path):
    """
    Find all scripts that start with a number in the given base path.
    
    Returns a dictionary: stage -> number -> [list of script paths]
    """
    stages = defaultdict(lambda: defaultdict(list))
    
    base = Path(base_path)
    if not base.exists():
        print(f"Error: Base path does not exist: {base_path}", file=sys.stderr)
        sys.exit(1)
    
    # Find all files starting with a number
    for script_path in base.rglob('[0-9]*'):
        if not script_path.is_file():
            continue
        
        # Extract stage (first directory after base)
        try:
            rel_path = script_path.relative_to(base)
            parts = rel_path.parts
            if len(parts) < 2:
                continue
            stage = parts[0]
        except ValueError:
            continue
        
        # Extract number from filename
        filename = script_path.name
        match = re.match(r'^(\d+)_', filename)
        if match:
            num = match.group(1)
            # Store relative path from base
            rel_path_str = str(rel_path)
            stages[stage][num].append(rel_path_str)
    
    return stages


def generate_markdown(stages):
    """
    Generate markdown output showing scripts grouped by stage and number.
    Only shows numbers with more than one script.
    """
    print('# Scripts Grouped by Number (per Stage)')
    print()
    print('This document lists all scripts that start with the same number within each stage.')
    print('Only numbers with more than one script are shown.')
    print()
    
    for stage in sorted(stages.keys()):
        print(f'## Stage: {stage}')
        print()
        
        # Get all numbers for this stage that have more than 1 script
        stage_numbers = {
            num: files 
            for num, files in stages[stage].items() 
            if len(files) > 1
        }
        
        if not stage_numbers:
            print('_No numbers with multiple scripts in this stage._')
            print()
            continue
        
        # Sort numbers numerically (treats "010" as 10, not octal)
        for num in sorted(stage_numbers.keys(), key=int):
            files = sorted(stage_numbers[num])
            print(f'### Number: {num} ({len(files)} scripts)')
            print()
            for f in files:
                print(f'- `{f}`')
            print()


def main():
    """Main entry point."""
    # Determine base path (usr/share/rear relative to script location)
    script_dir = Path(__file__).parent
    repo_root = script_dir.parent
    base_path = repo_root / 'usr' / 'share' / 'rear'
    
    if not base_path.exists():
        print(f"Error: ReaR scripts directory not found: {base_path}", file=sys.stderr)
        print(f"Make sure you run this script from the ReaR repository root.", file=sys.stderr)
        sys.exit(1)
    
    # Find and group scripts
    stages = find_scripts(base_path)
    
    # Generate markdown output
    generate_markdown(stages)


if __name__ == '__main__':
    main()

