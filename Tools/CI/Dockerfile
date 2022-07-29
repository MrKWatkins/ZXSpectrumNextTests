# sjasmplus ("Next" variant supporting "ZX Spectrum Next" extensions) built with GCC 12
#
# Copyleft 2019 by Peter Ped Helcmanovsky <ped _a_t_ 7gods _d_o_t_ org>
# MIT licensed * Use at your own risk!
#
# based on https://ownyourbits.com/2017/06/20/c-build-environment-in-a-docker-container/

# base image is gcc:12
FROM gcc:12

# clone sources of sjasmplus (from my fork repository, where I put also "RC" tags),
# build sjasmplus and install it as part of this container
RUN git --version \
    && git clone -j4 --depth=1 --single-branch --branch v1.20.1 --shallow-submodules --recurse-submodules https://github.com/ped7g/sjasmplus.git \
    && cd sjasmplus \
    && make clean \
    && make -j4 \
    && make install \
    && cd .. \
    && rm -rf sjasmplus
