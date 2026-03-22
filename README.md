# Firecracker snapshot performance testing

## Performance with network

```
# network setup uses sudo to setup tap device
$ ./network.sh

$ make
...
Listening on http://0.0.0.0:8000/ (http://localhost:8000/)
Warmup started
Request 100 took 149 us.
Request 200 took 169 us.
Request 300 took 263 us.
Request 400 took 211 us.
Request 500 took 175 us.
Request 600 took 175 us.
Request 700 took 101 us.
Request 800 took 251 us.
Request 900 took 126 us.
Request 1000 took 123 us.
Warmup complete
...
... 'load snapshot' API request took 2639 us.
...
GET request took 3448 us.
```


## Performance with vsock (initial commit)

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

* Why is vsock so slow?

Local vsock seems to be slow...

```
$ DENO_SERVE_ADDRESS=vsock:1:8000 ./target/helloworld
```

```
$ for i in {1..1000}; do target/measurevsock 1 8000; done
...
746
1062
761
805
999
1868
1756
1693
1703
1721
```
