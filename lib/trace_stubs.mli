(* Copyright (C) 2014, Thomas Leonard *)

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
(** [incr name amount] increases the named counter.
 * Deprecated: used Counter.increase instead. *)

(** {2 Interface for the main loop} *)

type hiatus_reason =
  | Wait_for_work
  | Suspend
  | Hibernate

val note_hiatus : hiatus_reason -> unit
(** Record that the process is about to stop running for a while. *)

val note_resume : unit -> unit
(** Record that the program has just resumed running. *)
