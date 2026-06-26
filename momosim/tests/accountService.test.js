const store = require('../data/store');
const { getAccount, getAllAccounts, adjustBalance } = require('../services/accountService');

beforeEach(() => {
  Object.keys(store.accounts).forEach((k) => delete store.accounts[k]);
  store.accounts['user_001'] = { id: 'user_001', name: 'Alice Mensah', balance: 5000 };
  store.accounts['user_002'] = { id: 'user_002', name: 'Bob Asante', balance: 3000 };
});

describe('getAccount', () => {
  test('returns the account for a known id', () => {
    const account = getAccount('user_001');
    expect(account).toEqual({ id: 'user_001', name: 'Alice Mensah', balance: 5000 });
  });

  test('throws for an unknown id', () => {
    expect(() => getAccount('ghost')).toThrow('Account not found: ghost');
  });
});

describe('getAllAccounts', () => {
  test('returns all accounts as an array', () => {
    const all = getAllAccounts();
    expect(all).toHaveLength(2);
    expect(all.map((a) => a.id)).toEqual(expect.arrayContaining(['user_001', 'user_002']));
  });
});

describe('adjustBalance', () => {
  test('increases balance by a positive amount', () => {
    adjustBalance('user_001', 500);
    expect(store.accounts['user_001'].balance).toBe(5500);
  });

  test('decreases balance by a negative amount', () => {
    adjustBalance('user_001', -1000);
    expect(store.accounts['user_001'].balance).toBe(4000);
  });

  test('returns the updated account', () => {
    const updated = adjustBalance('user_001', 200);
    expect(updated.balance).toBe(5200);
  });

  test('throws when account does not exist', () => {
    expect(() => adjustBalance('ghost', 100)).toThrow('Account not found: ghost');
  });
});
