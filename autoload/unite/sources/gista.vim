let s:save_cpo = &cpo
set cpo&vim

let s:V = gista#vital()
let s:S = s:V.import('Data.String')
let s:D = s:V.import('Data.Dict')

let s:CACHE_FORCED = 2
let s:PRIVATE_GISTID = repeat('*', 20)

function! s:parse_unite_args(args) abort
  " Unite gista
  " Unite gista:LOOKUP
  " Unite gista:LOOKUP:USERNAME
  " Unite gista:LOOKUP:USERNAME:APINAME
  let options = {
        \ 'lookup':   get(a:args, 0, ''),
        \ 'username': get(a:args, 1, 0),
        \ 'apiname':  get(a:args, 2, ''),
        \}
  return options
endfunction
function! s:format_entry_word(entry, context) abort
  return join([
        \ a:entry.id,
        \ a:entry.description,
        \ join(keys(a:entry.files), ', '),
        \])
endfunction
function! s:format_entry_abbr(entry, context) abort
  let gistid = a:entry.public
        \ ? '[' . a:entry.id . ']'
        \ : '[' . s:PRIVATE_GISTID . ']'
  let datetime = substitute(
        \ a:entry.created_at,
        \ '\v\d{2}(\d{2})-(\d{2})-(\d{2})T(\d{2}:\d{2}:\d{2})Z',
        \ '\1/\2/\3(\4)',
        \ ''
        \)
  let fetched = get(a:entry, '_gista_fetched')  ? '=' : '-'
  let starred = get(a:entry, '_gista_is_starred') ? '*' : ' '
  let prefix = fetched . ' ' . datetime . ' ' . starred . ' '
  let suffix = '   ' . gistid
  let description = empty(a:entry.description)
        \ ? join(keys(a:entry.files), ', ')
        \ : a:entry.description
  let description = substitute(description, "[\r\n]", ' ', 'g')
  let description = printf('[%d] %s', len(a:entry.files), description)
  return prefix . description . suffix
endfunction
function! s:create_candidate(entry, context) abort
  let options = {
        \ 'gist': a:entry,
        \ 'gistid': a:entry.id,
        \ 'filename': get(keys(a:entry.files), 0, ''),
        \ 'cache': s:CACHE_FORCED,
        \ 'verbose': 0,
        \}
  let path = gista#command#json#bufname(options)
  let uri  = gista#command#browse#call(options)
  let candidate = {
        \ 'kind': 'gista',
        \ 'word': s:format_entry_word(a:entry, a:context),
        \ 'abbr': s:format_entry_abbr(a:entry, a:context),
        \ 'source__entry': a:entry,
        \ 'action__text': a:entry.id,
        \ 'action__path': path,
        \ 'action__uri': uri,
        \}
  return candidate
endfunction

let s:source = {
      \ 'name': 'gista',
      \ 'description': 'candidates for gists of a lookup',
      \ 'syntax': 'uniteSource__Gista',
      \ 'hooks': {},
      \}
function! s:source.gather_candidates(args, context) abort
  if a:context.is_redraw
    try
      call a:context.source__session.enter()
      let a:context.source__index =
            \ gista#command#list#call(a:context.source__options)
      let client = gista#client#get()
      let username = client.get_authorized_username()
      let a:context.source__message = printf('%s:%s:%s',
            \ client.apiname,
            \ empty(username) ? 'ANONYMOUS' : username,
            \ empty(a:context.source__options.lookup)
            \   ? empty(username) ? 'public' : username
            \   : a:context.source__options.lookup,
            \)
    finally
      call a:context.source__session.exit()
    endtry
    let a:context.source__candidates = map(
          \ copy(a:context.source__index.entries),
          \ 's:create_candidate(v:val, a:context)'
          \)
  endif
  call unite#print_source_message(printf('%s [%d]',
        \ a:context.source__message,
        \ len(a:context.source__candidates),
        \), self.name)
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
    let candidates = gista#option#complete_lookup(
          \ matchstr(a:arglead, '^.\+:\zs.*$'),
          \ a:cmdline,
          \ a:cursorpos,
          \)
  endif
  return uniq(candidates)
endfunction
function! s:source.hooks.on_init(args, context) abort
  let a:context.source__options = s:parse_unite_args(a:args)
  let a:context.source__session =
        \ gista#client#session(a:context.source__options)
  try
    call a:context.source__session.enter()
    let a:context.source__index =
          \ gista#command#list#call(a:context.source__options)
    let client = gista#client#get()
    let username = client.get_authorized_username()
    let a:context.source__message = printf('%s:%s:%s',
          \ client.apiname,
          \ empty(username) ? 'ANONYMOUS' : username,
          \ empty(a:context.source__options.lookup)
          \   ? empty(username) ? 'public' : username
          \   : a:context.source__options.lookup,
          \)
  finally
    call a:context.source__session.exit()
  endtry
  let a:context.source__candidates = map(
        \ copy(a:context.source__index.entries),
        \ 's:create_candidate(v:val, a:context)'
        \)
endfunction
function! s:source.hooks.on_close(args, context) abort
endfunction
function! s:source.hooks.on_syntax(args, context) abort
  call gista#command#list#define_highlights()
  highlight default link uniteSource__GistaGistIDPublic GistaGistIDPublic
  highlight default link uniteSource__GistaGistIDPrivate GistaGistIDPrivate
  highlight default link uniteSource__GistaPartialMarker GistaPartialMarker
  highlight default link uniteSource__GistaDownloadedMarker GistaDownloadedMarker
  highlight default link uniteSource__GistaStarredMarker GistaStarredMarker
  highlight default link uniteSource__GistaDateTime GistaDateTime
  syntax match uniteSource__GistaGistIDPublic /\[[a-zA-Z0-9_\-]\{,20}\%(\/[a-zA-Z0-9]\+\)\?\]$/
        \ contained containedin=uniteSource__Gista
  syntax match uniteSource__GistaGistIDPrivate /\[\*\{20}\]$/
        \ contained containedin=uniteSource__Gista
  syntax match uniteSource__GistaMeta /[=\-] \d\{2}\/\d\{2}\/\d\{2}(\d\{2}:\d\{2}:\d\{2}) [ \*]/
        \ contained containedin=uniteSource__Gista
  syntax match uniteSource__GistaPartialMarker /-\s/
        \ contained containedin=uniteSource__GistaMeta
  syntax match uniteSource__GistaDownloadedMarker /=\s/
        \ contained containedin=uniteSource__GistaMeta
  syntax match uniteSource__GistaDateTime /\d\{2}\/\d\{2}\/\d\{2}(\d\{2}:\d\{2}:\d\{2})/
        \ contained containedin=uniteSource__GistaMeta
  syntax match uniteSource__GistaStarredMarker /\s\*/
        \ contained containedin=uniteSource__GistaMeta
endfunction

function! unite#sources#gista#define() abort
  return s:source
endfunction
call unite#define_source(s:source)

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
