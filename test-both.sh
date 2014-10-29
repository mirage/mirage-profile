#!/bin/sh -eux
oasis setup

ocaml setup.ml -configure --disable-tracing
make clean
make

ocaml setup.ml -configure --enable-tracing
make clean
make
