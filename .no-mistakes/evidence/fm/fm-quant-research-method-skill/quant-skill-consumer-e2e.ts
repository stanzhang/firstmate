import {
  type AssistantMessage,
  createAssistantMessageEventStream,
} from "@earendil-works/pi-ai";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

function textOf(content: unknown): string {
  if (typeof content === "string") return content;
  if (!Array.isArray(content)) return "";
  return content
    .filter((item): item is { type: "text"; text: string } =>
      typeof item === "object" && item !== null &&
      (item as { type?: unknown }).type === "text" &&
      typeof (item as { text?: unknown }).text === "string")
    .map((item) => item.text)
    .join("\n");
}

function assistant(model: { api: string; provider: string; id: string }): AssistantMessage {
  return {
    role: "assistant",
    content: [],
    api: model.api,
    provider: model.provider,
    model: model.id,
    usage: {
      input: 0,
      output: 0,
      cacheRead: 0,
      cacheWrite: 0,
      totalTokens: 0,
      cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 },
    },
    stopReason: "stop",
    timestamp: Date.now(),
  };
}

export default function (pi: ExtensionAPI): void {
  pi.registerProvider("quant-skill-e2e", {
    baseUrl: "http://127.0.0.1/unused",
    apiKey: "offline-test-only",
    api: "quant-skill-e2e-api",
    models: [{
      id: "deterministic",
      name: "Offline quant skill consumer probe",
      reasoning: false,
      input: ["text"],
      cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
      contextWindow: 32768,
      maxTokens: 1024,
    }],
    streamSimple(model, context) {
      const stream = createAssistantMessageEventStream();
      const systemPrompt = (context as { systemPrompt?: unknown }).systemPrompt;
      const delivered = [
        typeof systemPrompt === "string" ? systemPrompt : "",
        ...context.messages.map((message) => textOf(message.content)),
      ].join("\n");

      const discoveryOnly = !delivered.includes("# quant-research-method");
      const checks: Array<[string, boolean]> = discoveryOnly ? [
        ["AGENTS trigger reaches the consumer", delivered.includes("quant-research-method") && delivered.includes("load before scoping any quant experiment, writing a backtest brief, or interpreting a backtest result")],
      ] : [
        ["skill body delivered by Pi", delivered.includes("# quant-research-method")],
        ["factor test is frozen-model paired ablation with Rank IC", delivered.includes("Freeze the model, label, universe, split, and all non-tested features.") && delivered.includes("Run a paired ablation") && delivered.includes("Rank IC")],
        ["factor tests forbid strategy entry and exit rules", delivered.includes("A factor test needs no strategy, no entry rule, and no exit rule.")],
        ["gate requires prior exact factor evidence or factor-first", delivered.includes("Run the factor test first unless the gate brief cites a recorded factor-test result for the exact feature definition.")],
        ["gate declares custom state strategy and matched controls", delivered.includes("explicit custom state strategy") && delivered.includes("exposure-matched and volatility-matched controls")],
        ["framework defaults are forbidden", delivered.includes("Never inherit a framework default for the strategy itself.")],
        ["point-in-time and completed-period timing enforced", delivered.includes("available_at <= decision_time") && delivered.includes("Use the prior completed higher-timeframe period only")],
        ["one-indicator and matched placebo comparison enforced", delivered.includes("Test one indicator at a time.") && delivered.includes("placebo gate with a similar acceptance rate when feasible")],
        ["coverage and per-signal support remain distinct", delivered.includes("Report panel coverage separately from measurement support.") && delivered.includes("Per-signal support")],
        ["serial and overlap robust inference is explicit", delivered.includes("serial-dependence- and overlapping-window-robust standard errors") && delivered.includes("Name the estimator and predeclare a lag or block length")],
        ["walk-forward selection and purged sealed holdout enforced", delivered.includes("Use walk-forward splits for research selection") && delivered.includes("sealed holdout") && delivered.includes("label interval intersects")],
        ["honest null and no positive-result retuning enforced", delivered.includes("A null, adverse cost result, or rejection condition is a result.") && delivered.includes("Do not tune features, windows, thresholds, or costs toward a positive outcome.")],
        ["all named failure detectors are delivered", ["Current-week leakage", "Incorrect Wilder ATR initialization", "Survivor universe", "Label/execution mismatch", "Composite contamination", "Mechanical risk reduction", "Goalpost drift", "Framework-default strategy", "Double lag", "Coverage-support confusion", "Split-boundary label leakage"].every((name) => delivered.includes(name))],
        ["market and methodology findings close every traversal", delivered.includes("Every traversal records two findings") && delivered.includes("METHODOLOGY FINDING: NONE_DETECTED")],
        ["independent external review remains required", delivered.includes("independent external review remains necessary")],
        ["ranking backtest boundary is not swing or gate evidence", delivered.includes("not evidence for a swing or gate strategy")],
        ["research-only authority boundary is preserved", delivered.includes("It does not authorize a backtest, data access, promotion, or an order.")],
      ];

      const failed = checks.filter(([, ok]) => !ok).map(([label]) => label);
      const responseText = [
        discoveryOnly ? "QUANT_RESEARCH_METHOD_DISCOVERY_E2E" : "QUANT_RESEARCH_METHOD_CONSUMER_E2E",
        `consumer=pi version=${process.env.PI_E2E_VERSION ?? "unknown"}`,
        `loaded=${failed.length === 0 ? (discoveryOnly ? "trigger-registered" : "yes") : "no"}`,
        ...checks.map(([label, ok]) => `${ok ? "PASS" : "FAIL"} ${label}`),
        `result=${failed.length === 0 ? "PASS" : "FAIL"}`,
      ].join("\n");

      const output = assistant(model);
      queueMicrotask(() => {
        stream.push({ type: "start", partial: output });
        const block = { type: "text" as const, text: responseText };
        output.content.push(block);
        stream.push({ type: "text_start", contentIndex: 0, partial: output });
        stream.push({ type: "text_delta", contentIndex: 0, delta: responseText, partial: output });
        stream.push({ type: "text_end", contentIndex: 0, content: responseText, partial: output });
        stream.push({ type: "done", reason: "stop", message: output });
        stream.end();
      });
      return stream;
    },
  });
}
