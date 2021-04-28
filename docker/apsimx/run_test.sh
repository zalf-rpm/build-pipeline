#!/bin/bash
cd 
docker run --rm --mount type=bind,source="$(pwd)/test",target=/apsim \
zalfrpm/apsimx:6139 runapsim --recursive apsimfiles/*.apsimx

docker run --rm --mount type=bind,source="$(pwd)/test/apsimfiles",target=/apsim \
zalfrpm/apsimx:6139 runapsim potato_var_test_v4.apsimx

docker run --rm --mount type=bind,source="$(pwd)/test/dalby",target=/apsim \
zalfrpm/apsimx:6139 runapsim Soybean.apsimx
