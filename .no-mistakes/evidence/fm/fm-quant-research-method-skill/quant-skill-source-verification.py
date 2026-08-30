#!/usr/bin/env python3
"""Verify the immutable external source snapshots cited by the quant skill."""

import html
import re
from urllib.request import Request, urlopen


def fetch(url: str) -> str:
    request = Request(url, headers={"User-Agent": "firstmate-no-mistakes-evidence"})
    with urlopen(request, timeout=30) as response:
        return response.read().decode("utf-8")


checks = {
    "Qlib 79633dd signal strategy": (
        "https://raw.githubusercontent.com/microsoft/qlib/79633dd9506ea689e5400dea0197717b5b3d74b7/qlib/contrib/strategy/signal_strategy.py",
        ["class TopkDropoutStrategy", "pred_score", "method_buy=\"top\""],
    ),
    "Qlib 79633dd custom strategy state": (
        "https://raw.githubusercontent.com/microsoft/qlib/79633dd9506ea689e5400dea0197717b5b3d74b7/qlib/strategy/base.py",
        ["class BaseStrategy", "current_position"],
    ),
    "RD-Agent 6762f84 factor runner": (
        "https://raw.githubusercontent.com/microsoft/RD-Agent/6762f84f9bc0f5c6486c50a00e128a57ac6c3683/rdagent/scenarios/qlib/developer/factor_runner.py",
        ["class QlibFactorRunner", "combined data", "backtest results"],
    ),
    "RD-Agent 6762f84 factor template": (
        "https://raw.githubusercontent.com/microsoft/RD-Agent/6762f84f9bc0f5c6486c50a00e128a57ac6c3683/rdagent/scenarios/qlib/experiment/factor_template/conf_combined_factors.yaml",
        ["class: TopkDropoutStrategy", "class: PortAnaRecord"],
    ),
    "R&D-Agent(Q) paper v2": (
        "https://arxiv.org/html/2505.15155v2",
        ["candidate model is paired with the current SOTA factor set", "Qlib backtesting platform"],
    ),
    "ML4T 47e2c44 point-in-time validation": (
        "https://raw.githubusercontent.com/stefan-jansen/machine-learning-for-trading/47e2c442d85f17166a8e31e08ac5085bb68dbca3/02_financial_data_universe/14_point_in_time_validation.py",
        ["point-in-time"],
    ),
    "ML4T 47e2c44 IC inference": (
        "https://raw.githubusercontent.com/stefan-jansen/machine-learning-for-trading/47e2c442d85f17166a8e31e08ac5085bb68dbca3/07_defining_the_learning_task/06_ic_inference.py",
        ["information coefficient"],
    ),
    "ML4T 47e2c44 holdout mechanics": (
        "https://raw.githubusercontent.com/stefan-jansen/machine-learning-for-trading/47e2c442d85f17166a8e31e08ac5085bb68dbca3/20_strategy_synthesis/holdout.py",
        ["Holdout prediction", "out-of-sample validation"],
    ),
}

failures = []
for label, (url, markers) in checks.items():
    body = fetch(url)
    searchable = body
    if "arxiv.org/html/" in url:
        searchable = " ".join(html.unescape(re.sub(r"<[^>]+>", " ", body)).split())
    missing = [marker for marker in markers if marker.lower() not in searchable.lower()]
    if missing:
        failures.append(f"{label}: missing {missing}")
        print(f"FAIL {label}")
    else:
        print(f"PASS {label}")

print(f"result={'PASS' if not failures else 'FAIL'}")
if failures:
    raise SystemExit("; ".join(failures))
