# GitLab Contribution Statistics Script / GitLab 贡献统计脚本

[English](#english) | [中文](#chinese)

---

<a id="english"></a>
## English

### Overview

A PowerShell script that retrieves comprehensive contribution statistics for a GitLab user via the GitLab API. It analyzes merge requests, commits, files changed, and lines added/deleted for a specified year.

### Features

- **Merge Request Statistics**: Count and analyze merged MRs with file changes and line counts
- **Commit Statistics**: Track commits across all projects with detailed metrics
- **Project Breakdown**: View statistics grouped by project
- **Top Lists**: Display top 10 MRs and commits by lines changed
- **CSV Export**: Export detailed data to CSV file for further analysis
- **Rate Limiting**: Built-in delays to avoid API rate limits
- **Progress Display**: Real-time progress bars during data fetching

### Prerequisites

- Windows PowerShell 5.1 or PowerShell 7+
- A GitLab account with API access
- A GitLab Personal Access Token with `api` scope

### Usage

1. Clone or download this script
2. Edit the parameters at the top of the script:
   ```powershell
   $GitLabUrl = "https://gitlab.example.com"  # Your GitLab URL
   $Token = "your_personal_access_token"      # Your API token
   $Username = "your_username"                # Your GitLab username
   $Year = 2025                               # Year to analyze
   ```
3. Run the script:
   ```powershell
   .\gitlab_status.ps1
   ```

Or run with custom parameters:
```powershell
.\gitlab_status.ps1 -GitLabUrl "https://gitlab.example.com" -Token "your_token" -Username "john_doe" -Year 2025
```

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `GitLabUrl` | String | - | GitLab instance URL |
| `Token` | String | - | Personal Access Token |
| `Username` | String | - | GitLab username to analyze |
| `Year` | Int | `2025` | Year for statistics |

### Output

The script displays:
- Overall statistics (MRs, commits, files, lines)
- Statistics by project
- Top 10 Merge Requests
- Top 10 Commits
- Exports detailed data to `gitlab_stats_YYYY_timestamp.csv`

### Example Output

```
==============================================
             FINAL STATISTICS
==============================================

=== OVERALL STATISTICS ===
Year: 2025
User: John Doe

Merge Requests: 45
Commits: 234
Files Changed: 156
Lines Added: 12450
Lines Deleted: 3200
Net Lines Changed: 9250
```

### Getting a GitLab Personal Access Token

1. Go to GitLab **User Settings** -> **Access Tokens**
2. Create a new token with `api` scope
3. Copy the token and use it in this script

---

<a id="chinese"></a>
## 中文

### 概述

这是一个通过 GitLab API 获取用户年度完整贡献统计数据的 PowerShell 脚本。它可以分析指定年份内的合并请求、提交记录、文件变更以及代码增删行数。

### 功能特性

- **合并请求统计**：统计已合并的 MR，分析文件变更和代码行数
- **提交统计**：追踪所有项目中的提交记录及详细指标
- **项目分组统计**：按项目展示统计数据
- **排行榜**：展示按代码变更量排序的前10名 MR 和提交
- **CSV 导出**：将详细数据导出为 CSV 文件供进一步分析
- **速率限制保护**：内置延迟避免触发 API 速率限制
- **进度显示**：数据获取过程中显示实时进度条

### 环境要求

- Windows PowerShell 5.1 或 PowerShell 7+
- 具有 API 访问权限的 GitLab 账户
- 具有 `api` 权限的 GitLab 个人访问令牌

### 使用方法

1. 克隆或下载此脚本
2. 编辑脚本顶部的参数：
   ```powershell
   $GitLabUrl = "https://gitlab.example.com"  # 你的 GitLab 地址
   $Token = "your_personal_access_token"      # 你的 API 令牌
   $Username = "your_username"                # 你的 GitLab 用户名
   $Year = 2025                               # 要统计的年份
   ```
3. 运行脚本：
   ```powershell
   .\gitlab_status.ps1
   ```

或使用自定义参数运行：
```powershell
.\gitlab_status.ps1 -GitLabUrl "https://gitlab.example.com" -Token "your_token" -Username "zhang_san" -Year 2025
```

### 参数说明

| 参数 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| `GitLabUrl` | String | - | GitLab 实例地址 |
| `Token` | String | - | 个人访问令牌 |
| `Username` | String | - | 要分析的用户名 |
| `Year` | Int | `2025` | 统计年份 |

### 输出内容

脚本将显示：
- 整体统计（MR数、提交数、文件数、代码行数）
- 按项目分组的统计
- 前10名合并请求
- 前10名提交记录
- 导出详细数据到 `gitlab_stats_YYYY_时间戳.csv`

### 输出示例

```
==============================================
             最终统计
==============================================

=== 整体统计 ===
年份: 2025
用户: 张三

合并请求: 45
提交: 234
文件变更: 156
新增行数: 12450
删除行数: 3200
净变更行数: 9250
```

### 获取 GitLab 个人访问令牌

1. 进入 GitLab **用户设置** -> **访问令牌**
2. 创建新令牌，勾选 `api` 权限
3. 复制令牌并在本脚本中使用

---

## License / 许可证

MIT License
