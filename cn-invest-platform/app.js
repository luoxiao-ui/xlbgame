const defaultIndices = [
  {
    name: "上证指数",
    code: "000001.SH",
    value: 3286.72,
    change: 13.2,
    changePct: 0.86,
    points: [42, 45, 44, 46, 49, 48, 50, 53, 52, 54, 56, 58],
  },
  {
    name: "深证成指",
    code: "399001.SZ",
    value: 10128.63,
    change: 71.8,
    changePct: 1.35,
    points: [28, 29, 27, 30, 31, 30, 33, 32, 35, 34, 36, 38],
  },
  {
    name: "创业板指",
    code: "399006.SZ",
    value: 1986.14,
    change: -9.5,
    changePct: -0.48,
    points: [50, 49, 48, 50, 47, 46, 48, 45, 44, 43, 44, 42],
  },
  {
    name: "沪深300",
    code: "000300.SH",
    value: 3875.52,
    change: 9.3,
    changePct: 0.24,
    points: [33, 34, 35, 34, 36, 36, 37, 37, 38, 39, 39, 40],
  },
];

const defaultStocks = [
  { code: "600519", name: "贵州茅台", price: 1726.3, changePct: 1.08, turnover: 0.89, pe: 29.3 },
  { code: "300750", name: "宁德时代", price: 196.22, changePct: -0.86, turnover: 1.72, pe: 23.7 },
  { code: "601318", name: "中国平安", price: 48.61, changePct: 0.72, turnover: 0.54, pe: 8.6 },
  { code: "000333", name: "美的集团", price: 67.84, changePct: 1.33, turnover: 1.03, pe: 12.2 },
  { code: "601012", name: "隆基绿能", price: 21.73, changePct: -1.5, turnover: 2.64, pe: 15.1 },
  { code: "600030", name: "中信证券", price: 26.88, changePct: 0.52, turnover: 0.71, pe: 18.8 },
  { code: "000858", name: "五粮液", price: 142.33, changePct: 0.68, turnover: 0.95, pe: 20.5 },
  { code: "600036", name: "招商银行", price: 38.42, changePct: -0.19, turnover: 0.63, pe: 6.8 },
];

const defaultFunds = [
  {
    code: "161725",
    name: "招商中证白酒指数(LOF)A",
    type: "指数",
    nav: 1.324,
    estNav: 1.326,
    dayChangePct: 0.11,
    year: 9.8,
    fee: 0.5,
    volatility: "高",
    updateTime: null,
  },
  {
    code: "005827",
    name: "易方达蓝筹精选混合",
    type: "混合",
    nav: 2.117,
    estNav: 2.124,
    dayChangePct: 0.25,
    year: 5.2,
    fee: 1.2,
    volatility: "中高",
    updateTime: null,
  },
  {
    code: "110022",
    name: "易方达消费行业股票",
    type: "股票",
    nav: 3.45,
    estNav: 3.44,
    dayChangePct: -0.08,
    year: -1.4,
    fee: 1.2,
    volatility: "高",
    updateTime: null,
  },
  {
    code: "004752",
    name: "广发中证传媒ETF联接A",
    type: "指数",
    nav: 1.638,
    estNav: 1.646,
    dayChangePct: 0.5,
    year: 15.4,
    fee: 0.6,
    volatility: "高",
    updateTime: null,
  },
  {
    code: "006113",
    name: "汇添富创新医药混合",
    type: "混合",
    nav: 1.243,
    estNav: 1.246,
    dayChangePct: 0.24,
    year: 3.8,
    fee: 1.5,
    volatility: "中",
    updateTime: null,
  },
  {
    code: "001009",
    name: "摩根安全战略债券A",
    type: "债券",
    nav: 1.081,
    estNav: 1.081,
    dayChangePct: 0.02,
    year: 2.5,
    fee: 0.8,
    volatility: "低",
    updateTime: null,
  },
  {
    code: "017019",
    name: "博时中证农业主题指数发起式A",
    type: "指数",
    nav: 1.016,
    estNav: 1.02,
    dayChangePct: 0.3,
    year: 11.6,
    fee: 0.5,
    volatility: "中高",
    updateTime: null,
  },
];

const ALERT_STORAGE_KEY = "cn-invest-alert-rules-v1";
const RISK_PROFILE_KEY = "cn-invest-risk-profile-v1";

const news = [
  {
    title: "证监会发布上市公司信披新规，强化关键财务指标透明度",
    source: "财联社",
    time: "09:36",
    tags: ["政策", "A股"],
  },
  {
    title: "公募一季报窗口临近，科技主题基金仓位调升迹象明显",
    source: "证券时报",
    time: "10:02",
    tags: ["基金", "季报"],
  },
  {
    title: "北向资金早盘净流入 37 亿元，电子板块获持续加仓",
    source: "东方财富资讯",
    time: "10:18",
    tags: ["资金流", "北向"],
  },
  {
    title: "首批 AI 基础设施 REITs 试点方案征求意见",
    source: "上证报",
    time: "10:47",
    tags: ["REITs", "AI"],
  },
];

const lessons = [
  { title: "股票入门：什么是市盈率与估值", progress: 76, note: "把估值放在行业周期里看，而不是孤立看数值。" },
  { title: "基金筛选：看收益也要看回撤", progress: 41, note: "同等收益下，回撤更小的基金更适合新手坚持。" },
  { title: "仓位管理：分批建仓与止损思路", progress: 22, note: "先定义最大亏损，再决定买多少，而不是反过来。" },
];

let indices = defaultIndices.map((item) => ({
  ...item,
  points: [...item.points],
}));
let stocks = defaultStocks.map((item) => ({ ...item }));
let funds = defaultFunds.map((item) => ({ ...item }));

const state = {
  selectedFundType: "全部",
  riskProfile: "balanced",
  cash: 150000,
  holdings: [
    { id: "stock-600519", kind: "股票", code: "600519", name: "贵州茅台", qty: 100, cost: 1652.4 },
    { id: "stock-600030", kind: "股票", code: "600030", name: "中信证券", qty: 1200, cost: 25.2 },
    { id: "fund-161725", kind: "基金", code: "161725", name: "招商中证白酒指数", qty: 6000, cost: 1.22 },
  ],
  trades: [],
  sipPlans: [{ fundCode: "161725", monthly: 1500 }],
  indexHistory: new Map(),
  liveMode: "mock",
  liveUpdatedAt: null,
  liveError: null,
  liveSource: null,
  alertRules: [],
  triggeredAlerts: [],
  nextAlertId: 1,
};

const fundTypes = ["全部", ...new Set(defaultFunds.map((item) => item.type))];
const IS_FILE_PROTOCOL = window.location.protocol === "file:";

const marketGrid = document.getElementById("market-grid");
const sectorBars = document.getElementById("sector-bars");
const marketInsight = document.getElementById("market-insight");
const marketTime = document.getElementById("market-time");
const refreshLiveBtn = document.getElementById("refresh-live");
const watchlistBody = document.getElementById("watchlist-body");
const stockSearch = document.getElementById("stock-search");
const fundFilters = document.getElementById("fund-filters");
const fundList = document.getElementById("fund-list");
const newsList = document.getElementById("news-list");
const totalAsset = document.getElementById("total-asset");
const totalPnl = document.getElementById("total-pnl");
const cashBalance = document.getElementById("cash-balance");
const allocationBars = document.getElementById("allocation-bars");
const positionList = document.getElementById("position-list");
const riskProfileSelect = document.getElementById("risk-profile");
const riskItems = document.getElementById("risk-items");
const rebalanceBtn = document.getElementById("rebalance-btn");
const rebalanceResult = document.getElementById("rebalance-result");
const tradeSymbol = document.getElementById("trade-symbol");
const tradeQty = document.getElementById("trade-qty");
const tradePrice = document.getElementById("trade-price");
const buyBtn = document.getElementById("buy-btn");
const sellBtn = document.getElementById("sell-btn");
const txList = document.getElementById("tx-list");
const sipMonthly = document.getElementById("sip-monthly");
const sipYears = document.getElementById("sip-years");
const sipRate = document.getElementById("sip-rate");
const sipResult = document.getElementById("sip-result");
const sipPlanList = document.getElementById("sip-plan-list");
const academyList = document.getElementById("academy-list");
const alertForm = document.getElementById("alert-form");
const alertSymbol = document.getElementById("alert-symbol");
const alertDirection = document.getElementById("alert-direction");
const alertPrice = document.getElementById("alert-price");
const alertList = document.getElementById("alert-list");
const alertTriggeredList = document.getElementById("alert-triggered-list");
const toast = document.getElementById("toast");
const riskBadge = document.getElementById("risk-badge");

const formatMoney = (num) =>
  new Intl.NumberFormat("zh-CN", {
    style: "currency",
    currency: "CNY",
    maximumFractionDigits: 2,
  }).format(num);

const formatNumber = (num, digits = 2) =>
  new Intl.NumberFormat("zh-CN", {
    minimumFractionDigits: digits,
    maximumFractionDigits: digits,
  }).format(num);

const toDeltaClass = (value) => (value >= 0 ? "up" : "down");

const toNumber = (value, fallback = 0) => {
  const num = Number(value);
  return Number.isFinite(num) ? num : fallback;
};

function getMergedInstruments() {
  return [
    ...stocks.map((item) => ({ kind: "股票", code: item.code, name: item.name, price: item.price })),
    ...funds.map((item) => ({
      kind: "基金",
      code: item.code,
      name: item.name,
      price: item.estNav > 0 ? item.estNav : item.nav,
    })),
  ];
}

function getInstrumentPrice(code) {
  const current = getMergedInstruments().find((item) => item.code === code);
  return current ? current.price : 0;
}

function loadUserPreferences() {
  try {
    const savedProfile = localStorage.getItem(RISK_PROFILE_KEY);
    if (savedProfile && ["conservative", "balanced", "aggressive"].includes(savedProfile)) {
      state.riskProfile = savedProfile;
    }
  } catch {}

  try {
    const saved = localStorage.getItem(ALERT_STORAGE_KEY);
    if (!saved) return;
    const parsed = JSON.parse(saved);
    if (!Array.isArray(parsed)) return;

    state.alertRules = parsed
      .map((item) => ({
        id: Number(item.id),
        code: String(item.code || ""),
        direction: item.direction === "below" ? "below" : "above",
        targetPrice: toNumber(item.targetPrice, 0),
        createdAt: item.createdAt || null,
        status: item.status === "triggered" ? "triggered" : "armed",
      }))
      .filter((item) => item.code && item.targetPrice > 0);

    const maxId = state.alertRules.reduce((max, item) => Math.max(max, item.id || 0), 0);
    state.nextAlertId = maxId + 1;
  } catch {}
}

function persistAlertRules() {
  try {
    localStorage.setItem(ALERT_STORAGE_KEY, JSON.stringify(state.alertRules));
  } catch {}
}

function persistRiskProfile() {
  try {
    localStorage.setItem(RISK_PROFILE_KEY, state.riskProfile);
  } catch {}
}

function getTargetAllocation(profile) {
  if (profile === "conservative") {
    return { stock: 0.25, fund: 0.55, cash: 0.2, label: "保守" };
  }
  if (profile === "aggressive") {
    return { stock: 0.65, fund: 0.25, cash: 0.1, label: "进取" };
  }
  return { stock: 0.45, fund: 0.4, cash: 0.15, label: "平衡" };
}

function computePortfolioSnapshot() {
  const positions = state.holdings.map((item) => {
    const price = getInstrumentPrice(item.code) || item.cost;
    const marketValue = item.qty * price;
    const costValue = item.qty * item.cost;
    const pnl = marketValue - costValue;
    return {
      ...item,
      price,
      marketValue,
      pnl,
      pnlPct: costValue > 0 ? (pnl / costValue) * 100 : 0,
    };
  });

  const stockValue = positions
    .filter((item) => item.kind === "股票")
    .reduce((sum, item) => sum + item.marketValue, 0);
  const fundValue = positions
    .filter((item) => item.kind === "基金")
    .reduce((sum, item) => sum + item.marketValue, 0);
  const invested = positions.reduce((sum, item) => sum + item.qty * item.cost, 0);
  const marketValue = stockValue + fundValue;
  const total = marketValue + state.cash;
  const pnl = marketValue - invested;
  const cashRatio = total > 0 ? state.cash / total : 0;
  const stockRatio = total > 0 ? stockValue / total : 0;
  const fundRatio = total > 0 ? fundValue / total : 0;
  const maxPosition =
    positions.length > 0
      ? positions.reduce((top, item) => (item.marketValue > top.marketValue ? item : top), positions[0])
      : null;
  const maxPositionWeight = maxPosition && total > 0 ? maxPosition.marketValue / total : 0;
  const stressLoss = stockValue * 0.08 + fundValue * 0.035;
  const stressLossPct = total > 0 ? (stressLoss / total) * 100 : 0;

  return {
    positions,
    stockValue,
    fundValue,
    invested,
    marketValue,
    total,
    pnl,
    stockRatio,
    fundRatio,
    cashRatio,
    maxPosition,
    maxPositionWeight,
    stressLoss,
    stressLossPct,
  };
}

function seedIndexHistory() {
  for (const item of indices) {
    if (!state.indexHistory.has(item.code)) {
      state.indexHistory.set(item.code, [...item.points]);
    }
  }
}

function withUpdatedIndexHistory(nextIndices) {
  return nextIndices.map((item) => {
    const history = state.indexHistory.get(item.code) || [item.value];
    history.push(item.value);
    while (history.length > 18) history.shift();
    state.indexHistory.set(item.code, history);
    return { ...item, points: [...history] };
  });
}

function renderMarketTime() {
  const now = new Date();
  const weekday = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"][now.getDay()];
  const date = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}-${String(now.getDate()).padStart(2, "0")}`;

  if (state.liveMode === "realtime" && state.liveUpdatedAt) {
    const updated = new Date(state.liveUpdatedAt);
    const hm = `${String(updated.getHours()).padStart(2, "0")}:${String(updated.getMinutes()).padStart(2, "0")}:${String(updated.getSeconds()).padStart(2, "0")}`;
    marketTime.textContent = `${date} ${weekday} · 实时行情已更新 ${hm}`;
    return;
  }

  if (state.liveError) {
    marketTime.textContent = `${date} ${weekday} · 实时接口异常，当前为演示数据`;
    return;
  }

  marketTime.textContent = `${date} ${weekday} · 模拟交易时段 09:30-15:00`;
}

function renderSparkline(points, isUp) {
  const max = Math.max(...points);
  const min = Math.min(...points);
  const step = 100 / (points.length - 1);
  const span = max - min || 1;

  const positions = points
    .map((point, index) => {
      const x = index * step;
      const y = 100 - ((point - min) / span) * 100;
      return `${x},${y}`;
    })
    .join(" ");

  const color = isUp ? "#d7263d" : "#109e67";

  return `
    <svg class="sparkline" viewBox="0 0 100 100" preserveAspectRatio="none" aria-hidden="true">
      <polyline fill="none" stroke="${color}" stroke-width="4" points="${positions}" />
    </svg>
  `;
}

function computeSectorHeat() {
  const groups = [
    { name: "白酒消费", codes: ["600519", "000858"] },
    { name: "新能源", codes: ["300750", "601012"] },
    { name: "大金融", codes: ["601318", "600030", "600036"] },
    { name: "家电制造", codes: ["000333"] },
  ];

  return groups
    .map((group) => {
      const values = group.codes.map((code) => stocks.find((item) => item.code === code)?.changePct || 0);
      const avg = values.reduce((sum, item) => sum + item, 0) / Math.max(values.length, 1);
      const heat = Math.max(8, Math.min(96, Math.round((avg + 6) * 7)));
      return { name: group.name, heat };
    })
    .sort((a, b) => b.heat - a.heat);
}

function renderMarket() {
  marketGrid.innerHTML = indices
    .map((item) => {
      const deltaClass = toDeltaClass(item.changePct);
      const deltaSign = item.changePct >= 0 ? "+" : "";
      return `
        <article class="index-item">
          <p class="name">${item.name} (${item.code})</p>
          <p class="value">${formatNumber(item.value)}</p>
          <p class="delta ${deltaClass}">${deltaSign}${formatNumber(item.changePct)}%</p>
          ${renderSparkline(item.points, item.changePct >= 0)}
        </article>
      `;
    })
    .join("");

  sectorBars.innerHTML = computeSectorHeat()
    .map(
      (item) => `
      <div class="sector-row">
        <span>${item.name}</span>
        <div class="bar-track">
          <div class="bar-fill" style="width:${item.heat}%"></div>
        </div>
        <strong>${item.heat}</strong>
      </div>
    `
    )
    .join("");

  const risingCount = stocks.filter((item) => item.changePct > 0).length;
  const modeText = state.liveMode === "realtime" ? "实时行情模式" : "演示数据模式";
  marketInsight.textContent = `${modeText}：当前自选池中 ${risingCount}/${stocks.length} 只个股上涨。建议你先用模拟交易练仓位，再考虑实盘节奏。`;
}

function renderWatchlist() {
  const keyword = stockSearch.value.trim().toLowerCase();
  const filtered = stocks.filter(
    (item) => item.code.includes(keyword) || item.name.toLowerCase().includes(keyword)
  );

  watchlistBody.innerHTML = filtered
    .map((item) => {
      const deltaClass = toDeltaClass(item.changePct);
      const deltaSign = item.changePct >= 0 ? "+" : "";
      return `
        <tr>
          <td class="code">${item.code}</td>
          <td>${item.name}</td>
          <td>${formatNumber(item.price)}</td>
          <td class="${deltaClass}">${deltaSign}${formatNumber(item.changePct)}%</td>
          <td>${formatNumber(item.turnover)}%</td>
          <td>${formatNumber(item.pe)}</td>
          <td><button class="mini-btn" data-quick-buy="${item.code}">买入1手</button></td>
        </tr>
      `;
    })
    .join("");
}

function renderFundFilters() {
  fundFilters.innerHTML = fundTypes
    .map(
      (type) => `
      <button class="chip ${type === state.selectedFundType ? "active" : ""}" data-fund-type="${type}">
        ${type}
      </button>
    `
    )
    .join("");
}

function renderFunds() {
  const filtered =
    state.selectedFundType === "全部"
      ? funds
      : funds.filter((item) => item.type === state.selectedFundType);

  const sorted = [...filtered].sort((a, b) => b.year - a.year);

  fundList.innerHTML = sorted
    .map((item) => {
      const dayClass = toDeltaClass(item.dayChangePct);
      const daySign = item.dayChangePct >= 0 ? "+" : "";
      const yearClass = toDeltaClass(item.year);
      const yearSign = item.year >= 0 ? "+" : "";
      const livePrice = item.estNav > 0 ? item.estNav : item.nav;
      return `
        <article class="fund-card">
          <h3 class="fund-title">${item.name}</h3>
          <p class="fund-code">${item.code} · ${item.type}基金 · 波动${item.volatility}</p>
          <div class="fund-metrics">
            <p>估算净值<strong>${formatNumber(livePrice, 4)}</strong></p>
            <p>日估涨跌<strong class="${dayClass}">${daySign}${formatNumber(item.dayChangePct)}%</strong></p>
            <p>近一年<strong class="${yearClass}">${yearSign}${formatNumber(item.year)}%</strong></p>
          </div>
          <div class="fund-actions">
            <button class="outline" data-fund-code="${item.code}" data-fund-act="observe">加入关注</button>
            <button class="solid" data-fund-code="${item.code}" data-fund-act="sip">加入定投</button>
          </div>
        </article>
      `;
    })
    .join("");
}

function renderNews() {
  newsList.innerHTML = news
    .map(
      (item) => `
      <article class="news-item">
        <p>${item.title}</p>
        <p class="news-meta">${item.tags.map((tag) => `<span class="tag">${tag}</span>`).join("")}${item.source} · ${item.time}</p>
      </article>
    `
    )
    .join("");
}

function buildTradeOptions() {
  const merged = getMergedInstruments();
  const previous = tradeSymbol.value;

  tradeSymbol.innerHTML = merged
    .map(
      (item) => `
      <option value="${item.code}">${item.kind} · ${item.name} (${item.code})</option>
    `
    )
    .join("");

  if (previous && merged.some((item) => item.code === previous)) {
    tradeSymbol.value = previous;
  }
  updateTradePrice();
}

function updateTradePrice() {
  const code = tradeSymbol.value;
  const current = getMergedInstruments().find((item) => item.code === code);
  if (!current) {
    tradePrice.textContent = "";
    return;
  }
  tradePrice.textContent = `参考价格：${formatNumber(current.price, current.kind === "基金" ? 4 : 2)} 元/${current.kind === "基金" ? "份" : "股"}`;
}

function getHoldingByCode(code) {
  return state.holdings.find((item) => item.code === code);
}

function updateRiskBadge(stockWeight) {
  let level = "稳健型";
  if (stockWeight >= 0.7) level = "激进型";
  if (stockWeight >= 0.45 && stockWeight < 0.7) level = "平衡型";
  riskBadge.textContent = `风险等级：${level}`;
}

function renderPortfolio() {
  const snapshot = computePortfolioSnapshot();

  totalAsset.textContent = formatMoney(snapshot.total);
  totalPnl.className = toDeltaClass(snapshot.pnl);
  totalPnl.textContent = `持仓浮盈亏：${snapshot.pnl >= 0 ? "+" : ""}${formatMoney(snapshot.pnl)}`;
  cashBalance.textContent = `可用资金：${formatMoney(state.cash)}`;

  updateRiskBadge(snapshot.stockRatio);

  const allocation = [
    { name: "股票", value: snapshot.stockValue, className: "stock" },
    { name: "基金", value: snapshot.fundValue, className: "fund" },
    { name: "现金", value: state.cash, className: "cash" },
  ];

  allocationBars.innerHTML = allocation
    .map((item) => {
      const percent = snapshot.total > 0 ? (item.value / snapshot.total) * 100 : 0;
      return `
        <div class="allocation-row">
          <span>${item.name}</span>
          <div class="bar-track">
            <div class="bar-fill ${item.className}" style="width:${percent.toFixed(1)}%"></div>
          </div>
          <strong>${percent.toFixed(1)}%</strong>
        </div>
      `;
    })
    .join("");

  positionList.innerHTML = snapshot.positions
    .sort((a, b) => b.marketValue - a.marketValue)
    .map((item) => {
      const pnlClass = toDeltaClass(item.pnl);
      return `
        <article class="position-item">
          <h4>${item.name} (${item.code})</h4>
          <p>${item.kind} · 持有 ${formatNumber(item.qty, 0)} · 成本 ${formatNumber(item.cost, item.kind === "基金" ? 4 : 2)} · 现价 ${formatNumber(item.price, item.kind === "基金" ? 4 : 2)}</p>
          <p class="${pnlClass}">市值 ${formatMoney(item.marketValue)} · 浮盈亏 ${item.pnl >= 0 ? "+" : ""}${formatMoney(item.pnl)}</p>
        </article>
      `;
    })
    .join("");
}

function renderTransactions() {
  txList.innerHTML = state.trades.length
    ? state.trades
        .slice(0, 6)
        .map((item) => `<li>${item}</li>`)
        .join("")
    : "<li>暂无交易，先从小金额模拟开始。</li>";
}

function toRiskTag(level) {
  if (level === "danger") return "danger";
  if (level === "warn") return "warn";
  return "safe";
}

function renderRiskAssessment() {
  const snapshot = computePortfolioSnapshot();
  const target = getTargetAllocation(state.riskProfile);
  const maxPositionPct = snapshot.maxPositionWeight * 100;
  const stockGapPct = (snapshot.stockRatio - target.stock) * 100;
  const cashPct = snapshot.cashRatio * 100;
  const stressPct = snapshot.stressLossPct;

  const concentrationLevel = maxPositionPct > 35 ? "danger" : maxPositionPct > 25 ? "warn" : "safe";
  const stockLevel = Math.abs(stockGapPct) > 18 ? "danger" : Math.abs(stockGapPct) > 10 ? "warn" : "safe";
  const cashLevel = cashPct < 8 ? "danger" : cashPct < 12 ? "warn" : "safe";
  const stressLevel = stressPct > 7 ? "danger" : stressPct > 4 ? "warn" : "safe";

  const rows = [
    {
      title: "单一持仓集中度",
      value: `${formatNumber(maxPositionPct)}%`,
      tag: concentrationLevel,
      desc: snapshot.maxPosition
        ? `${snapshot.maxPosition.name} 占总资产 ${formatNumber(maxPositionPct)}%，建议控制在 25%-30% 以内。`
        : "暂无持仓数据。",
    },
    {
      title: "股票仓位偏离",
      value: `${stockGapPct >= 0 ? "+" : ""}${formatNumber(stockGapPct)}%`,
      tag: stockLevel,
      desc: `当前风格 ${target.label}，目标股票仓位 ${formatNumber(target.stock * 100)}%。`,
    },
    {
      title: "现金缓冲",
      value: `${formatNumber(cashPct)}%`,
      tag: cashLevel,
      desc: "现金越低，遇到回撤时越缺乏加仓和防守空间。",
    },
    {
      title: "压力测试回撤",
      value: `${formatNumber(stressPct)}%`,
      tag: stressLevel,
      desc: `假设股票跌 8%、基金跌 3.5%，账户约回撤 ${formatMoney(snapshot.stressLoss)}。`,
    },
  ];

  riskItems.innerHTML = rows
    .map(
      (item) => `
      <article class="risk-row">
        <div class="title-line">
          <p><strong>${item.title}</strong> · ${item.value}</p>
          <span class="risk-tag ${toRiskTag(item.tag)}">${item.tag === "danger" ? "高风险" : item.tag === "warn" ? "关注" : "良好"}</span>
        </div>
        <p class="hint">${item.desc}</p>
      </article>
    `
    )
    .join("");
}

function renderRebalanceAdvice() {
  const snapshot = computePortfolioSnapshot();
  const target = getTargetAllocation(state.riskProfile);
  const targetStock = snapshot.total * target.stock;
  const targetFund = snapshot.total * target.fund;
  const targetCash = snapshot.total * target.cash;

  const stockDiff = targetStock - snapshot.stockValue;
  const fundDiff = targetFund - snapshot.fundValue;
  const cashDiff = targetCash - state.cash;

  const suggestions = [];

  suggestions.push(`目标配置（${target.label}）：股票 ${formatNumber(target.stock * 100)}%，基金 ${formatNumber(target.fund * 100)}%，现金 ${formatNumber(target.cash * 100)}%。`);

  if (Math.abs(stockDiff) < 1200) {
    suggestions.push("股票仓位基本合理，可维持当前节奏。");
  } else if (stockDiff > 0) {
    suggestions.push(`股票仓位偏低，可分 2-3 批加仓约 ${formatMoney(stockDiff)}。`);
  } else {
    suggestions.push(`股票仓位偏高，可优先减仓约 ${formatMoney(Math.abs(stockDiff))}。`);
  }

  if (Math.abs(fundDiff) < 1200) {
    suggestions.push("基金仓位在可接受范围。");
  } else if (fundDiff > 0) {
    suggestions.push(`基金仓位可补充约 ${formatMoney(fundDiff)}，优先指数基金。`);
  } else {
    suggestions.push(`基金仓位略高，可赎回约 ${formatMoney(Math.abs(fundDiff))} 释放现金。`);
  }

  if (cashDiff > 0) {
    suggestions.push(`现金缓冲不足，建议先留出约 ${formatMoney(cashDiff)} 机动资金。`);
  } else {
    suggestions.push("现金缓冲充足，可按计划分批执行。");
  }

  if (snapshot.maxPosition && snapshot.maxPositionWeight > 0.33) {
    suggestions.push(
      `${snapshot.maxPosition.name} 仓位过高，建议降低至总资产 25%-30% 区间。`
    );
  }

  rebalanceResult.innerHTML = suggestions.map((item) => `<p>• ${item}</p>`).join("");
}

function buildAlertOptions() {
  const merged = getMergedInstruments();
  const previous = alertSymbol.value;

  alertSymbol.innerHTML = merged
    .map((item) => `<option value="${item.code}">${item.kind} · ${item.name} (${item.code})</option>`)
    .join("");

  if (previous && merged.some((item) => item.code === previous)) {
    alertSymbol.value = previous;
  }
}

function findInstrumentByCode(code) {
  return getMergedInstruments().find((item) => item.code === code);
}

function renderAlertRules() {
  if (!state.alertRules.length) {
    alertList.innerHTML = "<li class=\"muted\">暂无预警，建议至少设置一条止损线。</li>";
    return;
  }

  alertList.innerHTML = state.alertRules
    .slice()
    .sort((a, b) => b.id - a.id)
    .map((rule) => {
      const instrument = findInstrumentByCode(rule.code);
      const currentPrice = instrument ? instrument.price : 0;
      const directionLabel = rule.direction === "above" ? "上破" : "下破";
      const statusLabel = rule.status === "triggered" ? "已触发" : "待触发";
      const statusClass = rule.status === "triggered" ? "warn" : "safe";
      return `
        <li class="alert-item">
          <div class="line">
            <p><strong>${instrument ? instrument.name : rule.code}</strong> ${directionLabel} ${formatNumber(rule.targetPrice, 4)}</p>
            <button type="button" class="alert-remove" data-remove-alert="${rule.id}">删除</button>
          </div>
          <p class="meta">现价 ${formatNumber(currentPrice, currentPrice < 10 ? 4 : 2)} · 状态 <span class="risk-tag ${statusClass}">${statusLabel}</span></p>
        </li>
      `;
    })
    .join("");
}

function renderTriggeredAlerts() {
  if (!state.triggeredAlerts.length) {
    alertTriggeredList.innerHTML = "<li>暂无触发记录</li>";
    return;
  }

  alertTriggeredList.innerHTML = state.triggeredAlerts
    .slice(0, 8)
    .map((item) => `<li>${item}</li>`)
    .join("");
}

function evaluateAlertRules() {
  const now = new Date();
  let triggeredCount = 0;

  state.alertRules = state.alertRules.map((rule) => {
    if (rule.status === "triggered") return rule;
    const instrument = findInstrumentByCode(rule.code);
    if (!instrument) return rule;

    const hitAbove = rule.direction === "above" && instrument.price >= rule.targetPrice;
    const hitBelow = rule.direction === "below" && instrument.price <= rule.targetPrice;
    if (!hitAbove && !hitBelow) return rule;

    triggeredCount += 1;
    const stamp = now.toLocaleTimeString("zh-CN", { hour: "2-digit", minute: "2-digit" });
    const directionText = rule.direction === "above" ? "上破" : "下破";
    state.triggeredAlerts.unshift(
      `${stamp} ${instrument.name} ${directionText} ${formatNumber(rule.targetPrice, 4)}，现价 ${formatNumber(instrument.price, instrument.price < 10 ? 4 : 2)}`
    );

    return { ...rule, status: "triggered" };
  });

  if (triggeredCount > 0) {
    persistAlertRules();
    renderAlertRules();
    renderTriggeredAlerts();
    showToast(`有 ${triggeredCount} 条预警被触发`);
  }
}

function addAlertRule() {
  const code = alertSymbol.value;
  const direction = alertDirection.value === "below" ? "below" : "above";
  const targetPrice = toNumber(alertPrice.value, 0);
  const instrument = findInstrumentByCode(code);

  if (!instrument || targetPrice <= 0) {
    showToast("请输入有效的预警价格");
    return;
  }

  state.alertRules.push({
    id: state.nextAlertId++,
    code,
    direction,
    targetPrice,
    createdAt: new Date().toISOString(),
    status: "armed",
  });

  persistAlertRules();
  renderAlertRules();
  alertPrice.value = "";
  showToast(`已添加 ${instrument.name} 预警`);
}

function removeAlertRule(id) {
  const before = state.alertRules.length;
  state.alertRules = state.alertRules.filter((item) => item.id !== id);
  if (state.alertRules.length !== before) {
    persistAlertRules();
    renderAlertRules();
    showToast("预警已删除");
  }
}

function addTrade(actionType) {
  const code = tradeSymbol.value;
  const qty = Number(tradeQty.value);
  const instrument = getMergedInstruments().find((item) => item.code === code);

  if (!instrument || Number.isNaN(qty) || qty <= 0) {
    showToast("请输入有效数量");
    return;
  }

  const amount = instrument.price * qty;
  const holding = getHoldingByCode(code);
  const time = new Date().toLocaleTimeString("zh-CN", { hour: "2-digit", minute: "2-digit" });

  if (actionType === "buy") {
    if (amount > state.cash) {
      showToast("可用资金不足，先降低仓位规模");
      return;
    }
    state.cash -= amount;

    if (holding) {
      const totalCostValue = holding.qty * holding.cost + amount;
      holding.qty += qty;
      holding.cost = totalCostValue / holding.qty;
    } else {
      state.holdings.push({
        id: `${instrument.kind}-${code}`,
        kind: instrument.kind,
        code,
        name: instrument.name,
        qty,
        cost: instrument.price,
      });
    }

    state.trades.unshift(`${time} 买入 ${instrument.name} ${qty}${instrument.kind === "基金" ? "份" : "股"}，金额 ${formatMoney(amount)}`);
    showToast(`已模拟买入 ${instrument.name}`);
  }

  if (actionType === "sell") {
    if (!holding || holding.qty < qty) {
      showToast("持仓数量不足，无法卖出");
      return;
    }
    state.cash += amount;
    holding.qty -= qty;
    if (holding.qty === 0) {
      state.holdings = state.holdings.filter((item) => item.code !== code);
    }

    state.trades.unshift(`${time} 卖出 ${instrument.name} ${qty}${instrument.kind === "基金" ? "份" : "股"}，金额 ${formatMoney(amount)}`);
    showToast(`已模拟卖出 ${instrument.name}`);
  }

  renderPortfolio();
  renderTransactions();
  renderRiskAssessment();
  renderRebalanceAdvice();
}

function renderSipResult() {
  const monthly = Number(sipMonthly.value);
  const years = Number(sipYears.value);
  const annualRate = Number(sipRate.value) / 100;

  if (!monthly || !years || !annualRate) {
    sipResult.innerHTML = "<p>请输入完整参数</p>";
    return;
  }

  const n = years * 12;
  const r = annualRate / 12;
  const conservativeR = Math.max((annualRate - 0.03) / 12, 0.001);

  const fv = monthly * (((1 + r) ** n - 1) / r) * (1 + r);
  const conservative = monthly * (((1 + conservativeR) ** n - 1) / conservativeR) * (1 + conservativeR);
  const principal = monthly * n;

  sipResult.innerHTML = `
    <p>累计投入：${formatMoney(principal)}</p>
    <p class="big">预估市值：${formatMoney(fv)}</p>
    <p>保守情景（年化降低 3%）：${formatMoney(conservative)}</p>
  `;
}

function renderSipPlans() {
  if (!state.sipPlans.length) {
    sipPlanList.innerHTML = "<li>暂无计划，去基金中心添加一个定投目标。</li>";
    return;
  }
  sipPlanList.innerHTML = state.sipPlans
    .map((item) => {
      const fund = funds.find((f) => f.code === item.fundCode);
      return `<li>${fund ? fund.name : item.fundCode}：每月 ${formatMoney(item.monthly)}</li>`;
    })
    .join("");
}

function addSipPlan(code) {
  const existing = state.sipPlans.find((item) => item.fundCode === code);
  if (existing) {
    existing.monthly += 500;
    showToast("已存在计划，默认每月加投 500 元");
  } else {
    state.sipPlans.push({ fundCode: code, monthly: 1000 });
    showToast("已加入定投计划，每月 1000 元");
  }
  renderSipPlans();
}

function renderAcademy() {
  academyList.innerHTML = lessons
    .map(
      (item) => `
      <article class="academy-item">
        <div class="title">
          <strong>${item.title}</strong>
          <span>${item.progress}%</span>
        </div>
        <div class="progress"><span style="width:${item.progress}%"></span></div>
        <p class="note">${item.note}</p>
      </article>
    `
    )
    .join("");
}

let toastTimer = null;
function showToast(message) {
  toast.textContent = message;
  toast.classList.add("show");
  window.clearTimeout(toastTimer);
  toastTimer = window.setTimeout(() => toast.classList.remove("show"), 1700);
}

function applyLiveData(payload) {
  if (Array.isArray(payload.indices) && payload.indices.length) {
    const normalized = payload.indices.map((item, index) => {
      const fallback = defaultIndices[index] || defaultIndices[0];
      return {
        name: item.name || fallback.name,
        code: item.code || fallback.code,
        value: toNumber(item.value, fallback.value),
        change: toNumber(item.change, fallback.change),
        changePct: toNumber(item.changePct, fallback.changePct),
        points: [],
      };
    });
    indices = withUpdatedIndexHistory(normalized);
  }

  if (Array.isArray(payload.stocks) && payload.stocks.length) {
    const liveMap = new Map(payload.stocks.map((item) => [item.code, item]));
    stocks = defaultStocks.map((base) => {
      const live = liveMap.get(base.code);
      if (!live) return { ...base };
      return {
        ...base,
        name: live.name || base.name,
        price: toNumber(live.price, base.price),
        changePct: toNumber(live.changePct, base.changePct),
        turnover: toNumber(live.turnover, base.turnover),
        pe: toNumber(live.pe, base.pe),
      };
    });
  }

  if (Array.isArray(payload.funds) && payload.funds.length) {
    const liveMap = new Map(payload.funds.map((item) => [item.code, item]));
    funds = defaultFunds.map((base) => {
      const live = liveMap.get(base.code);
      if (!live) return { ...base };
      return {
        ...base,
        name: live.name || base.name,
        nav: toNumber(live.nav, base.nav),
        estNav: toNumber(live.estNav || live.nav, base.estNav),
        dayChangePct: toNumber(live.changePct, base.dayChangePct),
        updateTime: live.updateTime || null,
      };
    });
  }

  state.liveMode = "realtime";
  state.liveUpdatedAt = payload.updatedAt || new Date().toISOString();
  state.liveError = null;
  state.liveSource = payload.source || null;
}

async function loadLiveData({ silent = false } = {}) {
  if (IS_FILE_PROTOCOL) {
    if (!silent) {
      showToast("file 模式仅支持演示数据；实时数据请用 npm start");
    }
    return;
  }

  try {
    const response = await fetch(`/api/market/live?t=${Date.now()}`, { cache: "no-store" });
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }
    const payload = await response.json();
    if (!payload.ok) {
      throw new Error(payload.message || "live api failed");
    }

    applyLiveData(payload);
    renderMarketTime();
    renderMarket();
    renderWatchlist();
    renderFunds();
    buildTradeOptions();
    buildAlertOptions();
    renderPortfolio();
    renderRiskAssessment();
    renderRebalanceAdvice();
    renderAlertRules();
    renderSipPlans();
    evaluateAlertRules();

    if (!silent) {
      showToast("已刷新实时行情");
    }
  } catch (error) {
    state.liveMode = "mock";
    state.liveError = error instanceof Error ? error.message : String(error);
    renderMarketTime();
    if (!silent) {
      showToast("实时数据拉取失败，已切回演示数据");
    }
  }
}

function startLiveRefresh() {
  window.setInterval(() => {
    loadLiveData({ silent: true });
  }, 20000);
}

function attachEvents() {
  stockSearch.addEventListener("input", renderWatchlist);

  riskProfileSelect.addEventListener("change", () => {
    state.riskProfile = riskProfileSelect.value;
    persistRiskProfile();
    renderRiskAssessment();
    renderRebalanceAdvice();
  });

  rebalanceBtn.addEventListener("click", () => {
    renderRiskAssessment();
    renderRebalanceAdvice();
    showToast("已更新调仓建议");
  });

  watchlistBody.addEventListener("click", (event) => {
    const target = event.target;
    if (!(target instanceof HTMLElement)) return;
    const quickCode = target.dataset.quickBuy;
    if (!quickCode) return;

    tradeSymbol.value = quickCode;
    tradeQty.value = "100";
    updateTradePrice();
    addTrade("buy");
  });

  fundFilters.addEventListener("click", (event) => {
    const target = event.target;
    if (!(target instanceof HTMLElement)) return;
    const type = target.dataset.fundType;
    if (!type) return;
    state.selectedFundType = type;
    renderFundFilters();
    renderFunds();
  });

  fundList.addEventListener("click", (event) => {
    const target = event.target;
    if (!(target instanceof HTMLElement)) return;
    const code = target.dataset.fundCode;
    const act = target.dataset.fundAct;
    if (!code || !act) return;

    if (act === "observe") {
      showToast("已加入基金关注");
      return;
    }
    if (act === "sip") {
      addSipPlan(code);
    }
  });

  tradeSymbol.addEventListener("change", updateTradePrice);
  buyBtn.addEventListener("click", () => addTrade("buy"));
  sellBtn.addEventListener("click", () => addTrade("sell"));

  [sipMonthly, sipYears, sipRate].forEach((node) => {
    node.addEventListener("input", renderSipResult);
  });

  alertForm.addEventListener("submit", (event) => {
    event.preventDefault();
    addAlertRule();
  });

  alertList.addEventListener("click", (event) => {
    const target = event.target;
    if (!(target instanceof HTMLElement)) return;
    const removeId = target.dataset.removeAlert;
    if (!removeId) return;
    removeAlertRule(Number(removeId));
  });

  refreshLiveBtn.addEventListener("click", () => {
    if (IS_FILE_PROTOCOL) {
      showToast("请先执行 npm start，再访问 http://127.0.0.1:5178");
      return;
    }
    loadLiveData({ silent: false });
  });

  const navButtons = document.querySelectorAll("[data-target]");
  navButtons.forEach((button) => {
    button.addEventListener("click", () => {
      const targetId = button.getAttribute("data-target");
      const target = document.getElementById(targetId);
      if (!target) return;
      target.scrollIntoView({ behavior: "smooth", block: "start" });
      navButtons.forEach((node) => node.classList.remove("active"));
      document
        .querySelectorAll(`[data-target="${targetId}"]`)
        .forEach((matched) => matched.classList.add("active"));
    });
  });
}

function init() {
  loadUserPreferences();
  riskProfileSelect.value = state.riskProfile;
  seedIndexHistory();
  if (IS_FILE_PROTOCOL) {
    state.liveMode = "mock";
    state.liveError = "file protocol";
  }
  renderMarketTime();
  renderMarket();
  renderWatchlist();
  renderFundFilters();
  renderFunds();
  renderNews();
  buildTradeOptions();
  buildAlertOptions();
  renderPortfolio();
  renderRiskAssessment();
  renderRebalanceAdvice();
  renderAlertRules();
  renderTriggeredAlerts();
  renderTransactions();
  renderSipResult();
  renderSipPlans();
  renderAcademy();
  attachEvents();
  if (!IS_FILE_PROTOCOL) {
    loadLiveData({ silent: true });
    startLiveRefresh();
  }
}

init();
