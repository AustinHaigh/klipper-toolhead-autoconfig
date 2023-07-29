#!/bin/bash

CONFIG_DIR=$HOME/printer_data/config
COMMS_DIR=$HOME/printer_data/comms

# wait for klipper to start
OUTPUT=$(expect << EOF
set timeout 3
spawn ~/klipper/scripts/whconsole.py $COMMS_DIR/klippy.sock
expect "Connection"

set ready 0
while {\$ready==0} {
	send "{\"id\": 123, \"method\": \"info\", \"params\": {}}\n"
	expect {
		"\"state\":\"ready\"" {
			exit
		}
		"error" {
			exit
		}
	}
}
EOF
)

# if error, set toolhead.cfg to /dev/null and restart klipper
if grep error <<< "${OUTPUT}" > /dev/null; then
	# set empty toolhead config so klipper will start
	if [ "$(readlink $CONFIG_DIR/toolhead.cfg)" == "/dev/null" ]; then
		echo error: already null
		exit
	fi
	rm -f $CONFIG_DIR/toolhead.cfg
	ln -s /dev/null $CONFIG_DIR/toolhead.cfg
	#sleep 2
	
	# restart klipper
	echo '{"id": 123, "method": "gcode/firmware_restart"}' | $HOME/klipper/scripts/whconsole.py $COMMS_DIR/klippy.sock
	echo '{"id": 123, "method": "gcode/restart"}' | $HOME/klipper/scripts/whconsole.py $COMMS_DIR/klippy.sock
	#sudo systemctl restart klipper
	sleep 3

	# restart script
	exec $0
fi

sleep 1

# query toolhead sensor
wget -O /dev/null 'localhost:7125/printer/gcode/script?script=QUERY_ADC name=adc_button:PA1 pullup=4700' 
OHMS=$(grep -m1 'resistance' $COMMS_DIR/klippy.serial | sed -r 's/.*resistance ([0-9.]+).*/\1/')

echo resistance: $OHMS

# loop through toolhead configs, find one that matches measured resistance (must be +/-5%)
for i in $CONFIG_DIR/toolhead.d/*ohms.cfg; do
	cfg_ohms="$(sed -r 's-.*/([0-9]*)ohms.cfg-\1-' <<< "$i")"

	diff=$(($cfg_ohms - ${OHMS%.*})) 
	echo $diff
	echo $cfg_ohms
	echo percent difference $((100 * ${diff#-} / $cfg_ohms))
	if [ $((100 * ${diff#-} / $cfg_ohms)) -lt 5 ]; then
		echo got toolhead: $i

		if [ "$(basename $(readlink $CONFIG_DIR/toolhead.cfg))" == "$(basename $i)" ]; then
			echo already using correct config file
			break
		fi

		rm $CONFIG_DIR/toolhead.cfg
		ln -s $i $CONFIG_DIR/toolhead.cfg
		echo '{"id": 123, "method": "gcode/firmware_restart"}' | $HOME/klipper/scripts/whconsole.py $COMMS_DIR/klippy.sock

		# restart script
		exec $0
	fi
done
