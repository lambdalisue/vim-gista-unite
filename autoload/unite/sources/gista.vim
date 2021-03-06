let s:CACHE_FORCED = 2
let s:PRIVATE_GISTID = repeat('*', 32)

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

function! s:format_gist_word(gist, context) abort
  return join([
        \ a:gist.id,
        \ a:gist.description,
        \ join(keys(a:gist.files), ', '),
        \])
endfunction

function! s:format_gist_abbr(gist, context) abort
  let gistid = a:gist.public
        \ ? '[' . a:gist.id . ']'
        \ : '[' . s:PRIVATE_GISTID . ']'
  let datetime = substitute(
        \ a:gist.created_at,
        \ '\v\d{2}(\d{2})-(\d{2})-(\d{2})T(\d{2}:\d{2}:\d{2})Z',
        \ '\1/\2/\3(\4)',
        \ ''
        \)
  let fetched = get(a:gist, '_gista_fetched')  ? '=' : '-'
  let starred = get(a:gist, '_gista_is_starred') ? '*' : ' '
  let prefix = fetched . ' ' . datetime . ' ' . starred . ' '
  let suffix = '   ' . gistid
  let description = empty(a:gist.description)
        \ ? join(keys(a:gist.files), ', ')
        \ : a:gist.description
  let description = substitute(description, "[\r\n]", ' ', 'g')
  let description = printf('[%d] %s', len(a:gist.files), description)
  return prefix . description . suffix
endfunction

function! s:create_candidate(gist, context) abort
  let options = {
        \ 'gist': a:gist,
        \ 'cache': s:CACHE_FORCED,
        \ 'verbose': 0,
        \}
  let path = gista#command#json#bufname(options)
  let result = gista#command#browse#call(options)
  let candidate = {
        \ 'kind': 'gista',
        \ 'word': s:format_gist_word(a:gist, a:context),
        \ 'abbr': s:format_gist_abbr(a:gist, a:context),
        \ 'action__gist': a:gist,
        \ 'action__text': a:gist.id,
        \ 'action__path': path,
        \ 'action__uri': empty(result) ? '' : result.url,
        \}
  return candidate
endfunction

function! s:gather_candidates(args, context) abort
  let session = gista#client#session({
        \ 'apiname': a:context.source__options.apiname,
        \ 'username': a:context.source__options.username,
        \})
  try
    if session.enter()
      let result = gista#command#list#call({
            \ 'lookup': a:context.source__options.lookup,
            \})
      if empty(result)
        return [[], '']
      endif
      let client = gista#client#get()
      let username = client.get_authorized_username()
      let message = printf('%s:%s:%s',
            \ client.apiname,
            \ empty(username) ? 'anonymous': username,
            \ empty(result.lookup)
            \   ? empty(username) ? 'public' : result.lookup
            \   : result.lookup
            \)
      return [result.index, message]
    endif
  finally
    call session.exit()
  endtry
endfunction

let s:source = {
      \ 'name': 'gista',
      \ 'description': 'candidates for gists of a lookup',
      \ 'syntax': 'uniteSource__Gista',
      \ 'hooks': {},
      \}

function! s:source.gather_candidates(args, context) abort
  if a:context.is_redraw || !has_key(a:context, 'source_candidates')
    let [index, message] = s:gather_candidates(a:args, a:context)
    let a:context.source__candidates = map(
          \ index.entries,
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
endfunction

function! s:source.hooks.on_syntax(args, context) abort
  call gista#command#list#define_highlights()
  highlight default link uniteSource__GistaGistIDPublic GistaGistIDPublic
  highlight default link uniteSource__GistaGistIDPrivate GistaGistIDPrivate
  highlight default link uniteSource__GistaPartialMarker GistaPartialMarker
  highlight default link uniteSource__GistaDownloadedMarker GistaDownloadedMarker
  highlight default link uniteSource__GistaStarredMarker GistaStarredMarker
  highlight default link uniteSource__GistaDateTime GistaDateTime
  syntax match uniteSource__GistaGistIDPublic /\[[a-zA-Z0-9_\-]\{,32}\%(\/[a-zA-Z0-9]\+\)\?\]$/
        \ contained containedin=uniteSource__Gista
  syntax match uniteSource__GistaGistIDPrivate /\[\*\{32}\]$/
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
