# sjasmplus ("Next" variant supporting "ZX Spectrum Next" extensions) built with GCC 6
#
# Copyleft 2019 by Peter Ped Helcmanovsky <ped _a_t_ 7gods _d_o_t_ org>
# MIT licensed * Use at your own risk!
#
# based on https://ownyourbits.com/2017/06/20/c-build-environment-in-a-docker-container/

# base image is gcc:6
FROM gcc:6

# clone sources of sjasmplus (from my fork repository, where I put also "RC" tags),
# build sjasmplus and install it as part of this container
RUN git clone --depth=1 --branch v1.18.2 https://github.com/ped7g/sjasmplus.git \
    && cd sjasmplus \
    && make clean \
    && make -j4 \
    && make install \
    && make clean
