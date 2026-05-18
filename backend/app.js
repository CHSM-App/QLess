const express = require('express');
const app = express();
const cors = require('cors');
const morgan = require('morgan');
const protect = require('./routes/middleware/protect');
app.set('view engine', 'pug');
const axios = require("axios");
// ✅ Middleware FIRST
app.use(morgan('dev'));
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

const patientUsersRouter = require('./routes/patient/users');
const patientInsertRouter = require('./routes/patient/insert');
const patientIndexRouter = require('./routes/patient/index');
const doctorUsersRouter = require('./routes/doctor/users');
const doctorInsertRouter = require('./routes/doctor/insert');
const doctorIndexRouter = require('./routes/doctor/index');
const loginRouter = require('./routes/login');
const path = require("path");
app.use('/doctor/users',doctorUsersRouter);
app.use('/doctor/insert', doctorInsertRouter);
app.use('/doctor/index', doctorIndexRouter);
app.use('/patient/users', patientUsersRouter);
app.use('/patient/insert', patientInsertRouter);
app.use('/patient/index', patientIndexRouter);



app.use('/uploads', express.static(path.join(__dirname, 'uploads')));
app.use('/login', loginRouter);
app.get('/', (req, res) => {
  res.send('Hello World!');
});




const PORT = process.env.PORT || 8000;
app.listen(PORT, function () {
  console.log("Listening on :" + PORT);
});

module.exports = app;
