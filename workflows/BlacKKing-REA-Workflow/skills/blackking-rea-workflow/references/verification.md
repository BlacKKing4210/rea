# BlacKKing REA Workflow: verification and delivery

Use this reference for a verification, reconstruction, or delivery claim. Select
only the checks needed by the user's question. A static investigation does not
require a rebuilt application, a browser session, or a distribution package.
Keep REA's existing Evidence records as the analysis authority; link additional
build, UI, and package receipts to those records rather than creating a competing
interpretation of their facts.

## Close the claim, not merely the command

For each requested conclusion, record the selected input identity, observation
or output, method, coverage, result, and unresolved limits. Use SHA-256 for
artifact identity and retain relevant REA Evidence IDs. Keep observed facts,
derivations, inferences, and unknowns distinct. A missing result under partial
coverage remains unknown.

These are separate evidence dimensions, not an automatic ladder of success:

| Evidence | What it can establish | Boundary to keep explicit |
| --- | --- | --- |
| Container/static inspection | Examined structure, declared metadata, selected references | No execution or complete source recovery |
| Original-member byte comparison | Selected extracted bytes match the selected original members | No semantics, authenticity, or permission inference |
| Actual encoder roundtrip | Fresh encoder output matches the corresponding original representation | Shared-backend limits; no application behavior proof |
| Controlled original-class/function execution | Named inputs and observables in the declared original runtime or exact recovered slices | Dependency doubles, initialization, I/O and caller coverage |
| Original application scenario | Actually performed actions in the selected original build | Only the observed scenario and environment |
| Rebuilt application execution | The rebuilt artifact performs the observed scenario | No universal equivalence to the original |
| HTML/browser execution | Served build identity and real observed browser behavior | Device, browser, input, storage, performance and audio coverage |
| Distribution-byte audit | Selected members and dependency closure match accepted inputs | No startup or player-visible behavior proof |
| Relocated-package execution | Delivered package starts and works within the tested conditions | Other computers and untested entry paths remain unverified |

Do not promote one row into another. Preserve failed attempts and superseded
conclusions with the reason they were withdrawn. A later scoped pass does not
erase an earlier failure or prove all questions complete.

## Preserve original bytes and prove new output origin

Inventory members before extraction. Keep duplicate entry identities, source
locations, original bytes and hashes. Use format-aware checks for selected
payload ranges, sizes, duplicate names, platform path collisions, traversal and
unsupported fields. A legacy checksum can corroborate container integrity;
retain a collision-resistant digest for identity and state the check's limits.

Reading output, recovery backups and automatic-conversion folders may contain
copies of original bytecode. Their equality with the original proves copying,
not re-encoding. For an actual roundtrip or rebuild:

- Select a fresh, bounded output location and preserve existing user output.
- Bind each original member to the reading source, actual encoder/compiler
  input, invoked tool and newly produced output. Account for basename collisions.
- Retain command-reported paths, tool/runtime identity, relevant timestamps,
  input/output digests, exit state and warnings. If exit state or timing was not
  captured, say so; process-launch latency is not build duration.
- Independently compare the actual new bytes. Do not compare an old copy under
  a plausible filename, or infer successful production from an unchanged file.

Reuse matching prior evidence and inspect only changed parts when identity and
coverage remain applicable. A metadata-only member hash manifest can support an
incremental comparison without retaining another complete extraction.

## Warnings, semantics and controlled execution

Keep the baseline decompiler output and warning ledger. A second decompiler is
a candidate reading, not automatic agreement. Review affected methods against
the original representation, including control flow, call targets, assignment
order, local lifetimes and exception handling where the format exposes them.
Accept preferred readings only at the reviewed scope. Compile warnings and
unresolved methods remain visible after a successful compile.

Preserve resource fields, types, ordering and original bytes. A strict generic
parser rejecting a resource does not prove the application rejects it. Locate
the real consumer and version; a bounded test with its expected type and
complete-input/trailing-data controls can establish selected compatibility.
Do not silently repair the original input to obtain a pass.

For controlled probes, identify exact code slices or original classes, selected
runtime/artifact hashes, inputs, expected observable values and types, explicit
dependency doubles, profile/output locations and process ownership. Include a
meaningful negative or boundary control when it tests the claim. Test a repair
with the same failing input and probe before and after. Selected code replay,
an explicit test pack, or a different working directory is not an OS sandbox or
an all-I/O trace.

When inspecting generated JavaScript, distinguish actual emitted functions
executed with controlled dependencies from an application entry point running
in a browser. Record which constructors, queues, parsers or rendering callbacks
were real and which were doubles. Neither a fixture nor a static code review
certifies actual pixels, sound, full gameplay or persistence.

## Independent review

For a claim advertised as independently Agent-reviewed, use a separate reviewer
under the current delegation authorization. Give it the request, raw inputs,
existing Evidence references, a bounded question and a non-conflicting write
scope. Let it inspect actual outputs and challenge provenance and limits; do
not substitute the implementer's summary for its checks.

A reviewer should distinguish its own execution, its own image inspection,
independent byte checks, and observations supplied by another operator. If a
separate Agent is unavailable, continue useful supported checks and label the
independence actually achieved. A second script or a shared-backend roundtrip
must not be reported as a second Agent or independent semantic proof.

## Served-build identity and real UI evidence

Before attributing a browser observation to a new build, read the actual HTTP
response for a representative executable payload and compare its full streamed
digest with the accepted local artifact. A URL, listening port, page title,
no-cache header, successful build or old screenshot does not select the build.
Record endpoint, received bytes, digest and local build identity.
Bind changed resources, localization or configuration to that identity when
they affect the claim; an unchanged bootstrap file alone does not identify the
entire application.

For a local Windows experience launcher, exclusive binding prevents an existing
service and a new server from sharing the intended endpoint. On collision,
fail clearly before opening the browser; preserve the existing user process.
An explicitly selected isolated test port can verify the package separately.
Report that origin and its storage scope. It does not establish successful
startup on the occupied default port, and changing origins may change the
browser save/profile namespace. This local test pattern does not authorize a
persistent service, remote deployment or exposure beyond the approved scope.

Use real target-resolution frames for the important interaction states. Inspect
the saved images themselves: a late capture can show a defeat rather than the
intended action, or credits after the requested names have scrolled away.
Describe what each frame actually shows and identify operator-only observations.
Reuse a prior frame only when its build identity and coverage still apply, and
label that reuse. Never rename an image into evidence of an unseen state.

For actions with confirmation dialogs, verify the final affirmative action and
the resulting state. An open confirmation dialog is not a completed save, quit,
purchase or deletion. Respect any actual tool-enforced confirmation. For
persistence, distinguish checkpoint restoration from mid-action saving; test
the intended reload/restart boundary with the same browser/profile/origin when
that storage model applies. Keep audible fidelity, other devices and complete
content equivalence unverified unless they were actually checked.

## Deliver editable work and audit the real distribution

Keep these roles clear in the chosen project layout; do not duplicate entire
trees just to provide more entry points:

- Immutable originals and case-private evidence.
- Decompiled reading copies and lossless/derived configuration views.
- The authoritative editable reconstruction source and approved resource inputs.
- Derived native/web builds and explicitly requested distribution packages.
- Editable reports in the user's selected format, with source/resource maps,
  actual runtime evidence and residual limits.

Do not make a derived spreadsheet the configuration authority when the real
project uses resources or another approved data format. Do not present imported
texture caches, compiled bytecode or a packed build as the editable source.

For a standalone distribution, independently stream every archive member and
check its digest, CRC where applicable, selected-project closure, required
runtime/dependency manifest, path safety, case collisions and filename encoding.
Use an independently pinned vendor member manifest when claiming a complete
portable runtime. Compare packaged resources with the selected original inputs;
exclude unselected projects and user saves, profiles, credentials, logs, history
and caches. An exact approved closure is stronger than a filename blacklist.

Then test the actual packaged entry from a new directory, including spaces when
relevant, with its own declared runtime. Record default-entry success separately
from an isolated command or alternate browser used for testing. Preserve
explicitly required independent distribution copies; remove only verified,
generated temporary duplicates within the authorized cleanup scope. If cleanup
is rejected or fails, retain them, record the result and stop that action rather
than retrying through a different shell or API.

## Free choices and portable setup boundaries

Use existing free tools and caller-supplied engines supported by the primary
REA Skill. Installing this workflow does not install engines, transfer licenses,
register MCP, migrate accounts or prove tool availability in a running client.
Keep installation ownership, prerequisites and the new computer's environment
explicit. Use parameterized project/runtime/output locations rather than a
previous machine's paths.

Within already authorized work, when a non-paid choice genuinely needs user
input, record the recommended free reversible option, its effect and question
time. Continue independent work. After 15 minutes without an answer, that
recommended option may proceed only within the existing scope; a later answer
controls work not yet performed. Silence never authorizes payment, subscriptions,
paid APIs, recharges, destructive/irreversible actions, account/permission changes,
scope expansion, or bypassing a mandatory tool/setup confirmation. Do not create
new automation, tasks, services or agents merely because a role is named here.

Before a shell network command, follow the host's current proxy configuration:
read its current switch/address and apply or clear overrides only for that
command. Do not enable a proxy, alter VPN state, restore old forced variables or
change authentication as an automatic repair.

Publish only the authorized workflow, generic templates and self-authored test
fixtures. Keep case binaries, recovered code, resources, screenshots, saves,
credentials and sensitive local evidence outside the public tool repository.
Sanitized method summaries must not imply that the originating case achieved
full semantic equivalence or universal compatibility.
