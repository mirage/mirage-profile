open Ocamlbuild_plugin

(* Copied from mtime *)
(* The "--no-as-needed" thing seems to be required on Ubuntu 12.04.
   See: https://github.com/mirage/mirage-skeleton/pull/135 *)
let os = Ocamlbuild_pack.My_unix.run_and_read "uname -s"
let system_support_lib = match os with
| "Linux\n" -> [A "-cclib"; A "-Wl,--no-as-needed"; A "-cclib"; A "-lrt"]
| _ -> []

(* Copied from cppo *)
let cppo_rules use_tracing ext =
  let dep   = "%(name).cppo"-.-ext
  and prod1 = "%(name: <*> and not <*.cppo>)"-.-ext
  and prod2 = "%(name: <**/*> and not <**/*.cppo>)"-.-ext in
  let cppo_rule prod env _build =
    let dep = env dep in
    let prod = env prod in
    let tags = tags_of_pathname prod ++ "cppo" in
    let tracing = if use_tracing then S [A "-D"; A "USE_TRACING"] else S [] in
    Cmd (S[A "cppo"; T tags; S [A "-o"; P prod];  tracing ; P dep ])
  in
  rule ("cppo: *.cppo."-.-ext^" -> *."-.-ext)  ~dep ~prod:prod1 (cppo_rule prod1);
  rule ("cppo: **/*.cppo."-.-ext^" -> **/*."-.-ext)  ~dep ~prod:prod2 (cppo_rule prod2)

let dispatcher_cppo use_tracing =
      List.iter (cppo_rules use_tracing) ["ml"; "mli"]

let () =
  Ocamlbuild_plugin.dispatch (fun e ->
    (* Detect whether lwt.tracing is available. *)
    let use_tracing =
      match Unix.system("ocamlfind query lwt.tracing > /dev/null 2>&1") with
      | Unix.WEXITED 0 -> true
      | Unix.WEXITED _ -> false
      | _ -> failwith "ocamlfind failed!" in
    begin match e with
    | Before_options ->
        Printf.printf "lwt.tracing available: %b\n" use_tracing;
        ()
    | After_rules ->
        flag ["link"; "link_unix"] (S [S system_support_lib ; A "-cclib"; A "-ltime_stubs"; A "-I" ; P "unix"] );
        dep [ "link"; "link_unix"] ["unix/libtime_stubs.a"];
        dispatcher_cppo use_tracing
    | _ -> ()
    end;
  )
