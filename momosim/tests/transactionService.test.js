const store = require('../data/store');
const { transfer, splitBill } = require('../services/transactionService');

beforeEach(() => {
  // Reset accounts to known state
  Object.keys(store.accounts).forEach((k) => delete store.accounts[k]);
  store.accounts['user_001'] = { id: 'user_001', name: 'Alice Mensah', balance: 5000 };
  store.accounts['user_002'] = { id: 'user_002', name: 'Bob Asante', balance: 3000 };
  store.accounts['user_003'] = { id: 'user_003', name: 'Clara Boateng', balance: 2000 };
  store.accounts['user_004'] = { id: 'user_004', name: 'David Osei', balance: 1500 };

  // Clear transaction log
  store.transactions.length = 0;
});

// ─── transfer ─────────────────────────────────────────────────────────────────

describe('transfer', () => {
  test('returns success with a transaction reference', () => {
    const result = transfer({ from: 'user_001', to: 'user_002', amount: 500 });
    expect(result.status).toBe('success');
    expect(result.transactionRef).toMatch(/^TXN-/);
    expect(result.from).toBe('user_001');
    expect(result.to).toBe('user_002');
    expect(result.amount).toBe(500);
  });

  test('debits sender and credits recipient', () => {
    transfer({ from: 'user_001', to: 'user_002', amount: 1000 });
    expect(store.accounts['user_001'].balance).toBe(4000);
    expect(store.accounts['user_002'].balance).toBe(4000);
  });

  test('records the transaction in the log', () => {
    transfer({ from: 'user_001', to: 'user_002', amount: 200 });
    expect(store.transactions).toHaveLength(1);
    expect(store.transactions[0]).toMatchObject({
      from: 'user_001',
      to: 'user_002',
      amount: 200,
    });
    expect(store.transactions[0].timestamp).toBeDefined();
  });

  test('generates unique references across multiple transfers', () => {
    const r1 = transfer({ from: 'user_001', to: 'user_002', amount: 100 });
    const r2 = transfer({ from: 'user_001', to: 'user_002', amount: 100 });
    expect(r1.transactionRef).not.toBe(r2.transactionRef);
  });

  test('allows a transfer equal to the full sender balance', () => {
    const result = transfer({ from: 'user_001', to: 'user_002', amount: 5000 });
    expect(result.status).toBe('success');
    expect(store.accounts['user_001'].balance).toBe(0);
  });

  test('throws when sender has insufficient balance', () => {
    expect(() => transfer({ from: 'user_001', to: 'user_002', amount: 9999 })).toThrow(
      'Insufficient balance'
    );
  });

  test('does not modify balances when sender has insufficient funds', () => {
    try { transfer({ from: 'user_001', to: 'user_002', amount: 9999 }); } catch (_) {}
    expect(store.accounts['user_001'].balance).toBe(5000);
    expect(store.accounts['user_002'].balance).toBe(3000);
  });

  test('throws when amount is zero', () => {
    expect(() => transfer({ from: 'user_001', to: 'user_002', amount: 0 })).toThrow(
      'Amount must be greater than zero'
    );
  });

  test('throws when amount is negative', () => {
    expect(() => transfer({ from: 'user_001', to: 'user_002', amount: -100 })).toThrow(
      'Amount must be greater than zero'
    );
  });

  test('throws when sender does not exist', () => {
    expect(() => transfer({ from: 'ghost_user', to: 'user_002', amount: 100 })).toThrow(
      'Account not found: ghost_user'
    );
  });

  test('throws when recipient does not exist', () => {
    expect(() => transfer({ from: 'user_001', to: 'ghost_user', amount: 100 })).toThrow(
      'Account not found: ghost_user'
    );
  });
});

// ─── splitBill ────────────────────────────────────────────────────────────────

describe('splitBill', () => {
  test('returns success with splits for each recipient', () => {
    const result = splitBill({ from: 'user_001', recipients: ['user_002', 'user_003'], totalAmount: 1000 });
    expect(result.status).toBe('success');
    expect(result.from).toBe('user_001');
    expect(result.totalAmount).toBe(1000);
    expect(result.splits).toHaveLength(2);
  });

  test('divides amount evenly when divisible', () => {
    const result = splitBill({ from: 'user_001', recipients: ['user_002', 'user_003'], totalAmount: 1000 });
    expect(result.splits[0].amount).toBe(500);
    expect(result.splits[1].amount).toBe(500);
  });

  test('distributes remainder to first recipients when not evenly divisible', () => {
    // 100 / 3 = 33 remainder 1 → recipient[0] gets 34, others get 33
    const result = splitBill({ from: 'user_001', recipients: ['user_002', 'user_003', 'user_004'], totalAmount: 100 });
    expect(result.splits[0].amount).toBe(34);
    expect(result.splits[1].amount).toBe(33);
    expect(result.splits[2].amount).toBe(33);
  });

  test('split amounts always sum to totalAmount', () => {
    const result = splitBill({ from: 'user_001', recipients: ['user_002', 'user_003', 'user_004'], totalAmount: 100 });
    const total = result.splits.reduce((sum, s) => sum + s.amount, 0);
    expect(total).toBe(100);
  });

  test('debits sender and credits each recipient correctly', () => {
    splitBill({ from: 'user_001', recipients: ['user_002', 'user_003'], totalAmount: 1000 });
    expect(store.accounts['user_001'].balance).toBe(4000);
    expect(store.accounts['user_002'].balance).toBe(3500);
    expect(store.accounts['user_003'].balance).toBe(2500);
  });

  test('records a transaction per recipient', () => {
    splitBill({ from: 'user_001', recipients: ['user_002', 'user_003'], totalAmount: 1000 });
    expect(store.transactions).toHaveLength(2);
  });

  test('each split has a unique transaction reference', () => {
    const result = splitBill({ from: 'user_001', recipients: ['user_002', 'user_003'], totalAmount: 1000 });
    const refs = result.splits.map((s) => s.transactionRef);
    expect(new Set(refs).size).toBe(refs.length);
  });

  test('works with a single recipient', () => {
    const result = splitBill({ from: 'user_001', recipients: ['user_002'], totalAmount: 500 });
    expect(result.splits).toHaveLength(1);
    expect(result.splits[0].amount).toBe(500);
  });

  test('throws when sender has insufficient balance', () => {
    expect(() =>
      splitBill({ from: 'user_001', recipients: ['user_002', 'user_003'], totalAmount: 9999 })
    ).toThrow('Insufficient balance');
  });

  test('does not modify any balances if sender cannot cover the full amount', () => {
    try { splitBill({ from: 'user_001', recipients: ['user_002', 'user_003'], totalAmount: 9999 }); } catch (_) {}
    expect(store.accounts['user_001'].balance).toBe(5000);
    expect(store.accounts['user_002'].balance).toBe(3000);
    expect(store.accounts['user_003'].balance).toBe(2000);
  });

  test('throws when recipients array is empty', () => {
    expect(() =>
      splitBill({ from: 'user_001', recipients: [], totalAmount: 500 })
    ).toThrow('At least one recipient is required');
  });

  test('throws when totalAmount is zero', () => {
    expect(() =>
      splitBill({ from: 'user_001', recipients: ['user_002'], totalAmount: 0 })
    ).toThrow('totalAmount must be greater than zero');
  });

  test('throws when totalAmount is negative', () => {
    expect(() =>
      splitBill({ from: 'user_001', recipients: ['user_002'], totalAmount: -50 })
    ).toThrow('totalAmount must be greater than zero');
  });

  test('throws when a recipient does not exist (and does not partially execute)', () => {
    expect(() =>
      splitBill({ from: 'user_001', recipients: ['user_002', 'ghost_user'], totalAmount: 500 })
    ).toThrow('Account not found: ghost_user');
    // Balances must be untouched — validation is all-or-nothing
    expect(store.accounts['user_001'].balance).toBe(5000);
    expect(store.accounts['user_002'].balance).toBe(3000);
  });

  test('throws when sender does not exist', () => {
    expect(() =>
      splitBill({ from: 'ghost_user', recipients: ['user_002'], totalAmount: 500 })
    ).toThrow('Account not found: ghost_user');
  });
});
