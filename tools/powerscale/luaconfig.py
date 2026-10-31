"""Reads src/shared/Config.luau's big table and writes single values back into it without
touching anything else (comments, layout, colours), for the powerscaling dashboard.

  parse(text) -> (tree, spans)
      tree:  the table as JSON-able Python (numbers, strings, bools, dicts; arrays are lists;
             anything else, like Color3.fromRGB(...), comes through as {"expr": "..."})
      spans: { "Bosses.MotherHen.Health": (start, end, kind) } for every number and string,
             kind "number" or "string"; array items are 1-based like Luau ("...Attacks.1.Damage")
  write(text, edits) -> new text, edits = { path: value }; a path that isn't a number or a
             string literal in the file raises KeyError
"""

import re

TOKEN = re.compile(
    r"""
    (?P<ws>\s+)
  | (?P<comment>--\[(?P<ceq>=*)\[.*?\](?P=ceq)\]|--[^\n]*)
  | (?P<lstr>\[(?P<seq>=*)\[.*?\](?P=seq)\])
  | (?P<str>"(?:\\.|[^"\\\n])*"|'(?:\\.|[^'\\\n])*')
  | (?P<num>0[xX][0-9a-fA-F_]+|(?:\d[\d_]*\.?[\d_]*|\.\d[\d_]*)(?:[eE][+-]?\d+)?)
  | (?P<name>[A-Za-z_][A-Za-z0-9_]*)
  | (?P<op>==|~=|<=|>=|\.\.\.?|::|//|[-+*/%^#<>=(){}\[\];:,.])
    """,
    re.S | re.X,
)


def tokens(text):
    out, i = [], 0
    while i < len(text):
        m = TOKEN.match(text, i)
        if not m:
            raise ValueError("can't read Config.luau at character %d" % i)
        kind = m.lastgroup if m.lastgroup not in ("ceq", "seq") else None
        for k in ("ws", "comment", "lstr", "str", "num", "name", "op"):
            if m.group(k) is not None:
                kind = k
                break
        if kind not in ("ws", "comment"):
            out.append((kind, m.group(0), m.start(), m.end()))
        i = m.end()
    return out


def number(s):
    s = s.replace("_", "")
    if s[:2].lower() == "0x":
        return int(s, 16)
    v = float(s)
    return int(v) if v.is_integer() and "." not in s and "e" not in s.lower() else v


def unquote(s):
    return bytes(s[1:-1], "utf-8").decode("unicode_escape") if s[0] in "\"'" else s


ARITH = re.compile(r"^[\d_.eE+\-*/() ]+$")


class Parser:
    def __init__(self, text):
        self.text = text
        self.toks = tokens(text)
        self.i = 0
        self.spans = {}

    def peek(self, k=0):
        return self.toks[self.i + k] if self.i + k < len(self.toks) else ("eof", "", len(self.text), len(self.text))

    def take(self, want=None):
        t = self.peek()
        if want is not None and t[1] != want:
            raise ValueError("expected %r at character %d, got %r" % (want, t[2], t[1]))
        self.i += 1
        return t

    def table(self, path):
        self.take("{")
        out, arr, n = {}, [], 0
        while self.peek()[1] != "}":
            t, t1 = self.peek(), self.peek(1)
            if t[0] == "name" and t1[1] == "=":
                key = t[1]
                self.i += 2
            elif t[1] == "[" and self.peek(1)[0] in ("str", "num") and self.peek(2)[1] == "]" and self.peek(3)[1] == "=":
                k = self.peek(1)
                key = unquote(k[1]) if k[0] == "str" else str(number(k[1]))
                self.i += 4
            else:
                n += 1
                key = None
            p = "%s.%s" % (path, key if key is not None else n) if path else str(key if key is not None else n)
            v = self.value(p)
            if key is None:
                arr.append(v)
            else:
                out[key] = v
            if self.peek()[1] in (",", ";"):
                self.i += 1
        self.take("}")
        if arr and not out:
            return arr
        for idx, v in enumerate(arr, 1):
            out[str(idx)] = v
        return out

    def value(self, path):
        t = self.peek()
        if t[1] == "{":
            return self.table(path)
        # an expression: everything up to the next , ; or } at this depth
        start, depth, j = t[2], 0, self.i
        while True:
            k = self.toks[j]
            if depth == 0 and k[1] in (",", ";", "}"):
                break
            if k[1] in ("(", "{", "["):
                depth += 1
            elif k[1] in (")", "}", "]"):
                depth -= 1
            j += 1
        parts = self.toks[self.i:j]
        end = parts[-1][3]
        self.i = j
        raw = self.text[start:end]
        if len(parts) == 1 and parts[0][0] == "num":
            self.spans[path] = (start, end, "number")
            return number(raw)
        if len(parts) == 2 and parts[0][1] == "-" and parts[1][0] == "num":
            self.spans[path] = (start, end, "number")
            return -number(parts[1][1])
        if len(parts) == 1 and parts[0][0] == "str":
            self.spans[path] = (start, end, "string")
            return unquote(raw)
        if len(parts) == 1 and parts[0][1] in ("true", "false"):
            return parts[0][1] == "true"
        if len(parts) == 1 and parts[0][1] == "nil":
            return None
        if all(p[0] in ("num", "op") for p in parts) and ARITH.match(raw):
            try:
                v = eval(raw.replace("_", ""), {"__builtins__": {}}, {})  # (only digits and + - * / ( ))
                self.spans[path] = (start, end, "number")
                return v
            except Exception:
                pass
        return {"expr": raw}


def parse(text):
    p = Parser(text)
    while p.peek()[1] != "return":
        p.i += 1
    p.take("return")
    tree = p.table("")
    return tree, p.spans


def fmt(v):
    if isinstance(v, bool):
        raise TypeError("not a number")
    v = float(v)
    if abs(v) >= 1e15 or (v.is_integer() and abs(v) < 1e15):
        return str(int(round(v))) if abs(v) < 1e15 else repr(v)
    s = "%.6g" % v
    if "e" in s:
        s = repr(round(v, 10))
    return s


def write(text, edits):
    _, spans = parse(text)
    reps = []
    for path, v in edits.items():
        if path not in spans:
            raise KeyError(path)
        a, b, kind = spans[path]
        if kind == "number":
            reps.append((a, b, fmt(v)))
        else:
            reps.append((a, b, '"%s"' % str(v).replace("\\", "\\\\").replace('"', '\\"')))
    for a, b, s in sorted(reps, reverse=True):
        text = text[:a] + s + text[b:]
    return text
