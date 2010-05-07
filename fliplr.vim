" FlipLR -- Flips left hand side and right hand side.
"
" Maintainer: Shuhei Kubota <kubota.shuhei@gmail.com>
" Description:
"   This script flips left hand side and right hand side.
"   'lhs {operator} rhs' => 'rhs {operator} lhs'
"
" Usage:
"   1. In visual mode, select left hand side, operator and right hand side.
"   2. execute ':FlipLR operator'
"   2'. execute ':FlipLR /operator/' to flip with regexp
"
"   This mapping may help you.
"       noremap \f :FlipLR <C-R>=g:FlipLR_detectPivot()<CR>
"   This mapping highlights an operator. (add to your gvimrc)
"       noremap \f :call g:FlipLR_startHighlightingPivot()<CR><ESC>:FlipLR <C-R>=g:FlipLR_detectPivot()<CR>

command! -range -nargs=1 FlipLR call <SID>FlipLR_execute(<SID>FlipLR__getSelectedText(), <f-args>)

highlight FlipLREntire term=underline gui=underline
highlight FlipLRPivot term=reverse,bold gui=reverse,bold

let s:REGEXP_SPACE = '[ \t\e\r\b\n]'

function! s:FlipLR_execute(entire, ...) " only a:000[0] is used
    "[sp_l1][lhs][sp_l2][pivot][sp_r1][rhs][sp_r2]
    "[sp_l1][rhs][sp_l2][pivot][sp_r1][lhs][sp_r2]
    "lhs   : left hand side
    "rhs   : right hand side
    "sp_l1 : spaces befoer the lhs
    "sp_l2 : spaces after the lhs
    "sp_r1 : spaces before the rhs
    "sp_r2 : spaces after the rhs

    if len(a:000) == 0 | return | endif

    let pivotRegexp = a:000[0]
    if strlen(pivotRegexp) == 0 | return | endif

    " getting pivot
    if match(pivotRegexp, '\v/.+/') != -1 " regexp
        let pivotRegexp = pivotRegexp[1:-2] " /hoge/ => hoge
    else
        let pivotRegexp = '\V' . s:FlipLR__substituteSpecialChars(pivotRegexp)
    endif
    "echom '"' . pivotRegexp . '"'
    let pivot = matchstr(a:entire, pivotRegexp)
    "echom '"' . pivot . '"'

    let pos = stridx(a:entire, pivot)
    if pos == -1 | return | endif

    " build text

    "echom pos
    let left_sides = strpart(a:entire, 0, pos)
    "echom '"' . left_sides . '"'
    let right_sides = strpart(a:entire, pos + strlen(pivot))
    "echom '"' . right_sides . '"'

    let sp_l1 = matchstr(left_sides, '^' . s:REGEXP_SPACE . '*')
    "echom '"'.sp_l1.'"'
    let sp_l2 = matchstr(left_sides, '' . s:REGEXP_SPACE . '*$')
    "echom '"'.sp_l2.'"'
    let sp_r1 = matchstr(right_sides, '^' . s:REGEXP_SPACE . '*')
    "echom '"'.sp_r1.'"'
    let sp_r2 = matchstr(right_sides, '' . s:REGEXP_SPACE . '*$')
    "echom '"'.sp_r2.'"'

    let lhs = strpart(left_sides, strlen(sp_l1), strlen(left_sides) - strlen(sp_l1) - strlen(sp_l2))
    "echom '"'.lhs.'"'
    let rhs = strpart(right_sides, strlen(sp_r1), strlen(right_sides) - strlen(sp_r1) - strlen(sp_r2))
    "echom '"'.rhs.'"'

    let new_entire = sp_l1 . rhs . sp_l2 . pivot . sp_r1 . lhs . sp_r2
    "echom '['.sp_l1 .']['. lhs .']['. sp_l2 .']['. pivot .']['. sp_r1 .']['. rhs .']['. sp_r2 .']'
    "echom '['.sp_l1 .']['. rhs .']['. sp_l2 .']['. pivot .']['. sp_r1 .']['. lhs .']['. sp_r2 .']'
    "return

    " replace

    let old_t = @t
    let @t = new_entire
    normal gv
    normal "tp
    let @t = old_t

    "echom 'stridx:' . string(stridx(sp_r2, "\n"))
    "echom 'strlen:' . string(strlen(sp_r2) - 1)
    "if stridx(sp_r2, "\n") == strlen(sp_r2) - 1
    "    normal kJ
    "endif
endfunction

function! g:FlipLR_startHighlightingPivot()
    let pivot = s:FlipLR__substituteSpecialChars(g:FlipLR_detectPivot())

    normal gv
    let old_t = @t
    normal "ty
    let entire = s:FlipLR__substituteSpecialChars(@t)
    let @t = old_t

    syntax clear FlipLREntire
    execute 'syntax match FlipLREntire /\V' . entire . '/ containedin=ALL'
    " highlighting all pivots is annoying
    syntax clear FlipLRPivot
    execute 'syntax match FlipLRPivot /\%'.line('.').'l\V' . pivot . '/ containedin=ALL'

    let g:FlipLR__updatetime = &updatetime
    echom g:FlipLR__updatetime
    let &updatetime = 1
    augroup FlipLR
        autocmd!
        autocmd FlipLR CursorHold *
                    \ let &updatetime = g:FlipLR__updatetime | syntax clear FlipLREntire | syntax clear FlipLRPivot | autocmd! FlipLR
    augroup END
endfunction

function! g:FlipLR_detectPivot()
    normal gv
    let old_t = @t
    normal "ty
    let str = @t
    let @t = old_t

    let elems = split(str, s:REGEXP_SPACE . '\|\<\|\>')
    let c = len(elems)

    " init
    let ranks = map(copy(elems), '0')

    " gain centers' ranks
    if c % 2 == 1
        let ranks[c / 2] += 1
    else
        let ranks[c / 2 - 1] += 1
        let ranks[c / 2] += 1
    endif

    " gain non-word parts' ranks
    " gain equal sign's rank
    let i = 0
    while i < c
        if match(elems[i], '^\W\+$') != -1
            let ranks[i] += 1
            if stridx(elems[i], '=') != -1
                let ranks[i] += 2
            endif
        endif
        let i += 1
    endwhile

    let max_rank = -1
    let max_idx = 0
    let i = 0
    while i < c
        if max_rank < ranks[i]
            let max_rank = ranks[i]
            let max_idx = i
        endif
        let i += 1
    endwhile

    "echom join(elems, ', ')
    "echom join(ranks, ', ')
    let pivot = elems[max_idx]

    return pivot
endfunction

function! s:FlipLR__getSelectedText()
    let old_t = @t

    normal gv"ty
    let result = @t

    let @t = old_t

    return result
endfunction

function! s:FlipLR__substituteSpecialChars(str)
    let result = escape(a:str, '\')
    let result = substitute(result, '/', '\\/', 'g')
    let result = substitute(result, '\r\n\|\r\|\n', '\\n', 'g')
    return result
endfunction

" :FlipLR /.\?=/
" a = b
" a != b
" a |= b
" a ~= b
" a + c \= b

" vim: set et ft=vim sts=4 sw=4 ts=4 tw=0 : 
