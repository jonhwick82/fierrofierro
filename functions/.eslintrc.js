module.exports = {
  env: {
    es6: true,
    node: true,
  },
  parserOptions: {
    // Permite el uso de características modernas de JavaScript
    "ecmaVersion": 2020,
  },
  extends: [
    "eslint:recommended",
  ],
  rules: {
    "no-restricted-globals": ["error", "name", "length"],
    "prefer-arrow-callback": "error",
    "quotes": ["error", "double", {"allowTemplateLiterals": true}],
    "indent": "off", // Desactiva la regla de indentación estricta
  },
  overrides: [
    {
      files: ["**/*.spec.*"],
      env: {
        mocha: true,
      },
      rules: {},
    },
  ],
  globals: {},
};
