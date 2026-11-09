#!/usr/bin/env python3
"""Summarize tools/sim.sh results (one JSON object per line).

    tools/sim_summary.py results.jsonl [expected_runs_per_monster]

One summary per monster (the rows' "monster" id, in order of first
appearance; rows from before the roster count as Grount), so an OUT= file of
MONSTER=all summarizes the same way sim.sh printed it. Hero deaths are
attributed to the monster by each row's "monster_name" (the spawned monster
node's name, the "by" of the deaths it caused).
"""
import json, statistics, sys
from collections import Counter

DEFAULT_MONSTER = ("grount", "Grount")


def med(xs): return f"{statistics.median(xs):.0f}s" if xs else "-"
def q(xs, k):
    xs = sorted(xs); return f"{xs[int(k * (len(xs) - 1))]:.0f}s" if xs else "-"


def summarize(rows, expected):
    def pct(n): return f"{100.0 * n / len(rows):.0f}%"
    monster_id = rows[0].get("monster") or DEFAULT_MONSTER[0]
    monster_name = rows[0].get("monster_name") or DEFAULT_MONSTER[1]

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

    print(f"runs: {len(rows)}/{expected or len(rows)}   side: {rows[0]['side']}   monster: {monster_id} ({monster_name})")
    print(f"winner: heroes {pct(heroes)}  monster {pct(monster)} (of which timeout {timeouts})  undecided(cap) {capped}")
    print(f"match length: median {med(lengths)}  p10 {q(lengths, .1)}  p90 {q(lengths, .9)}")
    print(f"first hero<->monster contact: median {med(contact)}  ({len(contact)} runs)")
    print(f"first hero death: median {med(first_death)}  monster stage then: " +
          ", ".join(f"S{s}:{stage_at_first_death.count(s)}" for s in (1, 2, 3)))
    print(f"evolution: stage2 median {med(evo2)} ({len(evo2)} runs)  stage3 median {med(evo3)} ({len(evo3)} runs)")
    print("final monster stage: " + ", ".join(f"S{s}:{final_stage.count(s)}" for s in (1, 2, 3)))
    print(f"damage: heroes->monster median {statistics.median(r['hero_dmg_to_monster'] for r in rows):.0f}"
          f"  monster->heroes median {statistics.median(r['monster_dmg_to_heroes'] for r in rows):.0f}")
    killers = Counter()
    for r in rows:
        name = r.get("monster_name") or DEFAULT_MONSTER[1]
        for d in r["hero_deaths"]:
            k = d["by"]
            killers["monster" if k == name else "mob:" + k.rstrip("0123456789@") if k else "?"] += 1
    print("hero deaths by: " + ", ".join(f"{k} {v}" for k, v in killers.most_common()))
    deaths = [d for r in rows for d in r["hero_deaths"]]
    if deaths and "allies_500" in deaths[0]:
        alone = sum(1 for d in deaths if d["allies_500"] == 0)
        helped = sum(1 for d in deaths if d["allies_fighting"] > 0)
        print(f"hero deaths: {len(deaths)}  alone(no ally<500px) {alone}  ally fighting nearby {helped}"
              f"  median attackers {statistics.median(d['attackers'] for d in deaths):.0f}"
              f"  median level {statistics.median(d['level'] for d in deaths):.0f}")
    if "monster_killer" in rows[0]:
        mk = Counter(r["monster_killer"] for r in rows if r["monster_killer"])
        taken = {k: statistics.median(r["monster_dmg_taken"][k] for r in rows) for k in ("heroes", "mobs", "other")}
        print("monster deaths by: " + (", ".join(f"{k} {v}" for k, v in mk.most_common()) or "-") +
              "  damage taken median: " + ", ".join(f"{k} {v:.0f}" for k, v in taken.items()))
    print(f"mob kills: monster median {statistics.median(r['mob_kills_monster'] for r in rows):.0f}"
          f"  heroes median {statistics.median(r['mob_kills_heroes'] for r in rows):.0f}")


path = sys.argv[1]
expected = int(sys.argv[2]) if len(sys.argv) > 2 else 0
groups = {}
for line in open(path):
    if line.strip():
        row = json.loads(line)
        groups.setdefault(row.get("monster") or DEFAULT_MONSTER[0], []).append(row)
if not groups:
    print("no results (did the sim crash? run one seed by hand)"); sys.exit(1)
for i, rows in enumerate(groups.values()):
    if i:
        print()
    summarize(rows, expected)
