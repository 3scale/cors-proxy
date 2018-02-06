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
    metrics_port = '$ServerPort',
    env = { },
    sites_d = [============================[$sites_d]============================],
}
_EOC_

    $block->set_value("environment",$environment);
};

repeat_each(2);
run_tests();

__DATA__

=== TEST 1: GET /metrics
Responds with prometheus metrics
--- request
GET /metrics
--- more_headers
Host: metrics
--- response_body
# HELP nginx_http_connections Number of HTTP connections
# TYPE nginx_http_connections gauge
nginx_http_connections{state="accepted"} 0
nginx_http_connections{state="active"} 1
nginx_http_connections{state="handled"} 0
nginx_http_connections{state="reading"} 0
nginx_http_connections{state="total"} 0
nginx_http_connections{state="waiting"} 0
nginx_http_connections{state="writing"} 1
# HELP nginx_metric_errors_total Number of nginx-lua-prometheus errors
# TYPE nginx_metric_errors_total counter
nginx_metric_errors_total 0
--- error_code: 200
