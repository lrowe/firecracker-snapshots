#!/bin/bash
set -e

API_SOCKET="./firecracker.sock"
V_SOCKET="./v.sock"

# Run firecracker
target/firecracker --api-sock "${API_SOCKET}" &
PID=$!
trap "rm -f $API_SOCKET $V_SOCKET; kill -TERM $PID; wait $PID" INT TERM EXIT

# Load snapshot
curl -X PUT --unix-socket "${API_SOCKET}" \
  --data '{
    "snapshot_path": "target/helloworld.snapshot",
    "mem_backend": {
      "backend_path": "target/helloworld.mem",
      "backend_type": "File"
    },
    "resume_vm": true
  }' \
  "http://localhost/snapshot/load"

# Request

duration_us=$(target/measurefvsock "$V_SOCKET");
echo "GET request took $duration_us us."

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
rm -f $API_SOCKET $V_SOCKET
kill -TERM $PID
trap - INT TERM EXIT
wait $PID || true
