#!/usr/bin/env ocaml
#use "topfind"
#require "topkg"
open Topkg

let () =
  Pkg.describe "mirage-profile" @@ fun c ->
  Ok [ Pkg.mllib ~api:["MProf"] "lib/mProf.mllib" ]