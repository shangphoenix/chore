# Skills

此目录存放可复用的 Codex Skills。每个 Skill 使用独立目录，并以 `SKILL.md` 作为入口。

## Skills 列表

### [upload-markdown-images](./upload-markdown-images/SKILL.md)

检测 Markdown 当前修改中新增的本地图片引用，在用户明确确认后通过 PicGo-Core CLI 上传，并只替换上传成功的引用。

运行前需要安装并配置可用的 `picgo` 命令：

```powershell
Get-Command picgo
picgo -h
```

如需安装到本机 Codex，可将完整 Skill 目录复制到：

```text
%USERPROFILE%\.codex\skills\upload-markdown-images
```
