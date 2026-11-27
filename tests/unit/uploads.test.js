const path = require('path');

// S6: images can live outside the repo (Plesk git pull must never touch them).
test('UPLOADS_DIR wins; default is backend/uploads', () => {
  const saved = process.env.UPLOADS_DIR;
  try {
    delete process.env.UPLOADS_DIR;
    jest.isolateModules(() => {
      expect(require('../../src/uploads')).toBe(path.join(__dirname, '..', '..', 'uploads'));
    });
    process.env.UPLOADS_DIR = path.join('C:', 'srv', 'qless-uploads');
    jest.isolateModules(() => {
      expect(require('../../src/uploads')).toBe(path.resolve('C:/srv/qless-uploads'));
    });
  } finally {
    if (saved === undefined) delete process.env.UPLOADS_DIR; else process.env.UPLOADS_DIR = saved;
  }
});
