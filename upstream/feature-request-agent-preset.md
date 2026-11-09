# Feature request draft

Form: `02-feature-request.yml` in `LodyAI/Lody`
Title prefix required: `[Feature Request] `

---

## Affected area

Agent runtime / ACP

## Problem or workflow pressure

The `agent_preset` config option only accepts four hard-coded values: `standard`, `ptc`, `minimal`, `cordis`.

The bundled DeepSeek Harness runtime supports user-registered presets. The ACP adapter is constructed with

```
userPresetRoot: dshHomePath('.agent-presets')
```

and its startup routine scans that directory, skips the four reserved names, reads each folder's `preset.yml` and `agent.cordis.yml`, and registers the result through `ctx.agentPresets.register()`. Because Lody validates the requested preset against the static list on the client side, a valid user preset never reaches the runtime.

Reproduction:

1. Create `$DSH_HOME/.agent-presets/notion-memory/` containing a valid `preset.yml` and a minimal `agent.cordis.yml` that mounts `@deepseek-ai/dsh-persona` with a custom `prefix`.
2. Create a DeepSeek Harness session with `configOptionValues: {"agent_preset": "notion-memory"}`.

Observed:

```
Invalid value for config option "agent_preset": notion-memory.
Allowed values: standard, ptc, minimal, cordis.
```

A control session created with `standard` and asked whether a probe string from the custom preset appeared in its prompt answered that it did not, confirming the custom preset never mounted.

This blocks a documented DSH capability and forces users toward weaker injection channels.

## Desired outcome

A preset directory placed under `$DSH_HOME/.agent-presets/<name>/` appears in the Agent preset picker and can be selected for a new session, so a user can compose their own tool and prompt set without waiting for a bundled preset.

This is most useful for prompt-only presets such as one that mounts `dsh-persona` with a custom prefix, which would give a real system prompt instead of the user-role `<system-reminder>` that `$DSH_HOME/AGENTS.md` produces.

## Proposed solution

Build the `agent_preset` option list from the roster the runtime reports — for example `ctx.agentPresets.list()`, or the `configOptions` the ACP session advertises — and fall back to the current static list when the runtime reports no roster.

If the four built-in presets should remain the only supported surface, an explicit opt-in (an advanced toggle or a separate config option) would keep default behavior unchanged.

## Alternatives or workarounds

- `$DSH_HOME/AGENTS.md` works today. It is injected as a user-role `<system-reminder>` with guidance-level wording rather than as a system prompt, so adherence is weaker and depends on the model.
- Agent Roles with `promptPrefix` work, but require selecting the Role for every session and cannot change tool composition.
- A profile-level plugin calling `ctx.systemPrompt.section()` can inject a real system prompt. This is heavier than a preset and requires editing `profiles/<name>/cordis.patch.yml`.

## Trade-offs or non-goals

- User presets are arbitrary plugin compositions. Exposing them may widen the support surface and the range of failure modes.
- Preset identity is persisted in session headers. A preset removed later must degrade gracefully rather than fail session resume; the runtime already errors with "persisted agent preset is unavailable", so the client needs a matching fallback.
- This request is about the open-source CLI and ACP runtime only, not about hosted services or billing.

## Additional context

Environment:

- Lody 0.110.1
- Bundled DeepSeek Harness 0.2.1-rc.2
- macOS 27.0.1, arm64

Supporting observation: Lody's generated profile patch contains

```yaml
- id: agent-instructions
  disabled: true
```

This disables only the base-wide `@deepseek-ai/dsh-agent-instructions` row. The bundled `standard`, `ptc`, and `cordis` presets re-mount it inside the agent scope, which is why workspace instruction files still load in those presets and not in `minimal`.

A reproducible guide for the working `AGENTS.md` channel, its load order and byte budget, and the acceptance checks used above: https://github.com/ltx15382710886-png/lody-dsh-notion-memory

## Before submitting

- [x] I searched the existing issues and did not find a duplicate request.
- [x] This request concerns an open-source component in this repository, not a hosted service, Web or mobile app, account, or billing issue.
- [x] I removed credentials, private source, conversations, prompts, personal data, and other sensitive information.
