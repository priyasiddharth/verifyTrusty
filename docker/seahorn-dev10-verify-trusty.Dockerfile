#
# Minimal Dockerfile for SeaHorn and verifyTrusty environment
# produces a lightweight container with SeaHorn, trusty source code and compiled harness files
#

FROM seahorn/seahorn-llvm10:nightly

ENV SEAHORN=/home/usea/seahorn/bin/sea PATH="$PATH:/home/usea/seahorn/bin:/home/usea/bin"

## install required pacakges
USER root
RUN echo "Pulling Verify Trusty environment" && \
    # installing repo
    mkdir ~/bin && PATH=~/bin:$PATH && \
    apt-get update && \
    apt-get install --no-install-recommends -yqq \
        software-properties-common \
        sudo curl build-essential vim gdb git \
        python-dev python-setuptools python-pip libgraphviz-dev libc6-dev-i386 \
        bear libssl-dev zip \
        libc++-10-dev libc++1-10

## Install latest cmake
RUN apt -y remove --purge cmake
RUN apt -y update
RUN apt -y install wget
RUN wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | gpg --dearmor - | tee /etc/apt/trusted.gpg.d/kitware.gpg >/dev/null
RUN apt-add-repository 'deb https://apt.kitware.com/ubuntu/ bionic main'
RUN apt -y update
RUN apt -y install cmake

# install 32-bit versions of needed libraries
RUN dpkg --add-architecture i386
RUN apt-get -y update
RUN apt-get -y install gcc-multilib g++-multilib libssl-dev:i386

## install pyyaml parser
RUN pip3 install setuptools --upgrade && \
    pip3 install pyyaml 

## use local verify-trusty
USER usea
WORKDIR /home/usea
# RUN git clone https://github.com/seahorn/verifyTrusty.git
RUN mkdir verifyTrusty
COPY . verifyTrusty

## clony trusty repository (takes a long time)
WORKDIR /home/usea/verifyTrusty
RUN echo "Installing Trusty" && \
    mkdir /home/usea/bin/ && curl https://storage.googleapis.com/git-repo-downloads/repo > /home/usea/bin/repo && \
    chmod a+x /home/usea/bin/repo && \
    mkdir trusty && cd trusty && \
    python3 /home/usea/bin/repo init -u https://github.com/seahorn/verifyTrusty.git -b master && \
    python3 /home/usea/bin/repo sync -j32 

## To test that everything is working pre-generate bc files for our verification tasks
WORKDIR /home/usea/verifyTrusty
RUN mkdir build && cd build && cmake -DSEA_LINK=llvm-link-10 -DCMAKE_C_COMPILER=clang-10 -DCMAKE_CXX_COMPILER=clang++-10 -DSEAHORN_ROOT=/home/usea/seahorn -DTRUSTY_TARGET=x86_64 ../ -GNinja && cmake --build .

## Also generate jobs using handle_t as ptr
WORKDIR /home/usea/verifyTrusty
RUN mkdir build_ptr && cd build_ptr && cmake -DSEA_LINK=llvm-link-10 -DCMAKE_C_COMPILER=clang-10 -DCMAKE_CXX_COMPILER=clang++-10 -DSEAHORN_ROOT=/home/usea/seahorn -DTRUSTY_TARGET=x86_64 -DHANDLE_TYPE_IS_PTR=ON ../ -GNinja && cmake --build .

## set default user and wait for someone to login and start running verification tasks
USER usea
