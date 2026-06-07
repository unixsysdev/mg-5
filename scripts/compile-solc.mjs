import fs from "fs";
import path from "path";
import solc from "solc";

const root = process.cwd();
const roots = ["src", "script", "test", "lib/forge-std/src"];
const sources = {};

function walk(dir) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full);
    if (entry.isFile() && entry.name.endsWith(".sol")) {
      sources[path.relative(root, full)] = { content: fs.readFileSync(full, "utf8") };
    }
  }
}

for (const dir of roots) {
  const full = path.join(root, dir);
  if (fs.existsSync(full)) walk(full);
}

function findImport(importPath) {
  const candidates = [
    path.join(root, importPath),
    path.join(root, "node_modules", importPath),
    path.join(root, "lib", importPath.replace(/^forge-std\//, "forge-std/src/")),
  ];
  for (const candidate of candidates) {
    if (fs.existsSync(candidate)) return { contents: fs.readFileSync(candidate, "utf8") };
  }
  return { error: `File not found: ${importPath}` };
}

const input = {
  language: "Solidity",
  sources,
  settings: {
    optimizer: { enabled: true, runs: 200 },
    outputSelection: { "*": { "*": ["abi", "evm.bytecode.object"] } },
  },
};

const output = JSON.parse(solc.compile(JSON.stringify(input), { import: findImport }));
const errors = output.errors ?? [];
for (const error of errors) {
  console.log(error.formattedMessage.trim());
}
const fatal = errors.filter((error) => error.severity === "error");
if (fatal.length) process.exit(1);
console.log(`Compiled ${Object.keys(output.contracts ?? {}).length} Solidity source files.`);
