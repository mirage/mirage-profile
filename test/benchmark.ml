open Lwt

let c = MProf.Counter.make ~name:"counter"

let plain_lwt () =
  let t1, w1 = Lwt.wait () in
  let t2, w2 = Lwt.task () in
  let b1 = t1 >>= fun () -> t2 in
  Lwt.wakeup w1 ();
  Lwt.wakeup w2 ();
  MProf.Counter.increase c 1;
  b1

let profile_lwt () =
  let t1, w1 = MProf.Trace.named_wait "Bob" in
  let t2, w2 = MProf.Trace.named_task "Fred" in
  let b1 = t1 >>= fun () -> t2 in
  Lwt.wakeup w1 ();
  Lwt.wakeup w2 ();
  MProf.Counter.increase c 1;
  b1

let test ~name fn =
  Gc.full_major ();
  let rec aux = function
    | 0 -> Lwt.return ()
    | i -> fn () >>= fun () -> aux (i -1) in
  let n = 1000000 in
  let t0 = Unix.gettimeofday () in
  Lwt_unix.run (aux n);
  let t1 = Unix.gettimeofday () in
  let time = t1 -. t0 in
  Printf.printf "%s: %f ns/run\n" name (1_000_000_000. *. time /. float_of_int n)

let () =
  print_endline "Tracing OFF";
  test ~name:"plain_lwt:off" plain_lwt;
  test ~name:"profile_lwt:off" profile_lwt;

  print_endline "Tracing ON";
  MProf.Trace.Control.start ~size:1000000;
  test ~name:"plain_lwt:on" plain_lwt;
  test ~name:"profile_lwt:on" profile_lwt;

(*
  let buffer = MProf.Trace.Control.stop () in
  let ch = open_out "example/trace.bin" in
  for i = 0 to Bigarray.Array1.dim buffer - 1 do
    output_char ch (Bigarray.Array1.get buffer i);
  done;
  close_out ch
*)
