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
  (* Following LTT, our trace buffer is divided into a small number of
   * fixed-sized "packets", each of which contains many events. When there
   * isn't room in the current packet for the next event, we move to the next
   * packet. This wastes a few bytes at the end of each packet, but it allows
   * us to discard whole packets at a time when we need to overwrite something.
   *)
  type t = {
    log : log_buffer;
    bits_used : int array;        (* One entry per packet, set when packet is complete. *)
    packet_size : int;
    mutable next_event : int;     (* Index to write next event *)
    mutable packet_end : int;
    mutable consumer_next : int;  (* Next index to send to consumer *)
    mutable consumer_reading : bool;  (* Packet containing [consumer_next] is locked. *)
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

  (* The current packet is full. Move to the next one.
   * If consumer_next is in the next packet then:
   * - if the consumer is currently reading it, skip it.
   * - otherwise, advance consumer_next (packet is lost) *)
  let rec next_packet log =
    if log.packet_end = Array1.dim log.log then
      log.packet_end <- log.packet_size
    else
      log.packet_end <- log.packet_end + log.packet_size;
    let packet_start = log.packet_end - log.packet_size in
    log.next_event <- packet_start;
    (* Check if the new packet is being consumed. *)
    let consumer_i = log.consumer_next in
    if consumer_i >= packet_start && consumer_i < log.packet_end then (
      if log.consumer_reading then
        next_packet log
      else
        log.consumer_next <- log.packet_end mod Array1.dim log.log
    )

  let rec add_event log op len =
    (* Note: be careful about allocation here, as doing GC will add another event... *)
    let i = log.next_event in
    let new_i = i + 9 + len in
    (* >= rather than > is slightly wasteful, but avoids next_event overlapping the next packet *)
    if new_i >= log.packet_end then (
      (* Printf.printf "can't write %d at %d\n%!" (9 + len) i; *)
      assert (new_i - i < log.packet_size);
      let packet_start = log.packet_end - log.packet_size in
      log.bits_used.(packet_start / log.packet_size) <- (i - packet_start) * 8;
      next_packet log;
      add_event log op len
    ) else (
      (* Printf.printf "writing at %d\n%!" i; *)
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

  let magic = 0xc1fc1fc1l
  let uuid = "\x05\x88\x3b\x8d\x52\x1a\x48\x7b\xb3\x97\x45\x6a\xb1\x50\x68\x0c"

  let make ~size () =
    let n_packets = 4 in
    let packet_size = size / n_packets in
    let log = Array1.create char c_layout (n_packets * packet_size) in
    {
      log;
      bits_used = Array.make n_packets 0;
      packet_size;
      next_event = 0;
      packet_end = packet_size;
      consumer_next = 0;
      consumer_reading = false;
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

  cstruct packet_header {
    uint32_t magic;
    uint8_t  uuid[16];
    uint32_t size;
  } as little_endian
  let () =
    ignore (copy_packet_header_uuid, hexdump_packet_header, blit_packet_header_uuid)

  let dump log fn =
    let open Lwt in
    let rec dump_packets () =
      (* Called with consumer_reading=true, so log.consumer_next won't move,
       * even if extra events get added (through GC or the [fn] callback).
       * We might add more events to the packet, but the existing ones won't
       * get overwritten. *)

      let header = Cstruct.create sizeof_packet_header in
      set_packet_header_magic header magic;
      set_packet_header_uuid uuid 0 header;

      let dump_start = log.consumer_next in
      let consumer_packet = dump_start / log.packet_size in
      let consumer_packet_start = consumer_packet * log.packet_size in
      let consumer_packet_end = consumer_packet_start + log.packet_size in
      let producer_i = log.next_event in
      let dumping_active = producer_i >= consumer_packet_start && producer_i < consumer_packet_end in
      let buffer_size =
        if dumping_active then producer_i - dump_start
        else log.bits_used.(consumer_packet) / 8 in
      let buffer_size_bits = Int32.of_int ((sizeof_packet_header + buffer_size) * 8) in
      (* babeltrace doesn't like it if the packet is incomplete *)
      set_packet_header_size header buffer_size_bits;
      (* Printf.printf "dumping %d + %d\n%!" dump_start buffer_size; *)
      let buffer = Array1.sub log.log dump_start buffer_size in
      fn (Cstruct.to_bigarray header) buffer >>= fun () ->
      log.consumer_next <-
        if dumping_active then producer_i
        else (dump_start + log.packet_size) mod Array1.dim log.log;
      if dumping_active then return ()
      else dump_packets ()
    in
    assert (log.consumer_reading = false);
    log.consumer_reading <- true;
    finalize dump_packets
      (fun () -> log.consumer_reading <- false; return ())
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
