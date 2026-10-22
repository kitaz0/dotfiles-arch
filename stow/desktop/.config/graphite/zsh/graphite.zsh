# Optional Zsh prompt only. Source once from your own .zshrc, after prompt plugins.
# No aliases, history, completion, editor or shell settings are changed.
[[ -o interactive ]] || return
[[ -z ${GRAPHITE_PROMPT_LOADED:-} ]] || return
typeset -g GRAPHITE_PROMPT_LOADED=1
PROMPT='%F{#b8bb26}%n%f %F{#a89984}%~%f %(?.%F{#b8bb26}.%F{#fb4934})?%f '
