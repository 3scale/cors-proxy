JUNIT_OUTPUT_DIR = $(dir $(JUNIT_OUTPUT_FILE))

test: build
	docker run --rm cors-proxy-app /tmp/scripts/run --daemon

build: rock
	s2i build . quay.io/3scale/s2i-openresty-centos7:1.11.2.5-1-rover2 cors-proxy-app

dependencies:
	rover install

cpan:
	cpanm --notest --installdeps ./

$(JUNIT_OUTPUT_DIR):
	mkdir -p $@

$(JUNIT_OUTPUT_FILE): $(JUNIT_OUTPUT_DIR)

prove: cpan $(JUNIT_OUTPUT_FILE)
	rover exec prove

rock:
	luarocks make cors-proxy-scm-1.rockspec

clean:
	rm -rf tmp lua_modules t/servroot*
