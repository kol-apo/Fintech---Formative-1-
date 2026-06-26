const express = require('express');
const app = express();

app.use(express.json());

const apiRouter = require('./routes/api');
app.use('/api', apiRouter);

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`MoMoSim running on port ${PORT}`);
});

module.exports = app;
