# Wechat Link Fetcher

这是一个 Chrome 扩展原型，用来把“只给链接”这件事做得更顺手一些。

它的工作方式是：

1. 你在 Chrome 里保持微信文章可正常访问
2. 把一批 `mp.weixin.qq.com` 链接粘贴进插件
3. 插件后台逐篇打开页面
4. 从页面 DOM 提取标题和正文
5. 生成 JSON 结果供打标工具导入

## 安装方式

1. 打开 Chrome 扩展页：`chrome://extensions/`
2. 打开“开发者模式”
3. 选择“加载已解压的扩展程序”
4. 选择当前目录：`wechat-link-fetcher-extension`

## 使用方式

1. 点击插件图标
2. 粘贴公众号链接，一行一个
3. 点击“开始提取”
4. 等提取完成后点击“下载上次结果”
5. 把下载的 JSON 导入 `wechat-article-tagger`

## 当前限制

- 仅支持 `https://mp.weixin.qq.com/*`
- 文章必须能在当前浏览器正常打开
- 如果文章需要额外验证、失效、被屏蔽，提取会失败
- 当前是顺序提取，优先稳定性而不是速度
