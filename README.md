# lody-dsh-notion-memory

Give the **DeepSeek Harness** runtime inside **Lody** automatic Notion memory: read the user's Notion Memories at the start of every new session, and write durable preferences back with the official Notion memory conventions.

Verified on Lody 0.110.1 with bundled DSH 0.2.1-rc.2 (macOS arm64).

## Result

One file, no core changes, no plugin install, no `pnpm install`:

```
$DSH_HOME/AGENTS.md
```

New DSH sessions in this Lody provider load it automatically. Verified end to end:

- 2/2 fresh sessions called `read_mcp_resource` (`notion://docs/memory`) and `notion-fetch` (`id="memory"`) **before** answering a bare "hello".
- A save request created exactly one page in the Memories data source with `Type: Preference`, and a repeat request in a second session created nothing.
- A request to save `package.json` contents was refused, citing the saved policy.

## Why not a preset or a custom persona

DSH supports user presets (`$DSH_HOME/.agent-presets/`), and `dsh-persona` can replace the system prompt prefix. Lody 0.110.1 rejects any `agent_preset` outside its four built-in values before the request reaches the runtime, so that path is closed today. See [FINDINGS.md](FINDINGS.md) and [upstream/feature-request-agent-preset.md](upstream/feature-request-agent-preset.md).

`AGENTS.md` is the channel that works.

## Install

Copy the template and fill in your own preferences:

```bash
DSH_HOME="$HOME/.lody/dsh/providers/<provider-id>"

cp AGENTS.md.template "$DSH_HOME/AGENTS.md"
chmod 600 "$DSH_HOME/AGENTS.md"
```

Edit the template first: replace `<user-name>` and the preference bullets with your own. The template intentionally ships without anyone's personal preferences.

No restart is required for new sessions. Existing sessions keep the instruction baseline they started with.

## Verify

```bash
./verify.sh "$DSH_HOME"
```

The script locates the newest DSH session artifact, decompresses it, and prints the tool-call sequence so you can confirm the two recall calls happened before the first answer.

Manual acceptance:

1. Create a new DSH session and send only `你好` / `hello`.
2. Confirm the transcript's tool trace shows `notion://docs/memory` then `fetch id="memory"` before the reply.
3. Ask a preference question (for example, how you like reports formatted) and confirm a `memory-search` call plus a cited Notion link.

If step 2 fails, the instructions loaded but the model did not follow them. Escalate to a real system-prompt injection; do not keep adding user reminders.

## Rollback

```bash
rm "$DSH_HOME/AGENTS.md"
```

New sessions revert immediately. Notion pages already written are unaffected.

## Scope and safety

- Affects only this DSH provider's Standard / PTC / Creator sessions. Grok sessions are untouched.
- Never modifies `node_modules`, `pstack-dsh`, or the generated `@lody/dsh-host-*` package.
- Requires no `pnpm install`, so local patches survive.
- The policy tells the agent to skip repository and configuration facts, secrets, and temporary progress.

## Files

| Path | Purpose |
|---|---|
| `AGENTS.md.template` | The memory policy, with placeholders |
| `FINDINGS.md` | How each injection channel behaves, with evidence |
| `verify.sh` | Decode a DSH session artifact and list tool calls |
| `upstream/feature-request-agent-preset.md` | Draft Issue for the preset limitation |

## License

MIT. See [LICENSE](LICENSE).
