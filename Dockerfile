ARG PUBKY_CORE_VERSION=0.9.3

FROM --platform=$BUILDPLATFORM alpine:3.22 AS downloader

ARG PUBKY_CORE_VERSION
ARG TARGETARCH

RUN set -eux; \
    case "$TARGETARCH" in \
        amd64|arm64) archive_arch="$TARGETARCH" ;; \
        *) echo "Unsupported architecture: $TARGETARCH" >&2; exit 1 ;; \
    esac; \
    apk add --no-cache ca-certificates curl tar; \
    archive="pubky-core-v${PUBKY_CORE_VERSION}-linux-${archive_arch}.tar.gz"; \
    curl --fail --location --silent --show-error \
        "https://github.com/pubky/pubky-core/releases/download/v${PUBKY_CORE_VERSION}/${archive}" \
        --output /tmp/pubky-core.tar.gz; \
    tar -xzf /tmp/pubky-core.tar.gz -C /tmp; \
    install -D \
        "/tmp/pubky-core-v${PUBKY_CORE_VERSION}-linux-${archive_arch}/pubky-homeserver" \
        /out/pubky-homeserver

FROM alpine:3.22

COPY --from=downloader /out/pubky-homeserver /usr/local/bin/pubky-homeserver
COPY --from=downloader /etc/ssl/cert.pem /etc/ssl/cert.pem
COPY --from=downloader /etc/ssl/certs /etc/ssl/certs

VOLUME ["/data"]

EXPOSE 6286 6287 6288 6289

ENTRYPOINT ["pubky-homeserver"]
CMD ["--data-dir", "/data"]
