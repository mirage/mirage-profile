(* Copyright (C) 2014, Thomas Leonard *)

(** The extended profiling interface available when compiled with tracing enabled. *)

include (module type of Trace_stubs)

module Control : sig
  type event

  val start : size:int -> unit
  (** Allocate a ring buffer with [size] elements and start logging to it. *)

  val stop : unit -> event array
  (** Snapshot the current buffer and stop recording. *)

  val events : unit -> event array
  (** Return a snapshot of the event ring buffer.
   * For use while tracing is still active. *)

  val to_string : event -> string
end
