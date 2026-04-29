const { ZodError } = require('zod');

const validate = (schema) => (req, res, next) => {
  const result = schema.safeParse({
    body: req.body,
    params: req.params,
    query: req.query,
  });

  if (result.success) {
    req.validated = result.data;
    return next();
  }

  const issues =
    result.error instanceof ZodError
      ? result.error.issues.map((i) => ({ path: i.path.join('.'), message: i.message }))
      : [{ path: '', message: 'Invalid request' }];

  return res.status(400).json({
    ok: false,
    success: false,
    error: { message: 'Validation failed' },
    data: { issues },
    message: 'Validation failed',
  });
};

module.exports = { validate };
