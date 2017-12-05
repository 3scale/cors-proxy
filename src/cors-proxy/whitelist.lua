local mysql = require('resty.mysql')
local resty_env = require('resty.env')
local resty_url = require('resty.url')
local resty_resolver = require('resty.resolver')
local round_robin = require('resty.balancer.round_robin')
local lrucache = require('resty.lrucache')

local database_url = resty_env.get('DATABASE_URL')
local url = resty_url.split(database_url, 'mysql')

if not url then
  ngx.log(ngx.WARN, 'DATABASE_URL does not look like MySQL connection')
  url = {}
end

local _M = {
  db = {
    host = url[4],
    port = url[5] or 3306,
    user = url[2],
    password = url[3],
    database = string.sub(url[6] or '', 2),
  }
}

function _M:new()
  return setmetatable({
    cache = ngx.shared.whitelist or lrucache.new(100),
    ttl = 60,
    balancer = round_robin.new(),
  }, { __index = self, __call = self.call })
end

function _M:connect()
  local balancer = self.balancer
  local resolver = resty_resolver:instance()
  local connection = self.db
  local host = connection.host
  local port = connection.port
  local db = assert(mysql:new())
  local servers = resolver:get_servers(host, { port = port })
  local peer = balancer:select_peer(balancer:peers(servers))

  if peer then
    host, port = unpack(peer)
  end

  local opts = {
    host = host,
    port = port,
    user = connection.user,
    password = connection.password,
    database = connection.database,
  }

  local ok, err, errcode, sqlstate = db:connect(opts)

  if not ok then
    ngx.log(ngx.ERR, "failed to connect: ", err, ": ", errcode, " ", sqlstate)
    database_connection:set(0, {"state"})
    return nil, 'failed to connect'
  end

  database_connection:set(1, {"state"})
  return db
end

function _M:call()
  local db = assert(self:connect())

  local name = ngx.unescape_uri(ngx.var.host)
  local port = ngx.ctx.upstream.port

  local cache = self.cache
  local key = ("%s:%s"):format(name, port)

  if cache:get(key) then
    return true
  end

  local quoted_name = ngx.quote_sql_str("http%://" .. name .. "%")
  local sql = ("SELECT DISTINCT base_path FROM `api_docs_services` WHERE `base_path` LIKE %s;"):format(quoted_name)
  ngx.log(ngx.DEBUG, 'SQL: ', sql)
  local res, err, errcode, sqlstate = db:query(sql)

  db:set_keepalive()

  if not res then
    ngx.log(ngx.WARN, "bad result: ", err, ": ", errcode, ": ", sqlstate, ".")
    return
  end

  local match = false
  local ttl = self.ttl

  for i=1, #res do
    local uri = resty_url.split(res[i].base_path)

    if uri then
      local k = ("%s:%s"):format(uri[4], uri[5] or resty_url.default_port(uri[1]))

      cache:set(k, true, ttl)

      if not match then
        match = key == k
      end
    end
  end

  return match
end

return _M
