let s:CACHE_FORCED = 2
let s:PRIVATE_GISTID = repeat('*', 32)

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

function! s:format_commit_word(commit, context) abort
  return join([
        \ a:commit.version,
        \ a:commit.committed_at,
        \ join(keys(a:commit.files), ', '),
        \])
endfunction

function! s:format_commit_abbr(commit, context) abort
  let datetime = substitute(
        \ a:commit.committed_at,
        \ '\v\d{2}(\d{2})-(\d{2})-(\d{2})T(\d{2}:\d{2}:\d{2})Z',
        \ '\1/\2/\3(\4)',
        \ ''
        \)
  let fetched = get(a:commit, '_gista_fetched')  ? '=' : '-'
  let prefix = fetched . ' ' . datetime . ' '
  let suffix = '   ' . a:commit.version
  if get(a:commit.change_status, 'total', 0)
    let change_status = join([
          \ printf('%d additions', a:commit.change_status.additions),
          \ printf('%d deletions', a:commit.change_status.deletions),
          \], ', ')
  else
    let change_status = 'No changes'
  endif
  return prefix . change_status . suffix
endfunction

function! s:create_candidate(commit, context) abort
  let options = {
        \ 'gist': a:commit,
        \ 'cache': s:CACHE_FORCED,
        \ 'verbose': 0,
        \}
  let path = gista#command#json#bufname(options)
  let result = gista#command#browse#call(options)
  let candidate = {
        \ 'kind': 'gista/commit',
        \ 'word': s:format_commit_word(a:commit, a:context),
        \ 'abbr': s:format_commit_abbr(a:commit, a:context),
        \ 'action__commit': a:commit,
        \ 'action__text': a:commit.id,
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
      let result = gista#command#commits#call({
            \ 'gist': a:context.source__gist,
            \})
      if empty(result)
        return [[], '']
      endif
      let client = gista#client#get()
      let username = client.get_authorized_username()
      let message = printf('%s:%s:%s',
            \ client.apiname,
            \ empty(username) ? 'anonymous': username,
            \ result.gistid,
            \)
      return [result.entries, message]
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
    let [commits, message] = s:gather_candidates(a:args, a:context)
    let a:context.source__candidates = map(
          \ commits,
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
  if has_key(a:context, 'source__gist')
    " NOTE:
    " 'source__gist' might be a partial instance so make sure the instance
    " is a complete instance
    let result = gista#command#json#call({ 'gist': a:context.source__gist })
  else
    let result = gista#command#json#call(a:context.source__options)
  endif
  let a:context.source__gist = result.gist
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
