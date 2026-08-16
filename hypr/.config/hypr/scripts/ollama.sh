#!/bin/bash

# 1. Get model list, remove header, grab names, show in Rofi
selected_model=$(ollama list | tail -n +2 | awk '{print $1}' | rofi -dmenu -p "🤖 AI Model" -l 10)

# 2. Launch if selected
if [ -n "$selected_model" ]; then
    # Using 'ollama-chat' class for the window rule
    kitty --class ollama-chat --title "Ollama: $selected_model" ollama run "$selected_model"
fi
