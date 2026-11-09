# BlacKKing REA Workflow: target routing

This reference selects a route; it adds no parser, provider or execution
capability. Use the existing `reverse-engineer-anything` Skill as the primary
REA tool contract and read only its relevant guide. The connected server's
advertised tools and canonical schemas decide availability. A newer Skill or
an installed engine does not prove the running client has that capability.
The routes below delegate existing REA contracts; this workflow's verification
methods do not constitute new real-provider acceptance for every listed format.

Start from the user's actual artifact and question. Resolve ambiguous identity
before choosing a target; unrelated examples and historical paths do not select
one. For a complete development-source repository and an ordinary architecture
question, use normal repository tools without REA readiness/setup. For shipped
JavaScript, bytecode, packaged/native code or requested runtime evidence, use the
matching REA route. Reuse the current matching session and retained Evidence.

| Observed target | First route | Required boundary |
| --- | --- | --- |
| Godot exported pack | Archive inventory/selected extraction, then the primary Skill's Godot guide | The pack reader does not decompile scripts. A separately selected GDRE backend produces reading copies. Preserve actual runtime identity and fresh encoder-output provenance. |
| JVM application archive | Archive inventory/selected extraction, then the primary Skill's JVM guide | Keep application classes, libraries, resources, duplicate members and synthetic/nested mappings separate. Reading/compile/bytecode/runtime checks have distinct scope. |
| Managed PE/CLI assembly | `inspect_managed_artifact`, then focused advertised managed inspection | Canonical metadata inspection does not load or execute the assembly. Any reconstruction oracle or runtime probe is separately selected. |
| Native executable/library | `open_binary` with the chosen supported provider when active-target analysis is needed; use an advertised target-free inspector for a specific static question | Pseudocode and call graphs are static interpretations. Runtime instrumentation, attachment and mutation have their own contracts and authorization. |
| Electron ASAR or shipped/extracted JavaScript tree | `analyze_javascript_application`, then focused module/feature tracing | An ASAR/native launcher wrapper is not the application logic. Static graphs do not demonstrate actual browser/Electron behavior. |
| Mixed archive or unknown packaged application | `open_binary` and archive inventory; select the relevant contained payload before routing it | Do not deep-analyze only a native bootloader when the requested feature lives in a managed or JavaScript payload. Preserve exact contained-image identity. |

For large or unknown inventories, begin with a supported summary and page the
retained Evidence. Do not rerun an unchanged producer merely because the client
truncated its preview. Use the primary Skill's native/artifacts, JavaScript,
runtime-observation and Evidence guides as appropriate; exact tool names above
must still be advertised by the actual server before use.

## Important routing decisions

- Detect format and metadata from the supplied bytes. A filename suffix alone
  does not establish native, managed, framework or engine identity.
- .NET NativeAOT without recoverable CIL follows the native route. Do not promise
  original C# or send it through a CIL decompiler as if method bodies were present.
- A pack's engine-version field is a declaration. Verify the selected executable
  before claiming a matching engine. Preserve an existing target engine/version;
  a general game-engine preference does not authorize migration.
- Original container inspection, separately selected decompilers and a requested
  reconstruction are different operations. Read [verification](verification.md)
  when making a verification or delivery claim.
- Choose runtime observation only for a question that requires it and whose
  declared launch/attach/input/output/lifecycle are authorized and supported.
  Static inspection may still answer useful parts when runtime is unavailable.

## Bring-your-own engines and selected installation ownership

Prefer an available free backend that answers the selected question. Ghidra and
other engine routes use the caller's existing compatible installation; the
workflow does not install or upgrade engines or unrelated prerequisites. If a
caller already supplies an appropriately licensed configured proprietary
provider, its supported read-only route may be used within the request. Do not
purchase, subscribe, recharge or switch to a paid API to resolve a missing engine.
The free-choice waiting rule in [verification](verification.md) never supplies
payment or setup approval.

When the user selects a fork or source checkout, preserve that installation as
the owner. Resolve CLI/runtime and registration from its actual setup, record the
revision and local changes, and refresh the same owner's installation when
authorized. Do not replace it with an upstream package-runner fallback. A healthy
CLI, registered MCP server, installed Skill and tools discovered by this client
are separate observations.

Use the primary Skill's connection/recovery guide for an observed missing or
stale registration. Do not run setup before each normal investigation or create
a competing registration. A setup plan and its actual required approval remain
in force, even after a non-paid recommendation timeout. On another computer,
resolve local prerequisites and ownership anew without copying authentication,
provider sessions, case artifacts or a previous machine's absolute paths.
