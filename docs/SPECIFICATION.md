# M&G5 Global Reserve Protocol — EVM AppChain MVP Specification

## Scope

The first MVP is an EVM-compatible AppChain protocol target, intended for a future Avalanche L1 / Subnet-EVM-style deployment. Version 0 does not launch a real appchain. It builds and tests the monetary protocol locally using Solidity and Foundry.

The protocol issues `MG5`, a basket-backed reserve token. The product is stability, not yield. The protocol must rely on reserves, redemption rules, haircuts, waterfall logic, circuit breakers, transparent accounting, and stress-tested solvency.

Confidence is the result, not the mechanism.

## Technical Stack

- Language: Solidity
- Framework: Foundry
- Libraries: OpenZeppelin
- Local chain: Anvil
- Future target: Avalanche L1 / Subnet-EVM-compatible network
- Oracle layer: mocked oracle contracts in v0
- Reserve layer: mocked reserves in v0
- Bridge layer: not included in v0
- Validator infrastructure: not included in v0

Out of scope for v0:

- Solana program
- Rust/Anchor program
- Real appchain validators
- Real bridge
- Real reserve custody
- Real fiat/gold redemption
- Mainnet deployment
- DAO governance
- Yield mechanics

## Basket

All weights use basis points. `10000` bps equals `100%`.

| Sleeve | Weight | Role |
| --- | ---: | --- |
| GOLD | 2000 bps | Hard-reserve monetary anchor |
| USD | 3500 bps | Primary liquidity |
| CNY/CNH | 2500 bps | Productive-economy anchor |
| EUR | 1000 bps | Developed-market diversification |
| BRICK/EM | 1000 bps | Emerging-market sleeve |

Weights must always sum to `10000`.

## Price and NAV Model

All prices use 18-decimal fixed point. For v0, mocked oracle prices start normalized at `1e18`:

- `GOLD_UNIT_USD = 1e18`
- `USD_UNIT_USD = 1e18`
- `CNY_UNIT_USD = 1e18`
- `EUR_UNIT_USD = 1e18`
- `BRICK_UNIT_USD = 1e18`

Basket NAV:

```text
NAV =
  20% * GOLD_UNIT_USD
+ 35% * USD_UNIT_USD
+ 25% * CNY_UNIT_USD
+ 10% * EUR_UNIT_USD
+ 10% * BRICK_UNIT_USD
```

The initial normalized NAV is `1e18`.

## Contracts

### MG5Token

`MG5Token` is the basket-backed reserve token.

Requirements:

- ERC20
- 18 decimals
- Mintable only by `MintRedeem`
- Burnable only by `MintRedeem`
- No public minting
- No owner minting

Required functions:

```solidity
mint(address to, uint256 amount) external;
burnFrom(address from, uint256 amount) external;
```

### MGSToken

`MGSToken` is the protocol/share/governance simulation token.

For v0:

- ERC20
- 18 decimals
- Used only for simulated bounty rewards
- Does not collateralize MG5
- Does not defend the peg
- Does not receive real yield

MGS must not be treated as collateral for MG5.

### BasketOracle

Stores mocked prices and computes NAV.

State:

```solidity
struct Prices {
    uint256 goldUsd;
    uint256 usdUsd;
    uint256 cnyUsd;
    uint256 eurUsd;
    uint256 brickUsd;
    uint256 updatedAt;
    bool frozen;
}
```

Functions:

```solidity
updatePrices(uint256 goldUsd, uint256 usdUsd, uint256 cnyUsd, uint256 eurUsd, uint256 brickUsd) external;
freezeOracle() external;
unfreezeOracle() external;
getPrices() external view returns (Prices memory);
getNAV() external view returns (uint256 nav);
isStale() external view returns (bool);
```

Validation:

- All prices must be greater than zero.
- Frozen oracle blocks NAV-dependent actions.
- Stale oracle blocks mint/redeem.
- Default max staleness is 300 seconds.

### ReserveManager

Tracks mocked reserves, haircuts, liabilities, and collateral ratio.

Reserve buckets:

- GOLD
- USD
- CNY
- EUR
- BRICK

Initial haircuts:

- USD: 1%
- EUR: 2%
- GOLD: 5%
- CNY: 8%
- BRICK: 20%

Collateral ratios:

- Target collateral ratio: `10500` bps
- Minimum collateral ratio: `10200` bps

Main solvency rule:

```text
haircut-adjusted reserves >= MG5 liabilities + required buffer
```

### MintRedeem

Controls MG5 minting, burning, immediate redemption, and queue fallback.

Initial fees:

- `mintFeeBps = 10`
- `redeemFeeBps = 20`

Mint formula:

```text
netDeposit = depositValue - mintFee
mg5Out = netDeposit * 1e18 / NAV
```

Minting requires:

- Minting not paused
- Oracle fresh and unfrozen
- Post-mint collateral ratio at or above target
- Slippage check satisfied

Redeem formula:

```text
grossValue = mg5Amount * NAV / 1e18
netValue = grossValue - redeemFee
```

Immediate redemption requires:

- Redemptions not paused
- Oracle fresh and unfrozen
- Post-redemption collateral ratio at or above minimum
- Slippage check satisfied

If immediate redemption would break solvency, it reverts with `RedemptionQueueRequired`.

### RedemptionQueue

Queues redemptions that cannot process instantly without harming solvency.

State:

```solidity
enum Status {
    Pending,
    Processed,
    Cancelled
}

struct RedemptionRequest {
    uint256 id;
    address owner;
    uint256 mg5Amount;
    uint256 navAtRequest;
    uint256 redeemValue;
    uint256 createdAt;
    Status status;
}
```

Behavior:

- User requests redemption.
- MG5 transfers into escrow.
- Keeper processes when solvency permits.
- Escrowed MG5 is burned on processing.
- Only owner can cancel.
- Processed requests cannot be cancelled.
- Processing cannot violate minimum collateral ratio.

### WaterfallManager

Encodes the crisis defense hierarchy:

1. DEX liquidity / external market liquidity
2. Fee buffer
3. War chest
4. Reserve liquidation
5. Redemption queue
6. Circuit breaker

For v0, DEX liquidity and reserve liquidation capacity are mocked.

Initial war chest rule:

- `maxDailyWarChestDrawBps = 1000`

### CircuitBreaker

Pauses or throttles protocol operations during objective failure conditions.

Trigger conditions covered in v0:

- Oracle stale
- Oracle frozen
- Collateral ratio below minimum
- Redemption queue exceeds threshold
- Manual emergency pause

Circuit breakers should block minting first. Queued redemptions remain possible unless processing them would violate solvency.

### BountyManager

Simulates keeper/arbitrage rewards.

Rules:

- Rewards are paid only in MGS.
- No MG5 rewards in v0.
- Deviation before must exceed threshold.
- Deviation after must improve.
- Reward is capped.
- Reward budget prevents infinite MGS draining.

### ProtocolGovernor

Central v0 authority using OpenZeppelin `AccessControl`.

Roles:

- `DEFAULT_ADMIN_ROLE`
- `ORACLE_UPDATER_ROLE`
- `RESERVE_UPDATER_ROLE`
- `KEEPER_ROLE`
- `PAUSER_ROLE`

DAO governance is not included in v0.

## Errors

Implemented custom errors:

```solidity
error InvalidWeights();
error InvalidPrice();
error OracleFrozen();
error OracleStale();
error ProtocolPaused();
error MintPaused();
error RedeemPaused();
error Unauthorized();
error InvalidCollateralRatio();
error InsufficientCollateral();
error PostMintUndercollateralized();
error PostRedeemUndercollateralized();
error RedemptionQueueRequired();
error InvalidRedemptionRequest();
error RedemptionAlreadyProcessed();
error SlippageExceeded();
error BountyDoesNotImprovePeg();
error BountyRewardTooLarge();
error MathOverflow();
```

## Events

Implemented protocol events:

```solidity
event ProtocolInitialized(address indexed admin);
event PricesUpdated(uint256 nav, uint256 timestamp);
event ReservesUpdated(uint256 adjustedReserves, uint256 timestamp);
event StableMinted(address indexed user, uint256 depositValue, uint256 mg5Out);
event StableRedeemed(address indexed user, uint256 mg5Amount, uint256 valueOut);
event RedemptionRequested(uint256 indexed id, address indexed user, uint256 mg5Amount);
event RedemptionProcessed(uint256 indexed id, address indexed user, uint256 valueOut);
event CircuitBreakerTriggered(string reason);
event CircuitBreakerCleared();
event WarChestDrawn(uint256 amount);
event BountyClaimed(address indexed keeper, uint256 reward);
```

## Invariants

The MVP enforces or tests:

- Basket weights sum to `10000` bps.
- MG5 can only be minted by protocol logic.
- MGS cannot be used as MG5 collateral.
- No mint can execute if post-mint collateral ratio is below target.
- No immediate redemption can execute if post-redemption collateral ratio is below minimum.
- Oracle stale/frozen state blocks NAV-dependent actions.
- Fee buffer cannot go negative.
- War chest cannot go negative.
- Bounty rewards are capped.
- Circuit breaker activates under objective failure states.
- Math uses integer fixed-point arithmetic.

## Test Coverage

The Foundry test suite covers:

- MG5 and MGS deployment
- MG5 restricted mint/burn
- Unauthorized mint failure
- Valid price updates
- Zero price rejection
- NAV calculation
- Oracle freeze and staleness blocking mint/redeem
- Reserve updates
- Haircut updates
- Haircut-adjusted reserve values
- Collateral ratio changes
- Healthy mint/redeem
- Mint and redemption fees
- Under-collateralized mint rejection
- Unsafe redemption queue fallback
- Redemption request, escrow, process, cancel, and double-process rejection
- Waterfall liquidity and war chest draw limit
- Circuit breaker stale/frozen/low collateral/manual pause paths
- MGS-only bounty rewards
- MGS non-collateral invariant
- 20% redemption run
- 40% redemption run
- Combined stale oracle and redemption run
- Gold/CNY/EUR/BRICK sleeve shock
- Reserve haircut increase
- Fee buffer and war chest depletion bounds

## Deployment Script

`DeployLocal.s.sol` deploys:

- `ProtocolGovernor`
- `MG5Token`
- `MGSToken`
- `BasketOracle`
- `ReserveManager`
- `WaterfallManager`
- `CircuitBreaker`
- `RedemptionQueue`
- `BountyManager`
- `MintRedeem`

Then it configures:

- MG5 minter as `MintRedeem`
- MGS minter as `BountyManager`
- Redemption queue integration
- Circuit breaker integration
- Reserve manager protocol role
- Initial normalized prices
- Initial mocked reserves
- Mocked waterfall liquidity

## Acceptance Criteria

The MVP is complete when:

- Foundry repo builds.
- All unit tests pass.
- Stress tests pass.
- MG5 mint/redeem works under healthy collateralization.
- Undercollateralized minting is impossible.
- Unsafe redemptions go to queue.
- Circuit breaker activates correctly.
- Oracle freeze/staleness blocks NAV actions.
- Reserve haircuts affect collateral ratio.
- Waterfall logic is implemented.
- README documents the future appchain path.

## Future AppChain Roadmap

1. Local Foundry MVP
2. Private EVM devnet
3. Avalanche L1 / Subnet-EVM prototype
4. Validator set design
5. Bridge design
6. Oracle and reserve attestation integration
7. Legal/custody framework
8. Public testnet stress competition
9. Capped mainnet beta

Correct order:

1. Monetary logic first
2. Stress tests second
3. AppChain infrastructure third
4. Real reserves last

No reserve model, no currency. No stress survival, no appchain. No redemption path, no peg.
