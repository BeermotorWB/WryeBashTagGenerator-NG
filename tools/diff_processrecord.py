"""Compare ProcessRecord in NG vs Multi-NG (Multi exclusive: stock-master walk)."""
import re
import sys
import pathlib
from difflib import unified_diff

ROOT = pathlib.Path(__file__).resolve().parents[1]

def extract(path: pathlib.Path) -> str:
    t = path.read_text(encoding="utf-8", errors="replace")
    m = re.search(
        r"(Function ProcessRecord\(e: IwbMainRecord\): integer;.*?^End;)",
        t,
        re.S | re.M,
    )
    if not m:
        return ""
    return m.group(1)


def norm(s: str) -> str:
    return "\n".join(s.replace("\r\n", "\n").splitlines()) + "\n"


def strip_multi_stock_block(s: str) -> str:
    """Remove Multi-only while-loop and duplicate Nil check; keep one Master/Nil check."""
    pat = re.compile(
        r"  // get master record if record is an override\n"
        r"  o := Master\(e\);\n\n"
        r"  If Not Assigned\(o\) Then\n"
        r"    Exit;\n\n"
        r"  // Multi mode:.*?"
        r"\n  While Assigned\(o\) And \(Not IsStockMasterFile\(GetFileName\(GetFile\(o\)\)\)\) Do\n"
        r"    o := Master\(o\);\n\n"
        r"  If Not Assigned\(o\) Then\n"
        r"    Exit;\n\n",
        re.S,
    )
    rep = (
        "  // get master record if record is an override\n"
        "  o := Master(e);\n\n"
        "  If Not Assigned(o) Then\n"
        "    Exit;\n\n"
    )
    out, n = pat.subn(rep, s, count=1)
    if n != 1:
        raise SystemExit("expected to strip Multi stock block once; got %r" % n)
    return out


def main() -> None:
    ng = norm(extract(ROOT / "WryeBashTagGenerator-NG.pas"))
    mu = norm(extract(ROOT / "WryeBashTagGenerator-Multi-NG.pas"))
    mu2 = strip_multi_stock_block(mu)
    if ng == mu2:
        print("OK: ProcessRecord matches NG after normalizing Multi stock-master walk.")
        return
    d = list(
        unified_diff(
            ng.splitlines(),
            mu2.splitlines(),
            "WryeBashTagGenerator-NG.pas",
            "WryeBashTagGenerator-Multi-NG.pas (normalized)",
            n=2,
        )
    )
    sys.stdout.write("".join(d))


if __name__ == "__main__":
    main()
