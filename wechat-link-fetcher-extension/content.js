chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  if (message?.type !== "extract_article") {
    return false;
  }

  try {
    const article = extractArticle();
    sendResponse({ ok: true, article });
  } catch (error) {
    sendResponse({ ok: false, error: error.message });
  }

  return false;
});

function extractArticle() {
  const title =
    pickText("#activity-name") ||
    pickText("h1") ||
    document.title ||
    "未识别标题";

  const content =
    pickText("#js_content") ||
    pickText(".rich_media_content") ||
    "";

  const accountName =
    pickText("#js_name") ||
    pickText(".account_nickname_inner") ||
    "";

  if (!content) {
    throw new Error("未识别到正文节点。");
  }

  return {
    title: cleanText(title),
    url: location.href,
    content: cleanText(content),
    source: "wechat-extension",
    accountName: cleanText(accountName)
  };
}

function pickText(selector) {
  const element = document.querySelector(selector);
  return element ? element.innerText || element.textContent || "" : "";
}

function cleanText(value) {
  return String(value || "")
    .replace(/\u00a0/g, " ")
    .replace(/\s+\n/g, "\n")
    .replace(/\n{3,}/g, "\n\n")
    .replace(/[ \t]{2,}/g, " ")
    .trim();
}
