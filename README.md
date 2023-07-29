# Toolhead Autoconfig

Automatically swap klipper toolhead config. This is useful if you have multiple toolheads (eg. hotend, laser, drag knife, dremel, etc) and don't want to manually change your configuration files when you switch between them.

## Usage
This script uses an ADC pin on the control board, connected to a resistor on the toolhead, to detect which toolhead is connected. Each toolhead has a different value resistor, and the 4700ohm internal pullup is enabled to create a voltage divider.

The script will automatically run when klipper starts. It will wait for klipper to finish initializing, then check if the correct toolhead is loaded. If there is an error (eg. ADC out of range, because the current config includes an extruder temp sensor, but a different toolhead is attached that doesn't have a temp sensor), then the script will temporarily clear the toolhead config (symlink to /dev/null) and restart klipper.

## Installation

### Install dependencies
1. `sudo apt install expect`

### Set up klipper config
1. In your printer.cfg, add `[include toolhead.cfg]` (but don't make a toolhead.cfg file; the script creates a symlink to the real config file)
2. In printer.cfg, add a new gcode_button section (change `pin` to the ADC pin you're using)
```
[gcode_button sense_disconnected]
pin: PA1
analog_range: 4000000,4700000000
press_gcode:
        RESPOND MSG="NOTHING CONNECTED"
```
2. Create a toolhead.d/ directory in the same dir as your printer.cfg
3. In your toolhead.d/ directory, create a .cfg for your toolhead and move any relevant config lines from printer.cfg to this new file
4. In toolhead.d/, create a symlink to your toolhead config with the value of the resistor on the toolhead (eg. my laser has a 47000ohm resistor, so I ran `ln -s laser.cfg 47000ohm.cfg`)
5. Repeat 3-4 for each toolhead

### Install script
1. Copy the toolchange_config.sh script to the Linux machine running klipper (eg `scp toolchange_config.sh pi@mainsailos:`).
2. Add `ExecStartPost=/full/path/to/toolhead_config.sh` to /etc/systemd/system/klipper.service after the `[Service]` line (use the full path to where you copied toolhead_config.sh)
3. Run `sudo systemctl daemon-reload`
4. Restart klipper

This has only been tested on mainsailos. If your klipper system doesnt use the same paths (for config files, etc) then you will have to change the env vars at the top of toolchange_config.sh.
