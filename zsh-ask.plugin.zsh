#! /usr/bin/env zsh

# 初始化环境变量
export ASK_KB_DIR="${ASK_KB_DIR:-$HOME/Documents/knowledge_base}"
export ASK_OLLAMA_MODEL="${ASK_OLLAMA_MODEL:-deepseek-local}"
export ASK_PY_SCRIPT="${0:A:h}/ask-core.py"

# 主命令：ask
function ask() {
    if [[ "$1" == "--reindex" ]]; then
        python3 $ASK_PY_SCRIPT --reindex
    elif [[ "$1" == "--chat" ]]; then
        echo "Entering chat mode (type 'exit' to end):"
        while true; do
            read -er "?Question > "
            [[ "$REPLY" == "exit" ]] && break
            python3 $ASK_PY_SCRIPT "$REPLY"
        done
    else
        python3 $ASK_PY_SCRIPT "$@"
    fi
}

# 自动补全配置
function _ask_autocomplete() {
    local context state state_descr line
    typeset -A opt_args

    _arguments \
        "--reindex[Rebuild knowledge base index]" \
        "--chat[Start interactive chat]" \
        "*::query:->query"
    
    case $state in
        query)
            _files -W "$ASK_KB_DIR"
            _message "Enter your question or select a document"
            ;;
    esac
}

compdef _ask_autocomplete ask

# 快捷别名
alias askc="ask --chat"
alias askr="ask --reindex"