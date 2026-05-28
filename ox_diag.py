"""
Oxybelis Diagnostic System
==========================
Rust-like diagnostic output & syntax highlighting for the terminal.
"""

import sys
from dataclasses import dataclass, field
from enum import Enum, auto
from typing import List, Optional, Tuple


# ═══════════════════════════════════════════════════════════════
#  ANSI STYLES
# ═══════════════════════════════════════════════════════════════

class Style:
    RESET = '\033[0m'
    BOLD = '\033[1m'
    DIM = '\033[2m'
    ITALIC = '\033[3m'

    RED = '\033[31m'
    GREEN = '\033[32m'
    YELLOW = '\033[33m'
    BLUE = '\033[34m'
    MAGENTA = '\033[35m'
    CYAN = '\033[36m'
    GRAY = '\033[90m'

    BRIGHT_RED = '\033[91m'
    BRIGHT_GREEN = '\033[92m'
    BRIGHT_YELLOW = '\033[93m'
    BRIGHT_BLUE = '\033[94m'
    BRIGHT_MAGENTA = '\033[95m'
    BRIGHT_CYAN = '\033[96m'


# ═══════════════════════════════════════════════════════════════
#  SPAN  (source code location range)
# ═══════════════════════════════════════════════════════════════

@dataclass
class Span:
    start: int
    end: int
    start_line: int = 0
    start_col: int = 0
    end_line: int = 0
    end_col: int = 0

    @staticmethod
    def from_pos(pos: int, length: int, source: str = '', line: int = 1, col: int = 1) -> 'Span':
        end_pos = pos + length
        if not source:
            return Span(pos, end_pos, line, col, line, col + length)
        el, ec = line, col
        for i in range(pos, min(end_pos, len(source))):
            if source[i] == '\n':
                el += 1
                ec = 1
            else:
                ec += 1
        return Span(pos, end_pos, line, col, el, ec)

    def shift_left(self, n: int) -> 'Span':
        return Span(self.start, self.end - n, self.start_line, self.start_col, self.end_line, self.end_col - n)

    def merge(self, other: 'Span') -> 'Span':
        return Span(
            min(self.start, other.start), max(self.end, other.end),
            self.start_line, self.start_col,
            other.end_line, other.end_col
        )


# ═══════════════════════════════════════════════════════════════
#  SEVERITY
# ═══════════════════════════════════════════════════════════════

class Severity(Enum):
    ERROR = "error"
    WARNING = "warning"
    NOTE = "note"
    HELP = "help"


# ═══════════════════════════════════════════════════════════════
#  DIAGNOSTIC
# ═══════════════════════════════════════════════════════════════

@dataclass
class Diagnostic:
    severity: Severity
    message: str
    span: Optional[Span] = None
    code: str = ''
    notes: List[Tuple[str, Optional[Span]]] = field(default_factory=list)
    help_text: str = ''
    children: List['Diagnostic'] = field(default_factory=list)


# ═══════════════════════════════════════════════════════════════
#  SOURCE FILE  (line index for fast line:col lookup)
# ═══════════════════════════════════════════════════════════════

class SourceFile:
    def __init__(self, source: str, path: str = ''):
        self.source = source
        self.path = path
        self.lines = source.split('\n')
        self._line_starts: List[int] = [0]
        for i, ch in enumerate(source):
            if ch == '\n':
                self._line_starts.append(i + 1)

    def offset_to_line_col(self, offset: int) -> Tuple[int, int]:
        offset = max(0, min(offset, len(self.source) - 1))
        lo, hi = 0, len(self._line_starts) - 1
        while lo < hi:
            mid = (lo + hi + 1) // 2
            if self._line_starts[mid] <= offset:
                lo = mid
            else:
                hi = mid - 1
        return lo + 1, offset - self._line_starts[lo] + 1

    def line_text(self, n: int) -> str:
        return self.lines[n - 1] if 1 <= n <= len(self.lines) else ''


# ═══════════════════════════════════════════════════════════════
#  RENDERER
# ═══════════════════════════════════════════════════════════════

_SEV_STYLE = {
    Severity.ERROR: Style.BRIGHT_RED + Style.BOLD,
    Severity.WARNING: Style.BRIGHT_YELLOW + Style.BOLD,
    Severity.NOTE: Style.BRIGHT_CYAN + Style.BOLD,
    Severity.HELP: Style.BRIGHT_GREEN + Style.BOLD,
}
_SEV_LABEL = {
    Severity.ERROR: 'error',
    Severity.WARNING: 'warning',
    Severity.NOTE: 'note',
    Severity.HELP: 'help',
}
_ARROW_COLOR = {
    Severity.ERROR: Style.BRIGHT_RED,
    Severity.WARNING: Style.BRIGHT_YELLOW,
    Severity.NOTE: Style.CYAN,
    Severity.HELP: Style.GREEN,
}
R = Style.RESET


def render_diagnostics(diags: List[Diagnostic], src: SourceFile) -> str:
    lines: List[str] = []
    for d in diags:
        _render_one(d, src, lines)
    return '\n'.join(lines)


def _render_one(d: Diagnostic, src: SourceFile, lines: List[str]) -> None:
    code_str = f'[{d.code}]' if d.code else ''
    sev = d.severity
    lines.append(
        f'\n{_SEV_STYLE[sev]}{_SEV_LABEL[sev]}{R}{code_str}: {d.message}'
    )
    if d.span:
        _render_span(d.span, src, lines, sev)
    for note_msg, note_span in d.notes:
        lines.append(f'  {Style.GRAY}={R} {Style.BOLD}note{R}: {note_msg}')
        if note_span:
            _render_span(note_span, src, lines, Severity.NOTE, indent=2)
    if d.help_text:
        lines.append(f'  {Style.GRAY}={R} {Style.BOLD}help{R}: {d.help_text}')
    for child in d.children:
        _render_one(child, src, lines)


def _render_span(span: Span, src: SourceFile, lines: List[str],
                 severity: Severity, indent: int = 0) -> None:
    ins = ' ' * indent
    ac = _ARROW_COLOR.get(severity, R)
    loc = (f'{src.path}:{span.start_line}:{span.start_col}' if src.path
           else f'{span.start_line}:{span.start_col}')
    lines.append(f'{ins}{Style.BOLD} -->{R} {Style.GRAY}{loc}{R}')
    lines.append(f'{ins}  |')

    if span.start_line == span.end_line:
        text = src.line_text(span.start_line)
        if text is not None:
            sn = str(span.start_line)
            lines.append(f'{ins}{Style.GRAY}{sn}{R} | {text}')
            arr = [' '] * len(sn)
            for ci, ch in enumerate(text, 1):
                arr.append('^' if span.start_col <= ci < span.end_col else ' ')
            lines.append(f'{ins}{Style.GRAY}  |{R}{"".join(arr)}{ac}{R}')
            lines.append(f'{ins}  |')

    elif span.start_line < span.end_line and span.start_line > 0:
        text = src.line_text(span.start_line)
        if text:
            sn = str(span.start_line)
            lines.append(f'{ins}{Style.GRAY}{sn}{R} | {text}')
            arr = [' '] * len(sn)
            for ci, _ in enumerate(text, 1):
                arr.append('^' if ci >= span.start_col else ' ')
            lines.append(f'{ins}{Style.GRAY}  |{R}{ac}{"".join(arr)}^^^{R}')

        for ln in range(span.start_line + 1, span.end_line):
            t = src.line_text(ln)
            if t is not None:
                lines.append(f'{ins}{Style.GRAY}{ln}{R} | {ac}{t}{R}')

        text = src.line_text(span.end_line)
        if text:
            en = str(span.end_line)
            arr = [' '] * len(en)
            for ci, _ in enumerate(text, 1):
                arr.append('^' if ci <= span.end_col else ' ')
            lines.append(f'{ins}{Style.GRAY}{en}{R} | {text}')
            lines.append(f'{ins}{Style.GRAY}  |{R}{ac}{"".join(arr)}^^^{R}')


# ═══════════════════════════════════════════════════════════════
#  SYNTAX HIGHLIGHTER  (ANSI terminal)
# ═══════════════════════════════════════════════════════════════

_OX_KEYWORDS = frozenset({
    'fn', 'let', 'var', 'class', 'if', 'else', 'elif',
    'for', 'in', 'while', 'return', 'match', 'lazy', 'pub',
    'true', 'false', 'None', 'Some', 'import', 'and', 'or', 'not',
    'break', 'continue', '_',
})
_OX_TYPES = frozenset({'int', 'float', 'bool', 'str', 'void', 'List', 'Map', 'Option'})


def highlight_ox(source: str) -> str:
    out: List[str] = []
    i = 0
    while i < len(source):
        ch = source[i]

        if ch == '/' and i + 1 < len(source) and source[i + 1] == '/':
            end = source.find('\n', i)
            if end == -1:
                end = len(source)
            out.append(f'{Style.DIM}{Style.GRAY}{source[i:end]}{R}')
            i = end
            continue

        if ch == '/' and i + 1 < len(source) and source[i + 1] == '*':
            end = source.find('*/', i + 2)
            if end == -1:
                end = len(source) - 2
            out.append(f'{Style.DIM}{Style.GRAY}{source[i:end + 2]}{R}')
            i = end + 2
            continue

        if ch == '"':
            j = i + 1
            while j < len(source) and source[j] != '"':
                if source[j] == '\\':
                    j += 1
                j += 1
            j += 1
            out.append(f'{Style.GREEN}{source[i:j]}{R}')
            i = j
            continue

        if ch.isdigit() or (ch == '.' and i + 1 < len(source) and source[i + 1].isdigit()):
            j = i
            is_float = False
            while j < len(source) and (source[j].isdigit() or source[j] == '.'):
                if source[j] == '.':
                    is_float = True
                j += 1
            out.append(f'{Style.BRIGHT_YELLOW}{source[i:j]}{R}')
            i = j
            continue

        if ch.isalpha() or ch == '_':
            j = i
            while j < len(source) and (source[j].isalnum() or source[j] == '_'):
                j += 1
            word = source[i:j]
            if word in _OX_KEYWORDS:
                out.append(f'{Style.BRIGHT_BLUE}{Style.BOLD}{word}{R}')
            elif word in _OX_TYPES:
                out.append(f'{Style.BRIGHT_CYAN}{word}{R}')
            else:
                out.append(word)
            i = j
            continue

        if ch in '{}()[]':
            out.append(f'{Style.BRIGHT_MAGENTA}{ch}{R}')
        elif ch in '+-*/%=!<>&|^~':
            out.append(f'{Style.BOLD}{ch}{R}')
        else:
            out.append(ch)
        i += 1

    return ''.join(out)


def print_highlighted(source: str, file=sys.stdout) -> None:
    print(highlight_ox(source), file=file)
