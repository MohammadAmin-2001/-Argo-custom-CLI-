#!/bin/sh

usage() {
  echo ""
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --app-name <name>          ArgoCD app name"
  echo "  --deployment-name <name>   Deployment name"
  echo "  --server <url>             ArgoCD server URL"
  echo "  --token <token>            ArgoCD auth token"
  echo "  -r                         Refresh app before fetching"
  echo "  -i                         Allow insecure ArgoCD server URL"
  echo "  -h                         Show this help message"
  echo ""
  exit 0
}

while [ $# -gt 0 ]; do
  case "$1" in
    --app-name)        APP_NAME="$2";        shift 2 ;;
    --deployment-name) DEPLOYMENT_NAME="$2"; shift 2 ;;
    --server)          ARGOCD_SERVER_URL="$2"; shift 2 ;;
    --token)           ARGOCD_AUTH_TOKEN="$2"; shift 2 ;;
    -r)                REFRESH_FLAG="-r";    shift ;;
    -i)                INSECURE_FLAG="-i"; shift ;;
    -h)                usage ;;
    *)                 echo "Unknown flag: $1"; usage ;;
  esac
done

if [ -z "$APP_NAME" ] || [ -z "$DEPLOYMENT_NAME" ] || [ -z "$ARGOCD_SERVER_URL" ] || [ -z "$ARGOCD_AUTH_TOKEN" ]; then
  echo "Error: --app-name, --deployment-name, --server, and --token are required"
  usage
fi

ARGO_INFO=$(argo-info \
  --app-name $APP_NAME \
  --server $ARGOCD_SERVER_URL \
  --token $ARGOCD_AUTH_TOKEN \
  --image-name \
  --deployment-name $DEPLOYMENT_NAME \
  --get-app-health \
  --get-deployment-health \
  $REFRESH_FLAG \
  $INSECURE_FLAG)

[ -z "$ARGO_INFO" ] && echo "Error: argo-info returned no output" && exit 1

HEALTH=$(echo "$ARGO_INFO" | jq -r '.app_health // empty')
IMAGE=$(echo "$ARGO_INFO" | jq -r '.image // empty')
DEPLOYMENT_HEALTH=$(echo "$ARGO_INFO" | jq -r '.deployment_health // empty')

[ -z "$HEALTH" ] && echo "Error: app_health not found" && exit 1
[ -z "$IMAGE" ]  && echo "Error: image not found" && exit 1
[ -z "$DEPLOYMENT_HEALTH" ] && DEPLOYMENT_HEALTH="$HEALTH"

case "$HEALTH" in
  Healthy)     STATUS=":green_circle: Healthy" ;;
  Progressing) STATUS=":yellow_circle: Progressing" ;;
  *)           STATUS=":red_circle: Unhealthy" ;;
esac

case "$DEPLOYMENT_HEALTH" in
  Healthy)     JOB_STATUS=":green_circle: Healthy" ;;
  Progressing) JOB_STATUS=":yellow_circle: Progressing" ;;
  *)           JOB_STATUS=":red_circle: Unhealthy" ;;
esac

CONTENT=$(cat <<EOF
:info: **Deployment Status**
- **Namespace Health**: $STATUS
- **Deployment Health**: $JOB_STATUS
- **Environment**: $APP_NAME 
- **Image**: \`$IMAGE\`
EOF
)

echo "$CONTENT"