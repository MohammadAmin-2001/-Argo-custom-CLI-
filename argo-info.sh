#!/bin/sh

usage() {
  echo ""
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --app-name <name>          ArgoCD app name"
  echo "  --server <url>             ArgoCD server URL"
  echo "  --token <token>            ArgoCD authentication token"
  echo "  --get-app-health           Extract app health status"
  echo "  --get-deployment-health    Extract deployment health status (requires --deployment-name)"
  echo "  --image-name               Extract deployment image (requires --deployment-name)"
  echo "  --deployment-name <name>   Deployment name to extract image from"
  echo "  --timeout int              Timeout for using --get-deployment-health (requires --get-deployment-health)"
  echo "  -r                         Refresh app before fetching info"
  echo "  -i                         Allow insecure ArgoCD server URL"
  echo "  -h                         Show this help message"
  echo ""
  exit 0
}

REFRESH_FLAG=""
INSECURE_FLAG=""
EXTRACT_IMAGE=false
EXTRACT_HEALTH=false
EXTRACT_DEPLOYMENT_HEALTH=false
TIMEOUT=40

while [ $# -gt 0 ]; do
  case "$1" in
    --app-name)        APP_NAME="$2";        shift 2 ;;
    --server)          SERVER_URL="$2";      shift 2 ;;
    --token)           AUTH_TOKEN="$2";      shift 2 ;;
    --deployment-name) DEPLOYMENT_NAME="$2"; shift 2 ;;
    --image-name)      EXTRACT_IMAGE=true;   shift ;;
    --get-app-health)  EXTRACT_HEALTH=true;  shift ;;
    --get-deployment-health) EXTRACT_DEPLOYMENT_HEALTH=true;  shift ;;
    --timeout)         TIMEOUT=$2;  shift 2 ;;
    -r)                REFRESH_FLAG="--refresh"; shift ;;
    -i)                INSECURE_FLAG="--insecure"; shift ;;
    -h)                usage ;;
    *)                 echo "Unknown flag: $1"; usage ;;
  esac
done

if [ -z "$APP_NAME" ] || [ -z "$SERVER_URL" ] || [ -z "$AUTH_TOKEN" ]; then
  echo "Error: missing required flags (--app-name, --server, --token)"
  usage
fi

if [ "$EXTRACT_IMAGE" = true ] && [ -z "$DEPLOYMENT_NAME" ]; then
  echo "Error: --image-name requires --deployment-name"
  usage
fi

if [ "$EXTRACT_DEPLOYMENT_HEALTH" = true ] && [ -z "$DEPLOYMENT_NAME" ]; then
  echo "Error: --get-deployment-health requires --deployment-name"
  usage
fi


INFO=$(argocd app get "$APP_NAME" \
  --server "$SERVER_URL" \
  --auth-token "$AUTH_TOKEN" \
  $REFRESH_FLAG \
  $INSECURE_FLAG \
  --grpc-web \
  -o json)


if [ -z "$INFO" ]; then
  echo '{"error": "failed to get app info"}'
  exit 1
fi

if [ "$EXTRACT_DEPLOYMENT_HEALTH" = true ]; then
    if argocd app wait "$APP_NAME" \
        --server "$SERVER_URL" \
        --auth-token "$AUTH_TOKEN" \
        --health \
        --resource "apps:Deployment:$DEPLOYMENT_NAME" \
        --timeout $TIMEOUT \
        --grpc-web \
        $INSECURE_FLAG > /dev/null 2>&1 ; then

        DEPLOYMENT_HEALTH="Healthy"
    else
        DEPLOYMENT_HEALTH="Unhealthy"
    fi
fi



# build output conditionally
HEALTH_ARG=""
IMAGE_ARG=""
DEPLOYMENT_ARG=""
JQ_FILTER='{info: $info'

if [ "$EXTRACT_HEALTH" = true ]; then
  HEALTH=$(echo "$INFO" | jq -r '.status.health.status')
  HEALTH_ARG="--arg app_health $HEALTH"
  JQ_FILTER="$JQ_FILTER, app_health: \$app_health"
fi

if [ "$EXTRACT_IMAGE" = true ]; then
  IMAGE=$(echo "$INFO" \
    | jq -r ".status.operationState.syncResult.resources" \
    | jq -r --arg d "$DEPLOYMENT_NAME" '.[] | select(.name == $d) | .images[]')
  IMAGE_ARG="--arg image $IMAGE"
  JQ_FILTER="$JQ_FILTER, image: \$image"
fi

if [ "$EXTRACT_DEPLOYMENT_HEALTH" = true ] && [ -n "$DEPLOYMENT_HEALTH" ]; then

  DEPLOYMENT_ARG="--arg deployment_health $DEPLOYMENT_HEALTH"
  JQ_FILTER="$JQ_FILTER, deployment_health: \$deployment_health"
fi


JQ_FILTER="$JQ_FILTER}"

jq -n --argjson info "$INFO" $HEALTH_ARG $IMAGE_ARG $DEPLOYMENT_ARG "$JQ_FILTER"
