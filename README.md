# 💰 Microloan Platform with Bitcoin Collateral

A decentralized microloan platform built on Stacks blockchain that enables peer-to-peer lending with STX collateral. Borrowers can request loans by locking collateral, and lenders can fund these requests to earn interest.

## 🌟 Features

- **Collateralized Lending**: Borrowers must provide at least 150% collateral ratio
- **Peer-to-Peer**: Direct lending between users without intermediaries
- **Interest-Bearing**: Lenders earn interest on funded loans
- **Liquidation Mechanism**: Automatic collateral seizure for defaulted loans
- **Platform Fees**: Configurable fee system for platform sustainability
- **Loan Management**: Full lifecycle management from request to repayment

## 📋 Contract Functions

### Public Functions

#### `create-loan-request`
Creates a new loan request by depositing collateral.

**Parameters:**
- `loan-amount` (uint): Amount of STX requested
- `collateral-amount` (uint): Amount of STX to lock as collateral
- `interest-rate` (uint): Interest rate in basis points (e.g., 500 = 5%)
- `duration-blocks` (uint): Loan duration in blocks

**Returns:** Loan ID

**Requirements:**
- Collateral ratio must be ≥ 150%
- All amounts must be > 0

#### `fund-loan`
Fund a pending loan request as a lender.

**Parameters:**
- `loan-id` (uint): ID of the loan to fund

**Returns:** `true` on success

#### `repay-loan`
Repay an active loan and reclaim collateral.

**Parameters:**
- `loan-id` (uint): ID of the loan to repay

**Returns:** `true` on success

**Note:** Automatically deducts platform fee and returns collateral

#### `liquidate-loan`
Liquidate a defaulted loan and claim collateral.

**Parameters:**
- `loan-id` (uint): ID of the defaulted loan

**Returns:** `true` on success

**Requirements:**
- Loan must be past expiry block
- Only callable after default

#### `cancel-loan-request`
Cancel a pending loan request and reclaim collateral.

**Parameters:**
- `loan-id` (uint): ID of the loan to cancel

**Returns:** `true` on success

**Requirements:**
- Only borrower can cancel
- Loan must be in pending status

#### `set-platform-fee-rate`
Update platform fee rate (owner only).

**Parameters:**
- `new-rate` (uint): New fee rate in basis points (max 1000 = 10%)

#### `withdraw-fees`
Withdraw accumulated platform fees (owner only).

**Returns:** Total fees withdrawn

### Read-Only Functions

#### `get-loan`
Retrieve complete loan information.

**Parameters:**
- `loan-id` (uint): Loan identifier

**Returns:** Loan data tuple or `none`

#### `get-user-loan-count`
Get total number of loans created by a user.

**Parameters:**
- `user` (principal): User address

**Returns:** Loan count

#### `calculate-repayment-amount`
Calculate total repayment amount including interest.

**Parameters:**
- `loan-amount` (uint): Principal amount
- `interest-rate` (uint): Rate in basis points
- `duration-blocks` (uint): Loan duration

**Returns:** Total repayment amount

#### `is-loan-defaulted`
Check if a loan has defaulted.

**Parameters:**
- `loan-id` (uint): Loan identifier

**Returns:** `true` if defaulted, `false` otherwise

#### `get-collateral-ratio`
Calculate collateral-to-loan ratio.

**Parameters:**
- `loan-amount` (uint): Loan amount
- `collateral-amount` (uint): Collateral amount

**Returns:** Ratio percentage

#### `get-platform-fee-rate`
Get current platform fee rate.

**Returns:** Fee rate in basis points

#### `get-total-fees-collected`
Get total accumulated fees.

**Returns:** Total fees amount

## 🚀 Getting Started

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Stacks wallet for testing

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd Microloan-Platform-with-Bitcoin-Collateral
```

2. Check the contract:
```bash
clarinet check
```

3. Run tests:
```bash
clarinet test
```

### Usage Example

#### Creating a Loan Request
```clarity
(contract-call? .Microloan-Platform-with-Bitcoin-Collateral create-loan-request 
  u1000000    ;; 1 STX loan
  u1500000    ;; 1.5 STX collateral (150% ratio)
  u500        ;; 5% interest
  u1440)      ;; 10 days (144 blocks/day)
```

#### Funding a Loan
```clarity
(contract-call? .Microloan-Platform-with-Bitcoin-Collateral fund-loan u1)
```

#### Repaying a Loan
```clarity
(contract-call? .Microloan-Platform-with-Bitcoin-Collateral repay-loan u1)
```

## ⚙️ Configuration

### Constants

- **Minimum Collateral Ratio**: 150%
- **Liquidation Threshold**: 120%
- **Default Platform Fee**: 0.5% (50 basis points)
- **Blocks Per Day**: 144 (approximate)

## 🔒 Security Considerations

- Always verify collateral ratios before creating loans
- Monitor loan expiry to avoid liquidation
- Platform fees are capped at 10%
- Only contract owner can modify fee rates

## 📊 Loan Status Types

- `pending`: Loan request awaiting funding
- `active`: Loan funded and active
- `repaid`: Loan successfully repaid
- `liquidated`: Loan defaulted and collateral seized
- `cancelled`: Loan request cancelled by borrower

## 🛠️ Development

### Testing

Write unit tests in the `tests/` directory:
```bash
npm install
npm test
```

### Deployment

Deploy to testnet:
```bash
clarinet deployments generate --testnet
clarinet deployments apply -p deployments/default.testnet-plan.yaml
```

## 📜 License

MIT License

## 🤝 Contributing

Contributions welcome! Please open an issue or submit a pull request.

---

**⚠️ Disclaimer**: This is experimental software. Use at your own risk. Always audit smart contracts before deploying to mainnet.

