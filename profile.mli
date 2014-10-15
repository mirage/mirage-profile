(* Copyright (C) 2014, Thomas Leonard *)

val note_suspend : unit -> unit
val note_resume : unit -> unit

type event
val events : unit -> event list
val to_string : event -> string

val label : ?thread:_ Lwt.t -> string -> unit
(** Attach a label/comment to the given thread (or to the currently executing thread if none is given). *)
