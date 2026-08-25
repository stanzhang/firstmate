# fm-consult-openai-api terminal custody handoff

Date: 2026-08-25

## Disposition

This unfinished FirstMate-specific consultation implementation is superseded by the
Queen Anne and Codex control-plane migration. Do not resume, deliver, merge, or open an
upstream pull request from this branch without a new owner decision.

The replacement capability is tracked in
`stanzhang/queen-annes-revenge#2`. It does not depend on this implementation.

## Recoverable custody

- Branch: `fm/fm-consult-openai-api`
- Preserved implementation commit: `ecf93e190f874f7f0e7ec5ecd5be9b5076f85c1c`
- Parent: `038d0f7ec6ba7238a151722931434dcf06ff37c4`
- Cancelled no-mistakes run: `01M0VWVM9QPNZ2S5EYZ2C0CT1J`
- Cancelled run's recorded pipeline head: `68dcc11c10c7f6bdf2bb04510684cd55f7ceff93`

The recorded pipeline head was not available in the invoking worktree or local gate
after cancellation, so it is not claimed as a recoverable ref. The branch commit above
is the recoverable implementation boundary. Historical no-mistakes logs remain the
receipt for the cancelled review.

## Unresolved review findings

The cancelled review identified these unresolved behaviors:

- resume examines only the latest receipt and can block a recoverable earlier attempt;
- model-identity fallback can record an unrelated header button label;
- the immutable envelope delimiter is not rejected inside source material;
- dispatch can reuse an unrelated open ChatGPT conversation;
- adapter detail codes can be overwritten or omitted;
- interrupted dispatch claims have no documented recovery path.

Treat the implementation as not validated and not safe for consultation delivery.

## Authority

This handoff preserves code custody only. It grants no research, merge, sizing,
execution, trading, or order authority. Historical receipts are immutable; append a new
dated receipt if this disposition is ever superseded.
