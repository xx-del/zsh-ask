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