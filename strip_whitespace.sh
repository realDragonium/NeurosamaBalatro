#!/bin/bash

# Strip leading whitespaces from empty lines in Lua files
# This script removes leading whitespace from empty lines while preserving code indentation

echo "Stripping leading whitespace from empty lines..."

# Find all .lua files and process them
find . -name "*.lua" -type f | while read -r file; do
    echo "Processing: $file"
    
    # Use sed to remove leading whitespace from empty lines only
    # This preserves file endings and doesn't affect lines with content
    sed -i 's/^[[:space:]]\+$//' "$file"
done

echo "Done!"