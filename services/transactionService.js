const { transactions } = require('../data/store');
const { getAccount, adjustBalance } = require('./accountService');

function generateRef() {
  return 'TXN-' + Date.now() + '-' + Math.random().toString(36).slice(2, 7).toUpperCase();
}

function transfer({ from, to, amount }) {
  // Validate sender and recipient exist
  const sender = getAccount(from);
  getAccount(to);

  if (amount <= 0) throw new Error('Amount must be greater than zero');
  if (sender.balance < amount) throw new Error('Insufficient balance');

  adjustBalance(from, -amount);
  adjustBalance(to, amount);

  const transactionRef = generateRef();
  transactions.push({ transactionRef, from, to, amount, timestamp: new Date().toISOString() });

  return { status: 'success', transactionRef, from, to, amount };
}

function splitBill({ from, recipients, totalAmount }) {
  // --- Validation (all-or-nothing: check everything before touching balances) ---

  if (!recipients || recipients.length === 0) {
    throw new Error('At least one recipient is required');
  }
  if (totalAmount <= 0) {
    throw new Error('totalAmount must be greater than zero');
  }

  // Confirm sender exists and has enough for the full total
  const sender = getAccount(from);
  if (sender.balance < totalAmount) {
    throw new Error('Insufficient balance for the full split');
  }

  // Confirm every recipient exists before moving any money
  recipients.forEach((id) => getAccount(id));

  // --- Split calculation with remainder distribution ---
  // Divide totalAmount into equal integer-like shares. The base share is
  // Math.floor(totalAmount / n). The remainder (totalAmount % n) is distributed
  // one extra unit to the first `remainder` recipients, so all shares sum to
  // exactly totalAmount with no floating-point drift.
  const n = recipients.length;
  const base = Math.floor(totalAmount / n);
  const remainder = totalAmount % n;

  // --- Execute transfers ---
  const splits = recipients.map((to, index) => {
    const amount = index < remainder ? base + 1 : base;
    adjustBalance(from, -amount);
    adjustBalance(to, amount);

    const transactionRef = generateRef();
    transactions.push({ transactionRef, from, to, amount, timestamp: new Date().toISOString() });

    return { to, amount, transactionRef };
  });

  return { status: 'success', from, totalAmount, splits };
}

module.exports = { transfer, splitBill };
