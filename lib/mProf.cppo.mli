(* Copyright (C) 2014, Thomas Leonard *)

module Trace : sig 

(** Functions that libraries can use to add events to the trace.
 *
 * If mirage-profile is compiled with tracing disabled, these are null-ops (or
 * call the underlying untraced operation, as appropriate). The compiler should
 * optimise them out in this case.  *)

(** {2 General tracing calls for libraries} *)

val label : string -> unit
(** Attach a label/comment to the currently executing thread. *)

val named_wait : string -> 'a Lwt.t * 'a Lwt.u
(** Wrapper for [Lwt.wait] that labels the new thread. *)

val named_task : string -> 'a Lwt.t * 'a Lwt.u
(** Wrapper for [Lwt.task] that labels the new thread. *)

val named_condition : string -> 'a Lwt_condition.t
(** Create a Lwt_condition that will label its thread with the given name. *)

val named_mvar_empty : string -> 'a Lwt_mvar.t
(** Create a Lwt_mvar that will label its threads with the given name. *)

val named_mvar : string -> 'a -> 'a Lwt_mvar.t
(** Create a Lwt_mvar that will label its threads with the given name. *)

val note_increase : string -> int -> unit
(* Deprecated: use Counter.increase instead. *)

val note_counter_value : string -> int -> unit
(** Records the current value of the named counter.
 * (for internal use: use Counter.set_value instead) *)

val should_resolve : 'a Lwt.t -> unit
(** Add a hint that this thread is expected to resolve.
 * This is useful if a thread never completes and you want to find out why.
 * Without the hint, the viewer makes such threads almost invisible. *)

(** {2 Interface for the main loop} *)

type hiatus_reason =
  | Wait_for_work
  | Suspend
  | Hibernate

val note_hiatus : hiatus_reason -> unit
(** Record that the process is about to stop running for a while. *)

val note_resume : unit -> unit
(** Record that the program has just resumed running. *)

#ifdef USE_TRACING
(** The extended profiling interface available when compiled with tracing enabled. *)

open Bigarray
type log_buffer = (char, int8_unsigned_elt, c_layout) Array1.t

type timestamper = log_buffer -> int -> unit

module Control : sig
  type t

  val make : log_buffer -> timestamper -> t
  (** Create a new trace log, backed by the given array.
   * Use [MProf_unix] or [MProf_xen] to get the buffer and timestamper. *)

  val start : t -> unit
  (** Start logging to the given buffer. *)

  val stop : t -> unit
  (** Stop recording. *)
end

#endif

end

module Counter :sig 
(** A counter or other time-varying integer value. *)

type t

val create : ?init:int -> name:string -> unit -> t
val make : name:string -> t

val value : t -> int
val set_value : t -> int -> unit

val increase : t -> int -> unit
(** Record a change in the value of the metric. The change can be negative. *)

end