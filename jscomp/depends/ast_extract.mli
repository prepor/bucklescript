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




type _ kind =
  | Ml_kind : Parsetree.structure kind
  | Mli_kind : Parsetree.signature kind






module String_set = Depend.StringSet

val read_parse_and_extract : 'a kind -> 'a -> String_set.t

type ('a,'b) t 

val sort_files_by_dependencies :
  domain:String_set.t -> String_set.t String_map.t -> string Queue.t


val sort :
  ('a -> Parsetree.structure) ->
  ('b -> Parsetree.signature) ->
  ('a, 'b) t String_map.t -> string Queue.t  



(**
   [build fmt files parse_implementation parse_interface]
   Given a list of files return an ast table 
*)
val collect_ast_map :
  Format.formatter ->
  string list ->
  (Format.formatter -> string -> 'a) ->
  (Format.formatter -> string -> 'b) ->
  ('a, 'b) t String_map.t


val collect_from_main :
  ?extra_dirs:[`Dir of string  | `Dir_with_excludes of string * string list] list -> 
  ?excludes : string list -> 
  Format.formatter ->
  (Format.formatter -> string -> 'a) ->
  (Format.formatter -> string -> 'b) ->
  ('a -> Parsetree.structure) ->
  ('b -> Parsetree.signature) ->
  string -> ('a, 'b) t String_map.t * string Queue.t

val build_queue :
  Format.formatter ->
  string Queue.t ->
  ('b, 'c) t String_map.t ->
  (Format.formatter -> string -> string -> 'b -> unit) ->
  (Format.formatter -> string -> string -> 'c -> unit) -> unit
  
val handle_queue :
  Format.formatter ->
  String_map.key Queue.t ->
  ('a, 'b) t String_map.t ->
  (string -> string -> 'a -> unit) ->
  (string -> string -> 'b  -> unit) ->
  (string -> string -> string -> 'b -> 'a -> unit) -> unit


val build_lazy_queue :
  Format.formatter ->
  string Queue.t ->
  (Parsetree.structure lazy_t, Parsetree.signature lazy_t) t String_map.t ->
  (Format.formatter -> string -> string -> Parsetree.structure -> unit) ->
  (Format.formatter -> string -> string -> Parsetree.signature -> unit) -> unit  
