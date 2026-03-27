// --- State ---
let token = localStorage.getItem("token") || null;
let playerId = localStorage.getItem("player_id") || null;
let deviceId = localStorage.getItem("device_id") || null;
let gameState = "idle"; // idle, casting, waiting, timing, revealing
let castAnimFrame = null;
let timingAnimFrame = null;
let inventoryOffset = 0;
const INVENTORY_LIMIT = 50;

// --- DOM refs ---
const $ = (sel) => document.querySelector(sel);
const phases = {
    idle: $("#phase-idle"),
    cast: $("#phase-cast"),
    wait: $("#phase-wait"),
    timing: $("#phase-timing"),
    reveal: $("#phase-reveal"),
    miss: $("#phase-miss"),
    error: $("#phase-error"),
};

// --- Debug logging ---
const debugLog = $("#debug-log");
let debugCount = 0;

function logDebug(type, text) {
    debugCount++;
    if (debugCount > 50) {
        debugLog.removeChild(debugLog.lastChild);
    }
    const entry = document.createElement("div");
    entry.className = `debug-entry ${type}`;
    entry.textContent = text;
    debugLog.prepend(entry);
}

// --- API layer ---
async function apiFetch(path, options = {}) {
    const url = `/api${path}`;
    const headers = { "Content-Type": "application/json", ...(options.headers || {}) };
    if (token) headers["Authorization"] = `Bearer ${token}`;

    const method = options.method || "GET";
    logDebug("req", `${method} ${url} ${options.body || ""}`);

    let res;
    try {
        res = await fetch(url, { ...options, headers });
    } catch (err) {
        logDebug("err", `Network error: ${err.message}`);
        throw err;
    }

    const text = await res.text();
    let data;
    try {
        data = JSON.parse(text);
    } catch {
        data = text;
    }

    logDebug(res.ok ? "res" : "err", `${res.status} ${JSON.stringify(data)}`);

    // Handle 401 - refresh token and retry once
    if (res.status === 401 && deviceId) {
        const refreshed = await refreshToken();
        if (refreshed) {
            headers["Authorization"] = `Bearer ${token}`;
            const retryRes = await fetch(url, { ...options, headers });
            const retryText = await retryRes.text();
            try { data = JSON.parse(retryText); } catch { data = retryText; }
            logDebug(retryRes.ok ? "res" : "err", `RETRY ${retryRes.status} ${JSON.stringify(data)}`);
            return { status: retryRes.status, data };
        }
    }

    return { status: res.status, data };
}

async function refreshToken() {
    try {
        const res = await fetch("/api/auth/refresh", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ device_id: deviceId }),
        });
        if (res.ok) {
            const data = await res.json();
            token = data.token;
            playerId = data.player_id;
            localStorage.setItem("token", token);
            localStorage.setItem("player_id", playerId);
            logDebug("res", `Token refreshed for player ${playerId}`);
            return true;
        }
    } catch (err) {
        logDebug("err", `Refresh failed: ${err.message}`);
    }
    return false;
}

// --- Auth ---
async function register() {
    if (!deviceId) {
        deviceId = crypto.randomUUID();
        localStorage.setItem("device_id", deviceId);
    }

    const { status, data } = await apiFetch("/auth/register", {
        method: "POST",
        body: JSON.stringify({ device_id: deviceId }),
    });

    if (status === 200) {
        token = data.token;
        playerId = data.player_id;
        localStorage.setItem("token", token);
        localStorage.setItem("player_id", playerId);
        $("#connection-status").classList.add("connected");
        $("#player-info").textContent = `Player #${playerId}`;
    } else {
        $("#player-info").textContent = "Connection failed";
    }
}

// --- Phase management ---
function showPhase(name) {
    Object.values(phases).forEach((el) => el.classList.add("hidden"));
    if (phases[name]) phases[name].classList.remove("hidden");
}

// --- Game: Casting ---
let castPosition = 0;
let castDirection = 1;
const CAST_SPEED = 0.015;

function startCasting() {
    gameState = "casting";
    showPhase("cast");
    castPosition = 0;
    castDirection = 1;

    const indicator = $("#cast-indicator");
    const track = indicator.parentElement;

    function animate() {
        castPosition += CAST_SPEED * castDirection;
        if (castPosition >= 1) { castPosition = 1; castDirection = -1; }
        if (castPosition <= 0) { castPosition = 0; castDirection = 1; }

        const maxLeft = track.clientWidth - indicator.clientWidth;
        indicator.style.left = `${castPosition * maxLeft}px`;
        castAnimFrame = requestAnimationFrame(animate);
    }
    castAnimFrame = requestAnimationFrame(animate);
}

function lockCast() {
    cancelAnimationFrame(castAnimFrame);
    startWaiting();
}

// --- Game: Waiting ---
function startWaiting() {
    gameState = "waiting";
    showPhase("wait");

    const waitTime = 1000 + Math.random() * 3000; // 1-4 seconds
    setTimeout(() => {
        if (gameState === "waiting") startTiming();
    }, waitTime);
}

// --- Game: Timing minigame ---
let timingPosition = 0;
let zoneStart = 0;
let zoneEnd = 0;
const TIMING_SPEED = 0.008;

function startTiming() {
    gameState = "timing";
    showPhase("timing");

    // Random zone position and width
    const zoneWidth = 0.1 + Math.random() * 0.15; // 10-25% of track
    zoneStart = 0.1 + Math.random() * (0.8 - zoneWidth); // between 10% and 80%
    zoneEnd = zoneStart + zoneWidth;

    const zone = $("#timing-zone");
    zone.style.left = `${zoneStart * 100}%`;
    zone.style.width = `${zoneWidth * 100}%`;

    timingPosition = 0;
    const indicator = $("#timing-indicator");

    function animate() {
        timingPosition += TIMING_SPEED;
        if (timingPosition > 1) timingPosition = 0; // wrap around

        const track = indicator.parentElement;
        const maxLeft = track.clientWidth - indicator.clientWidth;
        indicator.style.left = `${timingPosition * maxLeft}px`;
        timingAnimFrame = requestAnimationFrame(animate);
    }
    timingAnimFrame = requestAnimationFrame(animate);
}

function lockTiming() {
    cancelAnimationFrame(timingAnimFrame);

    let timingScore;
    if (timingPosition >= zoneStart && timingPosition <= zoneEnd) {
        // Inside the zone: 0.5 - 1.0 based on proximity to center
        const zoneCenter = (zoneStart + zoneEnd) / 2;
        const zoneHalf = (zoneEnd - zoneStart) / 2;
        const distFromCenter = Math.abs(timingPosition - zoneCenter) / zoneHalf;
        timingScore = 0.5 + 0.5 * (1 - distFromCenter);
    } else {
        // Outside: 0.0 - 0.3 based on distance from zone edge
        const distToZone = Math.min(
            Math.abs(timingPosition - zoneStart),
            Math.abs(timingPosition - zoneEnd)
        );
        timingScore = Math.max(0, 0.3 - distToZone);
    }

    timingScore = Math.round(timingScore * 100) / 100; // 2 decimal places
    sendCatch(timingScore);
}

// --- Game: Catch ---
async function sendCatch(timingScore) {
    gameState = "revealing";

    const { status, data } = await apiFetch("/fish/catch", {
        method: "POST",
        body: JSON.stringify({ timing_score: timingScore }),
    });

    if (status === 200) {
        if (data.result === "miss") {
            showMiss(data.reason || "No fish available");
        } else {
            showReveal(data);
        }
        refreshInventory();
        refreshPool();
    } else if (status === 429) {
        showRateLimit(data.retry_after_seconds || 3);
    } else {
        showError(data.error || "Something went wrong");
    }
}

function showReveal(fish) {
    showPhase("reveal");

    const card = $("#reveal-card");
    card.style.borderColor = rarityColor(fish.rarity);

    const badge = $("#reveal-rarity-badge");
    badge.textContent = fish.rarity;
    badge.className = `rarity-badge rarity-bg-${fish.rarity}`;

    $("#reveal-species").textContent = fish.species;
    $("#reveal-species").style.color = rarityColor(fish.rarity);
    $("#reveal-edition").textContent = `#${fish.edition_number} / ${fish.edition_size}`;
    $("#reveal-size").textContent = fish.size_variant;
    $("#reveal-color").textContent = fish.color_variant;
}

function showMiss(reason) {
    showPhase("miss");
    $("#miss-reason").textContent = reason;
}

function showRateLimit(seconds) {
    showPhase("error");
    $("#error-message").textContent = "Too fast! Rate limited.";

    let remaining = seconds;
    const countdown = $("#error-countdown");
    countdown.textContent = `${remaining.toFixed(1)}s`;

    const interval = setInterval(() => {
        remaining -= 0.1;
        if (remaining <= 0) {
            clearInterval(interval);
            goIdle();
            return;
        }
        countdown.textContent = `${remaining.toFixed(1)}s`;
    }, 100);
}

function showError(message) {
    showPhase("error");
    $("#error-message").textContent = message;
    $("#error-countdown").textContent = "";
    setTimeout(goIdle, 3000);
}

function goIdle() {
    gameState = "idle";
    showPhase("idle");
}

// --- Inventory ---
async function refreshInventory() {
    inventoryOffset = 0;
    const { status, data } = await apiFetch(`/player/inventory?limit=${INVENTORY_LIMIT}&offset=0`);
    if (status !== 200) return;

    const grid = $("#inventory-grid");
    grid.innerHTML = "";
    $("#inventory-count").textContent = `(${data.total})`;

    data.fish.forEach((fish) => grid.appendChild(createFishCard(fish)));

    const loadMore = $("#btn-load-more");
    if (data.total > INVENTORY_LIMIT) {
        loadMore.classList.remove("hidden");
        inventoryOffset = INVENTORY_LIMIT;
    } else {
        loadMore.classList.add("hidden");
    }
}

async function loadMoreInventory() {
    const { status, data } = await apiFetch(`/player/inventory?limit=${INVENTORY_LIMIT}&offset=${inventoryOffset}`);
    if (status !== 200) return;

    const grid = $("#inventory-grid");
    data.fish.forEach((fish) => grid.appendChild(createFishCard(fish)));
    inventoryOffset += INVENTORY_LIMIT;

    if (inventoryOffset >= data.total) {
        $("#btn-load-more").classList.add("hidden");
    }
}

function createFishCard(fish) {
    const card = document.createElement("div");
    card.className = "fish-card";
    card.style.borderLeftColor = rarityColor(fish.rarity);

    const caughtAt = fish.caught_at ? new Date(fish.caught_at).toLocaleString() : "";

    card.innerHTML = `
        <div class="fish-name" style="color:${rarityColor(fish.rarity)}">${fish.species}</div>
        <div class="fish-edition">#${fish.edition_number} / ${fish.edition_size}</div>
        <div class="fish-traits">
            <span>${fish.size_variant}</span>
            <span>${fish.color_variant}</span>
        </div>
        <div class="fish-time">${caughtAt}</div>
    `;
    return card;
}

// --- Pool ---
async function refreshPool() {
    const { status, data } = await apiFetch("/fish/pool");
    if (status !== 200) return;

    const tbody = $("#pool-body");
    tbody.innerHTML = "";

    data.forEach((species) => {
        const pct = species.edition_size > 0
            ? (species.remaining / species.edition_size) * 100
            : 0;

        const tr = document.createElement("tr");
        tr.innerHTML = `
            <td style="color:${rarityColor(species.rarity)}">${species.name}</td>
            <td><span class="rarity-badge rarity-bg-${species.rarity}">${species.rarity}</span></td>
            <td>${species.remaining} / ${species.edition_size}</td>
            <td>
                <div class="pool-bar-container">
                    <div class="pool-bar rarity-bg-${species.rarity}" style="width:${pct}%"></div>
                </div>
            </td>
        `;
        tbody.appendChild(tr);
    });
}

// --- Helpers ---
function rarityColor(rarity) {
    const colors = {
        common: "#9e9e9e",
        uncommon: "#4caf50",
        rare: "#2196f3",
        epic: "#9c27b0",
        legendary: "#ff9800",
    };
    return colors[rarity] || "#9e9e9e";
}

// --- Event bindings ---
$("#btn-cast").addEventListener("click", startCasting);
$("#btn-lock-cast").addEventListener("click", lockCast);
$("#btn-catch").addEventListener("click", lockTiming);
$("#btn-cast-again").addEventListener("click", goIdle);
$("#btn-cast-after-miss").addEventListener("click", goIdle);
$("#btn-load-more").addEventListener("click", loadMoreInventory);

// Keyboard shortcut: Space to interact with current phase
document.addEventListener("keydown", (e) => {
    if (e.code !== "Space") return;
    e.preventDefault();
    if (gameState === "idle") startCasting();
    else if (gameState === "casting") lockCast();
    else if (gameState === "timing") lockTiming();
});

// --- Init ---
async function init() {
    showPhase("idle");
    await register();
    if (token) {
        refreshInventory();
        refreshPool();
    }
}

init();
