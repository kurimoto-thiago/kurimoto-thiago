const express = require('express');
const events = require('./events');
const alerts = require('./alerts');
const tenants = require('./tenants');
const auth = require('./auth');

const router = express.Router();

router.use('/auth', auth);
router.use('/events', events);
router.use('/alerts', alerts);
router.use('/tenants', tenants);

module.exports = router;
