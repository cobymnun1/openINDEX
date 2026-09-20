import http from "node:http";

const port = Number(process.env.PORT ?? 8787);
const endpoint = process.env.ZERO_EX_QUOTE_URL ?? "https://api.0x.org/swap/allowance-holder/quote";
const apiKey = process.env.ZERO_EX_API_KEY;
const chainId = process.env.CHAIN_ID ?? "8453";
const corsOrigin = process.env.CORS_ORIGIN ?? "http://127.0.0.1:8787";
const upstreamTimeoutMs = 10_000;

function json(res, status, body) {
  res.writeHead(status, {
    "content-type": "application/json",
    "cache-control": "no-store",
    "x-content-type-options": "nosniff",
    "access-control-allow-origin": corsOrigin,
    "access-control-allow-methods": "GET, POST, OPTIONS",
    "access-control-allow-headers": "content-type",
  });
  res.end(JSON.stringify(body));
}

function address(value, field) {
  if (typeof value !== "string" || !/^0x[0-9a-fA-F]{40}$/.test(value)) {
    throw new Error(`invalid ${field}`);
  }
  return value;
}

async function readBody(req) {
  let body = "";
  for await (const chunk of req) {
    body += chunk;
    if (body.length > 32_768) throw new Error("request too large");
  }
  const parsed = JSON.parse(body || "{}");
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) throw new Error("invalid request");
  return parsed;
}

function decimal(value, field) {
  if (typeof value !== "string" && typeof value !== "number") throw new Error(`invalid ${field}`);
  if (!/^(0|[1-9][0-9]*)$/.test(String(value))) throw new Error(`invalid ${field}`);
  return BigInt(value);
}

function hex(value, field) {
  if (typeof value !== "string" || !/^0x[0-9a-fA-F]*$/.test(value) || value.length % 2 !== 0) {
    throw new Error(`invalid ${field}`);
  }
  return value;
}

async function quote(input) {
  const sellToken = address(input.sellToken, "sellToken");
  const buyToken = address(input.buyToken, "buyToken");
  const taker = address(input.taker, "taker");
  if (sellToken.toLowerCase() === buyToken.toLowerCase()) throw new Error("tokens must differ");
  const sellAmount = decimal(input.sellAmount, "sellAmount");
  const slippageBps = decimal(input.slippageBps ?? "100", "slippageBps");
  const requestedChainId = decimal(input.chainId ?? chainId, "chainId");
  if (requestedChainId !== BigInt(chainId) || sellAmount <= 0n || slippageBps > 10_000n) {
    throw new Error("invalid amount or slippage");
  }

  const url = new URL(endpoint);
  url.searchParams.set("sellToken", sellToken);
  url.searchParams.set("buyToken", buyToken);
  url.searchParams.set("chainId", String(input.chainId ?? chainId));
  url.searchParams.set("sellAmount", sellAmount.toString());
  url.searchParams.set("taker", taker);
  url.searchParams.set("slippageBps", slippageBps.toString());
  const headers = { "0x-version": "v2" };
  if (apiKey) headers["0x-api-key"] = apiKey;

  const response = await fetch(url, {headers, signal: AbortSignal.timeout(upstreamTimeoutMs)});
  const body = await response.json();
  if (!response.ok) throw new Error(`0x quote failed: ${response.status}`);
  const buyAmount = decimal(body.buyAmount, "buyAmount");
  const minBuyAmount = decimal(
    body.minBuyAmount ?? (buyAmount * (10_000n - slippageBps) / 10_000n).toString(),
    "minBuyAmount"
  );
  const transactionTo = address(body.transaction?.to, "transaction.to");
  const allowanceTarget = address(body.allowanceTarget ?? transactionTo, "allowanceTarget");
  const transactionData = hex(body.transaction?.data, "transaction.data");
  const transactionValue = decimal(body.transaction?.value ?? "0", "transaction.value");
  if (buyAmount === 0n || minBuyAmount > buyAmount) {
    throw new Error("quote omitted executable route data");
  }
  return {
    buyAmount: buyAmount.toString(),
    minBuyAmount: minBuyAmount.toString(),
    allowanceTarget,
    transaction: {
      to: transactionTo,
      data: transactionData,
      value: transactionValue.toString(),
    },
  };
}

const server = http.createServer(async (req, res) => {
  if (req.method === "OPTIONS") return json(res, 204, {});
  if (req.method === "GET" && req.url === "/health") {
    return json(res, 200, { ok: true, service: "openINDEX-quote-service" });
  }
  if (req.method !== "POST" || req.url !== "/quote") {
    return json(res, 404, { error: "not found" });
  }
  try {
    return json(res, 200, await quote(await readBody(req)));
  } catch (error) {
    return json(res, 400, { error: error instanceof Error ? error.message : "request failed" });
  }
});

server.listen(port, "127.0.0.1", () => {
  console.log(`openINDEX quote service listening on http://127.0.0.1:${port}`);
});
