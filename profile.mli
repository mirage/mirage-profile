(* Copyright (C) 2014, Thomas Leonard *)

type event

val note_suspend : unit -> unit
val note_resume : unit -> unit

val start : size:int -> unit
(** Allocate a ring buffer with [size] elements and start logging to it. *)

val stop : unit -> event array
(** Snapshot the current buffer and stop recording. *)

val events : unit -> event array
(** Return a snapshot of the event ring buffer.
 * For use while tracing is still active. *)

val to_string : event -> string

val label : ?thread:_ Lwt.t -> string -> unit
(** Attach a label/comment to the given thread (or to the currently executing thread if none is given). *)

val note_increase : string -> int -> unit
(** [incr name amount] increases the named counter. *)

val named_condition : string -> 'a Lwt_condition.t
(** Create a Lwt_condition that will label its thread with the given name. *)
