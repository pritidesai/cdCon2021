'use strict';

const express = require('express');


// Constants
const PORT = process.env.PORT || "8082";
const HOST = process.env.HOST || "0.0.0.0";
const VERSION = process.env.VERSION || "1.0.0";

// App
const app = express();
app.get('/', (req, res) => {
  res.send('<h1 align="center">Hello cdCon 2021!</h1><h3 align="center">\n\n\nVersion: '+VERSION+'</h3>');
});

app.listen(PORT, HOST);
console.log('Running on http://%s:%s',HOST,PORT);