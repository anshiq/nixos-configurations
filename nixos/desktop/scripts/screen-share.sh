# screen-share status [--json]
# Whether something is sharing the screen over PipeWire (the portal screencast
# a browser, Teams or OBS asks for): counts running Stream/Output/Video nodes.
# Local wf-recorder recordings are not PipeWire streams; see screen-record.

count=$(pw-dump 2>/dev/null | jq '
  [ .[]
    | select(.type == "PipeWire:Interface:Node")
    | select(.info.props["media.class"] == "Stream/Output/Video")
    | select(.info.state == "running") ] | length
' 2>/dev/null || echo 0)
[ -n "$count" ] || count=0

case "${1:-status}" in
  status)
    if [ "$count" -gt 0 ]; then sharing=true; else sharing=false; fi
    if [ "${2:-}" = --json ]; then
      jq -cn --argjson sharing "$sharing" --argjson count "$count" '{sharing: $sharing, count: $count}'
    else
      echo "sharing: $sharing"
    fi
    ;;
  *)
    echo "usage: screen-share status [--json]" >&2
    exit 1
    ;;
esac
