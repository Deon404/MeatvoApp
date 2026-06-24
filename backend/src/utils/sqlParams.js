/**
 * Helpers for building parameterized PostgreSQL queries.
 * User-supplied values must only appear in the params array — never in SQL text.
 */

function createParamBinder(initialParams = []) {
  const params = [...initialParams];
  return {
    get params() {
      return params;
    },
    add(value) {
      params.push(value);
      return params.length;
    },
    ph(value) {
      return `$${this.add(value)}`;
    },
    placeholder(index = params.length) {
      return `$${index}`;
    },
  };
}

function joinWhere(fragments) {
  if (!fragments.length) return '';
  return `WHERE ${fragments.join(' AND ')}`;
}

/**
 * Build SET fragments for UPDATE from a whitelist of column names.
 * @param {string[]|Record<string, string>} allowed - column names or { bodyKey: columnName }
 */
function buildUpdateSet(allowed, updates) {
  const sets = [];
  const params = [];
  const isMap = allowed && typeof allowed === 'object' && !Array.isArray(allowed);

  for (const [key, value] of Object.entries(updates || {})) {
    if (value === undefined) continue;
    const column = isMap ? allowed[key] : (Array.isArray(allowed) && allowed.includes(key) ? key : null);
    if (!column) continue;
    params.push(value);
    sets.push(`${column} = $${params.length}`);
  }

  return { sets, params };
}

module.exports = {
  createParamBinder,
  joinWhere,
  buildUpdateSet,
};
