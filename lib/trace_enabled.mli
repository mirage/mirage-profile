(* Copyright (C) 2014, Thomas Leonard *)

(** The extended profiling interface available when compiled with tracing enabled. *)

include (module type of Trace_stubs)

open Bigarray
type log_buffer = (char, int8_unsigned_elt, c_layout) Array1.t

module Control : sig
  type t

  val make : size:int -> unit -> t
  (** Create a new trace buffer.
   * @param size the size in bytes of the buffer to use. *)

  val start : t -> unit
  (** Start logging to the given buffer. *)

  val stop : t -> unit
  (** Stop recording. *)

  val dump : t -> (log_buffer -> log_buffer -> unit Lwt.t) -> unit Lwt.t
  (** [dump t fn] calls [fn header body] on each buffer containing unread trace data,
   * starting with the oldest.
   * The data will not change until the thread returns, and it must return before
   * dump can be called again.
   *)
end
