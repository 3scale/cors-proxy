local balancer_blacklist = require('cors-proxy.balancer_blacklist')

describe('balancer blacklist', function()
  it('exists', function() assert.truthy(balancer_blacklist) end)
end)
