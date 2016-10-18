let suites :  Mt.pair_suites ref  = ref []
let test_id = ref 0
let eq loc x y = 
  incr test_id ; 
  suites := 
    (loc ^" id " ^ (string_of_int !test_id), (fun _ -> Mt.Eq(x,y))) :: !suites




let _ : _ Js.undefined = 
  Js.Undefined.bind [%node __dirname] (fun [@bs] p ->
      let root = App_root_finder.find_package_json p in
      let bsc_exe = 
        Node.Path.join 
          [| root ; "jscomp";  "bin"; "bsc.exe" |] in 

      match Node.Child_process.execSync 
              (bsc_exe ^ " -where ") 
              (Node.Child_process.option  ~encoding:"utf8" ()) with 
      | output -> 
        let dir = Js.String.trim output in 
        let files = Node.Fs.readdirSync dir  in
        let exists = 
          files 
          |> Js.Array.indexOf "pervasives.cmi" in 
        let non_exists = 
          files 
          |> Js.Array.indexOf "pervasive.cmi" in 
        let v = (exists >= 0 && non_exists < 0) in
        Js.log v;
        eq __LOC__  v true
      | exception e -> 
        assert false
    )

let () = 
  Mt.from_pair_suites __FILE__ !suites
