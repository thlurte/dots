#!/usr/bin/env python3
import json
import sys
import os
import re
from datetime import datetime, date
from pathlib import Path

GOALS_DIR = Path(os.path.expanduser("~/personal/goals"))
START_DATE = date(2026, 9, 1)

MONTH_THEMES = [
    "Month 1 (Sep 2026): Scalar & SIMD Distance Kernels",
    "Month 2 (Oct 2026): Quantization & Inverted Files (IVF-PQ)",
    "Month 3 (Nov 2026): Navigable Graphs (HNSW) & ColBERT",
    "Month 4 (Dec 2026): DiskANN, io_uring & GPU IVF Spine",
    "Month 5 (Jan 2027): GPU CAGRA, FastScan & Paged KV",
    "Month 6 (Feb 2027): Filtered ANN (ACORN) & SIMD NEON",
    "Month 7 (Mar 2027): FlashAttention-2, Multi-GPU & v2.0",
]

RESEARCH_PAPERS = [
    {"month": 1, "topic": "Microarchitectural Limits of SIMD Vector Distance Kernels", "due": date(2026, 9, 27)},
    {"month": 2, "topic": "Anisotropy-Aware Quantization: Hubness, Cones & Loss Functions", "due": date(2026, 10, 25)},
    {"month": 3, "topic": "Streaming Late Interaction: PLAID vs MUVERA in Dynamic LSM", "due": date(2026, 11, 29)},
    {"month": 4, "topic": "Billion-Scale Retrieval: In-VRAM GPU IVF vs NVMe DiskANN", "due": date(2026, 12, 27)},
    {"month": 5, "topic": "Paging vs Quantizing LLM KV Caches at Long Contexts", "due": date(2027, 1, 31)},
    {"month": 6, "topic": "Mitigating Recall Collapse in Filtered ANN Graphs (ACORN)", "due": date(2027, 2, 28)},
    {"month": 7, "topic": "Unified IO-Aware GPU Architecture: FA-2, Paged KV & Multi-GPU", "due": date(2027, 3, 12)},
]

LITERATURE_CURRICULUM = [
    {"weeks": range(1, 5), "title": "Zen and the Art of Motorcycle Maintenance", "author": "Robert M. Pirsig"},
    {"weeks": range(5, 9), "title": "Gödel, Escher, Bach (Part 1)", "author": "Douglas Hofstadter"},
    {"weeks": range(9, 15), "title": "The Magic Mountain (Der Zauberberg)", "author": "Thomas Mann"},
    {"weeks": range(15, 18), "title": "Cybernetics: Control & Communication", "author": "Norbert Wiener"},
    {"weeks": range(18, 22), "title": "I Am a Strange Loop", "author": "Douglas Hofstadter"},
    {"weeks": range(22, 27), "title": "The Master and Margarita", "author": "Mikhail Bulgakov"},
    {"weeks": range(27, 29), "title": "The Grand Intellectual Retrospective", "author": "Pirsig, Mann, Penrose"},
]

PENROSE_CHAPTERS = [
    "Ch 1: The Roots of Science (Platonic Mathematical World)",
    "Ch 2: An Ancient Theorem and a Modern Question (Pythagoras & Reals)",
    "Ch 3: Kinds of Number in the Physical World",
    "Ch 4: Magical Complex Numbers (Euler's Formula)",
    "Ch 5: Geometry of Logarithms, Powers, and Roots",
    "Ch 6: Real-Number Calculus (Derivatives & Taylor Series)",
    "Ch 7: Complex-Number Calculus (Holomorphic Functions)",
    "Ch 8: Riemann Surfaces and Complex Mappings",
    "Ch 9: Fourier Decomposition and Hyperfunctions",
    "Ch 10: Surfaces (Topology & Euler Characteristic)",
    "Ch 11: Complex Dimensions (Manifolds)",
    "Ch 12: Manifolds of n Dimensions (Differential Forms)",
    "Ch 13: Symmetry Groups (SO(3) and SU(2))",
    "Ch 14: Calculus on Manifolds (Covariant Derivatives)",
    "Ch 15: Fibre Bundles and Gauge Connections",
    "Ch 16: The Ladder of Infinity (Cantor & Turing)",
    "Ch 17: Spacetime (Special Relativity & Light Cones)",
    "Ch 18: Minkowskian Geometry (4-Vectors & Invariants)",
    "Ch 19: Classical Fields of Maxwell and Einstein",
    "Ch 20: Lagrangians and Hamiltonians (Least Action)",
    "Ch 21: The Quantum Particle (Wavefunctions & Schrodinger)",
    "Ch 22: Quantum Algebra, Geometry, and Spin",
    "Ch 23: The Entangled Quantum World (EPR Paradox & Bell)",
    "Ch 24: Dirac's Electron and Antiparticles",
    "Ch 25: Standard Model of Particle Physics",
    "Ch 26: Quantum Field Theory (Path Integrals & Invariance)",
    "Ch 27: Big Bang & Thermodynamics (Entropy S = k ln W)",
    "Ch 28: Speculative Theories of the Early Universe"
]

def parse_essays():
    essays_file = GOALS_DIR / "curriculum" / "essays.md"
    essays = []
    if essays_file.exists():
        content = essays_file.read_text(encoding="utf-8")
        pattern = re.compile(r"\|\s*\*\*(\d+)\*\*\s*\|\s*([^|]+)\s*\|\s*\*?([^*|]+)\*?\s*\|")
        for m in pattern.finditer(content):
            week_num = int(m.group(1))
            date_str = m.group(2).strip()
            title = m.group(3).strip()
            essays.append({
                "week": week_num,
                "date_str": date_str,
                "title": title
            })
    return essays

def get_progress():
    today = date.today()
    day_diff = (today - START_DATE).days
    
    is_before_start = day_diff < 0
    days_until_start = abs(day_diff) if is_before_start else 0
    
    current_day = max(1, min(196, day_diff + 1))
    current_week = min(28, (current_day - 1) // 7 + 1)
    current_month = min(7, (current_day - 1) // 28 + 1)
    
    total_days = 196
    pct_progress = round((current_day / total_days) * 100, 1)
    
    # Block info
    if current_week <= 16:
        block_name = "Block I: Vector Search Engine Spine"
        block_target = "v1.2-vs-spine-complete"
    else:
        block_name = "Block II: GPU Specialization"
        block_target = "v2.0 FlashAttention & Multi-GPU"
        
    # Find next essay
    essays = parse_essays()
    next_essay = None
    for e in essays:
        if e["week"] >= current_week:
            next_essay = e
            break
    if not next_essay and essays:
        next_essay = essays[-1]
        
    # Find next research paper
    next_paper = None
    for p in RESEARCH_PAPERS:
        if p["due"] >= today:
            days_left = (p["due"] - today).days
            next_paper = {
                "month": p["month"],
                "topic": p["topic"],
                "due_str": p["due"].strftime("%b %d"),
                "days_left": days_left
            }
            break
    if not next_paper:
        p = RESEARCH_PAPERS[-1]
        next_paper = {
            "month": p["month"],
            "topic": p["topic"],
            "due_str": p["due"].strftime("%b %d"),
            "days_left": 0
        }
        
    # Find active literature book
    active_book = LITERATURE_CURRICULUM[-1]
    for b in LITERATURE_CURRICULUM:
        if current_week in b["weeks"]:
            active_book = b
            break
            
    # Find active Penrose chapter
    penrose_idx = min(len(PENROSE_CHAPTERS) - 1, max(0, current_week - 1))
    next_penrose = PENROSE_CHAPTERS[penrose_idx]

    month_theme = MONTH_THEMES[current_month - 1] if current_month <= len(MONTH_THEMES) else ""

    res = {
        "ok": True,
        "is_before_start": is_before_start,
        "days_until_start": days_until_start,
        "current_day": current_day,
        "total_days": total_days,
        "current_week": current_week,
        "total_weeks": 28,
        "current_month": current_month,
        "total_months": 7,
        "pct_progress": pct_progress,
        "block_name": block_name,
        "block_target": block_target,
        "month_theme": month_theme,
        "next_essay": next_essay,
        "next_paper": next_paper,
        "active_book": f"{active_book['title']} ({active_book['author']})",
        "next_penrose": next_penrose
    }
    return res

if __name__ == "__main__":
    data = get_progress()
    print(json.dumps(data))
