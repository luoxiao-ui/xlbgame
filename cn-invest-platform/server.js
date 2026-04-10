const http = require("http");
const path = require("path");
const fs = require("fs/promises");

const HOST = "127.0.0.1";
const PORT = Number(process.env.PORT || 5178);
const ROOT = __dirname;

const MIME = {
  ".html": "text/html; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".js": "application/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".svg": "image/svg+xml; charset=utf-8",
  ".ico": "image/x-icon",
};

const INDEX_CONFIG = [
  { symbol: "s_sh000001", code: "000001.SH", fallbackName: "上证指数" },
  { symbol: "s_sz399001", code: "399001.SZ", fallbackName: "深证成指" },
  { symbol: "s_sz399006", code: "399006.SZ", fallbackName: "创业板指" },
  { symbol: "s_sh000300", code: "000300.SH", fallbackName: "沪深300" },
];

const STOCK_CONFIG = [
  { symbol: "sh600519", code: "600519", fallbackName: "贵州茅台", peFallback: 29.3 },
  { symbol: "sz300750", code: "300750", fallbackName: "宁德时代", peFallback: 23.7 },
  { symbol: "sh601318", code: "601318", fallbackName: "中国平安", peFallback: 8.6 },
  { symbol: "sz000333", code: "000333", fallbackName: "美的集团", peFallback: 12.2 },
  { symbol: "sh601012", code: "601012", fallbackName: "隆基绿能", peFallback: 15.1 },
  { symbol: "sh600030", code: "600030", fallbackName: "中信证券", peFallback: 18.8 },
  { symbol: "sz000858", code: "000858", fallbackName: "五粮液", peFallback: 20.5 },
  { symbol: "sh600036", code: "600036", fallbackName: "招商银行", peFallback: 6.8 },
];

const FUND_CONFIG = [
  { code: "161725", name: "招商中证白酒指数(LOF)A", type: "指数", fee: 0.5, year: 9.8, volatility: "高" },
  { code: "005827", name: "易方达蓝筹精选混合", type: "混合", fee: 1.2, year: 5.2, volatility: "中高" },
  { code: "110022", name: "易方达消费行业股票", type: "股票", fee: 1.2, year: -1.4, volatility: "高" },
  { code: "004752", name: "广发中证传媒ETF联接A", type: "指数", fee: 0.6, year: 15.4, volatility: "高" },
  { code: "006113", name: "汇添富创新医药混合", type: "混合", fee: 1.5, year: 3.8, volatility: "中" },
  { code: "001009", name: "摩根安全战略债券A", type: "债券", fee: 0.8, year: 2.5, volatility: "低" },
  { code: "017019", name: "博时中证农业主题指数发起式A", type: "指数", fee: 0.5, year: 11.6, volatility: "中高" },
];

const DEFAULT_HEADERS = {
  "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
  Referer: "https://gu.qq.com/",
};

function sendJson(res, statusCode, payload) {
  res.writeHead(statusCode, {
    "Content-Type": "application/json; charset=utf-8",
    "Cache-Control": "no-store",
  });
  res.end(JSON.stringify(payload));
}

function toNumber(value, fallback = 0) {
  const num = Number(value);
  return Number.isFinite(num) ? num : fallback;
}

async function fetchText(url, { encoding = "utf-8", timeoutMs = 7000 } = {}) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const response = await fetch(url, {
      signal: controller.signal,
      headers: DEFAULT_HEADERS,
    });
    if (!response.ok) {
      throw new Error(`request failed: ${response.status}`);
    }
    const arrayBuffer = await response.arrayBuffer();
    try {
      return new TextDecoder(encoding).decode(arrayBuffer);
    } catch {
      return Buffer.from(arrayBuffer).toString("utf-8");
    }
  } finally {
    clearTimeout(timer);
  }
}

async function fetchQtFields(symbols) {
  const text = await fetchText(`https://qt.gtimg.cn/q=${symbols.join(",")}`, {
    encoding: "gb18030",
  });

  const result = new Map();
  const lines = text.split(/\r?\n/).filter(Boolean);

  for (const line of lines) {
    const matched = line.match(/^v_([^=]+)="([\s\S]*)";$/);
    if (!matched) continue;
    const symbol = matched[1];
    const fields = matched[2].split("~");
    result.set(symbol, fields);
  }
  return result;
}

async function fetchFundRealtime(code) {
  const text = await fetchText(`https://fundgz.1234567.com.cn/js/${code}.js`, {
    encoding: "utf-8",
  });
  const matched = text.match(/jsonpgz\((.*)\);?/);
  if (!matched) {
    throw new Error(`fund parse failed for ${code}`);
  }
  return JSON.parse(matched[1]);
}

function parseIndexFromQt(config, fields) {
  return {
    code: config.code,
    name: fields[1] || config.fallbackName,
    value: toNumber(fields[3]),
    change: toNumber(fields[4]),
    changePct: toNumber(fields[5]),
    volume: toNumber(fields[6]),
    amount: toNumber(fields[7]),
  };
}

function parseStockFromQt(config, fields) {
  return {
    code: config.code,
    name: fields[1] || config.fallbackName,
    price: toNumber(fields[3]),
    change: toNumber(fields[31]),
    changePct: toNumber(fields[32]),
    turnover: toNumber(fields[38]),
    pe: toNumber(fields[39], config.peFallback),
    marketCapYi: toNumber(fields[44]),
  };
}

async function buildMarketPayload() {
  const indexSymbols = INDEX_CONFIG.map((item) => item.symbol);
  const stockSymbols = STOCK_CONFIG.map((item) => item.symbol);
  const qtData = await fetchQtFields([...indexSymbols, ...stockSymbols]);

  const indices = INDEX_CONFIG.map((item) => parseIndexFromQt(item, qtData.get(item.symbol) || []));
  const stocks = STOCK_CONFIG.map((item) => parseStockFromQt(item, qtData.get(item.symbol) || []));

  const fundResponses = await Promise.all(
    FUND_CONFIG.map(async (item) => {
      try {
        const fund = await fetchFundRealtime(item.code);
        return {
          code: item.code,
          name: fund.name || item.name,
          type: item.type,
          fee: item.fee,
          volatility: item.volatility,
          year: item.year,
          nav: toNumber(fund.dwjz),
          estNav: toNumber(fund.gsz || fund.dwjz),
          changePct: toNumber(fund.gszzl),
          updateTime: fund.gztime || fund.jzrq || null,
        };
      } catch {
        return {
          code: item.code,
          name: item.name,
          type: item.type,
          fee: item.fee,
          volatility: item.volatility,
          year: item.year,
          nav: 0,
          estNav: 0,
          changePct: 0,
          updateTime: null,
        };
      }
    })
  );

  return {
    ok: true,
    mode: "realtime",
    updatedAt: new Date().toISOString(),
    source: {
      quote: "qt.gtimg.cn",
      fund: "fundgz.1234567.com.cn",
    },
    indices,
    stocks,
    funds: fundResponses,
  };
}

async function serveStatic(reqPath, res) {
  const filePath = reqPath === "/" ? "/index.html" : reqPath;
  const resolved = path.resolve(ROOT, `.${filePath}`);

  if (!resolved.startsWith(ROOT)) {
    sendJson(res, 403, { ok: false, error: "forbidden" });
    return;
  }

  try {
    const stat = await fs.stat(resolved);
    if (!stat.isFile()) {
      sendJson(res, 404, { ok: false, error: "not found" });
      return;
    }
    const content = await fs.readFile(resolved);
    const ext = path.extname(resolved).toLowerCase();
    res.writeHead(200, {
      "Content-Type": MIME[ext] || "application/octet-stream",
      "Cache-Control": "no-cache",
    });
    res.end(content);
  } catch {
    sendJson(res, 404, { ok: false, error: "not found" });
  }
}

const server = http.createServer(async (req, res) => {
  try {
    const requestUrl = new URL(req.url || "/", `http://${req.headers.host}`);
    const pathname = decodeURIComponent(requestUrl.pathname);

    if (pathname === "/api/ping") {
      sendJson(res, 200, { ok: true, service: "cn-invest-platform" });
      return;
    }

    if (pathname === "/api/market/live") {
      try {
        const payload = await buildMarketPayload();
        sendJson(res, 200, payload);
      } catch (error) {
        sendJson(res, 502, {
          ok: false,
          error: "live fetch failed",
          message: error instanceof Error ? error.message : String(error),
        });
      }
      return;
    }

    await serveStatic(pathname, res);
  } catch (error) {
    sendJson(res, 500, {
      ok: false,
      error: "internal error",
      message: error instanceof Error ? error.message : String(error),
    });
  }
});

server.listen(PORT, HOST, () => {
  process.stdout.write(`cn-invest-platform running at http://${HOST}:${PORT}\n`);
});
