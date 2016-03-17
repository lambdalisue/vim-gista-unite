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

function! s:create_candidate(gist, filename, contents) abort
  let options = {
        \ 'gist': a:gist,
        \ 'filename': a:filename,
        \ 'verbose': 0,
        \}
  let path = gista#command#open#bufname(options)
  let result = gista#command#browse#call(options)
  let candidate = {
        \ 'word': s:format_entry_word(a:filename, a:contents),
        \ 'abbr': s:format_entry_abbr(a:filename, a:contents),
        \ 'kind': 'gista/file',
        \ 'action__gist': a:gist,
        \ 'action__filename': a:filename,
        \ 'action__text': path,
        \ 'action__path': path,
        \ 'action__uri': empty(result) ? '' : result.url,
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
  let gist = a:context.source__gist
  let client = gista#client#get()
  let username = client.get_authorized_username()
  call unite#print_source_message(printf('%s:%s:%s',
        \ client.apiname,
        \ empty(username) ? 'ANONYMOUS' : username,
        \ gist.public ? gist.id : s:PRIVATE_GISTID,
        \), self.name
        \)
  let candidates = map(
        \ items(gist.files),
        \ 's:create_candidate(gist, v:val[0], v:val[1])'
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
  if has_key(a:context, 'source__gist')
    " NOTE:
    " 'source__gist' might be a partial instance so make sure the instance
    " is a complete instance
    let result = gista#command#json#call({ 'gist': a:context.source__gist })
  else
    let result = gista#command#json#call(s:parse_unite_args(a:args))
  endif
  let a:context.source__gist = result.gist
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
