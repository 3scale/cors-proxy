rockspec_format = "1.1"
package = "cors-proxy"
version = "scm-1"
source = {
   url = "*** please add URL for source tarball, zip or repository here ***"
}
description = {
   summary = "*** please specify description summary ***",
   detailed = "*** please specify description description ***",
   homepage = "*** please specify description homepage ***",
   license = "MIT"
}
dependencies = {
   "apicast-cli == scm-1",
   "apicast == scm-1",
   "lua-resty-iputils",
}
build = {
   type = "builtin",
   modules = {
      ["cors-proxy.config.development"] = "config/development.lua",
      ["cors-proxy.config.production"] = "config/production.lua",
      ["cors-proxy.init"] = "src/cors-proxy/init.lua",
      ["cors-proxy.whitelist"] = "src/cors-proxy/whitelist.lua",
      ["cors-proxy.balancer_blacklist"] = "src/cors-proxy/balancer_blacklist.lua",
   },
   install = {}
}
