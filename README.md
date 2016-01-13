vim-gista-unite
===============================================================================

![Screenshot](img/screenshot.png)

*vim-gista-unite* is a harmonic plugin of [vim-gista](https://github.com/lambdalisue/vim-gista) which allow users to use [unite.vim](https://github.com/Shougo/unite.vim) interface to list gists.

Install
-------------------------------------------------------------------------------
Use [neobundle.vim](https://github.com/Shougo/neobundle.vim) or [vim-plug](https://github.com/junegunn/vim-plug) as:

```vim
" vim-plug
Plug 'Shougo/unite.vim'
Plug 'lambdalisue/vim-gista'
Plug 'lambdalisue/vim-gista-unite'

" neobundle.vim
NeoBundle 'lambdalisue/vim-gista-unite', {
    \ 'depends': [
    \   'lambdalisue/vim-gista'
    \   'Shougo/unite.vim'
    \ ],
    \}

" neobundle.vim (Lazy)
NeoBundle 'lambdalisue/vim-gista-unite', {
    \ 'depends': [
    \   'lambdalisue/vim-gista'
    \   'Shougo/unite.vim'
    \ ],
    \ 'on_unite': ['gista', 'gista/file'],
    \}
```

Or install the repository into your `runtimepath` manually.


Usage
-------------------------------------------------------------------------------
It provides `gista` and `gista/file` unite sources. Use these like:

```
:Unite gista
:Unite gista:{LOOKUP}
:Unite gista:{LOOKUP}:{USERNAME}
:Unite gista:{LOOKUP}:{USERNAME}:{APINAME}

:Unite gista/file
:Unite gista/file:{GISTID}
:Unite gista/file:{GISTID}:{USERNAME}
:Unite gista/file:{GISTID}:{USERNAME}:{APINAME}
```

License
-------------------------------------------------------------------------------
The MIT License (MIT)

Copyright (c) 2015 Alisue, hashnote.net

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
