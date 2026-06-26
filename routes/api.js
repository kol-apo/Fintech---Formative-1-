const express = require('express');
const router = express.Router();
const { getAllAccounts, getAccount } = require('../services/accountService');
const { transfer, splitBill } = require('../services/transactionService');
const { transactions } = require('../data/store');

router.get('/accounts', (req, res) => {
  res.json(getAllAccounts());
});

router.get('/accounts/:id', (req, res) => {
  try {
    res.json(getAccount(req.params.id));
  } catch (err) {
    res.status(404).json({ error: err.message });
  }
});

router.post('/transfer', (req, res) => {
  try {
    const { from, to, amount } = req.body;
    if (!from || !to || amount === undefined) {
      return res.status(400).json({ error: 'from, to, and amount are required' });
    }
    const result = transfer({ from, to, amount });
    res.json(result);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

router.post('/split', (req, res) => {
  try {
    const { from, recipients, totalAmount } = req.body;
    if (!from || !recipients || totalAmount === undefined) {
      return res.status(400).json({ error: 'from, recipients, and totalAmount are required' });
    }
    if (!Array.isArray(recipients)) {
      return res.status(400).json({ error: 'recipients must be an array' });
    }
    const result = splitBill({ from, recipients, totalAmount });
    res.json(result);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

router.get('/transactions', (req, res) => {
  res.json(transactions);
});

module.exports = router;
