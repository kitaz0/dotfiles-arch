# Optional Zsh prompt only. Source once from your own .zshrc, after prompt plugins.
# No aliases, history, completion, editor or shell settings are changed.
[[ -o interactive ]] || return
[[ -z ${GRAPHITE_PROMPT_LOADED:-} ]] || return
typeset -g GRAPHITE_PROMPT_LOADED=1
PROMPT='%F{#fe8019}%n%f %F{#a89984}%~%f %(?.%F{#fe8019}.%F{#fb4934})?%f '
