local balancer = require('cors-proxy.balancer_blacklist')
local resty_resolver = require('resty.resolver')
local resty_url = require('resty.url')
local whitelist = require('cors-proxy.whitelist')

local prometheus = require('nginx.prometheus').init("prometheus_metrics")

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

local select = select
local find = string.find
local tonumber = tonumber

local _M = {
  _VERSION = '0.1',
  balancer = balancer:new(),
  whitelist = whitelist:new(),
  resolver = resty_resolver
}

local metrics = {
  http_connections = prometheus:gauge("nginx_http_connections", "Number of HTTP connections", {"state"}),
  database_connection = prometheus:gauge("cors_proxy_database_connection", "Database Connection State", {"state"}),
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

local api_docs_headers = {
  'X-Apidocs-Path', 'X-Apidocs-Url', 'X-Apidocs-Query', 'X-Apidocs-Method'
}

local function set_cors_headers()
  local origin = ngx.var.http_origin

  if not origin then return end

  ngx.header['Access-Control-Allow-Headers'] = ngx.var.http_access_control_request_headers
  ngx.header['Access-Control-Allow-Methods'] = ngx.var.http_access_control_request_method
  ngx.header['Access-Control-Allow-Origin'] = origin
  ngx.header['Access-Control-Allow-Credentials'] = 'true'
end

local function cors_preflight_response()
  set_cors_headers()
  ngx.status = 204
  ngx.exit(ngx.status)
end

local function cors_preflight()
  return (
    ngx.req.get_method() == 'OPTIONS' and
    ngx.var.http_origin and
    ngx.var.http_access_control_request_method
  )
end

function _M:rewrite()
  if cors_preflight() then
    return cors_preflight_response()
  else
    local url = resty_url.split(ngx.var.http_x_apidocs_url)
    if not url then
      ngx.status = ngx.HTTP_BAD_REQUEST
      ngx.say('missing X-ApiDocs-URL header')
      ngx.exit(ngx.OK)
    end

    local upstream = {
      server = url[4],
      port = url[5] or resty_url.default_port(url[1]),
      host = url[4],
      path = ngx.var.http_x_apidocs_path or ngx.var.uri,
      args = ngx.var.http_x_apidocs_query or ngx.var.args or '',
      method = METHODS[ngx.var.http_x_apidocs_method],
    }
  
    ngx.ctx.upstream = upstream
    ngx.req.set_header('Host', upstream.host)
    ngx.var.proxy_scheme = url[1]
  
    for i=1,#api_docs_headers do
      ngx.req.clear_header(api_docs_headers[i])
    end
  
    if upstream.method then
      ngx.req.set_method(upstream.method)
    end
  
    ngx.var.proxy_path = upstream.path
    ngx.req.set_uri_args(upstream.args)
  end
end

function _M:header_filter()
  set_cors_headers()
end

function _M:access()
  local resolver = self.resolver
  local upstream = ngx.ctx.upstream

  local whitelist = self.whitelist

  if whitelist() then
    ngx.ctx.proxy = resolver:instance():get_servers(upstream.server, { port = upstream.port })
  else
    ngx.exit(403)
  end
end

function _M:upstream()
  local balancer = self.balancer

  if not balancer then
    return nil, 'not initialized'
  end

  return balancer:call()
end

function _M:metrics()
  local response = ngx.location.capture "/nginx_status"

  if response.status ~= 200 then
    ngx.status = ngx.HTTP_SERVICE_UNAVAILABLE
    ngx.log(ngx.ERR, "Nginx Status Module is not responding and failing with the Status: ", response.status)
    ngx.exit(ngx.status)
  end

  local accepted, handled, total = select(3, find(response.body, [[accepts handled requests\n (%d*) (%d*) (%d*)]]))

  metrics.http_connections:set(tonumber(ngx.var.connections_reading) or 0, {"reading"})
  metrics.http_connections:set(tonumber(ngx.var.connections_waiting) or 0, {"waiting"})
  metrics.http_connections:set(tonumber(ngx.var.connections_writing) or 0, {"writing"})
  metrics.http_connections:set(tonumber(ngx.var.connections_active) or 0, {"active"})
  metrics.http_connections:set(accepted or 0, {"accepted"})
  metrics.http_connections:set(handled or 0, {"handled"})
  metrics.http_connections:set(total or 0, {"total"})

  prometheus:collect()
end

return _M
