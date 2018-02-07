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



=== TEST 3: print upstream request info
When X-ApiDocs-Debug header is set
--- request
GET /
--- more_headers eval
<<HTTP_HEADERS
X-ApiDocs-URL: http://test:$ENV{TEST_NGINX_SERVER_PORT}/ignored
X-ApiDocs-Path: /t
X-ApiDocs-Debug: true
Forwarded: proto=https;
HTTP_HEADERS
--- upstream
location = /t {
  echo "success!";
}
--- response_body
success!
--- error_code: 200
--- error_log
Forwarded: proto=https;
