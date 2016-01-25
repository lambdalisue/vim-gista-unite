let s:V = gista#vital()
let s:Dict = s:V.import('Data.Dict')

let s:orig = unite#kinds#file_base#define()
let s:kind = {
      \ 'name': 'gista/file',
      \ 'parents': [
      \   'openable',
      \   'uri',
      \ ],
      \ 'default_action': 'open',
      \ 'alias_table' : { 'edit' : 'open' },
      \ 'action_table': s:Dict.pick(s:orig.action_table, [
      \   'preview',
      \   'read',
      \   'diff',
      \ ]),
      \}
let s:actions = s:kind.action_table

let s:actions.open = {}
let s:actions.open.description = 'open the selected file of the gist'
let s:actions.open.is_selectable = 1
function! s:actions.open.func(candidates) abort
  for candidate in a:candidates
    if buflisted(candidate.action__path)
      execute 'buffer' bufnr(candidate.action__path)
    else
      let path = unite#util#expand(
            \ fnamemodify(candidate.action__path, ':~:.')
            \)
      call unite#util#smart_execute_command('edit', path)
    endif
    call unite#remove_previewed_buffer_list(bufnr(candidate.action__path))
  endfor
endfunction

let s:actions.rename = {}
let s:actions.rename.description = 'rename the selected file of the gist'
let s:actions.rename.is_quit = 0
let s:actions.rename.is_invalidate_cache = 1
let s:actions.rename.is_selectable = 0
function! s:actions.rename.func(candidate) abort
  let options = {
        \ 'gist': a:candidate.source__entry,
        \ 'filename': a:candidate.source__filename,
        \}
  call gista#command#rename#call(options)
endfunction

let s:actions.remove = {}
let s:actions.remove.description = 'remove the selected file from the gist'
let s:actions.remove.is_quit = 0
let s:actions.remove.is_invalidate_cache = 1
let s:actions.remove.is_selectable = 1
function! s:actions.remove.func(candidates) abort
  for candidate in a:candidates
    let options = {
          \ 'gist': candidate.source__entry,
          \ 'filename': candidate.source__filename,
          \}
    call gista#command#remove#call(options)
  endfor
endfunction

function! unite#kinds#gista_file#define() abort
  return s:kind
endfunction
call unite#define_kind(s:kind)
