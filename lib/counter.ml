(* Copyright (C) 2014, Thomas Leonard *)

type t = {
  name : string;
}

let make ~name = { name }

let increase m amount =
  Trace.note_increase m.name amount
