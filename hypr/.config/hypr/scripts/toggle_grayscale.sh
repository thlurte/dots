#!/bin/bash

# Path to our shader
SHADER_PATH="$HOME/.config/hypr/shaders/grayscale.glsl"
# A temporary file to remember if the shader is currently ON
STATE_FILE="/tmp/hypr_grayscale_active"

if [ -f "$STATE_FILE" ]; then
    # If the state file exists, turn OFF the shader
    hyprctl keyword decoration:screen_shader "[[EMPTY]]"
    rm "$STATE_FILE"
else
    # If the state file doesn't exist, turn ON the shader
    hyprctl keyword decoration:screen_shader "$SHADER_PATH"
    touch "$STATE_FILE"
fi

