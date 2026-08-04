# Sensitive Word Dictionaries

This directory contains local dictionary snapshots loaded by `ContentSecurityService`.

## Source

- Repository: https://github.com/fwwdn/sensitive-stop-words
- License: Apache-2.0, copied in `fwwdn-sensitive-stop-words/LICENSE.txt`
- Snapshot commit: `a7d06bb1c321e669943b6841570d9da6dad8ce2b`
- Snapshot date: 2026-03-10

Included sensitive-word categories:

- `色情类.txt`
- `政治类.txt`
- `广告.txt`
- `涉枪涉爆违法信息关键词.txt`
- `网址.txt`

`stopword.dic` is intentionally not included because it is a natural-language stopword list, not a sensitive-word list.

Local additions can be configured through `ContentSecurity:SensitiveWords`. Obvious false positives can be configured through `ContentSecurity:IgnoredSensitiveWords`.
