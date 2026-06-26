// server.js
// Application entry point — wires together middleware and routes, then starts listening.

const express = require('express');
const app = express();

// Parse incoming JSON request bodies
app.use(express.json());

// --- Routes ---
// Dedicated accounts router (list, detail, history)
const accountsRouter = require('./routes/accounts');
app.use('/accounts', accountsRouter);

// --- Start server ---
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`MoMoSim running on port ${PORT}`);
});

module.exports = app; // exported so test suites can import without re-listening
