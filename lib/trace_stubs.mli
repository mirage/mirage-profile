(* Copyright (C) 2014, Thomas Leonard *)

(** Functions that libraries can use to add events to the trace.
 *
 * If mirage-profile is compiled with tracing disabled, these are null-ops (or
 * call the underlying untraced operation, as appropriate). The compiler should
 * optimise them out in this case.  *)

val note_suspend : unit -> unit
(** Record that the program is about to sleep. *)

val note_resume : unit -> unit
(** Record that the program has just resumed from sleep. *)

val label : string -> unit
(** Attach a label/comment to the currently executing thread. *)

val named_wait : string -> 'a Lwt.t * 'a Lwt.u
(** Wrapper for [Lwt.wait] that labels the new thread. *)

val named_task : string -> 'a Lwt.t * 'a Lwt.u
(** Wrapper for [Lwt.task] that labels the new thread. *)

val named_condition : string -> 'a Lwt_condition.t
(** Create a Lwt_condition that will label its thread with the given name. *)

val note_increase : string -> int -> unit
(** [incr name amount] increases the named counter.
 * Deprecated: used Counter.increase instead. *)
