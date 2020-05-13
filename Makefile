JUNIT_OUTPUT_DIR = $(dir $(JUNIT_OUTPUT_FILE))

BUILDER_IMAGE ?= quay.io/3scale/s2i-openresty-centos7:1.17.5.1-0-centos8
RUNTIME_IMAGE ?= $(BUILDER_IMAGE)-runtime
IMAGE_NAME ?= cors-proxy-candidate

.DEFAULT_GOAL := help

BUILD_TYPE ?= builder


build-builder: ## Build Docker image with all the development tools
	s2i build . $(BUILDER_IMAGE) $(IMAGE_NAME)

build-runtime: ## Build Docker image for runtime only
	s2i build . $(BUILDER_IMAGE) $(IMAGE_NAME) --runtime-image=$(RUNTIME_IMAGE)

dependencies:
	rover install

cpan:
	cpanm --notest --installdeps ./

start: ## Start cors-proxy from build Docker image
	docker run -p 8080:8080 --rm $(IMAGE_NAME)

# test: build-$(BUILD_TYPE)
test:
	docker run --rm \
		--mount type=tmpfs,destination=/var/lib/nginx,tmpfs-mode=1770 \
		$(IMAGE_NAME) sh -c 'exec $$([[ -f /tmp/scripts/run ]] && echo /tmp/scripts/run || echo /opt/app-root/scripts/run) --daemon'


$(JUNIT_OUTPUT_DIR):
	mkdir -p $@

$(JUNIT_OUTPUT_FILE): $(JUNIT_OUTPUT_DIR)

prove: cpan $(JUNIT_OUTPUT_FILE)
prove: ## Run integration tests
	rover exec prove

rock:
	luarocks make cors-proxy-scm-1.rockspec

#### Execute tests inside docker
DOCKER_PROVE_CMD ?= mkdir -p /tmp/junit && /usr/libexec/s2i/entrypoint sh -c 'rover exec prove --harness=TAP::Harness::JUnit'
docker-prove: ## Run Test::Nginx in the $(BUILDER_IMAGE) image
	docker run --rm -it -u $(shell id -u)  \
		--mount type=bind,source=$$(pwd),target=/opt/app-root/src \
		--mount type=tmpfs,destination=/var/lib/nginx,tmpfs-mode=1770 \
		-eJUNIT_OUTPUT_FILE=/tmp/junit/prove.xml \
		$(BUILDER_IMAGE)  $(MAKE) docker-exec CMD="$(DOCKER_PROVE_CMD)"

DOCKER_BUSTED_CMD := busted
docker-busted: ## Run lua tests in the $(BUILDER_IMAGE) image
	docker run --rm -it -u $(shell id -u)  \
		--mount type=bind,source=$$(pwd),target=/opt/app-root/src \
		--mount type=tmpfs,destination=/var/lib/nginx,tmpfs-mode=1770 \
		$(BUILDER_IMAGE)  $(MAKE) docker-exec CMD="$(DOCKER_BUSTED_CMD)"

DOCKER_SHELL_CMD := bash
docker-shell: ## Run lua tests in the $(BUILDER_IMAGE) image
	docker run --rm -it -u $(shell id -u)  \
		--mount type=bind,source=$$(pwd),target=/opt/app-root/src \
		--mount type=tmpfs,destination=/var/lib/nginx,tmpfs-mode=1770 \
		$(BUILDER_IMAGE)  $(MAKE) docker-exec CMD="$(DOCKER_SHELL_CMD)"

docker-exec: ## target to execute commands inside the $(BUILDER_IMAGE), mainly to execute tests both locally and in the CI
	$(MAKE) dependencies
	$(MAKE) cpan
	$(CMD)

clean: ## Cleans temp files/libraries inside the repo
	for file in $$(cat .gitignore); do rm -rf $${file}; done

# Check http://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
help: ## Print this help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
