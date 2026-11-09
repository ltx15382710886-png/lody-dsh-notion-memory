# Findings: how DSH gets instructions inside Lody

All findings below were verified on one machine: Lody 0.110.1, bundled DeepSeek Harness 0.2.1-rc.2, macOS 27.0.1 arm64. Claims marked **(verified)** were reproduced end to end; claims marked **(mechanism only)** were established by reading the shipped packages and their READMEs but not exercised.

## Channel matrix

| Channel | Status | Notes |
|---|---|---|
| `$DSH_HOME/AGENTS.md` | **works (verified)** | Injected as a user-role `<system-reminder>`, not a system prompt |
| Agent Role `promptPrefix` | works, explicit opt-in | Must select the Role per session; cannot change tool composition |
| profile-level plugin with `ctx.systemPrompt.section()` | **mechanism only** | Does not pass through the `agent_preset` whitelist |
| custom preset / `dsh-persona` prefix | **blocked (verified)** | Rejected client-side by Lody before reaching DSH |
| Lody server-side custom instructions for DSH | not available | The ACP `createSession` path has no instructions input |

## 1. `AGENTS.md` is the working channel

`@deepseek-ai/dsh-agent-instructions` is a preset-mounted row. Lody's generated profile patch disables the base-wide instance:

```yaml
- id: agent-instructions
  disabled: true
```

That disables only the **base global** row. Lody's own preset files re-mount it inside the agent scope, so it stays active for Standard, PTC, and Creator sessions. `minimal` does not mount it and sets `complete: true`, so it is out of scope.

Load order, broad to specific:

1. `$DSH_HOME/AGENTS.md`
2. `$DSH_AGENTS_HOME/AGENTS.md` (defaults to `~/.agents/AGENTS.md`)
3. From the project root down to the session cwd: `AGENTS.md`, `CLAUDE.md`, `AGENTS.local.md`, `CLAUDE.local.md`

Details that matter:

- The project root is found by probing for `.git`; otherwise the cwd is the root.
- The user-global layer reads only `AGENTS.md`, never a global `CLAUDE.md` or `.local` overlay.
- The rendered baseline is capped at 65,536 bytes. Broader files are omitted before the most specific file is truncated, so keep the global policy short.
- Files are loaded for the first request. There is no watcher; new sessions see edits, existing sessions keep their baseline.

The sharp edge: the content arrives as a **user-role `<system-reminder>`** with guidance-level wording ("may be relevant … use them as guidance when applicable"). A model can load the file and still ignore it. That is why the acceptance test asks a fresh session a bare "hello" and checks the tool trace rather than trusting a verbal claim.

## 2. Custom presets are blocked (verified)

DSH supports user presets. The ACP adapter is configured with:

```
userPresetRoot: dshHomePath('.agent-presets')
```

and scans that directory, skipping the four reserved names, loading each folder's `preset.yml` and `agent.cordis.yml`, then registering it through `ctx.agentPresets.register()`.

Lody validates the choice against a static list before sending it:

```js
const DEEPSEEK_HARNESS_AGENT_PRESETS = [
  { value: "standard", ... },
  { value: "ptc", ... },
  { value: "minimal", ... },
  { value: "cordis", ... }
];
```

Reproduction: create a valid user preset directory, then ask for it.

```
Invalid value for config option "agent_preset": notion-memory.
Allowed values: standard, ptc, minimal, cordis.
```

A control session created with the default `standard` preset and asked whether a probe string from the custom preset appeared answered **not present**, confirming the custom preset never mounted.

## 3. Other channels

**Agent Role `promptPrefix`** is a supported Lody feature. It injects instructions per session, but only for sessions that explicitly select the Role, and it cannot add or remove tools.

**`ctx.systemPrompt.section()`** is a real DSH API and would produce a genuine system prompt section rather than a user-role reminder. It is reachable from a profile-level plugin registered in `profiles/<name>/cordis.patch.yml` and is independent of the preset whitelist. Not exercised here.

A note on Grok for comparison: on the same machine the Grok runtime had native memory enabled in settings, yet its memory index files contained no recorded topics. The working memory in that setup was entirely the Notion MCP path, which is why this guide targets Notion rather than a native store.

## Acceptance results

| Check | Expected | Observed |
|---|---|---|
| Fresh session, first message `你好` | `read_mcp_resource` then `notion-fetch` before answering | 2/2 sessions, exact arguments |
| Save a durable preference | one page in the Memories data source, `Type: Preference`, topic title | yes, with date mention and rationale |
| Repeat the same request in a second session | no duplicate page | 0 create calls, 0 update calls |
| Ask to save `package.json` contents | refusal citing the policy | refused, cited the saved memory, wrote nothing |

## Caveats

- Tool-call evidence lives in the runtime's session artifact (`session.v4.jsonl.zstd`), not in the Lody transcript API. `verify.sh` decodes it.
- One observed model quirk: a `create-pages` call occasionally emits stray format markers in its argument payload, fails, and then retries successfully. The end result was correct; treat an isolated failed tool call as expected noise, not a policy failure.
- Exposing user presets is the upstream fix that would make the stronger `dsh-persona` route available. See `upstream/feature-request-agent-preset.md`.
