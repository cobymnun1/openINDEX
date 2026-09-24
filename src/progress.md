# v2 Progress Handoff

## Current files

- `TokenIssue.sol`: stripped-down OZ-style ERC-20 base.
- `NFTIssue.sol`: minimal non-transferable `IndexOwnerId` identifier.
- `indexFactory.sol`: validates index assets, deploys an `IndexToken` and an
  `IndexOwner`, then emits `IndexCreated` with asset addresses and weights.

## Current behavior

`IndexFactory.createIndex(string indexName, string iconURI, IndexAsset[] assets)`:

- requires at least two assets;
- requires nonzero deployed contract addresses and positive weights;
- requires all weights to total exactly `100`;
- deploys an ERC-20 named and symbolized with `indexName`;
- mints `100_000` tokens to the caller;
- deploys an owner identifier named `<indexName>OwnershipNFT`;
- mints owner ID `0` to the caller;
- includes `iconURI` in the NFT's on-chain `tokenURI()` metadata;
- exposes `iconURI()` on the ERC-20.
- emits the validated `IndexAsset[]` in `IndexCreated`.

The asset list is emitted for off-chain consumers but is not stored in the
index token or owner identifier.

The owner identifier is deliberately not a full transferable ERC-721. It only
supports metadata, `ownerOf`, internal minting, and internal burning.

## Latest local deployment

Anvil RPC:

```text
http://127.0.0.1:8545
```

Latest factory:

```text
0x0165878A594ca255338adfa4d48449f69242Eb8F
```

Latest test index (`testINDEX3`):

- Token: `0x3b02ff1e626ed7a8fd6ec5299e2c54e1421b626b`
- Owner identifier: `0xba12646cc07adbe43f8bd25d83fb628d29c8a762`
- Icon URI: `https://example.com/test-index.png`
- Owner ID: `0`

Test assets, each with 1,000,000 tokens minted to the Anvil deployer:

- `fakecoin`: `0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512`
- `testcoin`: `0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0`
- `memecoin`: `0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9`
- `shitcoin`: `0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9`

## Useful commands

Compile only the v2 factory:

```bash
/home/coby/.foundry/bin/forge build \
  --root /mnt/provenant_data/basket/base/openBSKT \
  src/v2/openIndexSRC/indexFactory.sol
```

Deploy the factory:

```bash
/home/coby/.foundry/bin/forge create \
  --root /mnt/provenant_data/basket/base/openBSKT \
  src/v2/openIndexSRC/indexFactory.sol:IndexFactory \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --broadcast
```

Create an index:

```bash
/home/coby/.foundry/bin/cast send FACTORY_ADDRESS \
  "createIndex(string,string,(address,uint256)[])" \
  "TestIndex" \
  "https://web.sciexchange.xyz/sciex.png?v=1" \
  "[(ASSET_1,25),(ASSET_2,25),(ASSET_3,25),(ASSET_4,25)]" \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

## Important notes

- Anvil uses disposable accounts. Never use its private key on a real network.
- The full project build currently scans the copied OZ tree under `src/v2` and
  fails on files requiring Solidity `0.8.26`/`0.8.27`. Targeted v2 builds work.
- ERC-20 icon display is wallet metadata behavior; `iconURI()` is custom and
  wallets do not automatically read it.
- The current NFT metadata is a minimal inline JSON data URI.
- Existing deployments do not update when the source changes; redeploy the
  factory and create a new index after changes.
- Event data uses standard ABI 32-byte padding; this is normal and preserves
  compatibility with standard decoders.

## Next logical step

Add storage for the validated asset addresses and weights, then implement the
actual index accounting and underlying-asset custody/recovery design.
