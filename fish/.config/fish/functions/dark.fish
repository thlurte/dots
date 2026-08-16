function dark --description "Revert terminal to default dark theme"
    # Reset terminal background and foreground to emulator defaults
    printf '\e]111\a'
    printf '\e]110\a'

    # Restore default Fish syntax colors for dark backgrounds
    set -U fish_color_normal normal
    set -U fish_color_command 005fd7
    set -U fish_color_param 00afff
    set -U fish_color_quote 999900
    set -U fish_color_error ff0000
    set -U fish_color_comment 990000
    set -U fish_color_keyword 5fff00
    set -U fish_pager_color_prefix normal --bold --underline
    set -U fish_pager_color_completion normal
    set -U fish_pager_color_description B3A06D
end
