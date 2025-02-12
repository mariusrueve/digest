# digest

![Logo](digest_logo.png)

[digest](https://github.com/mariusrueve/digest/blob/main/digest.sh) is a lightweight Bash script that aggregates all files from the current directory (or Git repository) into a Markdown-formatted digest. It automatically includes repository information if available and copies the output to your clipboard—making it easy to share code or configuration details with others or paste them into chatbots like ChatGPT.

## Features

- **Works Anywhere:**  
  Runs in any directory—even if it isn’t a Git repository.
  
- **Git Integration:**  
  When run inside a Git repository, it automatically adds repository details such as the repository name, current branch, and remote URL.
  
- **Customizable Exclusions:**  
  Exclude specific file extensions (e.g., `.md`) and directories (e.g., `tests`) from the digest.
  
- **Local Configuration:**  
  Place a [TOML‑style configuration](#configuration) file named **.digest** in your directory to always ignore specific file types or folders.
  
- **Clipboard Support:**  
  The final Markdown output is automatically copied to your clipboard using `pbcopy`, `xclip`, or `clip` (depending on your system).

## Installation

Install **digest** directly to `/usr/local/bin`, which is already in your PATH, by running the following one-liner in your terminal:

```bash
sudo curl -o /usr/local/bin/digest https://raw.githubusercontent.com/mariusrueve/digest/main/digest.sh && sudo chmod +x /usr/local/bin/digest
```

This command downloads the script and makes it executable.

## Usage

Navigate to the directory you want to generate a digest for and run:

```bash
digest
```

To exclude Markdown files (`*.md`) and a directory named `tests`, run:

```bash
digest -e .md -d tests
```

The script generates a Markdown digest that includes either Git repository information (if applicable) or the current directory name, along with the contents of each file (excluding those you’ve filtered out). The resulting Markdown is automatically copied to your clipboard for easy pasting.

## Configuration

If you want to always ignore certain file extensions or directories in a given folder, you can create a `.digest` file in that directory using a simple TOML‑style format. For example:

```toml
[ignore]
ext = [".md", ".txt"]
dir = ["tests", "build"]
```

When digest is run in a directory containing a `.digest` file, the specified exclusions will be applied automatically.

## Option

```bash
digest --help
Usage: /usr/local/bin/digest [-e EXTENSION] [-d DIRECTORY]
   -e, --exclude-ext   Exclude files matching the given extension (e.g. .md or "*.md")
   -d, --exclude-dir   Exclude an entire directory (e.g. tests)
```

## Requirements

- Bash:
  The script is written in Bash and should work on most Unix-like systems.
- Clipboard Utility:
  The script automatically uses one of the following utilities to copy output to your clipboard:
  - macOS: `pbcopy`
  - Linux: `xclip` (install with sudo apt install xclip)
  - Windows: `clip`
