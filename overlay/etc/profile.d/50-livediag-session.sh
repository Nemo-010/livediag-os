# Start the livediag session on the first virtual console only.
# Other consoles, su sessions and scripts are left untouched.
if [ -z "${WAYLAND_DISPLAY:-}" ] && [ -z "${DISPLAY:-}" ] &&
    [ "$(tty 2>/dev/null)" = "/dev/tty1" ]; then
    exec /usr/local/bin/livediag-session
fi
