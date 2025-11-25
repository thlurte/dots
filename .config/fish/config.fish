source /usr/share/cachyos-fish-config/cachyos-config.fish

# overwrite greeting
# potentially disabling fastfetch
#function fish_greeting
#    # smth smth
#end
fish_add_path /home/ahmed/.pixi/bin

if status is-interactive
    if not set -q SSH_AUTH_SOCK
        eval (ssh-agent -c)
    end
end
