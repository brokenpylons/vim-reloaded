import vim
import urllib.request
import urllib.error
import json
import websocket

def handle_errors(fun):
    def wrapper(*args, **kwargs):
        vim.command('let l:error = ""')
        try:
            fun(*args, **kwargs)
        except (urllib.error.HTTPError, websocket.WebSocketBadStatusException):
            vim.command('let l:error = "notfound"')
        except urllib.error.URLError:
            vim.command('let l:error = "cannotconnect"') 
    return wrapper

def call(ws_url, method, **kwargs):
    ws = websocket.create_connection(ws_url)
    message = {
        'method': method,
        'params': kwargs,
        'id': 1
    }
    ws.send(json.dumps(message))
    result = json.loads(ws.recv())
    ws.close()
    return result['result']

@handle_errors
def is_browser_open():
    port = vim.eval('g:reloaded_port')
    try:
        urllib.request.urlopen(f'http://localhost:{port}')
    except (urllib.error.HTTPError, urllib.error.URLError):
        vim.command('let l:result = 0')
        return
    vim.command('let l:result = 1')

@handle_errors
def get_pages():
    port = vim.eval('g:reloaded_port')
    response = urllib.request.urlopen(f'http://localhost:{port}/json/list')
    targets = json.loads(response.read())

    pages = [x for x in targets if x['type'] == 'page']
    vim.command(f'let s:pages = {pages}')

@handle_errors
def get_active_page(): 
    url = vim.eval('l:page.webSocketDebuggerUrl')
    result = call(url, 'Runtime.evaluate', expression='!document.hidden')
    focused = result['result']['value']
    vim.command(f'let l:focused = {int(focused)}') 

@handle_errors
def reload_page():
    url = vim.eval('b:boundpage.webSocketDebuggerUrl')
    call(url, 'Page.reload')

@handle_errors
def activate_page():
    port = vim.eval('g:reloaded_port')
    id = vim.eval('b:boundpage.id')
    urllib.request.urlopen(f'http://localhost:{port}/json/activate/{id}')

@handle_errors
def new_page():
    file = vim.eval('l:file')
    port = vim.eval('g:reloaded_port')
    response = urllib.request.urlopen(f'http://localhost:{port}/json/new?{file}')
    page = json.loads(response.read())
    vim.command(f'let b:boundpage = {page}')

@handle_errors
def open_page():
    file = vim.eval('l:file')
    url = vim.eval('b:boundpage.webSocketDebuggerUrl')
    call(url, 'Page.navigate', url=file)
