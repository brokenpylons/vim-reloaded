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

function! s:menu(name, items)
    execute 'belowright 7new ' . a:name
    setlocal buftype=nofile bufhidden=wipe noswapfile
    call setline(1, a:items)

    function! s:menuselect()
        let s:menuindex = line('.') - 1
        close
        doautocmd User ReloadedMenuSelect
        autocmd! User ReloadedMenuSelect
    endfunction
    nnoremap <silent> <buffer> <CR> :call <SID>menuselect()<CR>
    setlocal nomodifiable
endfunction

function! s:geturl(...)
    return 'file://' . fnamemodify(get(a:, 1, expand('%')), ':p')
endfunction

function! s:select() abort
    python3 get_pages()
    call s:rethrow(l:error)

    let l:titles = map(copy(s:pages), {key, val -> val.title})

    function! s:selected()
        let b:selectedpage = s:pages[s:menuindex]
    endfunction
    call s:menu('[pages]', l:titles)
    autocmd User ReloadedMenuSelect :call s:selected()
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

function! s:selectcall(fun, ...) abort
    call s:safecall('s:select')
    execute 'autocmd User ReloadedMenuSelect :call call(' . string(a:fun) . ', ' . string(a:000) . ')'
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

command! ReloadedSelect call s:safecall('s:select')
command! ReloadedStart call s:safecall('s:start')
command! ReloadedReload call s:safecall('s:reload')
command! ReloadedStop call s:safecall('s:stop')
command! ReloadedActivate call s:safecall('s:activate')
command! -nargs=? -complete=file ReloadedOpen call s:safecall('s:open', <f-args>)
command! -nargs=? -complete=file ReloadedNew call s:safecall('s:new', <f-args>)

command! ReloadedSelectStart call s:selectcall('s:start')
command! ReloadedSelectReload call s:selectcall('s:reload')
command! ReloadedSelectActivate call s:selectcall('s:activate')
command! -nargs=? -complete=file ReloadedSelectOpen call s:selectcall('s:open', <f-args>)

