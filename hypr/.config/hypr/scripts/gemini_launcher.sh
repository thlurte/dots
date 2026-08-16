#!/bin/bash

# 1. Define Directories
SEARCH_DIRS="$HOME/work $HOME/personal"

# 2. Get List
LIST=$(find $SEARCH_DIRS -mindepth 1 -maxdepth 1 -type d 2>/dev/null)

# 3. Select with FZF
SELECTED=$(echo "$LIST" | fzf \
    --prompt="Gemini Context > " \
    --height=100% \
    --layout=reverse \
    --border=rounded \
    --margin=1 \
    --padding=1 \
    --color="bg+:-1,fg:gray,fg+:white,border:green,hl:yellow,prompt:green,pointer:green" \
    --pointer=">" \
    --exit-0)

# 4. ACTION: Launch Alacritty and run Gemini
if [ -n "$SELECTED" ]; then
    # -e fish -c '...' -> Tells Alacritty to run a Fish command string
    # gemini;          -> Runs your Gemini tool
    # exec fish        -> When Gemini closes, replace the process with a fresh Fish shell so the window stays open
    
    CMD="alacritty --class gemini_context --working-directory '$SELECTED' -e fish -c 'gemini; exec fish'"
    
    hyprctl dispatch exec "$CMD"
fi
