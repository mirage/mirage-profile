(* Copyright (C) 2014, Thomas Leonard *)

(** This is the [Trace] module when we're compiled with tracing support. *)

open Bigarray

type log_buffer = (char, int8_unsigned_elt, c_layout) Array1.t

external timestamp : log_buffer -> int -> unit = "stub_mprof_get_monotonic_time"

let current_thread = ref (-1L)

let int_of_thread_type t =
  let open Lwt_tracing in
  match t with
  | Wait -> 0
  | Task -> 1
  | Bind -> 2
  | Try -> 3
  | Choose -> 4
  | Pick -> 5
  | Join -> 6
  | Map -> 7
  | Condition -> 8

module Control = struct
  type t = {
    log : log_buffer;
    mutable next_event : int;
  }

  let event_log = ref None

  let stop log =
    if Some log <> !event_log then
      failwith "Log is not currently tracing!";
    Lwt_tracing.tracer := Lwt_tracing.null_tracer;
    event_log := None

  let op_creates = 0
  let op_read = 1
  let op_fulfills = 2
  let op_fails = 3
  let op_becomes = 4
  let op_label = 5
  let op_increase = 6
  let op_switch = 7
  let op_gc = 8

  let write64 log v i =
    EndianBigstring.LittleEndian.set_int64 log i v;
    i + 8

  let write8 log v i =
    EndianBigstring.LittleEndian.set_int8 log i v;
    i + 1

  let write_string log v i =
    let l = String.length v in
    for idx = 0 to l - 1 do
      Array1.set log (i + idx) v.[idx]
    done;
    Array1.set log (i + l) '\x00';
    i + l + 1

  let rec add_event log op len =
    let i = log.next_event in
    let new_i = i + 9 + len in
    if new_i > Array1.dim log.log then (
      log.next_event <- 0;
      add_event log op len
    ) else (
      log.next_event <- new_i;
      timestamp log.log i;
      i + 8 |> write8 log.log op
    )

  (* This is faster than [let end_event = ignore]! *)
  external end_event : int -> unit = "%ignore"
(*
  let end_event i =
    match !event_log with
    | None -> assert false
    | Some log -> assert (i = log.next_event || log.next_event = 0)
*)

  let note_created log child thread_type =
    add_event log op_creates 17
    |> write64 log.log !current_thread
    |> write64 log.log child
    |> write8  log.log (int_of_thread_type thread_type)
    |> end_event

  let note_read log input =
    let new_current = Lwt.current_id () in
    (* (avoid expensive caml_modify call if possible) *)
    if new_current <> !current_thread then current_thread := new_current;
    if !current_thread <> input then (
      add_event log op_read 16
      |> write64 log.log !current_thread
      |> write64 log.log input
      |> end_event
    )

  let note_resolved log p ~ex =
    match ex with
    | Some ex ->
        let msg = Printexc.to_string ex in
        add_event log op_fails (17 + String.length msg)
        |> write64 log.log !current_thread
        |> write64 log.log p
        |> write_string log.log msg
        |> end_event
    | None ->
        add_event log op_fulfills 16
        |> write64 log.log !current_thread
        |> write64 log.log p
        |> end_event

  let note_becomes log input main =
    if main <> input then (
      add_event log op_becomes 16
      |> write64 log.log input
      |> write64 log.log main
      |> end_event
    )

  let note_label log thread msg =
    add_event log op_label (9 + String.length msg)
    |> write64 log.log thread
    |> write_string log.log msg
    |> end_event

  let note_increase log counter amount =
    add_event log op_increase (17 + String.length counter)
    |> write64 log.log !current_thread
    |> write64 log.log (Int64.of_int amount)
    |> write_string log.log counter
    |> end_event

  let note_switch log () =
    let id = Lwt.current_id () in
    if id <> !current_thread then (
      current_thread := id;
      add_event log op_switch 8
      |> write64 log.log id
      |> end_event
    )

  let note_suspend log () =
    current_thread := (-1L);
    add_event log op_switch 8
    |> write64 log.log (-1L)
    |> end_event

  let note_gc duration =
    match !event_log with
    | None -> ()
    | Some log ->
        add_event log op_gc 8
        |> write64 log.log (duration *. 1000000000. |> Int64.of_float)
        |> end_event

  let make ~size () = {
      log = Array1.create char c_layout size;
      next_event = 0;
    }

  let start log =
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
    Callback.register "MProf.Trace.note_gc" note_gc

  let dump log fn =
    (* TODO: flag for copy *)
    let buffer = Array1.sub log.log 0 (log.next_event) in
    fn buffer
end

let label name =
  match !Control.event_log with
  | None -> ()
  | Some log -> Control.note_label log (Lwt.current_id ()) name

let note_suspend () =
  match !Control.event_log with
  | None -> ()
  | Some log -> Control.note_suspend log ()

let note_resume () =
  match !Control.event_log with
  | None -> ()
  | Some log -> Control.note_switch log ()

let note_increase counter amount =
  match !Control.event_log with
  | None -> ()
  | Some log -> Control.note_increase log counter amount

let named_condition label =
  Lwt_condition.create ~label ()

let named_wait label =
  let pair = Lwt.wait () in
  begin match !Control.event_log with
  | None -> ()
  | Some log -> Control.note_label log (Lwt.id_of_thread (fst pair)) label end;
  pair

let named_task label =
  let pair = Lwt.task () in
  begin match !Control.event_log with
  | None -> ()
  | Some log -> Control.note_label log (Lwt.id_of_thread (fst pair)) label end;
  pair
