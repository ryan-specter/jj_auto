#!/system/bin/sh
# First-boot setup for JJ Launcher (com.themoon.y1)

while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 1
done

if [ ! -f /data/data/jj_launcher_initialized ]; then
    settings put system sound_effects_enabled 0
    pm install -r /data/jj_launcher.apk
    pm disable com.innioasis.y1 2>/dev/null
    pm disable org.rockbox 2>/dev/null
    touch /data/data/jj_launcher_initialized
fi
