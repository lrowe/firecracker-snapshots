#!/bin/bash
set -e

source ./common.sh

# Run firecracker
target/firecracker --api-sock "${API_SOCKET}" &
PID=$!
trap "rm -f $API_SOCKET $V_SOCKET; kill -TERM $PID; wait $PID" INT TERM EXIT

# API requests are handled asynchronously, it is important the configuration is
# set, before `InstanceStart`.
sleep 0.015s

# Set machine config
curl -X PUT --fail --unix-socket "${API_SOCKET}" \
  --data '{
    "vcpu_count": 1,
    "mem_size_mib": 256
  }' \
  "http://localhost/machine-config"

# Set boot source
curl -X PUT --fail --unix-socket "${API_SOCKET}" \
  --data "{
    \"kernel_image_path\": \"target/vmlinux\",
    \"boot_args\": \"console=ttyS0 reboot=k panic=1 DENO_SERVE_ADDRESS=tcp:0.0.0.0:8000 ip=${FC_IP}::${TAP_IP}:${MASK_LONG}::eth0:off -- helloworld\"
  }" \
    "http://localhost/boot-source"

# Set rootfs
curl -X PUT --fail --unix-socket "${API_SOCKET}" \
  --data '{
    "drive_id": "rootfs",
    "path_on_host": "target/root.squashfs",
    "is_root_device": true,
    "is_read_only": true
  }' \
  "http://localhost/drives/rootfs"

# Set vsock
curl -X PUT --fail --unix-socket "${API_SOCKET}" \
  --data '{
    "guest_cid": 3,
    "uds_path": "./v.sock"
  }' \
  "http://localhost/vsock"

# Set network interface
curl -X PUT --fail --unix-socket "${API_SOCKET}" \
    --data "{
        \"iface_id\": \"net1\",
        \"guest_mac\": \"$FC_MAC\",
        \"host_dev_name\": \"$TAP_DEV\"
    }" \
    "http://localhost/network-interfaces/net1"

# Start microVM
curl -X PUT --fail --unix-socket "${API_SOCKET}" \
  --data '{
    "action_type": "InstanceStart"
  }' \
  "http://localhost/actions"

# API requests are handled asynchronously, wait before connecting
sleep 1s

# Warmup requests (CONNECT is from the vsock protocol)
echo "Warmup started"
for i in {1..1000}; do
  duration_us=$(target/measure "$FC_IP" 8000);
  # start=$EPOCHREALTIME
  # output=$(printf "CONNECT 8000\nGET http://example.com/ HTTP/1.1\r\nHost: example.com\r\nConnection: close\r\n\r\n" | nc -U ./v.sock)
  # end=$EPOCHREALTIME
  # duration_us="$(bc <<<"(${end}-${start})*1000000/1")"
  if (( i % 100 == 0 )); then
    echo "Request $i took $duration_us us."
  fi
#   # OK 1073741834
#   # HTTP/1.1 200 OK
#   # ...
#   conn="${output%
# *}"
#   response="${output#*
# }"
#   if [[ "$conn" != "OK "* ]]; then
#     echo "BAD VSOCK CONNECTION:\n$conn"
#     exit 1
#   fi
#   if [[ "$response" != "HTTP/1.1 200 OK"* ]]; then
#     printf "BAD RESPONSE:\n${response}\n"
#     exit 1
#   fi
done
echo "Warmup complete"

curl -v http://$FC_IP:8000/

# Pause microVM
curl -X PATCH --fail --unix-socket "${API_SOCKET}" \
  --data '{ "state": "Paused" }' \
  "http://localhost/vm"

# curl -X GET --unix-socket "${API_SOCKET}" "http://localhost/"

# Create snapshot
curl -X PUT --fail --unix-socket "${API_SOCKET}" \
  --data '{
    "snapshot_type": "Full",
    "snapshot_path": "target/helloworld.snapshot",
    "mem_file_path": "target/helloworld.mem"
  }' \
  "http://localhost/snapshot/create"

echo "Snapshot created."

rm -f $API_SOCKET $V_SOCKET
kill -TERM $PID
trap - INT TERM EXIT
wait $PID || true
