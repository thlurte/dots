# Fetch: macchina. TTY clock: peaclock (run on a Linux console).
function fish_greeting
    if command -q macchina
        macchina
    end
end
fish_add_path /home/ahmed/.pixi/bin


# opencode
fish_add_path /home/ahmed/.opencode/bin



# Added by Antigravity CLI installer
set -gx PATH "/home/ahmed/.local/bin" $PATH
