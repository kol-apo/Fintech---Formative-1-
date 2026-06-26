# MoMoSim — Mobile Money Payment Simulator

*A lightweight simulation of mobile money transfers for the African market.*

## Problem Statement

Across Africa, mobile money services like MTN MoMo and Airtel Money are the
dominant payment rail, serving millions of people who are unbanked or far from
physical banks. However, developers and students lack a safe, free environment
to model and test how these transactions actually behave. MoMoSim simulates the
core logic of a mobile money transfer — validation, debit, credit, and
transaction records — without touching real money or telecom infrastructure.

## Target Users

- Developers and students learning how mobile money systems work
- Fintech teams prototyping payment flows before integrating a real provider
- Educators demonstrating transaction logic and edge cases

## Core Features

1. **User accounts** with balances
2. **Send money** — submit a payment request that is validated and processed
3. **Validation** — rejects insufficient balance, unknown recipients, invalid amounts
4. **Transaction history** — view past transactions with references
5. **Split bill** *(stretch goal)* — split one amount across multiple recipients

## Technology Stack

- **Runtime:** Node.js
- **Framework:** Express
- **Data storage:** [JSON file / SQLite — pick one]
- **Testing:** [Jest / your choice]

## Getting Started

### Prerequisites
- Node.js [version] and npm installed

### Setup
```bash
git clone [your-repo-url]
cd momosim
npm install
npm start
```

The API will run at `http://localhost:[port]`.

### Example: send a payment
```bash
curl -X POST http://localhost:[port]/transactions \
  -H "Content-Type: application/json" \
  -d '{"from": "user1", "to": "user2", "amount": 500}'
```

## Team

| Name | Role |
|------|------|
| Olubanjo Kolpo | Repo & Security |
| Sydney Wamalwa | Core Transaction Logic |
| Adepoju Kolade| Accounts & Data Layer |
| Adebayo Seyi | Project Planning / Board |
| Ofomi Hephzibah | Documentation & Split-Bill Feature |

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file.
