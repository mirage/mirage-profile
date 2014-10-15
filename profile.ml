(* Copyright (C) 2014, Thomas Leonard *)

open Sexplib.Std

external timestamp : unit -> float = "unix_gettimeofday"

type thread_id = int with sexp

let current_thread = ref (-1)

module Event = struct
  type op = 
    | Creates of thread_id * thread_id
    | Reads of thread_id * thread_id
    | Resolves of thread_id * thread_id * string option
    | Becomes of thread_id * thread_id
    | Label of thread_id * string
    | Switch of thread_id
    with sexp

  type t = {
    time : float;
    op : op;
  } with sexp
end

module Log = struct
  open Event

  let event_log = ref []

  let record op =
    let time = timestamp () in
    event_log := {time; op} :: !event_log

  let note_created child =
    Creates (!current_thread, child) |> record

  let note_read input =
    current_thread := Lwt.current_id ();
    Reads (!current_thread, input) |> record

  let note_resolved p ~ex =
    let msg =
      match ex with
      | Some ex -> Some (Printexc.to_string ex)
      | None -> None in
    Resolves (!current_thread, p, msg) |> record

  let note_becomes input main =
    if main <> input then
      Becomes (input, main) |> record

  let note_label thread label =
    Label (thread, label) |> record

  let note_switch () =
    let id = Lwt.current_id () in
    if id <> !current_thread then (
      current_thread := id;
      Switch id |> record
    )

  let note_suspend () =
    current_thread := (-1);
    Switch (-1) |> record

  let () =
    Lwt_tracing.tracer := { Lwt_tracing.
      note_created;
      note_read;
      note_resolved;
      note_becomes;
      note_label;
      note_switch;
      note_suspend;
    };
    note_switch ()
end

type event = Event.t

let events () =
  Log.record (Event.Resolves (0, 0, None));
  List.rev !Log.event_log

let to_string e = 
  Event.sexp_of_t e |> Sexplib.Sexp.to_string

let label ?thread name =
  let tid =
    match thread with
    | None -> Lwt.current_id ()
    | Some t -> Lwt.id_of_thread t in
  Log.note_label tid name

let note_suspend = Log.note_suspend
let note_resume = Log.note_switch
