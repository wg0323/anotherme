# 通用编码规约

> 来源：阿里巴巴前端规约 · 通用编码规约（https://alibaba.github.io/f2e-spec/），2026-10-29 提取改写，适用于多种编程语言。
> 级别：`强制` 必须遵守，违反将引起严重后果；`推荐` 尽量遵守，长期遵守有助于稳定性与协作效率；`参考` 理解并牢记，按场景自行判断。

## 缩进

- `强制` 使用 2 个空格缩进，禁止 4 个空格与 Tab。Tab 无法控制实际展示宽度；2 个空格比 1 个更明显，又比 3、4 个更节约空间，适合 `html`、`jsx` 等层级较深的语法。

  ```ini filename=".editorconfig"
  indent_style = space
  indent_size = 2
  ```

## 行宽

- `推荐` 折行行宽 100 字符。折行能提高代码阅读和调试的效率；衡量基准是等效 1600px 宽的屏幕左右分屏对比代码，更小的屏幕建议调小字体或缩放比例。

  ```ini filename=".editorconfig"
  max_line_length = 100
  ```

  ```json filename=".vscode/settings.json"
  {
    "editor.rulers": [100]
  }
  ```

## 字符集

- `强制` 所有源代码和纯文本文件使用 UTF-8 编码与解码。

  ```ini filename=".editorconfig"
  charset = utf-8
  ```
