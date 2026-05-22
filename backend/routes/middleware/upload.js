const path = require('path');
const fs = require('fs-extra');
const multer = require('multer');

const TEMP_DIR = path.join(__dirname, '..', '..', 'uploads', 'temp');
const MAX_FILE_BYTES = 5 * 1024 * 1024; // 5 MB per file

// Mime allowlist. SVG is intentionally excluded — it's XML and can carry
// inline <script>, which becomes XSS the moment it's served same-origin.
const ALLOWED_MIMES = new Set(['image/jpeg', 'image/png', 'image/webp']);

// Distinguishable from multer's own LIMIT_* errors so the error handler can
// return a 415 instead of a generic 400.
class MulterRejection extends Error {
  constructor(message) {
    super(message);
    this.name = 'MulterRejection';
  }
}

const storage = multer.diskStorage({
  destination: async (req, file, cb) => {
    try {
      await fs.ensureDir(TEMP_DIR);
      cb(null, TEMP_DIR);
    } catch (err) {
      cb(err);
    }
  },
  filename: (req, file, cb) => {
    // Strip anything that isn't a word char, dot, or hyphen — defends against
    // path traversal (../) and shell metacharacters in the saved filename.
    const safe = file.originalname.replace(/[^\w.\-]/g, '_');
    cb(null, `${Date.now()}-${safe}`);
  },
});

function fileFilter(req, file, cb) {
  if (!ALLOWED_MIMES.has(file.mimetype)) {
    return cb(new MulterRejection(`Unsupported file type: ${file.mimetype}`));
  }
  cb(null, true);
}

const upload = multer({
  storage,
  fileFilter,
  limits: {
    fileSize: MAX_FILE_BYTES,
    files: 5, // sanity bound on multi-field uploads
  },
});

// Magic-byte verification. The client-sent mime can lie; reading the first
// bytes off disk is the only way to confirm the file really is what it claims.
// Defends against polyglot files (e.g. PNG header + PHP payload).
async function detectImageMagic(filePath) {
  const fd = await fs.open(filePath, 'r');
  try {
    const buf = Buffer.alloc(12);
    const { bytesRead } = await fd.read(buf, 0, 12, 0);
    if (bytesRead < 12) return null;

    // JPEG: FF D8 FF
    if (buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff) return 'image/jpeg';
    // PNG: 89 50 4E 47 0D 0A 1A 0A
    if (
      buf[0] === 0x89 && buf[1] === 0x50 && buf[2] === 0x4e && buf[3] === 0x47 &&
      buf[4] === 0x0d && buf[5] === 0x0a && buf[6] === 0x1a && buf[7] === 0x0a
    ) return 'image/png';
    // WebP: "RIFF" .. .. .. .. "WEBP"
    if (
      buf[0] === 0x52 && buf[1] === 0x49 && buf[2] === 0x46 && buf[3] === 0x46 &&
      buf[8] === 0x57 && buf[9] === 0x45 && buf[10] === 0x42 && buf[11] === 0x50
    ) return 'image/webp';

    return null;
  } finally {
    await fd.close();
  }
}

function collectFiles(req) {
  const out = [];
  if (req.file) out.push(req.file);
  if (req.files) {
    for (const v of Object.values(req.files)) {
      if (Array.isArray(v)) out.push(...v);
      else out.push(v);
    }
  }
  return out;
}

// Delete whatever multer wrote to disk for this request. Called whenever the
// upload is rejected so /uploads/temp doesn't grow unbounded with rejects.
async function cleanupFiles(req) {
  const files = collectFiles(req);
  await Promise.allSettled(files.map((f) => fs.remove(f.path)));
}

// Wraps a multer middleware so its errors come back as clean JSON instead of
// surfacing in the global 500 handler.
function uploadHandler(multerMiddleware) {
  return (req, res, next) => {
    multerMiddleware(req, res, async (err) => {
      if (!err) return next();
      await cleanupFiles(req).catch(() => {});

      if (err.code === 'LIMIT_FILE_SIZE') {
        return res.status(413).json({
          success: false,
          error: 'File too large. Max 5 MB per file.',
        });
      }
      if (err.code === 'LIMIT_FILE_COUNT' || err.code === 'LIMIT_UNEXPECTED_FILE') {
        return res.status(400).json({
          success: false,
          error: 'Too many files or unexpected field.',
        });
      }
      if (err.name === 'MulterRejection') {
        return res.status(415).json({
          success: false,
          error: err.message,
        });
      }
      return next(err);
    });
  };
}

// Post-upload validator. Confirms each accepted file's bytes match an image
// format we trust. On mismatch, deletes the temp file(s) and 415s; route
// handler must check the return value and stop processing on `false`.
async function verifyImageFiles(req, res) {
  const files = collectFiles(req);
  for (const f of files) {
    const realType = await detectImageMagic(f.path);
    if (!realType) {
      await cleanupFiles(req).catch(() => {});
      res.status(415).json({
        success: false,
        error: `Uploaded file is not a valid image: ${f.originalname}`,
      });
      return false;
    }
  }
  return true;
}

module.exports = {
  upload,
  uploadHandler,
  verifyImageFiles,
  cleanupFiles,
};
