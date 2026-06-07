import { mkdir, writeFile } from "node:fs/promises";
import { execFile } from "node:child_process";
import { promisify } from "node:util";

const run = promisify(execFile);
const commands = [
  ["forge", ["build"]],
  ["forge", ["test"]],
  ["forge", ["test", "--match-contract", "StressRedemptionRun"]],
  ["forge", ["test", "--match-contract", "StressOracleFreeze"]],
  ["forge", ["test", "--match-contract", "StressReserveShock"]],
  ["forge", ["test", "--match-contract", "Invariants"]],
];

const scenarios = [
  "20% redemption run",
  "40% redemption run",
  "oracle freeze",
  "oracle stale plus redemption run",
  "gold sleeve down 15%",
  "CNY sleeve down 10%",
  "EUR sleeve down 10%",
  "BRICK sleeve down 30%",
  "reserve haircut increase",
  "fee buffer depletion",
  "war chest depletion",
  "collateralized mock reserve deposits",
  "MGS non-collateral invariant",
];

const rows = [];
for (const [bin, args] of commands) {
  const label = `${bin} ${args.join(" ")}`;
  try {
    const { stdout, stderr } = await run(bin, args, { cwd: process.cwd(), maxBuffer: 10 * 1024 * 1024 });
    rows.push({ label, status: "PASS", output: `${stdout}${stderr}`.trim() });
  } catch (error) {
    rows.push({ label, status: "FAIL", output: `${error.stdout ?? ""}${error.stderr ?? ""}`.trim() });
  }
}

const failed = rows.some((row) => row.status === "FAIL");
const report = `# M&G5 Stress Report

Generated: ${new Date().toISOString()}

## Command Status

| Command | Status |
| --- | --- |
${rows.map((row) => `| \`${row.label}\` | ${row.status} |`).join("\n")}

## Scenario Coverage

${scenarios.map((scenario) => `- ${scenario}`).join("\n")}

## Notes

- The report validates the local/devnet Solidity MVP only.
- Reserve balances and oracle prices remain mocked.
- Real custody, attestation, bridge, validator and mainnet deployment work remains out of scope.

## Raw Output Summary

${rows
  .map((row) => `### ${row.label}\n\n\`\`\`text\n${row.output.slice(-3000) || "No output"}\n\`\`\``)
  .join("\n\n")}
`;

await mkdir("reports", { recursive: true });
await writeFile("reports/stress-report.md", report);
if (failed) process.exit(1);
console.log("Wrote reports/stress-report.md");
