let s:save_cpo = &cpo
set cpo&vim

let s:V = gista#vital()
let s:S = s:V.import('Data.String')
let s:D = s:V.import('Data.Dict')

let s:CACHE_FORCED = 2
let s:PRIVATE_GISTID = repeat('*', 20)

function! s:parse_unite_args(args) abort
  " Unite gista/commit
  " Unite gista/commit:GISTID
  " Unite gista/commit:GISTID:USERNAME
  " Unite gista/commit:GISTID:USERNAME:APINAME
  let options = {
        \ 'gistid':   get(a:args, 0, ''),
        \ 'username': get(a:args, 1, 0),
        \ 'apiname':  get(a:args, 2, ''),
        \}
  return options
endfunction
function! s:format_entry_word(entry, context) abort
  return join([
        \ a:entry.version,
        \ a:entry.committed_at,
        \ join(keys(a:entry.files), ', '),
        \])
endfunction
function! s:format_entry_abbr(entry, context) abort
  let datetime = substitute(
        \ a:entry.committed_at,
        \ '\v\d{2}(\d{2})-(\d{2})-(\d{2})T(\d{2}:\d{2}:\d{2})Z',
        \ '\1/\2/\3(\4)',
        \ ''
        \)
  let fetched = get(a:entry, '_gista_fetched')  ? '=' : '-'
  let prefix = fetched . ' ' . datetime . ' '
  let suffix = '   ' . a:entry.version
  if get(a:entry.change_status, 'total', 0)
    let change_status = join([
          \ printf('%d additions', a:entry.change_status.additions),
          \ printf('%d deletions', a:entry.change_status.deletions),
          \], ', ')
  else
    let change_status = 'No changes'
  endif
  return prefix . change_status . suffix
endfunction
function! s:create_candidate(entry, context) abort
  let options = {
        \ 'gist': a:entry,
        \ 'cache': s:CACHE_FORCED,
        \ 'verbose': 0,
        \}
  let path = gista#command#json#bufname(options)
  let [uri, gistid, filename] = gista#command#browse#call(options)
  let candidate = {
        \ 'kind': 'gista/commit',
        \ 'word': s:format_entry_word(a:entry, a:context),
        \ 'abbr': s:format_entry_abbr(a:entry, a:context),
        \ 'source__entry': a:entry,
        \ 'action__text': a:entry.id,
        \ 'action__path': path,
        \ 'action__uri': uri,
        \}
  return candidate
endfunction
function! s:gather_candidates(options) abort
  let options = extend({}, a:options)
  let session = gista#client#session(options)
  try
    if session.enter()
      let [entries, gistid] = gista#command#commits#call(options)
      let client = gista#client#get()
      let username = client.get_authorized_username()
      let message = printf('%s:%s:%s',
            \ client.apiname,
            \ empty(username) ? 'anonymous': username,
            \ gistid,
            \)
      return [entries, message]
    endif
  finally
    call session.exit()
  endtry
endfunction

let s:source = {
      \ 'name': 'gista/commit',
      \ 'description': 'candidates for commits of a gist',
      \ 'syntax': 'uniteSource__GistaCommit',
      \ 'hooks': {},
      \}
function! s:source.gather_candidates(args, context) abort
  if a:context.is_redraw || !has_key(a:context, 'source_candidates')
    let [entries, message] = s:gather_candidates(a:context.source__options)
    let a:context.source__candidates = map(
          \ entries,
          \ 's:create_candidate(v:val, a:context)'
          \)
    call unite#print_source_message(printf('%s [%d]',
          \ message, len(a:context.source__candidates),
          \), self.name)
  endif
  return a:context.source__candidates
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
  let a:context.source__options = s:parse_unite_args(a:args)
  if has_key(a:context, 'action__entry')
    let a:context.source__options.gist = a:context.action__entry
  else
    let [gist, gistid] = gista#command#json#call(s:parse_unite_args(a:args))
    let a:context.source__options.gist = gist
  endif
endfunction
function! s:source.hooks.on_close(args, context) abort
endfunction
function! s:source.hooks.on_syntax(args, context) abort
  call gista#command#commits#define_highlights()
  highlight default link uniteSource__GistaGistVersion GistaGistVersion
  highlight default link uniteSource__GistaPartialMarker GistaPartialMarker
  highlight default link uniteSource__GistaDownloadedMarker GistaDownloadedMarker
  highlight default link uniteSource__GistaDateTime GistaDateTime
  highlight default link uniteSource__GistaAdditions GistaAdditions
  highlight default link uniteSource__GistaDeletions GistaDeletions
  syntax match uniteSource__GistaGistVersion /[a-zA-Z0-9]\+$/
        \ contained containedin=uniteSource__GistaCommit
  syntax match uniteSource__GistaMeta /[=\-] \d\{2}\/\d\{2}\/\d\{2}(\d\{2}:\d\{2}:\d\{2}) [ \*]/
        \ contained containedin=uniteSource__GistaCommit
  syntax match uniteSource__GistaPartialMarker /-\s/
        \ contained containedin=uniteSource__GistaMeta
  syntax match uniteSource__GistaDownloadedMarker /=\s/
        \ contained containedin=uniteSource__GistaMeta
  syntax match uniteSource__GistaDateTime /\d\{2}\/\d\{2}\/\d\{2}(\d\{2}:\d\{2}:\d\{2})/
        \ contained containedin=uniteSource__GistaMeta
  syntax match uniteSource__GistaAdditions /\d\+ additions/
        \ contained containedin=uniteSource__GistaCommit
  syntax match uniteSource__GistaDeletions /\d\+ deletions/
        \ contained containedin=uniteSource__GistaCommit
endfunction

function! unite#sources#gista_commit#define() abort
  return s:source
endfunction
call unite#define_source(s:source)



let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
