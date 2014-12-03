#!/bin/bash -eux
# Install OCaml and OPAM PPAs
case "$OCAML_VERSION" in
  4.01.0) ppa=avsm/ocaml41+opam12 ;;
  4.02.0) ppa=avsm/ocaml42+opam12 ;;
  *) echo Unknown $OCAML_VERSION; exit 1 ;;
esac

echo "yes" | sudo add-apt-repository ppa:$ppa
sudo apt-get update -qq
sudo apt-get install -qq ocaml ocaml-native-compilers camlp4-extra opam time libgmp-dev pkg-config

echo OCaml version
ocaml -version

export OPAMYES=1

opam init git://github.com/ocaml/opam-repository
eval `opam config env`
opam update
opam pin add mirage-profile .
opam install mirage-profile

echo Just stubs
ls -l `ocamlfind query mirage-profile`/*.a

opam pin add lwt 'https://github.com/mirage/lwt.git#tracing'
ocamlfind query lwt.tracing

echo Unix tracing
ls -l `ocamlfind query mirage-profile`/*.a

opam install mirage-xen-minios

echo Xen and Unix tracing
ls -l `ocamlfind query mirage-profile`/*.a
