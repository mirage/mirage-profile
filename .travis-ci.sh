#!/bin/bash -eux

# The base library works with OCaml 4.02
echo "yes" | sudo add-apt-repository ppa:avsm/ocaml42+opam12
sudo apt-get update -qq
sudo apt-get install -qq ocaml ocaml-native-compilers camlp4-extra opam time libgmp-dev pkg-config

echo OCaml version
ocaml -version

export OPAMYES=1

opam init git://github.com/ocaml/opam-repository
eval `opam config env`
opam update

opam pin add mirage-profile .

opam pin add lwt 'https://github.com/mirage/lwt.git#tracing'
ocamlfind query lwt.tracing

opam pin add mirage-profile-xen .

# Unix requires OCaml 4.03
opam switch 4.03.0

opam pin add mirage-profile .

opam pin add lwt 'https://github.com/mirage/lwt.git#tracing'

opam pin add mirage-profile-unix .

make test

