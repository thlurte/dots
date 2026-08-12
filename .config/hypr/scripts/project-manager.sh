#!/bin/bash

# Define the code editor
EDITOR="cursor"

# Define the base directories
PERSONAL_DIR="$HOME/personal"
WORK_DIR="$HOME/work"

# --- Rofi Main Menu ---
CHOICE=$(echo -e "1. Create New Project\n2. Open Existing Project" | rofi -dmenu -p "Project Manager")

case "$CHOICE" in
    "1. Create New Project")
        # --- Create Project Logic ---
        
        # 1. Select Type
        TYPE=$(echo -e "Personal\nWork" | rofi -dmenu -p "Project Type")
        
        if [ "$TYPE" == "Personal" ]; then
            BASE_DIR="$PERSONAL_DIR"
            DISPLAY_TYPE="Personal"
        elif [ "$TYPE" == "Work" ]; then
            BASE_DIR="$WORK_DIR"
            DISPLAY_TYPE="Work"
        else
            exit 0 # User cancelled
        fi
        
        # 2. Enter Name
        PROJECT_NAME=$(rofi -dmenu -p "Enter new ${DISPLAY_TYPE} project name")
        
        if [ -n "$PROJECT_NAME" ]; then
            PROJECT_PATH="$BASE_DIR/$PROJECT_NAME"
            
            # Create directory and launch
            mkdir -p "$PROJECT_PATH"
            notify-send "Project Manager" "Created new project: ${PROJECT_PATH}"
            $EDITOR "$PROJECT_PATH"
        fi
        ;;

    "2. Open Existing Project")
        # --- Open Existing Logic ---
        
        # 1. Combine all project paths and prefix them for identification
        PERSONAL_PROJECTS=$(find "$PERSONAL_DIR" -maxdepth 1 -mindepth 1 -type d -printf "P: %P\n")
        WORK_PROJECTS=$(find "$WORK_DIR" -maxdepth 1 -mindepth 1 -type d -printf "W: %P\n")
        
        ALL_PROJECTS=$(echo -e "$PERSONAL_PROJECTS\n$WORK_PROJECTS" | sort)
        
        if [ -z "$(echo "$ALL_PROJECTS" | tr -d '[:space:]')" ]; then
            notify-send "Project Manager" "No projects found in ~/personal or ~/work."
            exit 0
        fi
        
        # 2. Select Project
        SELECTED=$(echo -e "$ALL_PROJECTS" | rofi -dmenu -p "Open Existing Project")
        
        if [ -n "$SELECTED" ]; then
            # Extract prefix (P or W) and project name
            PREFIX=$(echo "$SELECTED" | cut -d: -f1)
            NAME=$(echo "$SELECTED" | cut -d: -f2 | xargs)
            
            if [ "$PREFIX" == "P" ]; then
                FINAL_PATH="$PERSONAL_DIR/$NAME"
            elif [ "$PREFIX" == "W" ]; then
                FINAL_PATH="$WORK_DIR/$NAME"
            fi
            
            # 3. Launch the selected project
            $EDITOR "$FINAL_PATH"
        fi
        ;;

    *)
        exit 0
        ;;
esac
