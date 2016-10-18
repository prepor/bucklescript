(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)



type module_info = Binary_ast.module_info 

let bsbuild_cache = ".bsbuild"
let main_ninja = "build.ninja"
let (//) = Filename.concat 
module Flags = struct 
  let bsc = ("bsc", "bsc.exe")
  let bsbuild = ("bsbuild", "bsbuild.exe")
  let package_name = "package-name"
  let bs_package_name = "-bs-package-name"
  let ocamllex = ("ocamllex", "ocamllex.opt")
  let bs_external_includes = "bs-external-includes"
  let bsc_flags = "bsc-flags"
  let file_groups = "file-groups"
  let files = "files"
  let ppx_flags = "ppx-flags"
  let build_output_prefix = ("build-output-prefix", Filename.current_dir_name)
  let static_resources = "static-resources"
end
module String_set = Depend.StringSet 


let dep_lit = " : "
let space = " "
let handle_depfile oprefix (fn : string) : unit = 
  let data = Binary_ast.read_build_cache bsbuild_cache in 
  let op_concat s = match oprefix with None -> s | Some v -> v // s in 
  let deps = 
    match Ext_string.ends_with_then_chop fn Literals.suffix_mlast with 
    | Some  input_file -> 
      let stru  = Binary_ast.read_ast Ml  fn in 
      let s = Ast_extract.read_parse_and_extract Ml_kind stru in 
      String_set.fold
        (fun k acc -> 
           match String_map.find k data with
           | {ml = Ml s | Re s  } 
           | {mll = Some s } 
             -> 
             acc ^ space ^ 
             (op_concat @@ Filename.chop_extension s ^ Literals.suffix_cmj  )
           | {mli = Mli s | Rei s } -> 
             acc ^ space ^  (op_concat @@   Filename.chop_extension s ^ Literals.suffix_cmi)
           | _ -> assert false
           | exception Not_found -> acc 
        ) s ((input_file ^ Literals.suffix_cmj) ^ dep_lit )   
    | None -> 
      begin match Ext_string.ends_with_then_chop fn Literals.suffix_mliast with 
      | Some input_file -> 
        let stri = Binary_ast.read_ast Mli  fn in 
        let s = Ast_extract.read_parse_and_extract Mli_kind stri in 
        String_set.fold
          (fun k acc ->
             match String_map.find k data with 
             | { ml = Ml f | Re f  }
             | { mll = Some f }
             | { mli = Mli f | Rei f } -> 
               acc ^ space ^ (op_concat @@ Filename.chop_extension f ^ Literals.suffix_cmi)
             | _ -> assert false
             | exception Not_found -> acc 
          ) s  ((input_file ^ Literals.suffix_cmi) ^ dep_lit ) 
      | None -> 
        raise (Arg.Bad ("don't know what to do with  " ^ fn))
      end
  in 
  let output = fn ^ Literals.suffix_d in
  Ext_pervasives.with_file_as_chan output  (fun v -> output_string v deps)










(* TODO check duplication *)
let module_info_of_ml exist ml : module_info =
  match exist with 
  | None -> { ml  = Ml ml ; mli = Mli_empty ; mll = None }
  | Some x -> { x with ml = Ml ml}

let module_info_of_re exist ml : module_info =
  match exist with 
  | None -> { ml  = Re ml ; mli = Mli_empty ; mll = None }
  | Some x -> { x with ml = Re ml} 

let module_info_of_mli exist mli : module_info = 
  match exist with 
  | None -> { mli  = Mli mli ; ml = Ml_empty ; mll = None }
  | Some x -> { x with mli = Mli mli} 

let module_info_of_rei exist mli : module_info = 
  match exist with 
  | None -> { mli  = Rei mli ; ml = Ml_empty ; mll = None }
  | Some x -> { x with mli = Rei mli} 

let module_info_of_mll exist mll : module_info = 
  match exist with 
  | None -> { mll  = Some mll ; ml = Ml_empty ; mli = Mli_empty }
  | Some x -> { x with mll = Some mll} 


let map_update ?dir map  name = 
  let prefix  x = match dir with None -> x | Some v -> v // x in
  let module_name = Ext_filename.module_name_of_file name in 
  let aux v name = 
    if Filename.check_suffix name ".ml" then module_info_of_ml v @@ prefix name  else
    if Filename.check_suffix name ".mll" then module_info_of_mll v @@ prefix  name else 
    if Filename.check_suffix name ".mli" then  module_info_of_mli v @@ prefix name else 
    if Filename.check_suffix name ".re" then  module_info_of_re v @@ prefix name else 
    if Filename.check_suffix name ".rei" then  module_info_of_rei v @@ prefix name else 
      assert false   in 
  match String_map.find module_name map with 
  | exception Not_found 
    -> String_map.add module_name (aux None name) map 
  | v -> 
    String_map.add module_name (aux (Some v) name)  map

type ty = 
  | Any
  | String 
  | List of ty

exception Expect of string * ty

let error (x,ty) = raise (Expect (x,ty) )

let expect_string (key, default) (global_data : Sexp_eval.env) =
  match Hashtbl.find global_data key with 
  | exception Not_found -> default
  | Atom s | Lit s -> s 
  | List _ | Data _ -> error (key, String)

let expect_string_opt key (global_data : Sexp_eval.env) =
  match Hashtbl.find global_data key with 
  | exception Not_found -> None
  | Atom s | Lit s -> Some s 
  | List _ | Data _ -> error (key, String)

let expect_string_list key (global_data : Sexp_eval.env) = 
  match Hashtbl.find global_data key  with 
  | exception Not_found -> [ ]
  | Atom _ | Lit _ | Data _ -> error(key, List String)
  | List xs -> 
    Ext_list.filter_map (fun x -> 
        match  x with 
        | Sexp_lexer.Atom x | Lit x -> Some x 
        | _ -> None 
      ) xs 

let expect_string_list_unordered 
  key 
  (global_data : Sexp_eval.env) 
  init update = 
  match Hashtbl.find global_data Flags.files with 
  | exception Not_found -> init
  | Atom _ | Lit _ 
  | Data _ -> error(key, List String)
  | List files -> 
    List.fold_left (fun acc s ->
        match s with 
        | Sexp_lexer.Atom s | Lit s -> update acc s 
        | _ -> acc (* raise Type error *)
      ) init files 

type 'a file_group = 
  { dir : string ;
    sources : 'a
  } 
let rec expect_file_groups  key (global_data : Sexp_eval.env) =
  match Hashtbl.find global_data key with 
  | exception Not_found -> []
  | Atom _ | Lit _ 
  | Data _ -> error (key, List Any)
  | List ls -> List.map expect_file_group  ls 

and expect_file_group (x : Sexp_lexer.t)  =
  match x with 
  | List [ List [ Atom "dir"; Lit dir ] ; List [ Atom "sources";  List files] ] -> 
    { dir ; 
      sources = List.fold_left (fun acc s ->
        match s with 
        | Sexp_lexer.Atom s | Lit s -> map_update ~dir  acc s 
        | _ -> acc (* raise Type error *)
      ) String_map.empty files
    }

  | _ -> error ("", List Any)

let output_ninja (global_data : Sexp_eval.env)  = 
  let bsc = expect_string Flags.bsc global_data in 
  let bsbuild = expect_string Flags.bsbuild global_data in 
  let package_name = expect_string_opt Flags.package_name global_data in 
  let ocamllex = expect_string Flags.ocamllex global_data in 
  let build_output_prefix = expect_string Flags.build_output_prefix global_data in 
  let bs_external_includes =
    expect_string_list Flags.bs_external_includes  global_data in 
  let static_resources = 
    expect_string_list Flags.static_resources global_data in

  let bs_file_groups = expect_file_groups Flags.file_groups global_data
  in  
  (* let bs_files = expect_string_list_unordered Flags.files global_data String_map.empty map_update in *)
  let bs_files, source_dirs  = List.fold_left (fun (acc,dirs) {sources ; dir } -> 
      String_map.merge (fun modname k1 k2 ->
          match k1 , k2 with
          | None , None 
          | Some _, Some _  -> assert false 
          | Some v, None  -> Some v 
          | None, Some v ->  Some v 
        ) acc  sources , dir::dirs
    ) (String_map.empty,[]) bs_file_groups in
  Binary_ast.write_build_cache bsbuild_cache bs_files ;

  let ppx_flags = 
    String.concat space @@
      Ext_list.flat_map (fun x -> ["-ppx";  x ])  @@
    expect_string_list Flags.ppx_flags global_data in 
  let bsc_computed_flags =
    let internal_includes =
      source_dirs
      |> Ext_list.flat_map (fun x -> ["-I" ; build_output_prefix // x ]) in 
    let external_includes = 
      Ext_list.flat_map (fun x -> ["-I" ; x]) bs_external_includes in 
    let init_flags = 
      match package_name with 
      | None -> external_includes @ internal_includes 
      | Some x -> Flags.bs_package_name ::  x :: external_includes @ internal_includes
    in 
    let bsc_flags = expect_string_list Flags.bsc_flags global_data in 
    String.concat " " ( bsc_flags @ init_flags)
  in
  let oc = open_out main_ninja in 
  begin 
    let all_deps = ref [] in
    let all_cmis = ref [] in 
    let () = 
      output_string oc "bsc = "; output_string oc bsc ; output_string oc "\n";
      output_string oc "bsc_computed_flags = "; output_string oc bsc_computed_flags ; output_string oc "\n";
      output_string oc "bsbuild = "; output_string oc bsbuild ; output_string oc "\n";
      output_string oc "ocamllex = "; output_string oc ocamllex ; output_string oc "\n";
      output_string oc "ppx_flags = "; output_string oc ppx_flags ; output_string oc "\n";
      output_string oc "build_output_prefix = "; output_string oc build_output_prefix ; output_string oc "\n";
      output_string oc "builddir = "; output_string oc build_output_prefix ; output_string oc "\n";
      output_string oc {|
rule build_ast
  command = ${bsc} ${pp_flags} ${ppx_flags} ${bsc_computed_flags} -c -o ${out} -bs-syntax-only -bs-binary-ast ${in}
  description = Building ast  ${out}
rule build_ast_from_reason_impl
  command = ${bsc} -pp refmt ${ppx_flags} ${bsc_computed_flags} -c -o ${out} -bs-syntax-only -bs-binary-ast -impl ${in}     
  description = Building ast from reason re ${out}
rule build_ast_from_reason_intf
  command = ${bsc} -pp refmt ${ppx_flags} ${bsc_computed_flags} -c -o ${out} -bs-syntax-only -bs-binary-ast -intf ${in}        
  description = Building ast from reason rei  ${out}

rule build_deps
  command = ${bsbuild} -oprefix ${build_output_prefix}  -bs-depfile ${in}
  description = Building deps ${out}

rule build_ml_from_mll
  command = ${ocamllex} -o ${out} ${in}
  description = Building ml from ml - ${in}
# this rule has multiple output        
rule build_cmj_only
  depfile = ${in}.d
  command = ${bsc} -bs-no-builtin-ppx-ml -bs-no-implicit-include ${bsc_computed_flags} -o ${in} -c -impl ${in}
  description = Building cmj - ${out}

# TODO: Windows path concat 
rule build_cmj_cmi
  depfile = ${in}.d
  command = ${bsc} -bs-assume-no-mli -bs-no-implicit-include -bs-no-builtin-ppx-ml ${bsc_computed_flags} -o ${in} -c -impl ${in}
  description = Building cmj and cmi - ${out}

rule build_cmi
  depfile = ${in}.d
  command = ${bsc} -bs-no-builtin-ppx-mli -bs-no-implicit-include ${bsc_computed_flags} -o ${out} -c -intf ${in}
  description = Building cmi - ${out}
|};
    if static_resources <> []   then 
      output_string oc {|
rule copy_resources
  command = cp ${in}  ${out}
  description = Copying ${in} into ${out}
|}
    in

    bs_files
    |> String_map.iter (fun module_name ({mli; ml; mll } : module_info) -> 
        let spit_out_ml (kind : [`Ml | `Re ])  file filename_sans_extension = 
          if kind = `Ml then 
            output_string oc 
              (Printf.sprintf "build %s.mlast : build_ast %s\n" 
                 (build_output_prefix // filename_sans_extension) file)
          else 
            output_string oc (Printf.sprintf "build %s.mlast : build_ast_from_reason_impl %s\n"
                                (build_output_prefix // filename_sans_extension) file)
          ;
          output_string oc (Printf.sprintf "build %s.mlast.d : build_deps %s.mlast\n" 
                              (build_output_prefix // filename_sans_extension)
                              (* output should always be marked explicitly,
                                 otherwise the build system can not figure out clearly
                                 however, for the command we don't need pass `-o`
                              *)
                              (build_output_prefix // filename_sans_extension));
          all_deps := (build_output_prefix // filename_sans_extension ^ Literals.suffix_mlastd) :: !all_deps;
          let rule_name , output, deps = 
            let cmi_file =
              build_output_prefix // filename_sans_extension ^ Literals.suffix_cmi
            in
            if mli = Mli_empty then "build_cmj_only",  cmi_file  , ""
            else "build_cmj_cmi", "", cmi_file  in  
          output_string oc 
            (Printf.sprintf "build %s.cmj %s : %s %s.mlast |  %s\n"
               (build_output_prefix // filename_sans_extension)
               output
               rule_name 
               (build_output_prefix // filename_sans_extension)
               deps
            ) in 

        begin match ml with 
          | Ml ml_file -> 
            let filename_sans_extension = Filename.chop_extension ml_file in 
            spit_out_ml `Ml ml_file filename_sans_extension
          | Re re_file -> 
            let filename_sans_extension = Filename.chop_extension re_file in 
            spit_out_ml `Re re_file filename_sans_extension

          | Ml_empty -> () end;
        let spit_out_mli (kind : [`Mli | `Rei ])  mli_file filename = 
          if kind = `Mli then 
            output_string oc (Printf.sprintf "build %s.mliast : build_ast %s\n" 
                                (build_output_prefix // filename)
                                ( mli_file))
          else
            output_string oc (Printf.sprintf "build %s.mliast : build_ast_from_reason_intf %s\n" 
                                (build_output_prefix // filename) 
                                ( mli_file));
          output_string oc (Printf.sprintf "build %s.mliast.d : build_deps %s.mliast\n"
                              (build_output_prefix // filename )
                              (build_output_prefix // filename));
          output_string oc (Printf.sprintf "build %s.cmi : build_cmi %s.mliast | %s.mliast.d\n"
                              (build_output_prefix // filename)
                              (build_output_prefix // filename)
                              (build_output_prefix // filename)
                           );
          all_cmis := (build_output_prefix // filename ^  Literals.suffix_cmi) :: !all_cmis ; 
          all_deps :=  build_output_prefix // (filename ^ Literals.suffix_mliastd) :: !all_deps in 

        begin match mli with 
          | Mli mli_file  -> 
            let filename = Filename.chop_extension mli_file in 
            spit_out_mli `Mli mli_file filename
          | Rei rei_file -> 
            let filename = Filename.chop_extension rei_file in 
            spit_out_mli `Rei rei_file filename
          | Mli_empty -> ()
        end;
        begin match mll with 
          | Some mll_file -> 
            (* if ml already exists then no need generate same *)
              let filename = Filename.chop_extension mll_file in
              if ml = Ml_empty then 
                spit_out_ml `Ml (filename ^ Literals.suffix_ml) filename;
              output_string oc (Printf.sprintf "build %s.ml : build_ml_from_mll %s.mll\n"
                                  (build_output_prefix // filename)
                                  filename);
              (* actually we would prefer generators in source ?
                 generator are divided into two categories:
                 1. not system dependent (ocamllex,ocamlyacc)
                 2. system dependent - has to be run on client's machine
              *)
          | None -> ()
        end
      );
    static_resources 
    |> List.iter (fun x -> 
        output_string oc 
          (Printf.sprintf "build %s : copy_resources %s\n"
             (build_output_prefix // x) x 
          );
        all_deps := (build_output_prefix // x) :: !all_deps
      )
    ;
    output_string oc  {|
rule reload
      command = ${bsbuild} -init
|};
    output_string oc (Printf.sprintf "build build.ninja : reload | bs.el\n" );

    output_string oc (Printf.sprintf "build config : phony %s\n" 
                        (String.concat " "   !all_deps)) ;
    output_string oc (Printf.sprintf "build cmis : phony %s\n"
                        (String.concat " " !all_cmis)
                     );
    close_out oc;
  end

let write_ninja_file () = 
  let global_data = Sexp_eval.eval_file "bs.el" in 
  output_ninja global_data 

let load_ninja = ref false

let ninja = "ninja" 
let load_ninja ninja_flags = 

  Unix.execvp ninja
    (Array.concat 
       [
         [|ninja ; "-d"; "keepdepfile"|];
         ninja_flags
       ]
    )
let call_ninja flags = 
  Sys.command 
    (String.concat " " (ninja :: "-d" :: "keepdepfile":: flags))
let output_prefix = ref None
let bsninja_flags =
  [
    "-bs-depfile", Arg.String (fun x -> handle_depfile !output_prefix x)  ,
    " generate deps file for ml";
    "-oprefix", Arg.String (fun x -> output_prefix := Some x),
    " set output prefix";
    "-init", Arg.Unit write_ninja_file,
    " generate build.ninja";
    (* "--", Arg.Rest collect_ninja_flags, *)
    (* " flags passed to ninja" *)
 ]

let usage = {|Usage: bsbuild.exe <options> <files>
Options are:|}

let anonymous arg =
  raise (Arg.Bad ("don't know what to do with " ^ arg))

let () = 
  try 
    begin match Ext_array.rfind_and_split Sys.argv Ext_string.equal "-" with 
      | `No_split ->       
        begin 
          Arg.parse_argv Sys.argv  bsninja_flags anonymous usage;
          (* load_ninja [| "config" |] *)
          (* Here the failure will cause non-terminating, since 
             [bsbuild.exe -init] fail, it will retry again
          *)
        end
      | `Split (bsninja_argv, ninja_flags) 
        -> 
        Arg.parse_argv bsninja_argv bsninja_flags anonymous usage;
        let exit_flag = call_ninja ["config"]  in
        if exit_flag <> 0 then 
          begin
            exit exit_flag 
          end; 
        load_ninja ninja_flags
    end
  with x ->
    begin
      Location.report_exception Format.err_formatter x ;
      exit 2
    end





