local iputils = require("resty.iputils")
local default_balancer = require('resty.balancer.round_robin').call
local resty_balancer = require('resty.balancer')

local _M = { _VERSION = '0.0', _NAME = 'IP Blacklist' }
local mt = { __index = _M }

local ipv4 = {
  unspecified = { '0.0.0.0/8' },
  broadcast = { '255.255.255.255/32' },
  multicast = { '224.0.0.0/4' },
  linkLocal = { '169.254.0.0/16' },
  loopback = { '127.0.0.0/8' },
  private = { '10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16' },
  reserved = { '192.0.0.0/24' }
}

local blacklist = {}

for _,cidrs in pairs(ipv4) do
  local list = iputils.parse_cidrs(cidrs)

  for i=1,#list do
    table.insert(blacklist, list[i])
  end
end


function _M.new()
  return setmetatable({}, mt)
end

function _M:init()
  iputils.enable_lrucache()
end

local balancer_with_blacklist = resty_balancer.new(function(peers)
  local peer, i = default_balancer(peers)

  local ip = peer[1]
  local blacklisted, err = iputils.ip_in_cidrs(ip, blacklist)

  if blacklisted then
    return nil, 'blacklisted'
  elseif err then
    return nil, err
  else
    return peer, i
  end
end)

function _M:balancer()
  local balancer = balancer_with_blacklist
  local host = ngx.var.proxy_host -- NYI: return to lower frame
  local peers = balancer:peers(ngx.ctx[host])

  local peer, err = balancer:set_peer(peers)

  if not peer then
    ngx.status = ngx.HTTP_SERVICE_UNAVAILABLE
    ngx.log(ngx.ERR, "failed to set current backend peer: ", err)
    ngx.exit(ngx.status)
  end
end

return _M
