// routes/accounts.js
// HTTP layer for account endpoints.
// Responsibilities: parse the request, call the service, send the response.
// No business logic lives here — delegate everything to accountService.

const express = require('express');
const router = express.Router();
const {
  getAllAccounts,
  getAccount,
  getHistory,
} = require('../services/accountService');

/**
 * GET /accounts
 * Returns a list of all accounts.
 */
router.get('/', (req, res) => {
  res.json(getAllAccounts());
});

/**
 * GET /accounts/:id
 * Returns a single account.
 * Responds with 404 if the account doesn't exist.
 */
router.get('/:id', (req, res) => {
  try {
    res.json(getAccount(req.params.id));
  } catch (err) {
    res.status(404).json({ error: err.message });
  }
});

/**
 * GET /accounts/:id/history
 * Returns all transactions involving this account.
 * Responds with 404 if the account doesn't exist.
 */
router.get('/:id/history', (req, res) => {
  try {
    res.json(getHistory(req.params.id));
  } catch (err) {
    res.status(404).json({ error: err.message });
  }
});

module.exports = router;
