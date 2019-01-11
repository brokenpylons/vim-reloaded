if !has('python3')
    finish
endif

let g:browserreload_port = get(g:, 'browserreload_port', 9222)

function! s:error(message)
    echohl ErrorMsg
    echomsg a:message
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

python3 << EOF
import vim
import urllib.request
import urllib.error
import json
import websocket

def error(message):
    vim.command(f"call s:error('{message}')|return")

def handle_error(fun):
    def wrapper(*args, **kwargs):
        vim.command('let l:error = ""')
        try:
            return fun(*args, **kwargs)
        except (urllib.error.HTTPError, websocket.WebSocketBadStatusException):
            vim.command('let l:error = "notfound"')
        except urllib.error.URLError:
            vim.command('let l:error = "cannotconnect"') 
    return wrapper

@handle_error
def get_pages():
    port = vim.eval('g:browserreload_port')
    response = urllib.request.urlopen(f'http://localhost:{port}/json/list')
    targets = json.loads(response.read())

    pages = [x for x in targets if x['type'] == 'page']
    vim.command(f'let s:pages = {pages}')

@handle_error
def reload_page():
    url = vim.eval('b:selectedpage.webSocketDebuggerUrl')
    ws = websocket.create_connection(url)
    ws.send("""{
        "method": "Page.reload",
        "id": 1
    }""")

@handle_error
def focus_page():
    port = vim.eval('g:browserreload_port')
    id = vim.eval('b:selectedpage.id')
    urllib.request.urlopen(f'http://localhost:{port}/json/activate/{id}')

@handle_error
def new_page():
    file = vim.eval('l:file')
    port = vim.eval('g:browserreload_port')
    response = urllib.request.urlopen(f'http://localhost:{port}/json/new?{file}')
    page = json.loads(response.read())
    vim.command(f'let b:selectedpage = {page}')

@handle_error
def open_page():
    file = vim.eval('l:file')
    url = vim.eval('b:selectedpage.webSocketDebuggerUrl')
    ws = websocket.create_connection(url)
    ws.send("""{
        "method": "Page.navigate",
        "params": {
            "url": "%s"
        },
        "id": 1
    }""" % file)
EOF

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

function! s:selectx(fun, ...) abort
    call s:safecall('s:select')
    execute 'autocmd User ReloadedMenuSelect :call call(' . string(a:fun) . ', ' . string(a:000) . ')'
endfunction

function! s:safecall(fun, ...) abort
    try
        call call(a:fun, a:000)
    catch /cannotconnect/
        call system('chromium --user-data-dir=/tmp --remote-debugging-port=9222 & &> /dev/null')
        sleep 1000m
        call call('s:safecall', [a:fun] + a:000)
    catch /nothingselected/
        call call('s:selectx', [a:fun] + a:000)
    catch /notfound/
        call call('s:selectx', [a:fun] + a:000)
    endtry
endfunction

function! s:errorcall(fun, ...) abort
    try
        call call(a:fun, a:000)
    catch /nothingselected/
        call s:error('WWW')
    catch /cannotconnect/
        call s:error('Cannot connect to browser at port ' . g:browserreload_port)
    catch /notfound/
        call s:error('XXX')
    endtry
endfunction

function! s:focus() abort
    call s:ifselected()
    python3 focus_page()
    call s:rethrow(l:error)
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

command! Select call s:safecall('s:select')
command! Start call s:errorcall('s:start')
command! Reload call s:errorcall('s:reload')
command! Stop call s:errorcall('s:stop')
command! Focus call s:errorcall('s:focus')
command! -nargs=? -complete=file Open call s:errorcall('s:open', <f-args>)
command! -nargs=? -complete=file New call s:errorcall('s:new', <f-args>)

