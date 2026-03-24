#!/bin/bash
set -e

source common.sh
NBD_SOCKET="target/nbd.sock"

trap "echo TRAP; rm -f $API_SOCKET $V_SOCKET $NBD_SOCKET; pkill -TERM -P $$; sudo umount target/mnt; sudo nbd-client -d /dev/nbd0; wait" INT TERM EXIT

nbdkit -f -v --readonly --unix $NBD_SOCKET file target/helloworld.mem 2> target/nbd.log &
sudo nbd-client -readonly -unix $NBD_SOCKET /dev/nbd0
sudo bindfs -p fo+r --block-devices-as-files --resolve-symlinks target/dev target/mnt
# Run firecracker
target/firecracker --api-sock "${API_SOCKET}" &
PID=$!

# Load snapshot
curl -X PUT --unix-socket "${API_SOCKET}" \
  --data '{
    "snapshot_path": "target/helloworld.snapshot",
    "mem_backend": {
      "backend_path": "target/mnt/nbd0",
      "backend_type": "File"
    },
    "resume_vm": true
  }' \
  "http://localhost/snapshot/load"

# Request

duration_us=$(target/measure "$FC_IP" 8000);
echo "GET request took $duration_us us. (Slow due to nbd.)"

# start=$EPOCHREALTIME
# output=$(printf "CONNECT 8000\nGET http://example.com/ HTTP/1.1\r\nHost: example.com\r\nConnection: close\r\n\r\n" | nc -U ./v.sock)
# end=$EPOCHREALTIME
# duration_us="$(bc <<<"(${end}-${start})*1000000/1")"
# echo "GET request took $duration_us us."

# # OK 1073741834
# # HTTP/1.1 200 OK
# # ...
# conn="${output%
# *}"
# response="${output#*
# }"
# if [[ "$conn" != "OK "* ]]; then
#   printf "BAD VSOCK CONNECTION:\n$conn"
#   exit 1
# fi
# if [[ "$response" == "HTTP/1.1 200 OK"* ]]; then
#   printf "."
# else
#   printf "\nBAD RESPONSE:\n${response}"
#   exit 1
# fi

# Cleanup
rm -f $API_SOCKET $V_SOCKET $NBD_SOCKET
kill -TERM $PID || true
wait $PID || true
sudo umount target/mnt
sudo nbd-client -d /dev/nbd0
pkill -TERM -P $$ || true
trap - INT TERM EXIT
wait || true

reads=( $(grep -P -o '(?<=pread.count=)[0-9]+' <target/nbd.log) )
sum=0
for num in "${reads[@]}"; do
  ((sum += num))
done
echo Read $(( $sum / 1024 )) KB across ${#reads[@]} calls.