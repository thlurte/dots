function paper --description "Switch terminal to a paper/e-ink theme"
    # Change terminal background to off-white (OSC 11)
    printf '\e]11;#F4F4E8\a'
    # Change terminal foreground text to charcoal ink (OSC 10)
    printf '\e]10;#2B2B2B\a'

    # Adjust Fish shell syntax colors for readability on a light background
    set -U fish_color_normal 2B2B2B
    set -U fish_color_command 000000 --bold
    set -U fish_color_param 4D4D4D
    set -U fish_color_quote 555555 --italic
    set -U fish_color_error A00000
    set -U fish_color_comment 777777 --italic
    set -U fish_color_keyword 000000 --bold
    set -U fish_pager_color_prefix 000000 --bold --underline
    set -U fish_pager_color_completion 2B2B2B
    set -U fish_pager_color_description 666666
end
