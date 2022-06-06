#!/bin/bash

# docker build -t jupyter . && \
docker image build --tag brys/jupyter . && \
(docker rm -f jupyter | exit 0) && \

docker run --restart unless-stopped -d \
   --gpus all \
   --net host \
   --name jupyter \
   --user root \
   -e JUPYTER_ENABLE_LAB=yes \
   -e GRANT_SUDO=yes \
   -e PROJ_LIB=/opt/conda/share/basemap \
   -v /home/andy/src:/home/jovyan/work \
   brys/jupyter
