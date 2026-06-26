const { accounts, transactions } = require("../data/store");

/**
 * Returns the account for the given id.
 * Throws if the account does not exist — callers (transfer, splitBill)
 * rely on this so that an invalid id is rejected during validation,
 * before any balances are touched.
 */
function getAccount(id) {
  const account = accounts[id];
  if (!account) throw new Error(`Account not found: ${id}`);
  return account;
}

/**
 * Non-throwing existence check, for when we want to test whether an
 * account exists without raising an error.
 */
function accountExists(id) {
  return Boolean(accounts[id]);
}

/**
 * Returns an array of all accounts.
 */
function getAllAccounts() {
  return Object.values(accounts);
}

/**
 * Adjusts an account's balance: positive `amount` credits, negative debits.
 * Throws (via getAccount) if the account does not exist.
 * Returns the updated account object.
 */
function adjustBalance(id, amount) {
  const account = getAccount(id);
  account.balance += amount;
  return account;
}

/**
 * Returns all transactions involving this account, as sender or recipient.
 * Throws if the account does not exist.
 */
function getHistory(id) {
  getAccount(id); // validate the account exists (throws if not)
  return transactions.filter((txn) => txn.from === id || txn.to === id);
}

module.exports = {
  getAccount,
  accountExists,
  getAllAccounts,
  adjustBalance,
  getHistory,
};
