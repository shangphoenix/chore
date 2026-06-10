---
name: upload-markdown-images
description: Use when creating or editing Markdown files and the current change adds local image references that may need uploading through PicGo.
---

# Upload Markdown Images

## Overview

Upload only local images introduced by the current Markdown change. Never upload or rewrite a link until the user explicitly confirms the complete candidate list or a selected subset.

## Workflow

1. Preserve the Markdown content from before the current edit.
2. Compare old and new content. Collect only newly added Markdown image references.
3. Exclude:
   - References already present before the edit
   - `http://`, `https://`, `data:`, and non-file URI references
   - Missing files and paths that do not resolve to a local image
4. Resolve relative paths from the Markdown file's directory. Treat repeated references to the same file as one upload.
5. Show one numbered list containing every candidate's displayed path and resolved absolute path.
6. Ask the user to choose exactly one:
   - Upload all
   - Upload selected numbers or paths
   - Cancel
7. Stop unless the user explicitly confirms all or a subset. Do not interpret silence, earlier general approval, or the request to edit Markdown as upload consent.
8. Pass only the confirmed absolute paths to the bundled uploader:

```powershell
& "<skill-dir>\scripts\upload-confirmed-images.ps1" `
  -ImagePath @("<absolute-path-1>", "<absolute-path-2>") `
  -Confirmed
```

9. Parse the JSON result. Replace references only where `status` is `uploaded`.
10. Preserve each reference's alt text and optional title. Leave failed and unselected references unchanged.
11. Write the Markdown atomically when possible. Never delete local image files.
12. Report uploaded, failed, and unselected images separately.

## Upload Contract

The uploader invokes `picgo upload "<absolute-path>"`. Each image gets one initial attempt plus three retries, with a two-second delay after each failed attempt. A valid absolute `http://` or `https://` URL is required; exit code zero alone is not success.

One image failing must not stop the remaining confirmed images. The script emits a JSON array with:

| Field | Meaning |
|---|---|
| `path` | Resolved local image path |
| `status` | `uploaded` or `failed` |
| `url` | Remote URL when successful |
| `attempts` | Number of PicGo invocations |
| `error` | Last failure summary |

For tests or a nonstandard installation, use `-PicGoCommand`. Do not print PicGo configuration, tokens, or secrets.

## Prerequisite

Require the PicGo-Core CLI command, not merely the PicGo desktop application:

```powershell
Get-Command picgo
picgo -h
```

If `picgo` is unavailable, stop before requesting upload confirmation and explain that PicGo-Core CLI must be installed or its command path supplied. Do not substitute `PicGo.exe` unless its CLI behavior has been explicitly verified.

## Supported References

Handle standard inline Markdown images such as:

```markdown
![diagram](./images/flow.png)
![diagram](./images/flow.png "Flow")
```

Do not rewrite HTML `<img>` elements, reference-style image definitions, Base64 content, or dynamically generated paths unless the user explicitly expands the scope.

## Common Mistakes

- Uploading while merely asking for confirmation
- Scanning the entire document instead of diffing the current change
- Treating three retries as three total attempts
- Trusting only PicGo's exit code
- Replacing every occurrence of a path, including pre-existing references
- Deleting local files after successful upload
