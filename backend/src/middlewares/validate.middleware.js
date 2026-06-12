const { ZodError } = require('zod');
const { fail } = require('../utils/response');

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

  return fail(res, 400, 'Validation failed', { issues });
};

module.exports = { validate };
