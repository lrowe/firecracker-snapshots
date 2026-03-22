# Firecracker snapshot performance testing

```
$ make
...
Listening on vsock:3:8000
Warmup started
Request 100 took 2012 us.
Request 200 took 2212 us.
Request 300 took 2153 us.
Request 400 took 2027 us.
Request 500 took 2224 us.
Request 600 took 2714 us.
Request 700 took 2179 us.
Request 800 took 2635 us.
Request 900 took 2588 us.
Request 1000 took 1950 us.
Warmup complete
...
... 'load snapshot' API request took 2151 us.
...
GET request took 4089 us.
```

## Open questions

* Why is this so slow compared to measuring helloworld on a local unix or tcp socket (under 100 us).
