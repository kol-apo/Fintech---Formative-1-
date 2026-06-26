// services/accountService.js
// Account logic layer — pure operations on account state.
// This layer knows nothing about HTTP; it only reads/writes the store.

const { accounts, transactions } = require('../data/store');

/**
 * getAccount(id)
 * Looks up a single account by id.
 * Returns the account object, or null if no account exists with that id.
 */
function getAccount(id) {
  return accounts[id] || null;
}

/**
 * getAllAccounts()
 * Returns every account as a flat array (order not guaranteed).
 */
function getAllAccounts() {
  return Object.values(accounts);
}

/**
 * adjustBalance(id, amount)
 * Adds `amount` to the account's balance.
 *   - Positive amount  → credit (money coming in)
 *   - Negative amount  → debit  (money going out)
 * Throws an Error if the account doesn't exist.
 * Returns the new balance after adjustment.
 *
 * Note: validation (sufficient funds, etc.) belongs in the transaction
 * service — this function only updates state, it does not judge it.
 */
function adjustBalance(id, amount) {
  const account = accounts[id];
  if (!account) {
    throw new Error(`Account not found: ${id}`);
  }
  account.balance += amount;
  return account.balance;
}

/**
 * getHistory(id)
 * Returns all transaction records that involve this account,
 * either as the sender (from) or the recipient (to).
 * Returns an empty array if the account exists but has no history.
 * Returns null if the account doesn't exist at all (lets the route send a 404).
 */
function getHistory(id) {
  if (!accounts[id]) {
    return null;
  }
  return transactions.filter(
    (tx) => tx.from === id || tx.to === id
  );
}

module.exports = { getAccount, getAllAccounts, adjustBalance, getHistory };
