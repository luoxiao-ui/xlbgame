const demoTagRules = `AI应用|大模型,提示词,agent,智能体,自动化,工作流|招聘,地产|2
金融投研|估值,财报,现金流,roe,回购,利润率,市盈率,资产负债表|理财广告,课程|2
宏观经济|利率,cpi,pmi,通胀,出口,消费,政策,财政,货币|旅游,美食|2
医药健康|临床,药物,患者,疗效,药企,适应症,试验|健身打卡,减肥餐|2
出海增长|独立站,出海,跨境,海外,用户增长,留存,投放,转化|留学申请|2`;

const demoArticles = [
    {
        title: "如何用智能体重构企业知识工作流",
        url: "https://mp.weixin.qq.com/s/demo-ai",
        content: "过去一年，大模型、提示词工程与 AI Agent 快速进入企业场景。文章围绕智能体工作流、知识库接入、自动化审批和多步骤任务拆解展开，讨论如何把人工分析流程改造成自动化链路，并评估部署成本与收益。"
    },
    {
        title: "从现金流和利润率看消费企业估值拐点",
        url: "https://mp.weixin.qq.com/s/demo-finance",
        content: "本文从财报、自由现金流、利润率、库存周转和回购计划几项核心指标出发，分析一家消费公司的估值修复空间，并对未来市盈率区间做出推演。"
    }
];

const extractorScript = `(function () {
  const title =
    document.querySelector('#activity-name')?.innerText?.trim() ||
    document.querySelector('h1')?.innerText?.trim() ||
    document.title;
  const content =
    document.querySelector('#js_content')?.innerText?.trim() ||
    document.querySelector('.rich_media_content')?.innerText?.trim() ||
    document.body?.innerText?.trim() ||
    '';
  const payload = {
    title,
    url: location.href,
    content,
    source: 'wechat'
  };
  const text = JSON.stringify(payload, null, 2);
  console.log(text);
  navigator.clipboard?.writeText(text);
  alert('已提取文章 JSON，并尝试复制到剪贴板。');
})();`;

const state = {
    articles: [],
    results: []
};

const elements = {
    tagRulesInput: document.getElementById("tagRulesInput"),
    tagRulePreview: document.getElementById("tagRulePreview"),
    manualTitleInput: document.getElementById("manualTitleInput"),
    manualUrlInput: document.getElementById("manualUrlInput"),
    manualContentInput: document.getElementById("manualContentInput"),
    batchImportInput: document.getElementById("batchImportInput"),
    articleQueue: document.getElementById("articleQueue"),
    resultList: document.getElementById("resultList"),
    queueSummary: document.getElementById("queueSummary"),
    resultSummary: document.getElementById("resultSummary"),
    extractorScriptBox: document.getElementById("extractorScriptBox")
};

document.getElementById("loadDemoTagsButton").addEventListener("click", () => {
    elements.tagRulesInput.value = demoTagRules;
    renderTagPreview();
});

document.getElementById("loadDemoArticlesButton").addEventListener("click", () => {
    state.articles.push(...demoArticles.map(withId));
    renderArticles();
});

document.getElementById("addManualArticleButton").addEventListener("click", () => {
    const title = elements.manualTitleInput.value.trim() || `未命名文章 ${state.articles.length + 1}`;
    const url = elements.manualUrlInput.value.trim();
    const content = elements.manualContentInput.value.trim();

    if (!content) {
        window.alert("请先粘贴文章正文。");
        return;
    }

    state.articles.unshift(withId({ title, url, content, source: "manual" }));
    elements.manualTitleInput.value = "";
    elements.manualUrlInput.value = "";
    elements.manualContentInput.value = "";
    renderArticles();
});

document.getElementById("importJsonButton").addEventListener("click", () => {
    const raw = elements.batchImportInput.value.trim();
    if (!raw) {
        window.alert("请先粘贴 JSON。");
        return;
    }

    try {
        const parsed = JSON.parse(raw);
        const incoming = Array.isArray(parsed) ? parsed : [parsed];
        const normalized = incoming
            .map((item, index) => normalizeArticle(item, index))
            .filter(Boolean)
            .map(withId);

        if (!normalized.length) {
            window.alert("没有识别到可导入的文章字段，至少需要 content。");
            return;
        }

        state.articles.unshift(...normalized.reverse());
        elements.batchImportInput.value = "";
        renderArticles();
    } catch (error) {
        window.alert(`JSON 解析失败：${error.message}`);
    }
});

document.getElementById("copyExtractorButton").addEventListener("click", async () => {
    try {
        await navigator.clipboard.writeText(extractorScript);
        window.alert("提取脚本已复制。到公众号文章页面控制台粘贴执行即可。");
    } catch (_error) {
        window.alert("复制失败，请手动复制下方脚本。");
    }
});

document.getElementById("runTaggingButton").addEventListener("click", () => {
    const rules = parseRules(elements.tagRulesInput.value);
    if (!rules.length) {
        window.alert("请先配置至少一个标签规则。");
        return;
    }
    if (!state.articles.length) {
        window.alert("请先导入文章。");
        return;
    }

    state.results = state.articles.map((article) => classifyArticle(article, rules));
    renderResults();
});

document.getElementById("clearArticlesButton").addEventListener("click", () => {
    state.articles = [];
    state.results = [];
    renderArticles();
    renderResults();
});

document.getElementById("exportJsonButton").addEventListener("click", () => {
    if (!state.results.length) {
        window.alert("还没有可导出的结果。");
        return;
    }
    downloadFile("tag-results.json", JSON.stringify(state.results, null, 2), "application/json");
});

document.getElementById("exportCsvButton").addEventListener("click", () => {
    if (!state.results.length) {
        window.alert("还没有可导出的结果。");
        return;
    }
    downloadFile("tag-results.csv", buildCsv(state.results), "text/csv;charset=utf-8;");
});

elements.tagRulesInput.addEventListener("input", renderTagPreview);
elements.extractorScriptBox.textContent = extractorScript;
elements.tagRulesInput.value = demoTagRules;

renderTagPreview();
renderArticles();
renderResults();

function parseRules(raw) {
    return raw
        .split("\n")
        .map((line) => line.trim())
        .filter(Boolean)
        .map((line) => {
            const [name, keywordsRaw = "", excludesRaw = "", thresholdRaw = "1"] = line.split("|");
            const keywords = splitByComma(keywordsRaw);
            const excludes = splitByComma(excludesRaw);
            const threshold = Math.max(1, Number.parseInt(thresholdRaw, 10) || 1);

            if (!name || !keywords.length) {
                return null;
            }

            return { name: name.trim(), keywords, excludes, threshold };
        })
        .filter(Boolean);
}

function splitByComma(raw) {
    return raw
        .split(",")
        .map((part) => part.trim().toLowerCase())
        .filter(Boolean);
}

function classifyArticle(article, rules) {
    const normalized = `${article.title}\n${article.content}`.toLowerCase();
    const matchedTags = [];
    const reasons = [];

    rules.forEach((rule) => {
        const matchedKeywords = rule.keywords.filter((keyword) => normalized.includes(keyword));
        const blockedKeywords = rule.excludes.filter((keyword) => normalized.includes(keyword));

        if (blockedKeywords.length > 0) {
            reasons.push(`标签【${rule.name}】被排除词拦截：${blockedKeywords.join("、")}`);
            return;
        }

        if (matchedKeywords.length >= rule.threshold) {
            matchedTags.push({
                name: rule.name,
                score: matchedKeywords.length,
                hits: matchedKeywords
            });
            reasons.push(`标签【${rule.name}】命中 ${matchedKeywords.length} 个关键词：${matchedKeywords.join("、")}`);
        }
    });

    const topTags = matchedTags.sort((a, b) => b.score - a.score);
    const summary = summarizeArticle(article.content);

    if (!topTags.length) {
        reasons.push("未达到任何标签的命中阈值，建议进入人工复核。");
    }

    return {
        id: article.id,
        title: article.title,
        url: article.url,
        source: article.source || "unknown",
        summary,
        contentLength: article.content.length,
        tags: topTags.map((item) => item.name),
        scoredTags: topTags,
        reasons
    };
}

function summarizeArticle(content) {
    const clean = content.replace(/\s+/g, " ").trim();
    if (!clean) {
        return "正文为空。";
    }
    if (clean.length <= 120) {
        return clean;
    }
    const sentences = clean.split(/(?<=[。！？!?.])/).map((part) => part.trim()).filter(Boolean);
    const firstChunk = sentences.slice(0, 2).join("");
    return firstChunk.length >= 60 ? firstChunk.slice(0, 160) : clean.slice(0, 160);
}

function normalizeArticle(item, index) {
    if (!item || typeof item !== "object") {
        return null;
    }

    const title = String(item.title || item.name || `导入文章 ${index + 1}`).trim();
    const url = String(item.url || item.link || "").trim();
    const content = String(item.content || item.body || item.text || "").trim();
    const source = String(item.source || "json").trim();

    if (!content) {
        return null;
    }

    return { title, url, content, source };
}

function withId(article) {
    return {
        ...article,
        id: `${Date.now()}-${Math.random().toString(16).slice(2, 8)}`
    };
}

function renderTagPreview() {
    const rules = parseRules(elements.tagRulesInput.value);
    elements.tagRulePreview.innerHTML = "";

    if (!rules.length) {
        const chip = document.createElement("span");
        chip.className = "chip";
        chip.textContent = "还没有有效标签";
        elements.tagRulePreview.appendChild(chip);
        return;
    }

    rules.forEach((rule) => {
        const chip = document.createElement("span");
        chip.className = "chip";
        chip.textContent = `${rule.name} · ${rule.keywords.length}词 · 阈值${rule.threshold}`;
        elements.tagRulePreview.appendChild(chip);
    });
}

function renderArticles() {
    const template = document.getElementById("articleCardTemplate");
    elements.articleQueue.innerHTML = "";

    if (!state.articles.length) {
        elements.articleQueue.className = "stack-list empty-state";
        elements.articleQueue.textContent = "加入文章后，会在这里显示标题、来源和内容预览。";
        elements.queueSummary.textContent = "当前还没有文章。";
        return;
    }

    elements.articleQueue.className = "stack-list";
    state.articles.forEach((article) => {
        const node = template.content.cloneNode(true);
        node.querySelector(".card-title").textContent = article.title;
        node.querySelector(".card-meta").textContent =
            `${article.source || "unknown"} · ${article.url || "无链接"} · ${article.content.length} 字`;
        node.querySelector(".card-preview").textContent = summarizeArticle(article.content);
        node.querySelector(".delete-button").addEventListener("click", () => {
            state.articles = state.articles.filter((entry) => entry.id !== article.id);
            state.results = state.results.filter((entry) => entry.id !== article.id);
            renderArticles();
            renderResults();
        });
        elements.articleQueue.appendChild(node);
    });

    elements.queueSummary.textContent = `当前共有 ${state.articles.length} 篇文章待处理。`;
}

function renderResults() {
    const template = document.getElementById("resultCardTemplate");
    elements.resultList.innerHTML = "";

    if (!state.results.length) {
        elements.resultList.className = "stack-list empty-state";
        elements.resultList.textContent = "点击“开始自动打标”后，这里会显示每篇文章的摘要、命中标签和依据。";
        elements.resultSummary.textContent = "还没有生成结果。";
        return;
    }

    elements.resultList.className = "stack-list";
    let taggedCount = 0;

    state.results.forEach((result) => {
        if (result.tags.length > 0) {
            taggedCount += 1;
        }

        const node = template.content.cloneNode(true);
        node.querySelector(".card-title").textContent = result.title;
        node.querySelector(".card-meta").textContent =
            `${result.source} · ${result.url || "无链接"} · ${result.contentLength} 字`;
        node.querySelector(".score-pill").textContent =
            result.tags.length > 0 ? `命中 ${result.tags.length} 个标签` : "待人工复核";
        node.querySelector(".result-summary").textContent = result.summary;

        const tagWrap = node.querySelector(".result-tags");
        if (result.scoredTags.length > 0) {
            result.scoredTags.forEach((tag) => {
                const chip = document.createElement("span");
                chip.className = "chip";
                chip.textContent = `${tag.name} · ${tag.score}`;
                tagWrap.appendChild(chip);
            });
        } else {
            const chip = document.createElement("span");
            chip.className = "chip";
            chip.textContent = "未命中标签";
            tagWrap.appendChild(chip);
        }

        const reasonList = node.querySelector(".reason-list");
        result.reasons.forEach((reason) => {
            const item = document.createElement("div");
            item.className = "reason-item";
            item.textContent = reason;
            reasonList.appendChild(item);
        });
        elements.resultList.appendChild(node);
    });

    elements.resultSummary.textContent =
        `共处理 ${state.results.length} 篇，其中 ${taggedCount} 篇命中至少一个标签，${state.results.length - taggedCount} 篇建议人工复核。`;
}

function buildCsv(results) {
    const header = ["title", "url", "source", "summary", "tags", "reasons"];
    const rows = results.map((item) => [
        item.title,
        item.url,
        item.source,
        item.summary,
        item.tags.join("|"),
        item.reasons.join(" / ")
    ]);
    return [header, ...rows]
        .map((row) => row.map(csvEscape).join(","))
        .join("\n");
}

function csvEscape(value) {
    const text = String(value || "");
    return `"${text.replace(/"/g, '""')}"`;
}

function downloadFile(filename, content, mimeType) {
    const blob = new Blob([content], { type: mimeType });
    const url = URL.createObjectURL(blob);
    const anchor = document.createElement("a");
    anchor.href = url;
    anchor.download = filename;
    anchor.click();
    URL.revokeObjectURL(url);
}
