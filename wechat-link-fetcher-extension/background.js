const DEFAULT_WAIT_MS = 2500;
const MAX_WAIT_MS = 15000;

chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  if (message?.type !== "start_batch_extract") {
    return false;
  }

  runBatchExtraction(message.links || [])
    .then((results) => sendResponse({ ok: true, results }))
    .catch((error) => sendResponse({ ok: false, error: error.message }));

  return true;
});

async function runBatchExtraction(links) {
  const normalizedLinks = Array.from(new Set(
    links
      .map((item) => String(item || "").trim())
      .filter((item) => item.startsWith("https://mp.weixin.qq.com/"))
  ));

  const results = [];

  for (const link of normalizedLinks) {
    try {
      const article = await extractSingleLink(link);
      results.push(article);
    } catch (error) {
      results.push({
        title: "提取失败",
        url: link,
        content: "",
        source: "wechat-extension",
        error: error.message
      });
    }
  }

  await chrome.storage.local.set({
    latestExtractionResults: results,
    latestExtractionAt: new Date().toISOString()
  });

  return results;
}

async function extractSingleLink(url) {
  const tab = await chrome.tabs.create({ url, active: false });

  try {
    await waitForTabReady(tab.id);
    await delay(DEFAULT_WAIT_MS);
    const response = await chrome.tabs.sendMessage(tab.id, { type: "extract_article" });

    if (!response?.ok || !response.article?.content) {
      throw new Error(response?.error || "页面未提取到正文，可能需要先在当前浏览器登录微信或页面尚未完全加载。");
    }

    return response.article;
  } finally {
    if (tab.id) {
      await chrome.tabs.remove(tab.id).catch(() => {});
    }
  }
}

function waitForTabReady(tabId) {
  return new Promise((resolve, reject) => {
    let done = false;

    const timeout = setTimeout(() => {
      if (done) {
        return;
      }
      done = true;
      chrome.tabs.onUpdated.removeListener(listener);
      reject(new Error("页面加载超时。"));
    }, MAX_WAIT_MS);

    const listener = (updatedTabId, changeInfo) => {
      if (updatedTabId !== tabId || changeInfo.status !== "complete" || done) {
        return;
      }

      done = true;
      clearTimeout(timeout);
      chrome.tabs.onUpdated.removeListener(listener);
      resolve();
    };

    chrome.tabs.onUpdated.addListener(listener);
  });
}

function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
