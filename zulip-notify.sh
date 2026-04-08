#!/bin/sh

usage() {
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "  --url <url>       Zulip bot URL"
  echo "  --email <email>   Zulip bot email"
  echo "  --api-key <key>   Zulip bot API key"
  echo "  --type <type>     Message type (stream or direct)"
  echo "  --to <to>         Stream name or user email"
  echo "  --topic <topic>   Topic (required for stream messages)"
  echo "  --content <text>  Message content"
  echo "  -h                Show this help"
  exit 0
}

while [ $# -gt 0 ]; do
  case "$1" in
    --url)     ZULIP_BOT_URL="$2";     shift 2 ;;
    --email)   ZULIP_BOT_EMAIL="$2";   shift 2 ;;
    --api-key) ZULIP_BOT_API_KEY="$2"; shift 2 ;;
    --type)    TYPE_MESSAGE="$2";      shift 2 ;;
    --to)      TO="$2";                shift 2 ;;
    --topic)   TOPIC="$2";             shift 2 ;;
    --content) CONTENT="$2";shift 2 ;;
    -h)        usage ;;
    *)         echo "Unknown flag: $1"; usage ;;
  esac
done

if [ -z "$ZULIP_BOT_URL" ] || [ -z "$ZULIP_BOT_EMAIL" ] || [ -z "$ZULIP_BOT_API_KEY" ] || \
   [ -z "$TYPE_MESSAGE" ] || [ -z "$TO" ] || [ -z "$CONTENT" ]; then
  echo "Error: missing required flags"
  usage
  exit 1
fi

curl -s -X POST "$ZULIP_BOT_URL" \
  -u "$ZULIP_BOT_EMAIL:$ZULIP_BOT_API_KEY" \
  -d "type=$TYPE_MESSAGE" \
  -d "to=$TO" \
  ${TOPIC:+-d "topic=$TOPIC"} \
  --data-urlencode "content=$CONTENT" || exit 1


