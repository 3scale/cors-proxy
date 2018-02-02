BEGIN {
    $ENV{TEST_NGINX_APICAST_BINARY} ||= 'rover exec apicast-cli';
}

use lib 't';
use Test::APIcast::Blackbox 'no_plan';

add_block_preprocessor(sub {
    my $block = shift;

    my $Workers = $Test::Nginx::Util::Workers;
    my $MasterProcessEnabled = $Test::Nginx::Util::MasterProcessEnabled;
    my $DaemonEnabled = $Test::Nginx::Util::DaemonEnabled;
    my $err_log_file = $block->error_log_file || $Test::Nginx::Util::ErrLogFile;
    my $LogLevel = $Test::Nginx::Util::LogLevel;
    my $PidFile = $Test::Nginx::Util::PidFile;
    my $AccLogFile = $Test::Nginx::Util::AccLogFile;
    my $ServerPort = $Test::Nginx::Util::ServerPort;

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
    env = { }
}
_EOC_
    $block->set_value("environment",$environment);
});

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
