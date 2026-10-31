# ocr [--qr | --text] [--translate [LANG]] [--lang LANGS] [--file FILE | --stdin]
#
# Copy text from anywhere on screen. Drag a region (the screen freezes while
# you pick); the text is copied to the clipboard (so it also lands in the
# Super+V history) and shown in a notification.
#   (default)       QR/barcode first, then OCR
#   --qr            only look for a QR code or barcode
#   --text          only OCR
#   --translate [L] translate the result to language L (default: en); this
#                   sends the text to Google Translate, nothing else does
#   --lang LANGS    tesseract languages, e.g. eng+hin (default; or $OCR_LANG)
#   --file FILE     read an image file instead of picking a region
#   --stdin         read an image from stdin (used by the clipboard panel)
# The recognised text is also printed on stdout.

lang="${OCR_LANG:-eng+hin}"
mode=auto
translate=""
input=screen
file=""

usage() {
  echo "usage: ocr [--qr | --text] [--translate [LANG]] [--lang LANGS] [--file FILE | --stdin]" >&2
  exit 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    --qr) mode=qr ;;
    --text) mode=text ;;
    --translate)
      translate=en
      if [ $# -gt 1 ] && [[ "$2" != -* ]]; then
        translate="$2"
        shift
      fi
      ;;
    --lang)
      [ $# -gt 1 ] || usage
      lang="$2"
      shift
      ;;
    --file)
      [ $# -gt 1 ] || usage
      input=image
      file="$2"
      shift
      ;;
    --stdin) input=pipe ;;
    *) usage ;;
  esac
  shift
done

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
img="$work/shot.png"

case "$input" in
  screen) freeze_region "$img" || exit 0 ;;
  image) cp -- "$file" "$img" ;;
  pipe) cat > "$img" ;;
esac

text=""
kind=""

if [ "$mode" != text ]; then
  if text=$(zbarimg --quiet --raw "$img" 2>/dev/null) && [ -n "$text" ]; then
    kind="QR code"
  else
    text=""
  fi
fi

if [ -z "$kind" ] && [ "$mode" != qr ]; then
  # Grey, enlarged and (for light-on-dark text, e.g. a terminal) inverted:
  # tesseract reads dark-on-light text at a decent size best.
  prepared="$work/prepared.png"
  mean=$(magick "$img" -colorspace Gray -format '%[fx:mean]' info: 2>/dev/null || echo 1)
  negate=()
  if awk -v m="$mean" 'BEGIN { exit !(m < 0.5) }'; then
    negate=(-negate)
  fi
  if ! magick "$img" -colorspace Gray "${negate[@]}" -resize 200% -normalize "$prepared" 2>/dev/null; then
    prepared="$img"
  fi
  text=$(tesseract "$prepared" stdout -l "$lang" --psm 6 2>/dev/null || true)
  text=$(printf '%s\n' "$text" | tr -d '\f' | sed -e 's/[[:space:]]*$//' | sed '/./,$!d')
  [ -n "$text" ] && kind="Text"
fi

if [ -z "$text" ]; then
  notify-send -t 3000 "Nothing found" "No text or QR code in that region" 2>/dev/null || true
  exit 0
fi

if [ -n "$translate" ]; then
  printf '%s\n' "$text" > "$work/text.txt"
  if translated=$(trans -b ":$translate" -i "$work/text.txt" 2>/dev/null) && [ -n "$translated" ]; then
    text="$translated"
    kind="$kind, translated to $translate"
  else
    kind="$kind (translation failed)"
  fi
fi

printf '%s' "$text" | wl-copy >/dev/null 2>&1
printf '%s\n' "$text"

# Notification bodies are markup (Quickshell's daemon renders it).
body="${text:0:300}"
body="${body//&/&amp;}"
body="${body//</&lt;}"
body="${body//>/&gt;}"
notify-send -t 5000 "$kind copied" "$body" 2>/dev/null || true
