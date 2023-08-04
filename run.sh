#!/bin/bash

# build container
docker build -t fuzzjit -f Dockerfile .

# required to disable on host
sudo sysctl -w 'kernel.core_pattern=|/bin/false'
runtime=86400

for i in {0..9}; do
    docker run --cpuset-cpus=$(($i*6+0)) -d -v "$(pwd)"/storage/fuzzjit/jsc/$i:/storage fuzzjit:latest bash -c "cd /fuzzjit; timeout $runtime swift run -c release FuzzilliCli --exportStatistics --profile=jsc --timeout=500 --storagePath=/storage /webkit/FuzzBuild/Debug/bin/jsc" &
    docker run --cpuset-cpus=$(($i*6+1)) -d -v "$(pwd)"/storage/fuzzilli/jsc/$i:/storage fuzzjit:latest bash -c "cd /fuzzilli; timeout $runtime swift run -c release FuzzilliCli --exportStatistics --profile=jsc --timeout=500 --storagePath=/storage /webkit/FuzzBuild/Debug/bin/jsc" &

    docker run --cpuset-cpus=$(($i*6+2)) -d -v "$(pwd)"/storage/fuzzjit/v8/$i:/storage fuzzjit:latest bash -c "cd /fuzzjit; timeout $runtime swift run -c release FuzzilliCli --exportStatistics --profile=v8 --timeout=500 --storagePath=/storage /v8/out/fuzzbuild/d8" &
    docker run --cpuset-cpus=$(($i*6+3)) -d -v "$(pwd)"/storage/fuzzilli/v8/$i:/storage fuzzjit:latest bash -c "cd /fuzzilli; timeout $runtime swift run -c release FuzzilliCli --exportStatistics --profile=v8 --timeout=500 --storagePath=/storage /v8/out/fuzzbuild/d8" &

    docker run --cpuset-cpus=$(($i*6+4)) -d -v "$(pwd)"/storage/fuzzjit/sm/$i:/storage fuzzjit:latest bash -c "cd /fuzzjit; timeout $runtime swift run -c release FuzzilliCli --exportStatistics --profile=spidermonkey --timeout=500 --storagePath=/storage /gecko-dev/obj-fuzzbuild/dist/bin/js" &
    docker run --cpuset-cpus=$(($i*6+5)) -d -v "$(pwd)"/storage/fuzzilli/sm/$i:/storage fuzzjit:latest bash -c "cd /fuzzilli; timeout $runtime swift run -c release FuzzilliCli --exportStatistics --profile=spidermonkey --timeout=500 --storagePath=/storage /gecko-dev/obj-fuzzbuild/dist/bin/js" &
done

sleep $(($runtime + 60))

# correctness rate
docker run -v "$(pwd)"/storage:/storage:ro -v "$(pwd)"/results:/results -v "$(pwd)"/correctness.py:/correctness.py fuzzjit:latest python3 /correctness.py
# coverage
docker run -v "$(pwd)"/storage:/storage:ro -v "$(pwd)"/results:/results -v "$(pwd)"/coverage.py:/coverage.py fuzzjit:latest python3 /coverage.py
