import vim
import urllib.request
import urllib.error
import json
import websocket

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
    port = vim.eval('g:reloaded_port')
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
def activate_page():
    port = vim.eval('g:reloaded_port')
    id = vim.eval('b:selectedpage.id')
    urllib.request.urlopen(f'http://localhost:{port}/json/activate/{id}')

@handle_error
def new_page():
    file = vim.eval('l:file')
    port = vim.eval('g:reloaded_port')
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
