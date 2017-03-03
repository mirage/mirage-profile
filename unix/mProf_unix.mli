(* Copyright (C) 2014, Thomas Leonard *)

open Bigarray
type log_buffer = (char, int8_unsigned_elt, c_layout) Array1.t

val timestamper : log_buffer -> int -> unit

val mmap_buffer : size: int -> string -> log_buffer
