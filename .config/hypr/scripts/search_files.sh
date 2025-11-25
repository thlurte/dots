#!/bin/bash

# =============================================================================
#  HYPRLAND AESTHETIC SEARCH (Grep + File Search Toggle)
# =============================================================================
#  Dependencies: fzf, ripgrep (rg), bat (optional), fd (optional, for file mode)
#
#  Keybinds inside the window:
#    Enter: Open in Neovim
#    Ctrl+f: Switch to "File Search" mode (Search by filename)
#    Ctrl+g: Switch to "Grep" mode (Search content inside files)
# =============================================================================

# 1. SMART PREVIEWER
#    This handles both "File:Line" (Grep) and "File" (File Search) formats.
#    It cleans colors, detects if a line number exists, and renders accordingly.
if command -v bat >/dev/null 2>&1; then
    PREVIEW_CMD='bash -c "
        file=\$(echo {1} | sed s/\x1b\[[0-9\;]*m//g);
        line=\$(echo {2} | sed s/\x1b\[[0-9\;]*m//g);
        if [ ! -z \"\$line\" ]; then
            bat --style=numbers --color=always --highlight-line \$line \$file
        else
            bat --style=numbers --color=always \$file
        fi
    "'
else
    PREVIEW_CMD='bash -c "
        file=\$(echo {1} | sed s/\x1b\[[0-9\;]*m//g);
        cat \$file
    "'
fi

# 2. COMMANDS
#    RG_CMD: Search content (Standard Grep)
#    FD_CMD: Search filenames (uses 'fd' if installed, else 'find')
RG_CMD="rg --line-number --no-heading --color=always --colors 'line:none' --colors 'path:none' --smart-case . \"$PWD\""

if command -v fd >/dev/null 2>&1; then
    FD_CMD="fd --type f --color=always . \"$PWD\""
else
    FD_CMD="find . -type f"
fi

# 3. RUN FZF
#    We start with RG_CMD.
#    --bind 'ctrl-f': Reloads fzf with the FD_CMD (File Mode)
#    --bind 'ctrl-g': Reloads fzf with the RG_CMD (Grep Mode)

eval "$RG_CMD" | \
fzf --ansi \
    --delimiter : \
    --layout=reverse \
    --border=rounded \
    --margin=1 \
    --padding=1 \
    --prompt="Grep > " \
    --pointer=">" \
    --marker="*" \
    --color="bg+:-1,fg:gray,fg+:white,border:blue,hl:yellow,prompt:blue,pointer:blue" \
    --header="CTRL-F: Files | CTRL-G: Grep" \
    --header-first \
    --bind "ctrl-f:reload($FD_CMD)+change-prompt(Files > )+clear-query" \
    --bind "ctrl-g:reload($RG_CMD)+change-prompt(Grep > )+clear-query" \
    --preview "$PREVIEW_CMD" \
    --preview-window 'right:60%:border-left' \
    --bind 'enter:execute(nvim {1} +{2})'
