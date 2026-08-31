#!/usr/bin/env bash
set -euo pipefail

if [ "$(basename "$0")" = pro-cli ]; then
  printf '%s\n' "$*" >> "$DEMO_LOG"
  case "${1-}:${2-}" in
    doctor:--json)
      printf '{"ok":true,"data":{"ready":true}}\n'
      ;;
    limits:--json)
      printf '{"ok":true,"data":{"account":{"planType":"pro"},"observedLimits":[{"featureName":"gpt-5-6-pro","remaining":1,"observedAt":"%s"}]}}\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
      ;;
    job:create)
      printf 'create\n' >> "$DEMO_COUNT"
      printf '{"ok":true,"data":{"job":{"id":"job_evidence_demo","status":"queued"}}}\n'
      ;;
    job:wait)
      : > "$DEMO_WAIT_STARTED"
      while [ ! -e "$DEMO_RELEASE" ]; do sleep 0.05; done
      printf '{"ok":true,"data":{"job":{"id":"job_evidence_demo","status":"succeeded"}}}\n'
      exit 75
      ;;
    job:status)
      printf '{"ok":true,"data":{"job":{"id":"job_evidence_demo","status":"succeeded"}}}\n'
      ;;
    job:result)
      printf '{"ok":true,"data":{"jobId":"job_evidence_demo","result":"fixture advisory bytes; intentionally never printed"}}\n'
      ;;
    --version:*)
      printf 'pro-cli evidence fixture\n'
      ;;
    *)
      printf '{"ok":false,"error":{"code":"UNEXPECTED_FIXTURE_CALL"}}\n' >&2
      exit 97
      ;;
  esac
  exit 0
fi

REPO_ROOT=${1:?usage: run-fm-consult-demo.sh <repository-root>}
EVIDENCE_FILE="$(cd "$(dirname "$0")" && pwd)/fm-consult-end-to-end-cli.txt"
DEMO_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/fm-consult-evidence.XXXXXX")
case "$DEMO_ROOT" in
  */fm-consult-evidence.*) ;;
  *) printf 'unsafe demo root: %s\n' "$DEMO_ROOT" >&2; exit 1 ;;
esac
DEMO_FM_HOME="$DEMO_ROOT/fm-home"
DEMO_BIN="$DEMO_ROOT/bin"
DEMO_LOG="$DEMO_ROOT/pro-cli.argv"
DEMO_COUNT="$DEMO_ROOT/create.count"
DEMO_WAIT_STARTED="$DEMO_ROOT/wait.started"
DEMO_RELEASE="$DEMO_ROOT/wait.release"
QUESTION_FILE="$DEMO_ROOT/question.md"
mkdir -p "$DEMO_FM_HOME/state" "$DEMO_BIN"
chmod 0700 "$DEMO_FM_HOME" "$DEMO_FM_HOME/state"
printf 'fixture question bytes; intentionally never printed\n' > "$QUESTION_FILE"
ln -s "$(cd "$(dirname "$0")" && pwd)/$(basename "$0")" "$DEMO_BIN/pro-cli"
export DEMO_LOG DEMO_COUNT DEMO_WAIT_STARTED DEMO_RELEASE

cleanup_demo() {
  find "$DEMO_ROOT" -depth -delete 2>/dev/null || true
}
trap cleanup_demo EXIT

{
  printf 'Firstmate private consultation end-to-end CLI evidence\n'
  printf 'Transport: isolated fake pro-cli; no network, live consultation, cookie, or billable action\n\n'

  prepare_out=$(FM_HOME="$DEMO_FM_HOME" FM_ROOT_OVERRIDE="$REPO_ROOT" PATH="$DEMO_BIN:$PATH" \
    "$REPO_ROOT/bin/fm-consult.sh" prepare --question "$QUESTION_FILE" --privacy internal-research)
  CONSULT_ID=$(printf '%s\n' "$prepare_out" | awk '/^prepared: / {print $2}')
  [ -n "$CONSULT_ID" ]
  printf '1. Prepare through the public CLI\n'
  printf '%s\n' "$prepare_out" | sed "s/$CONSULT_ID/<consult-id>/g"
  RECORD_DIR="$DEMO_FM_HOME/data/consults/$CONSULT_ID"
  printf 'record_mode=%s\n' "$(stat -f '%Lp' "$RECORD_DIR")"
  find "$RECORD_DIR" -maxdepth 1 -type f -exec stat -f '%N %Lp' {} \; \
    | sed 's#.*/##' | sort | sed 's/^/leaf=/'
  printf '\n'

  start_ms=$(perl -MTime::HiRes=time -e 'printf "%.0f", time()*1000')
  submit_out=$(FM_HOME="$DEMO_FM_HOME" FM_ROOT_OVERRIDE="$REPO_ROOT" PATH="$DEMO_BIN:$PATH" \
    "$REPO_ROOT/bin/fm-consult.sh" submit "$CONSULT_ID")
  end_ms=$(perl -MTime::HiRes=time -e 'printf "%.0f", time()*1000')
  submit_ms=$((end_ms - start_ms))
  SOURCE_ID="consult-$CONSULT_ID"
  REGISTRATION="$DEMO_FM_HOME/state/procevent/$SOURCE_ID.source"
  [ -f "$REGISTRATION" ]
  [ "$(wc -l < "$DEMO_COUNT" | tr -d ' ')" = 1 ]
  [ "$submit_ms" -lt 2000 ]
  printf '2. Submit once and arm a known-job waiter\n'
  printf '%s\n' "$submit_out" | sed "s/$CONSULT_ID/<consult-id>/g"
  printf 'foreground_submit_elapsed_ms=%s\n' "$submit_ms"
  printf 'job_create_calls=1\n'
  printf 'wait_registration=present mode=%s\n\n' "$(stat -f '%Lp' "$REGISTRATION")"

  reconcile_out=$(FM_HOME="$DEMO_FM_HOME" FM_ROOT_OVERRIDE="$REPO_ROOT" PATH="$DEMO_BIN:$PATH" \
    FM_PROCEVENT_CLAIM_ROOT="$DEMO_ROOT/claims" "$REPO_ROOT/bin/fm-procevent.sh" reconcile)
  for _ in $(seq 1 100); do [ -e "$DEMO_WAIT_STARTED" ] && break; sleep 0.05; done
  [ -e "$DEMO_WAIT_STARTED" ]
  printf '3. Start the generic background runner\n'
  printf '%s\n' "$reconcile_out"
  printf 'background_wait_started=true; conversational_command_already_returned=true\n'
  : > "$DEMO_RELEASE"
  RESULT_FILE=''
  for _ in $(seq 1 200); do
    for candidate in "$DEMO_FM_HOME/state/procevent-inbox/$SOURCE_ID".*.result; do
      if [ -s "$candidate" ]; then RESULT_FILE=$candidate; break; fi
    done
    [ -n "$RESULT_FILE" ] && break
    sleep 0.05
  done
  [ -n "$RESULT_FILE" ]
  for _ in $(seq 1 100); do [ ! -e "$REGISTRATION" ] && break; sleep 0.05; done
  [ ! -e "$REGISTRATION" ]
  printf 'captured_envelope='
  perl -MJSON::PP -e '
    my $v=decode_json(do{local $/; open my $f,"<",$ARGV[0] or die; <$f>});
    print encode_json({schema=>$v->{schema},wait_exit=>$v->{wait_exit},wait_timed_out=>$v->{wait_timed_out},job_status=>$v->{job_status},contains_advisory=>JSON::PP::false}),"\n";
  ' "$RESULT_FILE"
  printf 'terminal_registration=retired_even_with_wait_exit_75\n\n'

  handle_out=$(FM_HOME="$DEMO_FM_HOME" FM_ROOT_OVERRIDE="$REPO_ROOT" PATH="$DEMO_BIN:$PATH" \
    "$REPO_ROOT/bin/fm-procevent-consult.sh" handle "$CONSULT_ID" 1 "$RESULT_FILE")
  printf '4. Handle the exact captured job and publish a private receipt\n'
  printf '%s\n' "$handle_out" | sed "s/$SOURCE_ID/<source-id>/g; s/$CONSULT_ID/<consult-id>/g"
  receipt_terminal=$(perl -MJSON::PP -e 'my $v=decode_json(do{local $/;open my $f,"<",$ARGV[0] or die;<$f>}); print $v->{result_terminal}' "$RECORD_DIR/receipt.json")
  receipt_hash=$(perl -MJSON::PP -e 'my $v=decode_json(do{local $/;open my $f,"<",$ARGV[0] or die;<$f>}); print $v->{answer_sha256}' "$RECORD_DIR/receipt.json")
  advisory_hash=$(shasum -a 256 "$RECORD_DIR/advisory.md" | awk '{print $1}')
  [ "$receipt_hash" = "$advisory_hash" ]
  printf 'receipt_terminal=%s\n' "$receipt_terminal"
  printf 'receipt_mode=%s advisory_mode=%s answer_hash_matches=true\n' \
    "$(stat -f '%Lp' "$RECORD_DIR/receipt.json")" "$(stat -f '%Lp' "$RECORD_DIR/advisory.md")"
  printf 'private_question_or_advisory_bytes_printed=false\n\n'

  replay_out=$(FM_HOME="$DEMO_FM_HOME" FM_ROOT_OVERRIDE="$REPO_ROOT" PATH="$DEMO_BIN:$PATH" \
    "$REPO_ROOT/bin/fm-consult.sh" submit "$CONSULT_ID")
  [ "$(wc -l < "$DEMO_COUNT" | tr -d ' ')" = 1 ]
  printf '5. Replay the same consult\n'
  printf '%s\n' "$replay_out" | sed "s/$CONSULT_ID/<consult-id>/g"
  printf 'job_create_calls_after_replay=1\n\n'

  printf '6. Observed pro-cli argv (private contents omitted)\n'
  sed -E 's/job_evidence_demo/<job-id>/g' "$DEMO_LOG"
  [ "$(grep -c '^job create ' "$DEMO_LOG")" = 1 ]
  grep -q '^job create @question.md --json --retries 0 --temporary --model gpt-5-6-pro --reasoning standard$' "$DEMO_LOG"
  ! grep -qE '(^| )ask( |$)|job create .*--wait' "$DEMO_LOG"
  printf 'forbidden_ask_or_create_wait_calls=0\n'
} > "$EVIDENCE_FILE"

printf '%s\n' "$EVIDENCE_FILE"
