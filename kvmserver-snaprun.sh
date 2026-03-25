#!/bin/bash
set -e

source common.sh
NBD_SOCKET="target/nbd.sock"

trap "echo TRAP; rm -f $API_SOCKET $V_SOCKET $NBD_SOCKET; pkill -TERM -P $$; sudo umount target/mnt; sudo nbd-client -d /dev/nbd0; wait" INT TERM EXIT

nbdkit -f -v --readonly --unix $NBD_SOCKET file target/helloworld.kvmserver 2> target/nbd-kvmserver.log &
sudo nbd-client -readonly -unix $NBD_SOCKET /dev/nbd0
sudo bindfs -p fo+r --block-devices-as-files --resolve-symlinks target/dev target/mnt
# Run kvmserver
target/kvmserver -e snaprun target/mnt/nbd0 &
PID=$!

# Request

duration_us=$(target/measure 127.0.0.1 8000);
echo "GET request took $duration_us us. (Slow due to nbd.)"

# Cleanup
rm -f $API_SOCKET $V_SOCKET $NBD_SOCKET
kill -TERM $PID || true
wait $PID || true
sudo umount target/mnt
sudo nbd-client -d /dev/nbd0
pkill -TERM -P $$ || true
trap - INT TERM EXIT
wait || true

reads=( $(grep -P -o '(?<=pread.count=)[0-9]+' <target/nbd-kvmserver.log) )
sum=0
for num in "${reads[@]}"; do
  ((sum += num))
done
echo Read $(( $sum / 1024 )) KB across ${#reads[@]} calls.