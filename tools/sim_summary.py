#!/usr/bin/env python3
"""Summarize tools/sim.sh results (one JSON object per line)."""
import json, statistics, sys

path = sys.argv[1]
expected = int(sys.argv[2]) if len(sys.argv) > 2 else 0
rows = [json.loads(l) for l in open(path) if l.strip()]
if not rows:
    print("no results (did the sim crash? run one seed by hand)"); sys.exit(1)

def pct(n): return f"{100.0 * n / len(rows):.0f}%"
def med(xs): return f"{statistics.median(xs):.0f}s" if xs else "-"
def q(xs, k):
    xs = sorted(xs); return f"{xs[int(k * (len(xs) - 1))]:.0f}s" if xs else "-"

heroes = sum(1 for r in rows if r["winner"] == "Heroes")
monster = sum(1 for r in rows if r["winner"] == "Monster")
capped = sum(1 for r in rows if r["reason"] == "cap")
timeouts = sum(1 for r in rows if r["winner"] == "Monster" and r["game_clock"] >= 599.0)
lengths = [r["t"] for r in rows]
contact = [r["first_contact"] for r in rows if r["first_contact"] >= 0]
first_death = [r["hero_deaths"][0]["t"] for r in rows if r["hero_deaths"]]
stage_at_first_death = [r["hero_deaths"][0]["stage"] for r in rows if r["hero_deaths"]]
evo2 = [e["t"] for r in rows for e in r["evolutions"] if e["stage"] == 2]
evo3 = [e["t"] for r in rows for e in r["evolutions"] if e["stage"] == 3]
final_stage = [r["monster_stage"] for r in rows]

print(f"runs: {len(rows)}/{expected or len(rows)}   side: {rows[0]['side']}")
print(f"winner: heroes {pct(heroes)}  monster {pct(monster)} (of which timeout {timeouts})  undecided(cap) {capped}")
print(f"match length: median {med(lengths)}  p10 {q(lengths, .1)}  p90 {q(lengths, .9)}")
print(f"first hero<->monster contact: median {med(contact)}  ({len(contact)} runs)")
print(f"first hero death: median {med(first_death)}  monster stage then: " +
      ", ".join(f"S{s}:{stage_at_first_death.count(s)}" for s in (1, 2, 3)))
print(f"evolution: stage2 median {med(evo2)} ({len(evo2)} runs)  stage3 median {med(evo3)} ({len(evo3)} runs)")
print("final monster stage: " + ", ".join(f"S{s}:{final_stage.count(s)}" for s in (1, 2, 3)))
print(f"damage: heroes->monster median {statistics.median(r['hero_dmg_to_monster'] for r in rows):.0f}"
      f"  monster->heroes median {statistics.median(r['monster_dmg_to_heroes'] for r in rows):.0f}")
from collections import Counter
killers = Counter()
for r in rows:
    for d in r["hero_deaths"]:
        k = d["by"] or "?"
        killers["monster" if "Grount" in k else ("mob:" + k.rstrip("0123456789@")) if k else "?"] += 1
print("hero deaths by: " + ", ".join(f"{k} {v}" for k, v in killers.most_common()))
deaths = [d for r in rows for d in r["hero_deaths"]]
if deaths and "allies_500" in deaths[0]:
    alone = sum(1 for d in deaths if d["allies_500"] == 0)
    helped = sum(1 for d in deaths if d["allies_fighting"] > 0)
    print(f"hero deaths: {len(deaths)}  alone(no ally<500px) {alone}  ally fighting nearby {helped}"
          f"  median attackers {statistics.median(d['attackers'] for d in deaths):.0f}"
          f"  median level {statistics.median(d['level'] for d in deaths):.0f}")
print(f"mob kills: monster median {statistics.median(r['mob_kills_monster'] for r in rows):.0f}"
      f"  heroes median {statistics.median(r['mob_kills_heroes'] for r in rows):.0f}")
