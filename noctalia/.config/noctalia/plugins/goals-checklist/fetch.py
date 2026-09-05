#!/usr/bin/env python3
import json
import sys
import os
import re
from datetime import datetime, date
from pathlib import Path

GOALS_DIR = Path(os.path.expanduser("~/personal/goals"))
START_DATE = date(2026, 9, 5) # Tomorrow is Day 1!
END_DATE = date(2027, 3, 19)

def get_current_info():
    today = date.today()
    day_diff = (today - START_DATE).days
    
    is_before_start = day_diff < 0
    days_until_start = abs(day_diff) if is_before_start else 0
    
    current_day = 0 if is_before_start else min(196, day_diff + 1)
    target_day = max(1, min(196, day_diff + 1))
    current_week = min(28, (target_day - 1) // 7 + 1)
    current_month = min(7, (target_day - 1) // 28 + 1)
    
    return {
        "today_iso": today.isoformat(),
        "is_before_start": is_before_start,
        "days_until_start": days_until_start,
        "current_day": current_day,
        "target_day": target_day,
        "current_week": current_week,
        "current_month": current_month,
    }

def toggle_task(file_path_str, task_text):
    path = Path(file_path_str)
    if not path.exists():
        return {"ok": False, "error": f"File not found: {file_path_str}"}
    
    content = path.read_text(encoding="utf-8")
    clean_search = re.escape(task_text[:30].strip())
    
    pattern_unchecked = re.compile(r"(\*\s*[`]?\[)\s*(\][`]?\s*.*?" + clean_search + r")", re.DOTALL)
    pattern_checked = re.compile(r"(\*\s*[`]?\[)[xX](\][`]?\s*.*?" + clean_search + r")", re.DOTALL)
    
    if pattern_unchecked.search(content):
        new_content = pattern_unchecked.sub(r"\g<1>x\g<2>", content, count=1)
        path.write_text(new_content, encoding="utf-8")
        return {"ok": True, "action": "checked"}
    elif pattern_checked.search(content):
        new_content = pattern_checked.sub(r"\g<1> \g<2>", content, count=1)
        path.write_text(new_content, encoding="utf-8")
        return {"ok": True, "action": "unchecked"}
    
    return {"ok": False, "error": "Task text pattern not matched"}

def parse_today():
    info = get_current_info()
    c_day = info["current_day"]
    t_day = info["target_day"] # Day to display/preview
    c_week = info["current_week"]
    c_month = info["current_month"]
    is_before_start = info["is_before_start"]
    days_until = info["days_until_start"]
    
    day_of_week = (t_day - 1) % 7
    # Since Day 1 (2026-09-05) is Saturday:
    # 0 = Saturday, 1 = Sunday, 2 = Monday, 3 = Tuesday, 4 = Wednesday, 5 = Thursday, 6 = Friday
    is_weekend = day_of_week in (0, 1)
    
    month_dir = GOALS_DIR / "curriculum" / "days" / f"month-{c_month:02d}"
    day_file = None
    if month_dir.exists():
        matches = list(month_dir.glob(f"day-{t_day:03d}-*.md"))
        if matches:
            day_file = matches[0]
            
    week_file = GOALS_DIR / "curriculum" / "weeks" / f"week-{c_week:02d}.md"
    reading_file = GOALS_DIR / "curriculum" / "evening_reading_plan.md"
    
    week_theme = "Vector Search & AI Systems Specialization"
    tasks = []
    slots = []
    
    if is_before_start:
        day_title = f"Day 000 · Starts Tomorrow ({days_until}d)"
    else:
        day_title = f"Day {c_day:03d}"
    
    # 1. Evening Reading Plan parsing
    lit_text = ""
    if reading_file.exists():
        r_content = reading_file.read_text(encoding="utf-8")
        if day_file:
            m_date = re.search(r"day-\d{3}-(\d{4})-(\d{2})-(\d{2})", day_file.name)
            if m_date:
                y, m, d = int(m_date.group(1)), int(m_date.group(2)), int(m_date.group(3))
                d_obj = date(y, m, d)
                month_abbr = d_obj.strftime("%b")
                pat = rf"\*\s*\*\*([^*]*{month_abbr}\s*{d_obj.day}[^*]*)\*\*:\s*([^\n]+)"
                m_lit = re.search(pat, r_content)
                if m_lit:
                    lit_text = m_lit.group(2).strip()

    # 2. Week file parsing
    c1, c2, c3 = "", "", ""
    if week_file.exists():
        w_text = week_file.read_text(encoding="utf-8")
        
        m_theme = re.search(r">\s*\*\*Theme\*\*:\s*([^\n]+)", w_text)
        if m_theme:
            week_theme = m_theme.group(1).strip()
            
        tt_pattern = re.compile(rf"\|\s*\*\*([^*]+)\*\*\s*\|\s*([^|]+)\s*\|\s*\[`Day {t_day:03d}`\]\([^)]+\)\s*\|\s*([^|]+)\|\s*([^|]+)\|\s*([^|]+)\|")
        m_tt = tt_pattern.search(w_text)
        if m_tt:
            day_name = m_tt.group(1).strip()
            date_str = m_tt.group(2).strip()
            if not is_before_start:
                day_title = f"Day {c_day:03d} · {date_str}"
            c1 = m_tt.group(3).strip().replace("**", "")
            c2 = m_tt.group(4).strip().replace("**", "")
            c3 = m_tt.group(5).strip().replace("**", "")
            
        # Parse tasks from section ### 🔹 ... Day XXX
        day_pattern = re.compile(
            rf"###\s*🔹\s*.*?Day\s*{t_day:03d}.*?\n(.*?)(?=\n###|\n---|\Z)",
            re.DOTALL
        )
        day_match = day_pattern.search(w_text)
        if day_match:
            block = day_match.group(1)
            for line in block.strip().split("\n"):
                line = line.strip()
                if not line.startswith("*"):
                    continue
                checked = "[x]" in line or "[X]" in line
                if "Core" in line:
                    t_type = "core"
                    label = "Core" if not is_before_start else "Tomorrow"
                elif "Optional" in line or "Stretch" in line:
                    t_type = "stretch"
                    label = "Stretch"
                else:
                    t_type = "item"
                    label = "Task"
                
                clean = re.sub(r"^\*[\s\-\[`]*\[[ xX]\][`\s]*", "", line)
                clean = re.sub(r"^\*\*[^*]+\*\*:\s*", "", clean)
                clean = clean.replace("`", "").strip()
                if clean:
                    tasks.append({
                        "type": t_type,
                        "label": label,
                        "text": clean,
                        "checked": checked
                    })

    # Build structured slots
    if not is_weekend:
        slots = [
            {"time": "05:30", "icon": "book-open", "label": "Systems", "desc": c1 or "Systems & Architecture Reading"},
            {"time": "06:30", "icon": "hammer", "label": "Builder", "desc": c2 or "Morning Builder Track"},
            {"time": "18:30", "icon": "book", "label": "Literature", "desc": lit_text or "Evening Reading Sanctuary"},
            {"time": "20:30", "icon": "cpu", "label": "secan", "desc": c3 or "Night Hands-On C++/CUDA"}
        ]
    elif day_of_week == 0: # Saturday
        slots = [
            {"time": "09:00", "icon": "divide", "label": "Math 1", "desc": c1 or "Pure Math Block 1: Theory & Derivations"},
            {"time": "15:00", "icon": "book", "label": "Sanctuary", "desc": lit_text or "Weekend Literature Sanctuary"},
            {"time": "18:00", "icon": "layers", "label": "InfoTheory", "desc": "Cover & Thomas: Elements of Information Theory"},
            {"time": "19:30", "icon": "edit-3", "label": "Math Lab", "desc": "Graduate Math Problem-Set & Proof Lab"}
        ]
    else: # Sunday
        slots = [
            {"time": "09:00", "icon": "divide", "label": "Math 2", "desc": c1 or "Pure Math Block 2: Problem Sets & Proofs"},
            {"time": "13:00", "icon": "tool", "label": "Runtime", "desc": "Maintenance for limbed / ggmbed"},
            {"time": "15:00", "icon": "globe", "label": "Penrose", "desc": lit_text or "The Road to Reality"},
            {"time": "18:00", "icon": "database", "label": "Dist/IR", "desc": "Distributed Systems & IR (DDIA / Manning IIR)"},
            {"time": "19:30", "icon": "cpu", "label": "Sys Lab", "desc": "Graduate Systems & GPU Architecture Lab"}
        ]

    if not tasks:
        tasks = [
            {"type": "core", "label": "Core", "text": c3[:80] if c3 else "secan engineering implementation", "checked": False},
            {"type": "stretch", "label": "Stretch", "text": "Review architecture and run benchmarks", "checked": False}
        ]

    res = {
        "ok": True,
        "day_num": c_day,
        "day_title": day_title,
        "day_of_week": day_of_week,
        "is_weekend": is_weekend,
        "week_num": c_week,
        "month_num": c_month,
        "week_theme": week_theme,
        "is_before_start": is_before_start,
        "days_until_start": days_until,
        "file_path": str(day_file) if day_file else str(week_file),
        "week_file": str(week_file),
        "reading_file": str(reading_file),
        "slots": slots,
        "tasks": tasks,
        "math_topic": c1[:90],
        "reading_topic": c2[:90],
        "code_topic": c3[:90]
    }
    return res

if __name__ == "__main__":
    if len(sys.argv) > 2 and sys.argv[1] == "--toggle":
        res = toggle_task(sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else "")
        print(json.dumps(res))
    else:
        data = parse_today()
        print(json.dumps(data))
