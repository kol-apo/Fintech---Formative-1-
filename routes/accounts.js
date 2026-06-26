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
  const account = getAccount(req.params.id);
  if (!account) {
    return res.status(404).json({ error: `Account '${req.params.id}' not found` });
  }
  res.json(account);
});

/**
 * GET /accounts/:id/history
 * Returns all transactions involving this account.
 * Responds with 404 if the account doesn't exist.
 */
router.get('/:id/history', (req, res) => {
  const history = getHistory(req.params.id);
  if (history === null) {
    return res.status(404).json({ error: `Account '${req.params.id}' not found` });
  }
  res.json(history);
});

module.exports = router;
