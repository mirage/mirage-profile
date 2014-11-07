(* Copyright (C) 2014, Thomas Leonard *)

open Bigarray

let mmap_buffer ~size path =
  let fd = Unix.(openfile path [O_RDWR; O_CREAT; O_TRUNC; O_CLOEXEC] 0o644) in
  Unix.ftruncate fd size;
  let ba = Array1.map_file fd char c_layout true size in
  Unix.close fd;
  ba
