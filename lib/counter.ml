(* Copyright (C) 2014, Thomas Leonard *)

type t = {
  name : string;
  mutable value : int;
}

let create ?(init=0) ~name () = { name; value = init }
let make ~name = create ~name ()

let increase m amount =
  m.value <- m.value + amount;
  Trace.note_increase m.name amount

let value m = m.value

let set_value m v = increase m (v - m.value)
