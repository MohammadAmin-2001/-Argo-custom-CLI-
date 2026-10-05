# Argo Custom CLI

A lightweight container with shell utilities for inspecting Argo CD applications, checking deployment health, and sending deployment updates to Zulip. Use it in command-line workflows and CI/CD jobs to retrieve deployment details as JSON or generate a formatted status message.

## Features

- Fetch Argo CD application details as JSON.
- Extract application health and deployment image information.
- Wait for a deployment to become healthy with a configurable timeout.
- Generate a Markdown deployment summary with status emoji.
- Send messages to Zulip streams or direct conversations.

## Included tools

| Command | Source | Purpose |
| --- | --- | --- |
| `argo-info` | `argo-info.sh` | Retrieve application details and optional health/image fields. |
| `get-info` | `get-info.sh` | Generate a deployment status message using `argo-info`. |
| `zulip-notify` | `zulip-notify.sh` | Send a message to a Zulip API endpoint. |

The Docker image uses Alpine 3.23 and includes Argo CD CLI 3.3.6, `curl`, `jq`, and CA certificates. The Dockerfile downloads the Linux AMD64 Argo CD binary, so use an AMD64 container environment.

## Build and run

From the repository directory:

```sh
docker build -t argo-custom-cli:local .
```

The image starts with `sh` as its entrypoint. Use `-c` to run a command or open an interactive shell:

```sh
docker run --rm -it argo-custom-cli:local
```

To run outside Docker, install `argocd`, `jq`, and `curl`, then run the scripts with `sh`. For `get-info.sh`, also make `argo-info.sh` available on your `PATH` under the command name `argo-info`.

## Retrieve application information

Set these variables in your host shell:

```sh
export ARGOCD_SERVER='argocd.example.com'
export ARGOCD_APP='my-app'
export ARGOCD_DEPLOYMENT='my-deployment'
export ARGOCD_TOKEN='<your-argocd-token>'
```

Fetch application details, health, and deployment image information:

```sh
docker run --rm \
  --env ARGOCD_SERVER --env ARGOCD_APP \
  --env ARGOCD_DEPLOYMENT --env ARGOCD_TOKEN \
  argo-custom-cli:local -c '
    argo-info \
      --app-name "$ARGOCD_APP" \
      --server "$ARGOCD_SERVER" \
      --token "$ARGOCD_TOKEN" \
      --deployment-name "$ARGOCD_DEPLOYMENT" \
      --get-app-health \
      --image-name \
      --get-deployment-health \
      --timeout 60
  '
```

The output always contains `info`, the full application JSON. Requested fields appear alongside it as `app_health`, `image`, and `deployment_health`.

| Option | Description |
| --- | --- |
| `--app-name <name>` | Required Argo CD application name. |
| `--server <server>` | Required Argo CD server address. |
| `--token <token>` | Required authentication token. |
| `--get-app-health` | Include application health. |
| `--image-name` | Include image information; requires `--deployment-name`. |
| `--get-deployment-health` | Wait for deployment health; requires `--deployment-name`. |
| `--deployment-name <name>` | Deployment to inspect. |
| `--timeout <seconds>` | Deployment health wait timeout; defaults to `40`. |
| `-r` | Refresh the application before fetching details. |
| `-i` | Skip Argo CD server TLS certificate verification. |
| `-h` | Show help. |

Argo CD requests use `--grpc-web`. Deployment health is reported as `Healthy` when the wait succeeds and `Unhealthy` when it fails, including a timeout. Image information comes from `.status.operationState.syncResult.resources` and requires image data in that sync result.

## Generate a deployment summary

Inside the container, run the following with your Argo CD variables set:

```sh
get-info \
  --app-name "$ARGOCD_APP" \
  --deployment-name "$ARGOCD_DEPLOYMENT" \
  --server "$ARGOCD_SERVER" \
  --token "$ARGOCD_TOKEN" \
  -r
```

All four named arguments are required. `get-info` also accepts `-i` and `-h`, and uses the default 40-second deployment health wait.

Example output:

```text
:info: **Deployment Status**
- **Namespace Health**: :green_circle: Healthy
- **Deployment Health**: :green_circle: Healthy
- **Environment**: my-app
- **Image**: `registry.example.com/my-app:latest`
```

The `Namespace Health` label represents the Argo CD application's health. The message is printed to standard output for use in notifications.

## Send a Zulip notification

Inside the container, set `ZULIP_BOT_EMAIL` and `ZULIP_BOT_API_KEY`, then run:

```sh
zulip-notify \
  --url 'https://zulip.example.com/api/v1/messages' \
  --email "$ZULIP_BOT_EMAIL" \
  --api-key "$ZULIP_BOT_API_KEY" \
  --type stream \
  --to 'deployments' \
  --topic 'my-app' \
  --content 'Deployment completed.'
```

Supply the full messages API endpoint with `--url`. All arguments except `--topic` are checked as required by the script; supply a topic for stream messages. For a direct message, use `--type direct` and the recipient email with `--to`. The command prints the API response.

To send a generated summary, run both commands in the same container or environment:

```sh
CONTENT=$(get-info \
  --app-name "$ARGOCD_APP" \
  --deployment-name "$ARGOCD_DEPLOYMENT" \
  --server "$ARGOCD_SERVER" \
  --token "$ARGOCD_TOKEN")

zulip-notify \
  --url 'https://zulip.example.com/api/v1/messages' \
  --email "$ZULIP_BOT_EMAIL" \
  --api-key "$ZULIP_BOT_API_KEY" \
  --type stream \
  --to 'deployments' \
  --topic "$ARGOCD_APP" \
  --content "$CONTENT"
```

For CI/CD, provide credentials through your CI system's secret variables and pass them into the container as environment variables.
