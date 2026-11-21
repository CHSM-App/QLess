// Where user images live. In production set UPLOADS_DIR to a folder OUTSIDE
// the repo, so a Plesk git pull can never delete or overwrite them (see
// DEPLOY.md §4). Default: backend/uploads.
const path = require('path');

module.exports = process.env.UPLOADS_DIR
  ? path.resolve(process.env.UPLOADS_DIR)
  : path.join(__dirname, '..', 'uploads');
