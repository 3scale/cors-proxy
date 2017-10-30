return {
  worker_processes = 'auto',
  master_process = 'on',
  lua_code_cache = 'on',
  lua_path = './src/?.lua;./src/?/init.lua;;',
}
