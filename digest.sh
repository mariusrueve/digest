#!/bin/bash
#
# digest - Gather all files (with optional exclusions) from the current directory,
# including Git repository information if available, and copy the aggregated Markdown
# output to the clipboard or print it to stdout (allowing redirection).
#
# Usage:
#   ./digest [-e EXTENSION[,EXTENSION...]] [-d DIRECTORY[,DIRECTORY...]]
#
# Options:
#   -e, --exclude-ext   Exclude files matching the given extension(s) (e.g. .md or "*.md").
#                       You can pass multiple extensions separated by commas (e.g. .md,.txt).
#
#   -d, --exclude-dir   Exclude an entire directory (e.g. tests).
#                       You can pass multiple directories separated by commas (e.g. tests,build).
#
# Example:
#   ./digest -e .md,.txt -d tests,build
#
# When run interactively the final Markdown output is automatically copied to your clipboard.
# When output is being redirected (e.g. digest > file.txt), the output is directly written to stdout.

# Function: Print usage instructions.
usage() {
    echo "Usage: $0 [-e EXTENSION[,EXTENSION...]] [-d DIRECTORY[,DIRECTORY...]]"
    echo "   -e, --exclude-ext   Exclude files matching the given extension(s) (e.g. .md or \"*.md\")"
    echo "                       You can pass multiple extensions separated by commas (e.g. .md,.txt)."
    echo "   -d, --exclude-dir   Exclude an entire directory (e.g. tests)"
    echo "                       You can pass multiple directories separated by commas (e.g. tests,build)."
    exit 1
}

# Arrays to hold exclusion patterns.
exclude_ext=()
exclude_dir=()

# Parse command-line arguments.
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    -e|--exclude-ext)
      if [[ -n "$2" ]]; then
         # Split comma-separated extensions and add each to the array.
         IFS=',' read -ra exts <<< "$2"
         for ext in "${exts[@]}"; do
             exclude_ext+=("$ext")
         done
         shift
      else
         echo "Error: --exclude-ext requires a value."
         usage
      fi
      ;;
    -d|--exclude-dir)
      if [[ -n "$2" ]]; then
         # Split comma-separated directories and add each to the array.
         IFS=',' read -ra dirs <<< "$2"
         for dir in "${dirs[@]}"; do
             exclude_dir+=("$dir")
         done
         shift
      else
         echo "Error: --exclude-dir requires a value."
         usage
      fi
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Unknown parameter: $1"
      usage
      ;;
  esac
  shift
done

# --- New Feature: Load exclusions from a .digest file (TOML-style) if it exists ---
# Expected .digest file format:
#
#   [ignore]
#   ext = [".md", ".txt"]
#   dir = ["tests", "build"]
#
if [[ -f ".digest" ]]; then
    in_ignore_section=0
    while IFS= read -r line; do
        # Remove leading/trailing whitespace.
        trimmed=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        # Skip empty lines and comments.
        if [[ -z "$trimmed" || "$trimmed" == \#* ]]; then
            continue
        fi
        # Check for section headers.
        if [[ "$trimmed" =~ ^\[.*\]$ ]]; then
            if [[ "$trimmed" == "[ignore]" ]]; then
                in_ignore_section=1
            else
                in_ignore_section=0
            fi
            continue
        fi
        if [[ $in_ignore_section -eq 1 && "$trimmed" == *"="* ]]; then
            key=${trimmed%%=*}
            value=${trimmed#*=}
            key=$(echo "$key" | tr -d ' ')
            # Remove brackets and quotes.
            value=$(echo "$value" | sed -e 's/[][]//g' -e 's/"//g' -e "s/'//g")
            # Trim any remaining whitespace.
            value=$(echo "$value" | xargs)
            if [[ "$key" == "ext" ]]; then
                IFS=',' read -ra exts_config <<< "$value"
                for ext in "${exts_config[@]}"; do
                    ext=$(echo "$ext" | xargs)
                    if [[ -n "$ext" ]]; then
                        exclude_ext+=("$ext")
                    fi
                done
            elif [[ "$key" == "dir" ]]; then
                IFS=',' read -ra dirs_config <<< "$value"
                for dir in "${dirs_config[@]}"; do
                    dir=$(echo "$dir" | xargs)
                    if [[ -n "$dir" ]]; then
                        exclude_dir+=("$dir")
                    fi
                done
            fi
        fi
    done < ".digest"
fi
# --- End .digest loading ---

# Determine repository/directory information.
header_info=""
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    # In a Git repository.
    repo_top=$(git rev-parse --show-toplevel)
    repo_name=$(basename "$repo_top")
    current_branch=$(git rev-parse --abbrev-ref HEAD)
    remote_url=$(git remote get-url origin 2>/dev/null)
    header_info+="# Repository: $repo_name"$'\n'
    header_info+="Current branch: $current_branch"$'\n'
    if [[ -n "$remote_url" ]]; then
      header_info+="Remote: $remote_url"$'\n'
    fi
else
    # Not a Git repository; use current directory.
    repo_top=$(pwd)
    repo_name=$(basename "$repo_top")
    header_info+="# Directory: $repo_name"$'\n'
fi
header_info+=$'\n'"## Files"$'\n\n'

# Decide where to send output.
# If stdout is a terminal, use a temporary file (to later copy to clipboard);
# otherwise (output redirected) write directly to stdout.
if [ -t 1 ]; then
    output_file=$(mktemp)
    use_temp=true
else
    output_file="/dev/stdout"
    use_temp=false
fi

# Write header to output.
printf "%s" "$header_info" >> "$output_file"

# Build the 'find' command with default and user-provided exclusions.
# Exclude the .git folder if it exists.
find_cmd=(find . -type f)
if [[ -d .git ]]; then
    find_cmd+=(-not -path "./.git/*")
fi

# Always exclude the .digest file.
find_cmd+=(-not -name ".digest")

# Add directory exclusions.
for dir in "${exclude_dir[@]}"; do
    # Remove any trailing slash for consistency.
    dir=${dir%/}
    find_cmd+=(-not -path "./$dir/*")
done

# Add file extension exclusions.
for ext in "${exclude_ext[@]}"; do
    # If the extension starts with a dot, assume the user wants to match the ending.
    if [[ $ext == .* ]]; then
         pattern="*${ext}"
    else
         # Otherwise, assume the user provided a wildcard pattern.
         pattern="$ext"
    fi
    find_cmd+=(-not -name "$pattern")
done

# Process each file found.
while IFS= read -r file; do
  # Remove leading "./" for a cleaner path.
  file_path="${file#./}"
  {
    echo "### File: $file_path"
    echo '```'
    cat "$file"
    echo '```'
    echo ""
  } >> "$output_file"
done < <("${find_cmd[@]}")

# --- Output handling ---
if $use_temp; then
    # When running interactively, copy the output to the clipboard.
    if command -v pbcopy >/dev/null 2>&1; then
        cat "$output_file" | pbcopy
        echo "Output copied to clipboard (using pbcopy)."
    elif command -v xclip >/dev/null 2>&1; then
        cat "$output_file" | xclip -selection clipboard
        echo "Output copied to clipboard (using xclip)."
    elif command -v clip >/dev/null 2>&1; then
        cat "$output_file" | clip
        echo "Output copied to clipboard (using clip)."
    else
        echo "Warning: No clipboard utility found (pbcopy, xclip, or clip)."
        echo "The output is printed below:"
        cat "$output_file"
    fi
    rm "$output_file"
fi
