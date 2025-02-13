deekseek生成的，命令行本地知识库，zsh插件

以下是专为 **Zsh** 开发的插件实现方案，可将本地知识库 + Ollama + DeepSeek 的问答功能深度集成到终端环境中：

---

### **1. 插件目录结构**
```bash
~/.oh-my-zsh/custom/plugins/zsh-ask/
├── zsh-ask.plugin.zsh   # 主插件逻辑
├── ask-core.py          # Python核心逻辑
├── _ask                 # Zsh自动补全文件
└── README.md            # 使用说明
```

---

### **2. 核心实现文件**

#### **2.1 Python 核心脚本 `ask-core.py`**
```python
import sys
from llama_index import VectorStoreIndex, SimpleDirectoryReader
from llama_index.llms import Ollama
import os

# 从环境变量读取配置
DOCS_DIR = os.getenv("ASK_KB_DIR", "~/Documents/knowledge_base")
OLLAMA_MODEL = os.getenv("ASK_OLLAMA_MODEL", "deepseek-local")
OLLAMA_BASE = os.getenv("ASK_OLLAMA_BASE_URL", "http://localhost:11434")

class AskAgent:
    def __init__(self):
        self.llm = Ollama(model=OLLAMA_MODEL, base_url=OLLAMA_BASE)
        self.index = self.load_index()
    
    def load_index(self):
        documents = SimpleDirectoryReader(os.path.expanduser(DOCS_DIR)).load_data()
        return VectorStoreIndex.from_documents(documents)
    
    def query(self, question):
        return self.index.as_query_engine(llm=self.llm).query(question)

if __name__ == "__main__":
    agent = AskAgent()
    if len(sys.argv) > 1:
        if sys.argv[1] == "--reindex":
            agent.index = agent.load_index()
            print("Index reloaded!")
        else:
            print(agent.query(" ".join(sys.argv[1:])))
    else:
        print("Usage: ask-core.py [question|--reindex]")
```

#### **2.2 Zsh 插件主文件 `zsh-ask.plugin.zsh`**
```zsh
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
```

#### **2.3 自动补全文件 `_ask`**
```zsh
#compdef ask

local -a commands
commands=(
    "--reindex[Rebuild knowledge base index]"
    "--chat[Start interactive chat]"
)

_arguments -C \
    $commands \
    '*:: :->args' && return
```

---

### **3. 安装步骤**

1. **创建插件目录**：
   ```bash
   mkdir -p ~/.oh-my-zsh/custom/plugins/zsh-ask
   ```

2. **放入上述三个文件**到目录中

3. **修改 `.zshrc`** 启用插件：
   ```zsh
   plugins=(... zsh-ask)
   ```

4. **安装 Python 依赖**：
   ```bash
   pip install llama-index python-dotenv watchdog
   ```

---

### **4. 使用示例**

#### **基础问答**：
```zsh
$ ask "解释量子纠缠的基本原理"
>> Answer: 量子纠缠是指两个或多个粒子...

# 自动补全文档内容（按Tab键）
$ ask ~/Documents/knowledge_base/物理基础.md "总结核心观点"
```

#### **交互式对话**：
```zsh
$ askc
Entering chat mode (type 'exit' to end):
Question > 如何用Python实现快速排序？
>> Answer: 以下是快速排序的Python实现...
Question > exit
```

#### **重建索引**：
```zsh
$ askr
Index reloaded!
```

---

### **5. 高级功能扩展**

#### **5.1 添加文件监控自动更新**
在 `ask-core.py` 的 `AskAgent` 类中新增：
```python
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

class AutoIndexHandler(FileSystemEventHandler):
    def on_modified(self, event):
        self.agent.index = self.agent.load_index()

def start_watcher(self):
    observer = Observer()
    observer.schedule(AutoIndexHandler(self), path=DOCS_DIR, recursive=True)
    observer.start()
```

#### **5.2 添加会话历史记录**
在 `zsh-ask.plugin.zsh` 中添加：
```zsh
ASK_HISTORY_FILE="${HOME}/.ask_history"

function _ask_persist_history() {
    local question="$1"
    local answer="$2"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] Q: $question\nA: $answer" >> $ASK_HISTORY_FILE
}

# 修改主函数
function ask() {
    # ...原有逻辑...
    local response=$(python3 $ASK_PY_SCRIPT "$REPLY")
    _ask_persist_history "$REPLY" "$response"
    echo ">> Answer: $response"
}
```

---

### **6. 性能优化建议**

1. **启用 GPU 加速**：
   ```zsh
   export OLLAMA_NUM_GPU=1  # 在.zshrc中设置
   ```

2. **使用量化模型**：
   ```zsh
   export ASK_OLLAMA_MODEL="deepseek-7b-Q4_K_M"
   ```

3. **索引缓存**（修改 `ask-core.py`）：
   ```python
   from llama_index import StorageContext, load_index_from_storage

   def load_index(self):
       try:
           storage_context = StorageContext.from_defaults(persist_dir="./storage")
           return load_index_from_storage(storage_context)
       except:
           documents = SimpleDirectoryReader(...).load_data()
           index = VectorStoreIndex.from_documents(documents)
           index.storage_context.persist(persist_dir="./storage")
           return index
   ```

---

### **方案特点**
1. **深度 Zsh 集成**：
   - 支持参数自动补全
   - 历史记录持久化
   - 智能文档路径提示

2. **生产级功能**：
   - 后台文件监控
   - 索引缓存加速
   - 多会话管理

3. **用户友好**：
   ```zsh
   # 一键帮助提示
   function ask-help() {
       echo "Usage:"
       echo "  ask <question>      # 直接提问"
       echo "  askc                # 进入对话模式"
       echo "  askr                # 重建知识库索引"
       echo "Environment Variables:"
       echo "  ASK_KB_DIR          # 知识库路径 (默认: ~/Documents/knowledge_base)"
       echo "  ASK_OLLAMA_MODEL    # 模型名称 (默认: deepseek-local)"
   }
   ```

将插件代码托管至 GitHub 仓库，即可通过 Oh My Zsh 的插件管理器一键安装：
```zsh
git clone https://github.com/yourname/zsh-ask ~/.oh-my-zsh/custom/plugins/zsh-ask
```# zsh-ask
