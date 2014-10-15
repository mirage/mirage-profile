open Assemblage

let profiling_enabled =
  Features.create "lwt-tracing"
    ~doc:"Use Lwt tracing support. If false, we just compile dummy stubs."

let profile_ml = unit ~available:profiling_enabled "profile" (`Path []) ~deps:[
  pkg_pp "sexplib.syntax";
  pkg "sexplib";
  pkg "lwt";
]

let profile = lib "mirage-profile" (`Units [profile_ml])
let () = assemble (project ~version:"0.1" "mirage-profile" [profile])
