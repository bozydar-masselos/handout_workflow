FROM condaforge/mambaforge:latest
LABEL contact = "theodoregionnas@gmail.com"
LABEL build_date = "2024-02-02"

#This set installation to be noninteractive
ENV DEBIAN_FRONTEND=noninteractive

#Install essential dependencies for my script
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    libssl-dev \
    libxml2-dev \
    git \
    gzip \
    zless \
    tar \
    wget && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* 

#Create the conda environment in a new folder of my choice.
RUN mdir -p /conda-envs/gooe
COPY envs/environment.yaml /conda-envs/gooe/environment.yaml

#Next part creates a new environment in the the directory we created above and  installs dependencies based on the environment.yaml file. Also clean uneeded files. 
RUN mamba env create --prefix /conda-envs/gooe --file /conda-envs/gooe/environment.yaml && \
    mamba clean --all -y 

#Adds the environment path to PATH and ensures that executables of the environment are available globally. 
ENV PATH /conda-envs/gooe/bin:$PATH

#Set default shell, so that subsequent RUN commands are executed using BASH syntax. Set default command which will run when the container starts in this case it just opens an interactive Bash shell. 
SHELL ["/bin/bash", "-c"]
CMD ["/bin/bash"]
