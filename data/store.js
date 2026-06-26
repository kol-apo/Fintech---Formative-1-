// data/store.js
// In-memory data store — the single source of truth for all runtime state.
// No database; objects live in memory and reset on every server restart.

// Accounts are keyed by user id for O(1) lookup.
// Each account has: id (string), name (string), balance (number, in base currency units).
const accounts = {
  user_001: { id: 'user_001', name: 'Amara Diallo',  balance: 12500 },
  user_002: { id: 'user_002', name: 'Kofi Mensah',   balance: 3750  },
  user_003: { id: 'user_003', name: 'Zainab Traoré', balance: 0     }, // zero-balance edge-case seed
};

// All completed transactions are pushed here by the transaction service.
// Each record is expected to carry at least: { id, from, to, amount, timestamp }
const transactions = [];

module.exports = { accounts, transactions };
