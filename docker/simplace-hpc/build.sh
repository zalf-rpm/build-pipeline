
#!/bin/bash

# copy compiled simplace folder  (assuming it can be found in ~/simplace)
cp -r ~/simplace/lapclient/console ./simplace_exe
# remove windows executable
cd simplace_exe
rm simplace.exe

# optional set memory option to use more memory on a HPC node 
# replace'-Xmx10g' with '-Xmx30g'
sed -i 's/-Xmx10g/-Xmx30g/g' simplace

# build docker image
docker build -t zalfrpm/simplace-hpc:5.0 --no-cache --build-arg EXECUTABLE_SOURCE=simplace_exe .