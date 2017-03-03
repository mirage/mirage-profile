#!/usr/bin/env ocaml
#use "topfind"
#require "topkg"
open Topkg

let xen = Conf.with_pkg ~default:false "xen"

let () =
  Pkg.describe "mirage-profile" @@ fun c ->
  let xen = Conf.value c xen in
  Ok [
    Pkg.mllib ~api:["MProf"] "lib/mProf.mllib" ; 
    Pkg.mllib "unix/mProf_unix.mllib" ; 
    Pkg.mllib ~cond:xen "xen/mProf_xen.mllib" ; 
  ]