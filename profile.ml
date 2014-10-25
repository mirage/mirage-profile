(* Copyright (C) 2014, Thomas Leonard *)

open Sexplib.Std

external timestamp : unit -> float = "unix_gettimeofday"

type thread_id = int with sexp

let current_thread = ref (-1)

module Event = struct
  type thread_type = Lwt_tracing.thread_type

  let sexp_of_thread_type t =
    let open Lwt_tracing in
    Sexplib.Sexp.Atom begin match t with
    | Wait -> "Wait"
    | Task -> "Task"
    | Bind -> "Bind"
    | Try -> "Try"
    | Choose -> "Choose"
    | Pick -> "Pick"
    | Join -> "Join"
    | Map -> "Map"
    | Condition -> "Condition"
    end

  let thread_type_of_sexp _ = assert false

  type time = float

  (* sexp_of_float uses strtod which we don't have yet on Xen. *)
  let sexp_of_time f = Printf.sprintf "%.15f" f |> sexp_of_string
  let time_of_sexp _ = assert false

  type op = 
    | Creates of thread_id * thread_id * thread_type
    | Reads of thread_id * thread_id
    | Resolves of thread_id * thread_id * string option
    | Becomes of thread_id * thread_id
    | Label of thread_id * string
    | Switch of thread_id
    | Gc of time
    | Increases of thread_id * string * int
    with sexp

  type t = {
    time : time;
    op : op;
  } with sexp
end

module Log = struct
  open Event

  type t = {
    log : Event.t array;
    mutable last_event : int;
    mutable did_loop : bool;    (* (first event is at last_event + 1) *)
  }

  let event_log = ref None

  let stop () =
    Lwt_tracing.tracer := Lwt_tracing.null_tracer;
    event_log := None

  let record log op =
    let next_index = log.last_event + 1 in
    let next_index =
      if next_index >= Array.length log.log then (
        log.did_loop <- true;
        0
      ) else next_index in
    log.last_event <- next_index;
    let time = timestamp () in
    log.log.(next_index) <- {time; op}

  let note_created log child thread_type =
    Creates (!current_thread, child, thread_type) |> record log

  let note_read log input =
    current_thread := Lwt.current_id ();
    if !current_thread <> input then
      Reads (!current_thread, input) |> record log

  let note_resolved log p ~ex =
    let msg =
      match ex with
      | Some ex -> Some (Printexc.to_string ex)
      | None -> None in
    Resolves (!current_thread, p, msg) |> record log

  let note_becomes log input main =
    if main <> input then
      Becomes (input, main) |> record log

  let note_label log thread label =
    Label (thread, label) |> record log

  let note_increase log counter amount =
    Increases (!current_thread, counter, amount) |> record log

  let note_switch log () =
    let id = Lwt.current_id () in
    if id <> !current_thread then (
      current_thread := id;
      Switch id |> record log
    )

  let note_suspend log () =
    current_thread := (-1);
    Switch (-1) |> record log

  let note_gc duration =
    match !event_log with
    | None -> ()
    | Some log -> Gc duration |> record log

  let start ~size =
    let log = {
      log = Array.make size {time = 0.0; op = Gc 0.};
      last_event = -1;
      did_loop = false;
    } in
    event_log := Some log;
    Lwt_tracing.tracer := { Lwt_tracing.
      note_created = note_created log;
      note_read = note_read log;
      note_resolved = note_resolved log;
      note_becomes = note_becomes log;
      note_label = note_label log;
      note_switch = note_switch log;
      note_suspend = note_suspend log;
    };
    note_switch log ()

  let () =
    Callback.register "Profile.note_gc" note_gc
end

type event = Event.t

let events () =
  let open Log in
  match !event_log with
  | None -> failwith "no event log!"
  | Some event_log ->
      let first_event = if event_log.did_loop then event_log.last_event + 1 else 0 in
      let ring_size = Array.length event_log.log in
      let n_events = if event_log.did_loop then ring_size else event_log.last_event + 1 in
      Array.init n_events (fun i ->
        let i = i + first_event in
        let i = if i >= ring_size then i - ring_size else i in
        event_log.log.(i)
      )

let start ~size =
  Log.start ~size

let stop () =
  let trace = events () in
  Log.stop ();
  trace

let to_string e = 
  Event.sexp_of_t e |> Sexplib.Sexp.to_string

let label ?thread name =
  match !Log.event_log with
  | None -> ()
  | Some log ->
      let tid =
        match thread with
        | None -> Lwt.current_id ()
        | Some t -> Lwt.id_of_thread t in
      Log.note_label log tid name

let note_suspend () =
  match !Log.event_log with
  | None -> ()
  | Some log -> Log.note_suspend log ()

let note_resume () =
  match !Log.event_log with
  | None -> ()
  | Some log -> Log.note_switch log ()

let note_increase counter amount =
  match !Log.event_log with
  | None -> ()
  | Some log -> Log.note_increase log counter amount

let named_condition label =
  Lwt_condition.create ~label ()
