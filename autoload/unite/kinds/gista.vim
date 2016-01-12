let s:save_cpo = &cpo
set cpo&vim

let s:V = gista#vital()
let s:D = s:V.import('Data.Dict')

let s:orig = unite#kinds#file_base#define()
let s:kind = {
      \ 'name': 'gista',
      \ 'parents': [
      \   'openable',
      \   'uri',
      \ ],
      \ 'default_action': 'narrow',
      \ 'alias_table' : { 'edit' : 'narrow' },
      \ 'action_table': s:D.pick(s:orig.action_table, [
      \   'open',
      \   'preview',
      \   'read',
      \   'diff',
      \ ]),
      \}
let s:actions = s:kind.action_table

let s:actions.narrow = {}
let s:actions.narrow.description = 'narrow the selected gist'
let s:actions.narrow.is_quit = 0
let s:actions.narrow.is_start = 1
function! s:actions.narrow.func(candidate) abort
  let context = {}
  let context.action__entry = a:candidate.source__entry
  call unite#start_temporary([['gista/file']], context)
endfunction

let s:actions.delete = {}
let s:actions.delete.description = 'delete the selected gist'
let s:actions.delete.is_quit = 0
let s:actions.delete.is_invalidate_cache = 1
let s:actions.delete.is_selectable = 1
function! s:actions.delete.func(candidates) abort
  for candidate in a:candidates
    let options = {
          \ 'gist': candidate.source__entry,
          \}
    call gista#command#delete#call(options)
  endfor
endfunction

let s:actions.fork = {}
let s:actions.fork.description = 'fork the selected gist'
let s:actions.fork.is_quit = 0
let s:actions.fork.is_invalidate_cache = 1
let s:actions.fork.is_selectable = 1
function! s:actions.fork.func(candidates) abort
  for candidate in a:candidates
    let options = {
          \ 'gist': candidate.source__entry,
          \}
    call gista#command#fork#call(options)
  endfor
endfunction

let s:actions.star = {}
let s:actions.star.description = 'star the selected gist'
let s:actions.star.is_quit = 0
let s:actions.star.is_invalidate_cache = 1
let s:actions.star.is_selectable = 1
function! s:actions.star.func(candidates) abort
  for candidate in a:candidates
    let options = {
          \ 'gist': candidate.source__entry,
          \}
    call gista#command#star#call(options)
  endfor
endfunction

let s:actions.unstar = {}
let s:actions.unstar.description = 'unstar the selected gist'
let s:actions.unstar.is_quit = 0
let s:actions.unstar.is_invalidate_cache = 1
let s:actions.unstar.is_selectable = 1
function! s:actions.unstar.func(candidates) abort
  for candidate in a:candidates
    let options = {
          \ 'gist': candidate.source__entry,
          \}
    call gista#command#unstar#call(options)
  endfor
endfunction

function! unite#kinds#gista#define() abort
  return s:kind
endfunction
call unite#define_kind(s:kind)

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
