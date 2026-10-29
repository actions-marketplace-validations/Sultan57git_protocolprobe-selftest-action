# ProtocolProbe self-test (GitHub Action)

Runs [`protocolprobe-selftest`](https://www.npmjs.com/package/protocolprobe-selftest) against **your own MCP server**
in your CI: the workflow starts your server over stdio from your repository, the checks run inside your runner, and
the results stay in your workflow (log, optional JSON report, optional SARIF for GitHub code scanning). Nothing is sent
to ProtocolProbe.

Use it only on a server you own or are authorised to test. The action passes `--i-own-this-server`: adding it to your
workflow is that statement.

## Usage

```yaml
name: MCP self-test
on: [push, pull_request]

permissions:
  contents: read
  security-events: write   # only needed for the SARIF upload step

jobs:
  selftest:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - uses: actions/setup-node@949feb2413d6458794dcd2491c4babbbce0c15c1 # v7.1.0
        with:
          node-version: 22
      - run: npm ci && npm run build

      - uses: Sultan57git/protocolprobe-selftest-action@v1
        with:
          command: node ./dist/server.js
          sarif-anchor: src/server.ts

      - uses: github/codeql-action/upload-sarif@9b3254085494b55a0f7c4c2b3d2d52cc712ce370 # v4.39.1
        # upload also when the self-test step failed because of a finding, but only if a SARIF file was written
        if: always() && hashFiles('protocolprobe-selftest.sarif') != ''
        with:
          sarif_file: protocolprobe-selftest.sarif
          category: protocolprobe-selftest
```

Python server (needs [uv](https://docs.astral.sh/uv/) on the runner):

```yaml
      - uses: Sultan57git/protocolprobe-selftest-action@v1
        with:
          command: uv run --directory . server.py
```

## Inputs

| input | default | meaning |
|---|---|---|
| `command` | (required) | Command line that starts your MCP server over stdio. Split on spaces; quoting is not supported, so put a complex command in a script file. |
| `version` | `0.5.0` | Exact `protocolprobe-selftest` version from npm, 0.4.0 or later (earlier versions lack `--fail-on-finding` and `--sarif`). Ranges and tags are refused. |
| `fail-on-finding` | `true` | Fail the step (exit 5) when a check needs attention (`VULNERABLE` or `FOUND`). |
| `sarif` | `protocolprobe-selftest.sarif` | SARIF 2.1.0 file to write. Empty to skip. |
| `sarif-anchor` | | File the SARIF results point at (line 1). Default: the first file of `command` inside the working directory. Set it when that file is build output (for example `dist/`) that is not in the repository. |
| `out` | | JSON report to write. Empty to skip. |
| `allow-mutating` | `false` | Also run the check that calls tools which may change data. Only on a disposable test server. |
| `allow-fuzzing` | `false` | Also run the check that sends malformed input to your tools. |
| `working-directory` | `.` | Folder to run in; paths in the other inputs are relative to it. |

Outputs: `exit-code` (0 result printed, 1 could not start or connect, 2 refused arguments, 5 finding with
`fail-on-finding`) and `sarif-file`.

## What it does and does not do

- Starts the command you give, connects as an MCP client and runs the checks described in the
  [package README](https://www.npmjs.com/package/protocolprobe-selftest). Checks that call tools which may change data,
  or that send malformed input, are off unless you turn them on.
- Stdio servers only. The package's `--url` mode needs a one-time proof added to the server's instructions; it is not
  offered here.
- The score counts only checks that ran; a check that did not run says nothing about that behaviour. A clean result is
  not a certificate of safety.
- Network: the only outbound traffic is the npm download of the package, plus whatever your own server does. Your
  server is started with a minimal environment, so the runner's secrets are not passed to it.
- Inputs reach the script only as environment variables and are validated; the command is never run through a shell
  string or `eval`.

## Versioning

`v1` moves to the newest `v1.x.y` release; `v1.x.y` tags never move. To pin exactly, use the commit SHA:
`uses: Sultan57git/protocolprobe-selftest-action@<full commit SHA> # v1.0.0`.

## Security

Report a problem with this action to hello@protocolprobe.com (see SECURITY.md).

## Licence

ISC. ProtocolProbe: https://protocolprobe.com
