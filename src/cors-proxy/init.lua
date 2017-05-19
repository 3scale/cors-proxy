local balancer = require('cors-proxy.balancer_blacklist')
local resty_resovler = require('resty.resolver')
local resty_url = require('resty.url')

local METHODS = {
  GET = ngx.HTTP_GET,
  HEAD = ngx.HTTP_HEAD,
  PUT = ngx.HTTP_PUT,
  POST = ngx.HTTP_POST,
  DELETE = ngx.HTTP_DELETE,
  OPTIONS = ngx.HTTP_OPTIONS,
  MKCOL = ngx.HTTP_MKCOL,
  COPY = ngx.HTTP_COPY,
  MOVE = ngx.HTTP_MOVE,
  PROPFIND = ngx.HTTP_PROPFIND,
  PROPPATCH = ngx.HTTP_PROPPATCH,
  LOCK = ngx.HTTP_LOCK,
  UNLOCK = ngx.HTTP_UNLOCK,
  PATCH = ngx.HTTP_PATCH,
  TRACE = ngx.HTTP_TRACE,
}

local _M = {
  _VERSION = '0.1',
  balancer = balancer.new(),
  resolver = resty_resovler
}

function _M:init()

  local balancer = self.balancer
  local resolver = self.resolver

  if not balancer or not resolver then
    return nil, 'not initialized'
  end

  require("resty.core")

  balancer:init()
  resolver.init()
end

function _M:access()
  -- TODO: verify domain whitelist
end

local api_docs_headers = {
  'X-Apidocs-Path', 'X-Apidocs-Url', 'X-Apidocs-Query', 'X-Apidocs-Method'
}
function _M:rewrite()
  local resolver = self.resolver

  local url = resty_url.split(ngx.var.http_x_apidocs_url)
  local upstream = {
    server = url[4],
    port = url[5] or resty_url.default_port(url[1]),
    host = url[4],
    path = ngx.var.http_x_apidocs_path or ngx.var.uri,
    args = ngx.var.http_x_apidocs_query or ngx.var.args,
    method = METHODS[ngx.var.http_x_apidocs_method],
  }

  ngx.ctx.upstream = resolver:instance():get_servers(upstream.server, { port = upstream.port })
  ngx.req.set_header('Host', upstream.host)
  ngx.var.proxy_scheme = url[1]

  for i=1,#api_docs_headers do
    ngx.req.clear_header(api_docs_headers[i])
  end

  if upstream.method then
    ngx.req.set_method(upstream.method)
  end

  ngx.req.set_uri(upstream.path)
  ngx.req.set_uri_args(upstream.args)
end

function _M:upstream()
  local balancer = self.balancer

  if not balancer then
    return nil, 'not initialized'
  end

  return balancer:call()
end

return _M
