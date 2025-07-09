# 🏠 Real Estate NFT with Ownership History

A Clarity smart contract for tokenizing real estate properties as NFTs with complete ownership history tracking on the Stacks blockchain.

## ✨ Features

- 🏘️ **Property Tokenization**: Convert real estate properties into unique NFTs
- 📋 **Detailed Metadata**: Store property details (address, type, bedrooms, bathrooms, square feet, year built)
- 📚 **Ownership History**: Track complete ownership transfers with timestamps and prices
- 🏪 **Marketplace**: List and buy properties directly through the contract
- 🔒 **Secure Transfers**: Built-in ownership verification and secure transfer mechanisms

## 🚀 Getting Started

### Prerequisites

- [Clarinet](https://docs.hiro.so/clarinet) installed
- Basic understanding of Clarity smart contracts

### Installation

```bash
git clone <repository-url>
cd Real-Estate-NFT-with-Ownership-History
clarinet console
```

## 📖 Usage

### Minting a Property NFT

Only the contract owner can mint new property NFTs:

```clarity
(contract-call? .Real-Estate-NFT-with-Ownership mint-property 
  'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM  ; recipient
  "123 Main St, Anytown, USA"                    ; address
  "Single Family Home"                           ; property-type
  u3                                             ; bedrooms
  u2                                             ; bathrooms
  u1500                                          ; square-feet
  u2020                                          ; year-built
)
```

### Transferring Property

Property owners can transfer their NFTs:

```clarity
(contract-call? .Real-Estate-NFT-with-Ownership transfer-property 
  u1                                             ; token-id
  tx-sender                                      ; current owner
  'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG  ; new owner
)
```

### Listing Property for Sale

```clarity
(contract-call? .Real-Estate-NFT-with-Ownership list-property 
  u1                                             ; token-id
  u100000                                        ; price in microSTX
)
```

### Buying Listed Property

```clarity
(contract-call? .Real-Estate-NFT-with-Ownership buy-property u1)
```

### Viewing Property Data

```clarity
(contract-call? .Real-Estate-NFT-with-Ownership get-property-data u1)
```

### Checking Ownership History

```clarity
(contract-call? .Real-Estate-NFT-with-Ownership get-ownership-history u1 u0)
```

## 🔧 Contract Functions

### Public Functions

- `mint-property`: Create a new property NFT (owner only)
- `transfer-property`: Transfer ownership of a property
- `list-property`: List a property for sale
- `unlist-property`: Remove a property from sale
- `buy-property`: Purchase a listed property

### Read-Only Functions

- `get-last-token-id`: Get the latest minted token ID
- `get-property-data`: Retrieve property metadata
- `get-ownership-history`: Get specific ownership transfer
- `get-transfer-count`: Get total number of transfers for a property
- `get-property-listing`: Get listing information
- `get-owner`: Get current owner of a property
- `get-property-history`: Get complete ownership history

## 🗂️ Data Structures

### Property Data
- Address, property type, bedrooms, bathrooms
- Square footage, year built, creation timestamp

### Ownership History
- Previous and new owners
- Sale price and timestamp
- Transaction hash for verification

### Property Listings
- Seller, price, listing timestamp
- Active status

## 🧪 Testing

Run the test suite:

```bash
clarinet test
```

## 🔐 Security Features

- Owner-only minting restrictions
- Ownership verification for all transfers
- Secure STX payment handling
- Immutable ownership history

## 📝 License

This project is open source and available under the [MIT License](LICENSE).

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
