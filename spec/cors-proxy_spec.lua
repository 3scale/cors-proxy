local cors-proxy = require("cors-proxy")

describe('double-spec', function()

  it('exists', function()
    assert.truthy(cors-proxy)
  end)

  it('runs inside nginx', function ()
    assert.truthy(ngx)
  end)
end)
