#!/bin/bash

# Script to connect to Bluetooth LE (low energy aka Bluetooth SMART) heart 
# rate monitor and stream time (unix epoc time) and heart rate (bpm) to stdout.
#
# Requires a reasonably up-to-date bluez Bluetooth stack.
#
# The Bluetooth connection sometimes drops, but gatttool fails to 
# exit. There is currently no timeout options for gatttool. To overcome
# this limitation the process is killed and restarted if no BT events
# arrive in 10 seconds. To achieve this timeout a pipe must be used as bash
# 'read' timeout does not work when reading from [??]
#
# http://stackoverflow.com/questions/4874993/bash-script-with-non-blocking-read/4875924#4875924
#

# Bluetooth address of Heart Rate monitor. Use "hcitool lescan" to discover.
BTADDR=D0:39:72:D3:11:50

# Restart gatttool if no messages received in this number of seconds
TIMEOUT=10

# File descriptor used for pipe
FD=7

# FIFO file: add BTADDR to faciliate more than one instance of the script running
FIFO=/tmp/hr_fifo_$$

echo "FIFO=$FIFO"

# Create a FIFO pipe
mknod $FIFO p

# Assign this pipe to file handle 7
exec 7<>${FIFO}

# Kill all subprocesses and delete FIFO on exit
# http://stackoverflow.com/questions/360201/kill-background-process-when-shell-script-exit
trap "rm $FIFO ; trap - SIGTERM && kill -- -$$ ; " SIGINT SIGTERM EXIT

# Loop forever
while true ; do 

	echo "Staring gatttool"
	
	# Send gatttool into file handle 7
	gatttool -b $BTADDR --char-write-req -a  0x13 -n 0100 --listen >&7  &
	gatttool_pid=$!

	while read -t $TIMEOUT -u 7 line ; do
		#read_exit_code=$?
  	 	a=( $line )

		# Extract col index 6 and convert from hex to dec
		hr=$(( 16#${a[6]} ))

		# Output <unix-time> <heart-rate>	
		echo "`date +%s` $hr"
	done

	#kill -- -$BASHPID
	echo "killing gatttool on process $gatttool_pid"
	kill $gatttool_pid	
done

