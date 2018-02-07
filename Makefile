JUNIT_OUTPUT_DIR = $(dir $(JUNIT_OUTPUT_FILE))

BUILDER_IMAGE ?= quay.io/3scale/s2i-openresty-centos7:1.13.6.1-rover5
RUNTIME_IMAGE ?= $(BUILDER_IMAGE)-runtime
IMAGE_NAME ?= cors-proxy-candidate

BUILD_TYPE ?= builder

test: build-$(BUILD_TYPE)
	docker run --rm $(IMAGE_NAME) sh -c 'exec $$([[ -f /tmp/scripts/run ]] && echo /tmp/scripts/run || echo /opt/app-root/scripts/run) --daemon'

build-builder:
	s2i build . $(BUILDER_IMAGE) $(IMAGE_NAME)

build-runtime:
	s2i build . $(BUILDER_IMAGE) $(IMAGE_NAME) --runtime-image=$(RUNTIME_IMAGE)

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
