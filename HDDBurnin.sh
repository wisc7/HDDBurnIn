#!/bin/bash

# Drives to test
DRIVES=(/dev/sda /dev/sdb /dev/sdc /dev/sdd /dev/sde)

LOGDIR=/var/log/drive_burnin
mkdir -p $LOGDIR

# Temperature thresholds
TEMP_THRESHOLD=50
CRIT_THRESHOLD=55

# Runtime options (default: all enabled)
RUN_SHORT=true
RUN_LONG=true
RUN_BADBLOCKS=true
RUN_FIO=true

# Parse command-line options
while [[ $# -gt 0 ]]; do
  case $1 in
    --no-short) RUN_SHORT=false ;;
    --no-long) RUN_LONG=false ;;
    --no-badblocks) RUN_BADBLOCKS=false ;;
    --no-fio) RUN_FIO=false ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
  shift
done

monitor_temps() {
  while true; do
    for d in "${DRIVES[@]}"; do
      name=$(basename $d)
      temp=$(smartctl -A $d | awk '/Temperature_Celsius/{print $10}')
      echo "$(date) $d Temp: $temp°C" >> $LOGDIR/${name}_temp.log
      echo "$(date) $d Temp: $temp°C" >> $LOGDIR/burnin_status.log

      if [ "$temp" -ge "$CRIT_THRESHOLD" ]; then
        echo "$(date) CRITICAL: $d at $temp°C — aborting tests!" >> $LOGDIR/${name}_temp.log
        pkill -f "badblocks.*$d"
        pkill -f "fio.*$d"
      elif [ "$temp" -ge "$TEMP_THRESHOLD" ]; then
        echo "$(date) WARNING: $d at $temp°C — consider increasing cooling." >> $LOGDIR/${name}_temp.log
      fi
    done
    sleep 300
  done
}

# Start temperature monitoring in background
monitor_temps &
MONITOR_PID=$!

# === Phase 1: SMART Short Test ===
if $RUN_SHORT; then
  for d in "${DRIVES[@]}"; do
    name=$(basename $d)
    echo "Starting SMART short test on $d..."
    smartctl -t short $d
  done

  echo "Polling for SMART short test completion..."
  while true; do
    unfinished=0
    for d in "${DRIVES[@]}"; do
      if smartctl -c $d | grep -q "Self-test routine in progress"; then
        unfinished=$((unfinished+1))
      fi
    done
    if [ $unfinished -eq 0 ]; then
      break
    fi
    sleep 30  # poll every 30s for short test
  done

  for d in "${DRIVES[@]}"; do
    name=$(basename $d)
    smartctl -a $d > $LOGDIR/${name}_smart_short.log
  done
fi

# === Phase 2: SMART Long Test ===
if $RUN_LONG; then
  for d in "${DRIVES[@]}"; do
    name=$(basename $d)
    echo "Starting SMART long test on $d..."
    smartctl -t long $d
  done

  echo "Polling for SMART long test completion..."
  while true; do
    unfinished=0
    for d in "${DRIVES[@]}"; do
      if smartctl -c $d | grep -q "Self-test routine in progress"; then
        unfinished=$((unfinished+1))
      fi
    done
    if [ $unfinished -eq 0 ]; then
      break
    fi
    sleep 600  # poll every 10 minutes for long test
  done

  for d in "${DRIVES[@]}"; do
    name=$(basename $d)
    smartctl -a $d > $LOGDIR/${name}_smart_long.log
  done
fi

# === Phase 3: Badblocks ===
if $RUN_BADBLOCKS; then
  for d in "${DRIVES[@]}"; do
    name=$(basename $d)
    echo "Starting badblocks on $d..."
    nohup badblocks -b 8192 -sv $d > $LOGDIR/${name}_badblocks.log 2>&1 &
  done
  wait
fi

# === Phase 4: fio stress test ===
if $RUN_FIO; then
  for d in "${DRIVES[@]}"; do
    name=$(basename $d)
    echo "Starting fio stress test on $d..."
    nohup fio --name=burnin --filename=$d --rw=randrw --bs=4k \
              --size=20G --numjobs=4 --runtime=21600 --group_reporting \
              > $LOGDIR/${name}_fio.log 2>&1 &
  done
  wait
fi

echo "Burn-in complete. Logs are in $LOGDIR"

# Stop temperature monitor
kill $MONITOR_PID
