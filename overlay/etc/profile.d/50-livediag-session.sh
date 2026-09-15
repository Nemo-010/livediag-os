# Start the livediag session on the first virtual console only.
# Other consoles, su sessions and scripts are left untouched.
if [ -z "${WAYLAND_DISPLAY:-}" ] && [ -z "${DISPLAY:-}" ] &&
    [ "$(tty 2>/dev/null)" = "/dev/tty1" ]; then
    # In a CI boot the unattended runner owns the machine; do not draw.
    case "$(cat /sys/class/dmi/id/product_serial 2>/dev/null)" in
    *livediag.ci*) return 0 ;;
    esac
    exec /usr/local/bin/livediag-session
fi
