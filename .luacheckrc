std = 'ngx_lua+lua52' -- lua52 has table.pack

busted = {std = "+busted"}
files["**/spec/**/*_spec.lua"] = busted

globals = { 'rawlen' }
