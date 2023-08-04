FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
RUN mkdir -p /etc/apt/apt.conf.d/ && \
    printf 'APT::Get::Assume-Yes "true";\nAPT::Get::force-yes "true";\n' > /etc/apt/apt.conf.d/90forceye && \
    apt update && \
    apt upgrade && \
    apt install -y git \
                   clang-13 \
                   python3-pip \
                   wget \
                   binutils \
                   gnupg2 \
                   libc6-dev \
                   libcurl4-openssl-dev \
                   libedit2 \
                   libgcc-9-dev \
                   libpython3.10 \
                   libsqlite3-0 \
                   libstdc++-9-dev \
                   libxml2-dev \
                   libz3-dev \
                   ninja-build \
                   pkg-config \
                   tzdata \
                   unzip \
                   zlib1g-dev \
                   cmake \
                   ruby-full \
                   python3-seaborn && \
    ln -s /usr/bin/clang-13 /usr/bin/clang && \
    ln -s /usr/bin/clang++-13 /usr/bin/clang++

# install swift
RUN mkdir /swift && \
    cd /swift && \
    wget https://download.swift.org/swift-5.7-release/ubuntu2204/swift-5.7-RELEASE/swift-5.7-RELEASE-ubuntu22.04.tar.gz && \
    tar zxvf ./swift-5.7-RELEASE-ubuntu22.04.tar.gz
ENV PATH="$PATH:/swift/swift-5.7-RELEASE-ubuntu22.04/usr/bin"

# fetch and build fuzzjit
RUN git clone https://github.com/fuzz-evaluator/fuzzjit-upstream fuzzjit
RUN cd fuzzjit && \
    git checkout a3d3f6da7f7f8577476892d6135eee6c50afc7ad && \
    swift build -c release

# fetch and build fuzzilli (for baseline)
RUN git clone https://github.com/googleprojectzero/fuzzilli.git
RUN cd fuzzilli && \
    git checkout ec1178af8c606c2adb87de23994f836642652a6f && \
    swift build -c release

# shallow-clone spidermonkey, checkout commit indicated by fuzzjit repo
# we need to patch the build script of spidermonkey
RUN mkdir gecko-dev && \
    cd gecko-dev && \
    git init . && \
    git remote add origin https://github.com/mozilla/gecko-dev && \
    git fetch --depth 1 origin defeab22356a2ff5dd5f35612a561ce020a0fb4a && \
    git checkout FETCH_HEAD && \
    sed -i '/^.* .mozconfig*/a CC=clang-13\nCXX=clang++-13\nac_add_options --disable-bootstrap\nac_add_options --disable-tests' /fuzzjit/Targets/Spidermonkey/fuzzbuild.sh

RUN cd gecko-dev && \
    printf "\n" | ./mach bootstrap --application-choice=js || true

RUN cd gecko-dev && \
    /fuzzjit/Targets/Spidermonkey/fuzzbuild.sh

# full clone of v8, checkout commit indicated by fuzzjit repo
RUN git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
RUN PATH="$PATH:/depot_tools" gclient config https://chromium.googlesource.com/v8/v8 && \
    PATH="$PATH:/depot_tools" gclient sync && \
    cd v8 && \
    git checkout 45d4d220d2b97082023ca02cb7510f087abc0851 && \
    PATH="$PATH:/depot_tools" gclient sync && \
    sed -i "s/checkout_clang_coverage_tools': False/checkout_clang_coverage_tools': True/" DEPS && \
    PATH="$PATH:/depot_tools" gclient runhooks && \
    PATH="$PATH:/depot_tools" /fuzzjit/Targets/V8/fuzzbuild.sh

## shallow-clone jsc, checkout commit indicated by fuzzjit repo
RUN mkdir webkit && \
    cd webkit && \
    git init . && \
    git remote add origin https://github.com/WebKit/webkit && \
    git fetch --depth 1 origin f003c2e7452c4e83aefc524c254c7ab7760e8ef8 && \
    git checkout FETCH_HEAD && \
    git apply /fuzzjit/Targets/JavaScriptCore/Patches/webkit.patch && \
    /fuzzjit/Targets/JavaScriptCore/fuzzbuild.sh

# build the engines for lcov
COPY covbuildJSC.sh /fuzzjit/Targets/JavaScriptCore
COPY covbuildSpidermonkey.sh /fuzzjit/Targets/Spidermonkey
COPY covbuildV8.sh /fuzzjit/Targets/V8

RUN chmod +x /fuzzjit/Targets/JavaScriptCore/covbuildJSC.sh && \
    chmod +x /fuzzjit/Targets/Spidermonkey/covbuildSpidermonkey.sh && \
    chmod +x /fuzzjit/Targets/V8/covbuildV8.sh

RUN cd webkit && \
    /fuzzjit/Targets/JavaScriptCore/covbuildJSC.sh

RUN cd v8 && \
    PATH="$PATH:/depot_tools" /fuzzjit/Targets/V8/covbuildV8.sh

RUN cd gecko-dev && \
    /fuzzjit/Targets/Spidermonkey/covbuildSpidermonkey.sh
