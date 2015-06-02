(* Copyright (C) 2014, Thomas Leonard *)

(** A counter or other time-varying integer value. *)

type t

val create : ?init:int -> name:string -> unit -> t
val make : name:string -> t

val value : t -> int
val set_value : t -> int -> unit

val increase : t -> int -> unit
(** Record a change in the value of the metric. The change can be negative. *)
