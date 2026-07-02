# MoMoSim — Mobile Money Payment Simulator

> A lightweight REST API that simulates mobile money transfers for the African market.

## African Context

Across Africa, mobile money services like MTN MoMo and Airtel Money are the dominant payment rail, serving millions of people who are unbanked or far from physical banks. However, developers and students lack a safe, free environment to model and test how these transactions actually behave. MoMoSim simulates the core logic of a mobile money transfer — validation, debit, credit, and transaction records — without touching real money or telecom infrastructure.

## Team Members

- Olubanjo Kolapo - Repo & Security
- Sydney Wamalwa - Core Transaction Logic
- Adepoju Kolade - Accounts & Data Layer
- Adebayo Seyi - Project Planning / Board
- Ofomi Hephzibah - Documentation & Split-Bill Feature

## Project Overview

MoMoSim is a Node.js/Express REST API that replicates the core behaviour of a mobile money platform. It maintains a set of user accounts with balances and processes payment requests through the same validation rules a real provider would apply — checking that the sender exists, the recipient exists, the amount is valid, and the sender has sufficient funds before executing any transfer.

All transactions are recorded in an in-memory ledger with unique references, giving users a full audit trail of every debit and credit. The system is intentionally simple so that students and developers can read, modify, and test the logic without needing a real payment gateway or database.

The project also includes a split-bill feature, which allows a single payer to divide a total amount equally across multiple recipients in one atomic operation. This mirrors real-world group-payment scenarios common in African social and business contexts — such as splitting a shared bill or distributing a group contribution.

### Target Users
- Developers and students learning how mobile money systems work
- Fintech teams prototyping payment flows before integrating a real provider
- Educators demonstrating transaction logic and edge cases in a classroom setting

### Core Features
- Feature 1: **Account management** — query accounts and balances
- Feature 2: **Send money** — validated, atomic single transfers between accounts
- Feature 3: **Split bill** — divide a total amount equally across multiple recipients in one request
- Feature 4: **Transaction history** — every transfer is logged with a unique reference and timestamp
- Feature 5: **Validation** — rejects insufficient balance, unknown accounts, and invalid amounts before touching any data

## Technology Stack

- **Backend**: Node.js / Express
- **Frontend**: None (REST API only)
- **Database**: In-memory store (plain JavaScript objects and arrays)
- **Other**: CommonJS modules, no external frameworks beyond Express

## Getting Started

### Prerequisites
- Node.js 16+ and npm

### Installation

1. Clone the repository
```bash
git clone https://github.com/kol-apo/Fintech---Formative-1-.git
cd Fintech---Formative-1-
```

2. Install dependencies
```bash
npm install
```

3. Run the application
```bash
node server.js
```

### Running with Docker Compose

1. Make sure [Docker Desktop](https://www.docker.com/products/docker-desktop/) is installed and running

2. Clone the repository (if not already done)
```bash
git clone https://github.com/kol-apo/Fintech---Formative-1-.git
cd Fintech---Formative-1-
```

3. Start the application
```bash
docker compose up
```

The API will be available at `http://localhost:3000`.

To stop the application:
```bash
docker compose down
```

To run in the background (detached mode):
```bash
docker compose up -d
```

### Usage

**Transfer money between two accounts**
```bash
curl -X POST http://localhost:3000/api/transfer \
  -H "Content-Type: application/json" \
  -d '{"from": "user_001", "to": "user_002", "amount": 500}'
```

**Split a bill across multiple recipients**
```bash
curl -X POST http://localhost:3000/api/split \
  -H "Content-Type: application/json" \
  -d '{"from": "user_001", "recipients": ["user_002", "user_003", "user_004"], "totalAmount": 300}'
```

**View all accounts**
```bash
curl http://localhost:3000/api/accounts
```

**View transaction history**
```bash
curl http://localhost:3000/api/transactions
```

## Project Structure

```
Fintech---Formative-1-/
├── data/
│   └── store.js               # In-memory accounts and transactions
├── services/
│   ├── accountService.js      # getAccount, getAllAccounts, adjustBalance
│   └── transactionService.js  # transfer, splitBill
├── routes/
│   └── api.js                 # Express route handlers
├── server.js                  # Entry point
└── package.json
```

## Links

- [Project Board](https://github.com/kol-apo/Fintech---Formative-1-/projects)

## Task Sheets
https://docs.google.com/spreadsheets/d/1vvY5NJ8Aj2NM7L4KviNWLulCJvoscEkdLuV4_2ArjZM/edit?usp=sharing

## License

MIT License
