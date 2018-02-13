BEGIN {
    $ENV{TEST_NGINX_APICAST_BINARY} ||= 'rover exec apicast-cli';
}

use lib 't';
use Test::APIcast::Blackbox 'no_plan';

push @Test::Nginx::Util::BlockPreprocessors, sub {
    my $block = shift;

    my $Workers = $Test::Nginx::Util::Workers;
    my $MasterProcessEnabled = $Test::Nginx::Util::MasterProcessEnabled;
    my $DaemonEnabled = $Test::Nginx::Util::DaemonEnabled;
    my $err_log_file = $block->error_log_file || $Test::Nginx::Util::ErrLogFile;
    my $LogLevel = $Test::Nginx::Util::LogLevel;
    my $PidFile = $Test::Nginx::Util::PidFile;
    my $AccLogFile = $Test::Nginx::Util::AccLogFile;
    my $ServerPort = $Test::Nginx::Util::ServerPort;
    my $sites_d = $block->sites_d;

    my $environment= <<_EOC_;
return {
    worker_processes = '$Workers',
    master_process = '$MasterProcessEnabled',
    daemon = '$DaemonEnabled',
    error_log = '$err_log_file',
    log_level = '$LogLevel',
    lua_path = '$ENV{LUA_PATH}',
    lua_cpath = '$ENV{LUA_CPATH}',
    pid = '$PidFile',
    lua_code_cache = 'on',
    access_log = '$AccLogFile',
    port = '$ServerPort',
    env = { },
    sites_d = [============================[$sites_d]============================],
}
_EOC_

    $block->set_value("environment",$environment);
};

$ENV{CORS_PROXY_BALANCER_WHITELIST}='127.0.0.1/32';
delete $ENV{DATABASE_URL};

repeat_each(1);
run_tests();

__DATA__

=== TEST 1: X-ApiDocs-URL header missing
Responds with Bad Request status.
--- request
GET /
--- response_body
missing X-ApiDocs-URL header
--- error_code: 400


=== TEST 2: proxies to the upstream server
Responds with the upstream server response.
--- request
GET /
--- more_headers eval
<<HTTP_HEADERS
X-ApiDocs-URL: http://test:$ENV{TEST_NGINX_SERVER_PORT}/ignored
X-ApiDocs-Path: /t
HTTP_HEADERS
--- upstream
location = /t {
  echo "success!";
}
--- response_body
success!
--- error_code: 200


=== TEST 3: proxy strips X-Forwarded and Forwarded headers
So upstream servers don't feel like being proxied.
--- request
GET /
--- more_headers eval
<<HTTP_HEADERS
X-ApiDocs-URL: http://test:$ENV{TEST_NGINX_SERVER_PORT}/ignored
X-ApiDocs-Path: /t
X-Forwarded-For: 10.1.0.1
X-Forwarded-Host: example.com
X-Forwarded-Proto: https
Forwarded: for=10.1.0.1;host=example.com;proto=https
Api-Key: somekey
HTTP_HEADERS
--- upstream
location = /t {
  content_by_lua_block {  ngx.print(ngx.req.raw_header()) }
}
--- response_body eval
<<RESPONSE
GET /t HTTP/1.1\x{0d}
Host: test\x{0d}
Api-Key: somekey\x{0d}
\x{0d}
RESPONSE
--- error_code: 200
--- no_error_log
[error]

=== TEST 4: doesn't double-encode the upstream path with special characters
Proxies to the exact value of the upstream path.
--- request
GET /
--- more_headers eval
<<HTTP_HEADERS
X-ApiDocs-Url: http://test:$ENV{TEST_NGINX_SERVER_PORT}/ignored
X-ApiDocs-Path: /api/this%3Dpath%2Cis%3Balready%3Descaped
HTTP_HEADERS
--- upstream
location / {
  echo $request_uri;
}
--- response_body
/api/this%3Dpath%2Cis%3Balready%3Descaped
--- error_code: 200


=== TEST 5: Append the query parameters from 'X-ApiDocs-Path'
Proxies the request with query parameters
--- request
GET /
--- more_headers eval
<<HTTP_HEADERS
X-ApiDocs-Url: http://test:$ENV{TEST_NGINX_SERVER_PORT}/ignored
X-ApiDocs-Path: /t
X-ApiDocs-Query: q=first&param=second&foo=bar
HTTP_HEADERS
--- upstream
location / {
  echo $query_string;
}
--- response_body
q=first&param=second&foo=bar
--- error_code: 200


=== TEST 6: Doesn't fail with empty 'X-ApiDocs-Query' header
Proxies the request with no query parameters
--- request
GET /
--- more_headers eval
<<HTTP_HEADERS
X-ApiDocs-Url: http://test:$ENV{TEST_NGINX_SERVER_PORT}/ignored
X-ApiDocs-Path: /t
HTTP_HEADERS
--- upstream
location / {
  echo "success!";
}
--- response_body
success!
--- error_code: 200


=== TEST 7: Allows underscores in headers
Request headers with underscores are not dropped
--- request
GET /
--- more_headers eval
<<HTTP_HEADERS
X-ApiDocs-Url: http://test:$ENV{TEST_NGINX_SERVER_PORT}/ignored
X-ApiDocs-Path: /t
api_key: abc123
HTTP_HEADERS
--- upstream
location /t {
  set_by_lua $apikey 'return ngx.var.http_api_key';
  echo $apikey;
}
--- response_body
abc123
--- error_code: 200
