
-- ============================================================
-- SECTION 1: OPTIONS
-- Core Neovim settings, leaders, options
-- ============================================================
require("theme")

-- ============================================================
-- SECTION 3: PLUGINS
-- ============================================================
require("plugins/neo-tree/setup")
require("plugins/smear-cursor/setup")

-- 加载自定义快捷键
require("keymappings")