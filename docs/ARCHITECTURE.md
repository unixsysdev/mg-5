# M&G5 Protocol Architecture

M&G5 v0 is a local Solidity MVP for an EVM-compatible AppChain protocol. It proves monetary logic before any validator, bridge, custody, or appchain work.

## Components

- `MG5Token`: ERC20 reserve token. Minting and burning are restricted to `MintRedeem`.
- `MGSToken`: ERC20 share/governance simulation token. It is only used for bounty rewards and is never collateral.
- `BasketOracle`: Mock oracle for normalized basket sleeve prices and NAV.
- `ReserveManager`: Mock reserve accounting, haircuts, liabilities, and collateral ratio.
- `MockReserveAsset`: Local/devnet ERC20 collateral assets used to simulate reserve custody.
- `MintRedeem`: MG5 minting, collateralized mock reserve deposits, immediate redemption, fees, and solvency enforcement.
- `RedemptionQueue`: Escrows MG5 when immediate redemption would be unsafe.
- `WaterfallManager`: Encodes the crisis response order.
- `CircuitBreaker`: Triggers/pause logic under objective failure conditions.
- `BountyManager`: MGS-only simulated keeper rewards.
- `ProtocolGovernor`: v0 role registry using OpenZeppelin `AccessControl`.
- `IPriceAdapter` and `IReserveAttestation`: future integration boundaries for production oracle and reserve reporting.

## Flow

```mermaid
flowchart LR
User --> MintRedeem
MintRedeem --> MG5Token
MintRedeem --> BasketOracle
MintRedeem --> ReserveManager
MintRedeem --> MockReserveAsset
User --> RedemptionQueue
RedemptionQueue --> MintRedeem
  CircuitBreaker --> MintRedeem
  CircuitBreaker --> BasketOracle
  CircuitBreaker --> ReserveManager
  BountyManager --> MGSToken
```

## Solvency Model

Minting requires the post-mint collateral ratio to stay at or above `10500` bps. The v0.1 collateralized path pulls configured mock reserve ERC20s into reserve custody before minting MG5. Immediate redemption requires the post-redemption collateral ratio to stay at or above `10200` bps. If immediate redemption cannot meet that rule, the user must use the redemption queue.

All reserve values are mocked and normalized in v0. The protocol uses haircut-adjusted reserves for collateral ratio checks. Redemption release defaults to pro-rata reserve reduction and can be switched to liquidity-priority order for stress modeling.
