if !has('python3')
    finish
endif

execute 'py3file ' . expand('<sfile>:p:h') . '/reloaded.py'

let g:reloaded_port = get(g:, 'reloaded_port', 9222)

function! s:error(message)
    echohl ErrorMsg
    echomsg 'Reloaded: ' . a:message
    echohl None
endfunction

function! s:rethrow(error)
    if a:error != ""
        throw a:error
    endif
endfunction

function! s:ifselected()
    if !exists('b:selectedpage')
        throw 'nothingselected'
    endif
endfunction

function! s:focuslost()
    doautocmd User ReloadedFocusLost
endfunction

function! s:geturl(...)
    return 'file://' . fnamemodify(get(a:, 1, expand('%')), ':p')
endfunction

function! s:bind() abort
    python3 get_pages()
    call s:rethrow(l:error)

    for l:page in s:pages
        python get_active_page()
        call s:rethrow(l:error)

        if l:value
            let b:selectedpage = l:page
            break
        endif
    endfor
endfunction

function! s:safecall(fun, ...) abort
    try
        call call(a:fun, a:000)
    catch /cannotconnect/
        call s:error('Cannot connect to the browser at port ' . g:reloaded_port)
    catch /nothingselected/
        call s:error('You need to select the page first')
    catch /notfound/
        call s:error('The page "'. b:selectedpage.title . '" could not be found. Did you close it?')
    endtry
endfunction

function! s:activate() abort
    call s:ifselected()
    python3 activate_page()
    call s:rethrow(l:error)
    call s:focuslost()
endfunction

function! s:reload() abort
    call s:ifselected()
    python3 reload_page()
    call s:rethrow(l:error)
endfunction

function! s:new(...) abort
    let l:file = call('s:geturl', a:000)
    python3 new_page()
    call s:rethrow(l:error)
    call s:focuslost()
endfunction

function! s:open(...) abort
    call s:ifselected()
    let l:file = call('s:geturl', a:000)
    python3 open_page()
    call s:rethrow(l:error)
endfunction

function! s:start() abort
    augroup Reloaded
        autocmd!
        autocmd BufWritePost <buffer> :call s:safecall('s:reload')
    augroup END
endfunction

function! s:stop() abort
    augroup Reloaded
        autocmd!
    augroup END
endfunction

command! ReloadedBind call s:safecall('s:bind')
command! ReloadedStart call s:safecall('s:start')
command! ReloadedReload call s:safecall('s:reload')
command! ReloadedStop call s:safecall('s:stop')
command! ReloadedActivate call s:safecall('s:activate')
command! -nargs=? -complete=file ReloadedOpen call s:safecall('s:open', <f-args>)
command! -nargs=? -complete=file ReloadedNew call s:safecall('s:new', <f-args>)
