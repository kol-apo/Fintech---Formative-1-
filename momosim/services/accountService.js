const { accounts } = require('../data/store');

function getAccount(id) {
  const account = accounts[id];
  if (!account) throw new Error(`Account not found: ${id}`);
  return account;
}

function getAllAccounts() {
  return Object.values(accounts);
}

function adjustBalance(id, amount) {
  const account = getAccount(id);
  account.balance += amount;
  return account;
}

module.exports = { getAccount, getAllAccounts, adjustBalance };
