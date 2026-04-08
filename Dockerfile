FROM docker.arvancloud.ir/alpine:3.23

# Install dependencies
RUN apk add --no-cache \
    curl \
    jq \
    ca-certificates \
    && update-ca-certificates

# Download and install Argo CD CLI
RUN curl -sSL "https://github.com/argoproj/argo-cd/releases/download/v3.3.6/argocd-linux-amd64" -o /usr/local/bin/argocd \
        && chmod +x /usr/local/bin/argocd

    # Verify installations
RUN argocd version --client || true \
    && curl --version \
    && jq --version

COPY ./argo-info.sh /bin/argo-info
COPY ./get-info.sh /bin/get-info
COPY ./zulip-notify.sh /bin/zulip-notify

RUN  chmod +x /bin/argo-info && chmod +x  /bin/zulip-notify && chmod +x /bin/get-info
ENTRYPOINT ["sh"]
