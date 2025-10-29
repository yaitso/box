oi() {
  local oi_code=$(cat)
  echo "[oi heredoc received]"
  echo "$oi_code"
}

__oi_snippet() {
  local template=$'oi <<OI\n\nOI'
  READLINE_LINE="${READLINE_LINE:0:$READLINE_POINT}${template}${READLINE_LINE:$READLINE_POINT}"
  READLINE_POINT=$((READLINE_POINT + 8))
}
bind -x '"\C-o": __oi_snippet'

