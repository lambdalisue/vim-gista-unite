let s:save_cpo = &cpo
set cpo&vim

let s:V = gista#vital()
let s:D = s:V.import('Data.Dict')
let s:PRIVATE_GISTID = repeat('*', 20)

function! s:parse_unite_args(args) abort
  " Unite gista/file
  " Unite gista/file:GISTID
  " Unite gista/file:GISTID:USERNAME
  " Unite gista/file:GISTID:USERNAME:APINAME
  let options = {
        \ 'gistid':   get(a:args, 0, ''),
        \ 'username': get(a:args, 1, 0),
        \ 'apiname':  get(a:args, 2, ''),
        \}
  return options
endfunction
function! s:format_entry_word(filename, contents) abort
  return join([
        \ a:filename,
        \ a:contents.size,
        \ a:contents.language,
        \ a:contents.type
        \])
endfunction
function! s:format_entry_abbr(filename, contents) abort
  let size = a:contents.size . ' Bytes'
  let lang = a:contents.language
  return printf('%s [%s] (%s)', a:filename, lang, size)
endfunction
function! s:create_candidate(entry, filename, contents) abort
  let options = {
        \ 'gist': a:entry,
        \ 'filename': a:filename,
        \ 'verbose': 0,
        \}
  let path = gista#command#open#bufname(options)
  let [uri, gistid, filename] = gista#command#browse#call(options)
  let candidate = {
        \ 'word': s:format_entry_word(filename, a:contents),
        \ 'abbr': s:format_entry_abbr(filename, a:contents),
        \ 'kind': 'gista/file',
        \ 'source__entry': a:entry,
        \ 'source__filename': a:filename,
        \ 'action__text': path,
        \ 'action__path': path,
        \ 'action__uri': uri,
        \}
  return candidate
endfunction

let s:source = {
      \ 'name': 'gista/file',
      \ 'description': 'candidates for files in a gist',
      \ 'syntax': 'uniteSource__GistaFile',
      \ 'hooks': {},
      \}
function! s:source.gather_candidates(args, context) abort
  let entry = a:context.source__entry
  let client = gista#client#get()
  let username = client.get_authorized_username()
  call unite#print_source_message(printf('%s:%s:%s',
        \ client.apiname,
        \ empty(username) ? 'ANONYMOUS' : username,
        \ entry.public ? entry.id : s:PRIVATE_GISTID,
        \), self.name
        \)
  let candidates = map(
        \ items(entry.files),
        \ 's:create_candidate(entry, v:val[0], v:val[1])'
        \)
  return candidates
endfunction
function! s:source.complete(args, context, arglead, cmdline, cursorpos) abort
  if a:arglead =~# '^.\+:.\+:.*$'
    let candidates = gista#option#complete_apiname(
          \ matchstr(a:arglead, '^.\+:.\+:\zs.*$'),
          \ a:cmdline,
          \ a:cursorpos,
          \)
  elseif a:arglead =~# '^.\+:.*$'
    let candidates = gista#option#complete_username(
          \ matchstr(a:arglead, '^.\+:\zs.*$'),
          \ a:cmdline,
          \ a:cursorpos,
          \)
  elseif a:arglead =~# '^.*$'
    let candidates = gista#option#complete_gistid(
          \ matchstr(a:arglead, '^.\+:\zs.*$'),
          \ a:cmdline,
          \ a:cursorpos,
          \)
  endif
  return uniq(candidates)
endfunction
function! s:source.hooks.on_init(args, context) abort
  if has_key(a:context, 'action__entry')
    let a:context.source__entry = a:context.action__entry
  else
    let [gist, gistid] = gista#command#json#call(s:parse_unite_args(a:args))
    let a:context.source__entry = gist
  endif
endfunction
function! s:source.hooks.on_close(args, context) abort
endfunction
function! s:source.hooks.on_syntax(args, context) abort
  call gista#command#list#define_highlights()
  highlight default link uniteSource__GistaFileLang Special
  highlight default link uniteSource__GistaFileSize Comment
  syntax match uniteSource__GistaFileMeta /\[[^\]]*\] (\d* Bytes)$/
        \ contained containedin=uniteSource__GistaFile
  syntax match uniteSource__GistaFileLang /\[.*\]/
        \ contained containedin=uniteSource__GistaFileMeta
  syntax match uniteSource__GistaFileSize /(.*)/
        \ contained containedin=uniteSource__GistaFileMeta
endfunction

function! unite#sources#gista_file#define() abort
  return s:source
endfunction
call unite#define_source(s:source)

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
