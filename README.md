# cors-proxy

## Description

cors-proxy is an apicast based proxy that manages CORS requests in behalf of a client's apicast gateway. It mainly exists because clients do not correcly setup CORS in their apicast integrations, making CORS requests for the apidocs functionality fail in the 3scale SaaS. To avoid this, cors-proxy sits in the middle of this type of requests and transparently handles CORS so the final user browser does not fail on cross domain requests.
This is a very specific scenario that happens with the apidocs functionality, where the user browser, inside a 3scale.net domain, will request the api swagger to the client's api through apicast, in a differen domain.

It works by whitelisting the domains that are allowed to perform requests through cors-proxy by querying the system database. If the domain is whitelisted, cors-proxy will contact the user's apicast to retrieve the swagger api spec and return it to the browser with the proper CORS headers in place. It also hanldes CORS preflight requests.

## Configuration

### Environment variables

### Environmnet variables

| Varible                       | Default               | Purpose                                                                              |
|-------------------------------|-----------------------|--------------------------------------------------------------------------------------|
| DATABASE_URL                  | N/A                   | [required] system dsn, with format `mysql://<user>:<pass>@<host>:<port>/<database>`  |
| CORS_PROXY_BALANCER_WHITELIST | N/A                   | manually add IPs to the whitelist                                                    |

### Exposed ports

* Proxy is exposed in port 8080
* Metrics are exposed in port 9145

## Development

### Local test execution with docker

* Unit tests: `make docker-busted`
* Integration tests: `make docker-prove`

### Release process

The release process is managed with a [CircleCI pipeline](https://app.circleci.com/pipelines/github/3scale/cors-proxy). This pipeline can be triggered in two different ways:

* With every push of code to the repo, the build and test steps of the pipeline wil be executed
* When an annotated git tag is pushed to the repo that matches the pattern "v.*", the pipeline will execute the build, test and release steps. The release step will push a new image to quay.io/3scale/cors-proxy, tagged with the git tag. It will also tag the image as latest. The recommended way to create a new git annotated tag is to create a new GitHub release in this repository, with all the release information.

### cors-proxy image

The cors-proxy image is published to [quay.io/3scale/cors-proxy](https://quay.io/repository/3scale/cors-proxy?tab=tags). The image is built using the [s2i](https://github.com/openshift/source-to-image) tool (source to image), using [quay.io/3scale/s2i-openresty-centos7](https://quay.io/repository/3scale/s2i-openresty-centos7?tab=tags) as the builder image. To update the tag of the builder image you will need to change it both in the Makefile (for local image generation) and in the circleci configuration yaml. The builder image is built from [this repo](https://github.com/3scale/s2i-openresty).
