# Project working agreement

## Design before UI implementation

- The user creates the design first. Treat Figma links, screenshots, design feedback, and feasibility questions as material for discussion, not permission to implement.
- For every new design or design update, follow this sequence:

  1. Inspect the supplied Figma design, screenshot, or other design material read-only before recommending changes.
  2. Share observations, suggestions, and any questions about behavior, appearance, scope, or native macOS constraints.
  3. Discuss the findings with the user and resolve open questions until the intended changes and scope are agreed.
  4. Summarize the agreed implementation scope, explicitly ask whether implementation may begin, and wait for the user's approval.

- Do not change UI code or edit the Figma design during the review and discussion stages. Do not treat sending a design update as permission to implement it, or skip directly from inspection to implementation.
- Get explicit confirmation to implement the agreed scope before making any UI changes, including icon size, typography, colors, spacing, layout, or controls. A clear approval in response to an implementation proposal counts; a positive reaction or a question such as "Can it be 24 × 24?" alone does not.
- After confirmation, implement the approved design using its existing variables, text styles, and original assets. If another visible change is needed, discuss it and obtain approval first.
- Verify the implementation and share a preview or development build for review. Approval to implement does not authorize a public release.

## Meaningful releases with separate confirmation

- Accumulate related improvements into meaningful releases. Do not publish a release for every small update.
- When a release is appropriate, present its proposed scope, version, release notes, and validation results, then wait for explicit confirmation to publish that release.
- Do not create or push a version tag, publish a GitHub release, or upload public release assets before that confirmation. Do not treat earlier implementation approval or the original request for a public repository as release approval.
- Once the user confirms a release, finish its required checks before pushing the approved version tag. The existing GitHub workflow then builds and publishes that release.
- Normal commits, repository synchronization, automated checks, and development artifacts are separate from releases and do not require a new release. Avoid incrementing the app's release version for each small development change.

These instructions govern subsequent work on this project. A later explicit user instruction may change the workflow or approve a specific implementation or release.
