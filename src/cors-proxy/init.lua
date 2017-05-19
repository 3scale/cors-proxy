local balancer = require('cors-proxy.balancer_blacklist')

local _M = {
  _VERSION = '0.1',
  balancer = balancer.new()
}

function _M:init()
  local balancer = self.balancer

  if not balancer then
    return nil, 'not initialized'
  end

  balancer:init()
end

function _M:access()
  -- TODO: verify domain whitelist
end

function _M:content()
  -- TODO: resolve and proxy to the correct server
end

return _M
