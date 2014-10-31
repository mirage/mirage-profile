(* Copyright (C) 2014, Thomas Leonard *)

(** The extended profiling interface available when compiled with tracing enabled. *)

include (module type of Trace_stubs)

open Bigarray
type log_buffer = (char, int8_unsigned_elt, c_layout) Array1.t

module Control : sig
  val start : size:int -> unit
  (** Allocate a ring buffer with [size] elements and start logging to it. *)

  val stop : unit -> log_buffer
  (** Snapshot the current buffer and stop recording. *)

  val events : unit -> log_buffer
  (** Return a snapshot of the event ring buffer.
   * For use while tracing is still active. *)
end
