const linksInput = document.getElementById("linksInput");
const extractButton = document.getElementById("extractButton");
const downloadButton = document.getElementById("downloadButton");
const statusBox = document.getElementById("statusBox");
const previewBox = document.getElementById("previewBox");

extractButton.addEventListener("click", async () => {
  const links = linksInput.value
    .split("\n")
    .map((item) => item.trim())
    .filter(Boolean);

  if (!links.length) {
    setStatus("请先粘贴至少一个公众号链接。");
    return;
  }

  setStatus(`准备处理 ${links.length} 个链接，这个过程会自动打开后台标签页。`);
  previewBox.textContent = "提取中，请稍候...";
  toggleBusy(true);

  try {
    const response = await chrome.runtime.sendMessage({
      type: "start_batch_extract",
      links
    });

    if (!response?.ok) {
      throw new Error(response?.error || "提取失败。");
    }

    const successCount = response.results.filter((item) => item.content).length;
    const failedCount = response.results.length - successCount;

    setStatus(`处理完成：成功 ${successCount} 篇，失败 ${failedCount} 篇。`);
    previewBox.textContent = JSON.stringify(response.results.slice(0, 3), null, 2);
  } catch (error) {
    setStatus(`提取失败：${error.message}`);
    previewBox.textContent = "没有拿到结果。";
  } finally {
    toggleBusy(false);
  }
});

downloadButton.addEventListener("click", async () => {
  const data = await chrome.storage.local.get(["latestExtractionResults"]);
  const results = data.latestExtractionResults || [];

  if (!results.length) {
    setStatus("还没有可下载的结果，请先执行一次提取。");
    return;
  }

  const blob = new Blob([JSON.stringify(results, null, 2)], {
    type: "application/json"
  });
  const url = URL.createObjectURL(blob);
  const filename = `wechat-articles-${Date.now()}.json`;

  await chrome.downloads.download({
    url,
    filename,
    saveAs: true
  });

  setStatus("结果 JSON 已开始下载。");
});

restoreLastPreview();

async function restoreLastPreview() {
  const data = await chrome.storage.local.get(["latestExtractionResults", "latestExtractionAt"]);
  const results = data.latestExtractionResults || [];

  if (!results.length) {
    return;
  }

  const time = data.latestExtractionAt ? new Date(data.latestExtractionAt).toLocaleString() : "刚刚";
  setStatus(`已读取上次结果，共 ${results.length} 篇，时间：${time}`);
  previewBox.textContent = JSON.stringify(results.slice(0, 3), null, 2);
}

function setStatus(text) {
  statusBox.textContent = text;
}

function toggleBusy(isBusy) {
  extractButton.disabled = isBusy;
  downloadButton.disabled = isBusy;
}
