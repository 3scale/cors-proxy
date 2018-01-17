test: build
	docker run --rm cors-proxy-app /tmp/scripts/run --daemon

build: rock
	s2i build . quay.io/3scale/s2i-openresty-centos7:1.11.2.5-1-rover2 cors-proxy-app

rock:
	luarocks make cors-proxy-scm-1.rockspec
