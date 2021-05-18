'use strict';

const express = require('express');


// Constants
const PORT = process.env.PORT || "8082";
const HOST = process.env.HOST || "0.0.0.0";
const VERSION = process.env.VERSION || "2.0.1";

// App
const app = express();
app.get('/', (req, res) => {
  res.send('<h1 align="center">Hello cdCon 2021!</h1>\n\n\n<h3 align="center">Version: '+VERSION+'</h3>');
});

app.listen(PORT, HOST);
console.log('Running on http://%s:%s',HOST,PORT);