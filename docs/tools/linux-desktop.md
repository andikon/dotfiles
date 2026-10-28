# Linux desktop

The desktop set is optional and targets a native Linux Hyprland session. WSL and remote/server defaults use terminal tools. Selecting these files does not enable a display manager, change your login session, reboot, or start background services.

The Hyprland configuration expects Ghostty, Thunar, Wofi, Waybar, SwayNC, hyprpaper, and hyprlock. Some keybindings also use hyprpicker, Flameshot, WirePlumber's `wpctl`, brightnessctl, and `hyprshutdown`; availability varies by distribution. The wizard checks the main dependencies; install auxiliary session utilities through your distribution where available.

Review keyboard layout, monitors, brightness/audio controls, and lock/shutdown bindings for your hardware. The config currently uses the `us` layout with the `de_se_fi` variant. A generic preferred monitor mode is used.

hyprpaper has no bundled wallpaper path because this repository does not contain an image. Add a wallpaper block referencing an existing local image if desired. The Waybar GPU script emits nothing when `nvidia-smi` is absent, so non-NVIDIA machines can still run the bar.

The weather widget uses IP-based location by default. Set `DOTFILES_WEATHER_LOCATION` to an ASCII city identifier such as `Berlin` before starting Waybar to choose a fixed location. Requests have a five-second timeout and use HTTPS.

Hyprland and bar configuration formats evolve. Review application diagnostics after installing on a distribution with significantly different versions. The installer checks presence and declared minimum versions; it does not certify a complete graphical session on every distribution.
