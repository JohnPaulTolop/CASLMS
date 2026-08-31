module.exports = {
  root: true,

  env: {
    es6: true,
    node: true,
  },

  extends: [
    "eslint:recommended",
    "plugin:import/errors",
    "plugin:import/warnings",
    "plugin:import/typescript",
    "google",
    "plugin:@typescript-eslint/recommended",
  ],

  parser: "@typescript-eslint/parser",

  parserOptions: {
    project: [
      "tsconfig.json",
      "tsconfig.dev.json",
    ],
    sourceType: "module",

    // Makes ESLint resolve the TypeScript configs
    // from the functions folder instead of C:\caslms-main.
    tsconfigRootDir: __dirname,
  },

  ignorePatterns: [
    "/lib/**/*", // Ignore built files.
    "/generated/**/*", // Ignore generated files.
  ],

  plugins: [
    "@typescript-eslint",
    "import",
  ],

  rules: {
    "quotes": ["error", "double"],
    "import/no-unresolved": 0,
    "indent": ["error", 2],
  },
};
