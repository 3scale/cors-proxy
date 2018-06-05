# cors-proxy

Welcome to new project using [APIcast-cli](https://github.com/3scale/apicast-cli).

## Usage

You can start the server:

```shell
apicast-cli start -e development
```

## Deployment

Build process uses s2i to package docker image.

```shell
s2i build . quay.io/3scale/s2i-openresty-centos7:1.11.2.5-1-rover2  cors-proxy-app
```

Run the container:
```shell
docker run --rm --name corsproxy -p 8080:8080 cors-proxy-app
```

You can deploy app to OpenShift by running:

```shell
oc new-app quay.io/3scale/s2i-openresty-centos7:1.11.2.5-1-rover2~https://github.com/3scale/cors-proxy.git
```