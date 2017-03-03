#!/usr/bin/env ocaml
#use "topfind"
#require "topkg"
#require "unix"
open Topkg

let xen = Conf.with_pkg ~default:false "xen"

let () =
  Pkg.describe "mirage-profile" @@ fun c -> 
  let use_tracing =
    match Unix.system("ocamlfind query lwt.tracing > /dev/null 2>&1") with
    | Unix.WEXITED 0 -> true
    | Unix.WEXITED _ -> false
    | _ -> failwith "ocamlfind failed!" in
  let xen = Conf.value c xen && use_tracing in
  Ok [
    Pkg.mllib ~api:["MProf"] "lib/mProf.mllib" ; 
    Pkg.mllib ~cond:use_tracing "unix/mProf_unix.mllib" ; 
    Pkg.mllib ~cond:xen "xen/mProf_xen.mllib" ; 
  ]