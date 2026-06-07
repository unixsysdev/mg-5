# Risk Model

## Core Principle

MG5 should not rely on confidence alone to defend its peg. Confidence is the result of transparent reserves, redemption rules, haircuts, waterfall logic, circuit breakers, accounting, and stress-tested solvency.

## Main Risks Covered in v0

- Oracle stale or frozen state blocks NAV-dependent actions.
- Post-mint undercollateralization is rejected.
- Post-redemption undercollateralization is rejected.
- Unsafe immediate redemptions are routed to queue.
- Reserve haircut increases reduce collateral ratio.
- Collateralized mock minting must transfer configured reserve ERC20s into reserve custody.
- MGS cannot collateralize MG5.
- Bounty rewards are capped and paid only in MGS.
- War chest drawdown is bounded by a daily limit.
- Redemption accounting can be tested under pro-rata or liquidity-priority reserve release.

## v0 Limitations

- Reserves are mocked.
- Mock reserve assets are ERC20 simulations, not real-world custody claims.
- Prices are mocked.
- There is no custody integration.
- There is no bridge.
- There is no real DEX liquidity.
- There is no DAO governance.
- There is no yield model.
- There is no production redemption rail.

## Required Future Work

- Independent reserve attestations.
- Production oracle design and fallback rules.
- Production adapter implementation for `IPriceAdapter`.
- Reserve attestation implementation for `IReserveAttestation`.
- Legal/custody framework.
- Redemption operations and settlement design.
- AppChain security model.
- Validator and bridge threat modeling.
