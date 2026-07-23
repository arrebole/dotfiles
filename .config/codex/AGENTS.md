<!-- LANGUAGE_START -->
## 语言规则

### 核心规则

**所有输出必须使用简体中文，无例外。** 包括：对话回复、工具调用结果、生成的文件、文档、注释、错误信息。即使用户使用英文提问，也必须用中文回复。

### 工具调用输出

所有工具执行后的结果描述、成功/失败消息、摘要说明必须使用中文：

- 文件操作：`read_file`、`write_file`、`edit_file` 等
- 代码搜索：`codebase_search`、`grep` 等
- 终端命令：`run_terminal_cmd` 执行结果说明
- 其他工具：`todo_write`、`web_search` 等

**示例：**

- ✅ "已成功读取文件 config.json，包含 15 行配置"
- ❌ "Successfully read file config.json, contains 15 lines"

**注意：** 代码中的变量名和函数名保持英文，但注释、文档和所有说明文字必须是中文。
<!-- LANGUAGE_END -->