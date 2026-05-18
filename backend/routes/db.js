const express = require('express');
const mssql = require('mssql');
const sqlConfig = {
    user: 'QlessAdmin',      // Replace with your username
    password:  'QLess#321',//'@x8#H8$?hEQJU',   // Replace with your password
    server: 'winsome.grabweb.in' ,        // Replace with your server
    database: 'QLess',
    port:5691,
      // Replace with your database
    options: {
        encrypt: true, // Use this if you're on Windows Azure
        trustServerCertificate: true // Change to true for local dev / self-signed certs
    }
};
const db = mssql.connect(sqlConfig,function(err){
    if(err)
        console.log(err);
    else
    console.log("Success")


});
module.exports = db;