#!/bin/bash

# Script to connect to Bluetooth LE heart rate monitor and display
# time (unix epoc time) and heart rate (bpm).
#
# The Bluetooth connection sometimes drops, but gatttool fails to 
# exit. There is currently no timeout options for gatttool. To overcome
# this limitation the process is killed and restarted if no BT events
# arrive in 10s. To achieve this timeout a pipe must be used as bash
# 'read' timeout does not work when reading from [??]
#
# http://stackoverflow.com/questions/4874993/bash-script-with-non-blocking-read/4875924#4875924
#

# TODO: del FIFO on exit
# TODO: kill all subprocesses

# Bluetooth address of Heart Rate monitor
BTADDR=D0:39:72:D3:11:50

# Retart gatttool if no messages received in this number of seconds
TIMEOUT=10

# File descriptor used for pipe
FD=7
FIFO=/tmp/hr_fifo

# Create a FIFO pipe
mknod $FIFO p

# Remove FIFO pipe on script exit
trap "rm $FIFO" EXIT

# Assign this pipe to file handle 7
exec 7<>${FIFO}

# Kill all subprocesses on exit
# http://stackoverflow.com/questions/360201/kill-background-process-when-shell-script-exit
trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT


while true ; do 

	echo "Staring gatttool"
	
	# Send gatttool into file handle 7
	gatttool -b $BTADDR --char-write-req -a  0x13 -n 0100 --listen >&$FD &
	#ping -i 10 8.8.8.8 >&$FD &
	gatttool_pid=$!

	while read -t $TIMEOUT -u $FD line ; do
		read_exit_code=$?
  	 	a=( $line )

		#echo "exit_code=$read_exit_code"

		# Extract col index 6 and convert from hex to dec
		hr=$(( 16#${a[6]} ))	
		echo "`date +%s` $hr $read_exit_code"
		#echo "`date +%s` $line"
	done

	#kill -- -$BASHPID
	echo "killing $gatttool_pid"
	kill $gatttool_pid	
done


