#!/usr/bin/env python3
"""Test runner for Oxybelis.

Compiles and runs each .ox test file in tests/, comparing output
against expected values stored in tests/expected/<name>.txt.

Exit code: number of failures (0 = all pass).
"""

import os, sys, subprocess, difflib

TESTS_DIR = os.path.dirname(os.path.abspath(__file__))
EXPECTED_DIR = os.path.join(TESTS_DIR, 'expected')
COMPILER = os.path.join(os.path.dirname(TESTS_DIR), 'oxybelis.py')

# ── Test definitions ────────────────────────────────────────────
# Each entry: (filename, expected_output_lines, skip_reason or None)
# expected_output_lines can be:
#   - a list of strings (exact match)
#   - "IGNORE" (don't check output, just compile+run without error)
TESTS = [
    ('test_basics.ox', [
        '55',        # fib(10)
        '120',       # factorial(5)
        '45',        # sum_range(10)
        '5.5',       # 3.5 + 2.0
        '7',         # 3.5 * 2.0
        '1.5',       # 3.5 - 2.0
        '1.75',      # 3.5 / 2.0
        'false',     # true and false
        'true',      # true or false
        'false',     # not true
        'true',      # is_even(42)
        'true',      # 1 < 2
        'false',     # 1 > 2
        'true',      # 1 <= 1
        'true',      # 2 >= 2
        'true',      # 1 == 1
        'true',      # 1 != 2
        'hello',     # s
        'hello world',  # s + " world"
        'zero',      # if/elif/else
        '5',         # for count
        '6',         # while factorial (3*2*1 = 6... wait, 3*2*1 = 6 but we start with acc=1, n=3,
                     #   iter 1: acc=3, n=2; iter 2: acc=6, n=1; iter 3: acc=6, n=0; exit)
        '16',        # break/continue sum (1+3+5+7 = 16)
        '3',         # sqrt(9.0)
        '5',         # abs(-5)
        '8',         # pow(2.0, 3.0)
        '20',        # max(10, 20)
        '10',        # min(10, 20)
        '15',        # ca += 5
        '12',        # ca -= 3
        '24',        # ca *= 2
        '8',         # ca /= 3
        'done',      # void func
    ]),
    ('test_collections.ox', [
        '[10, 20, 30, 40]',  # print(v)
        '4',                  # len(v)
        '40',                 # pop(v)
        '[10, 20, 30]',       # print(v) after pop
        '[10, 99, 20, 30]',   # after insert
        '20',                 # removed at index 2
        '[10, 99, 30]',       # after remove
        'false',              # contains 20 (was removed)
        'false',              # contains 999
        '[1, 2, 3, 4, 5]',   # nums
        '[2, 4, 6, 8, 10]',  # doubled
        '[2, 4]',             # evens
        '15',                 # reduce sum
        'true',               # any > 3
        'true',               # all < 10
        'Some(3)',            # find == 3
        '15',                 # sum()
        '1',                  # min()
        '5',                  # max()
        'true',               # map contains "a"
        'false',              # map contains "z"
        '2',                  # map_get("b")
        '[1, 2, 3, 4]',      # it list
        '[[1, 2], [1, 3], [1, 4], [2, 3], [2, 4], [3, 4]]',  # combinations(2)
        '[[1, 2], [1, 3], [1, 4], [2, 1], [2, 3], [2, 4], [3, 1], [3, 2], [3, 4], [4, 1], [4, 2], [4, 3]]',  # permutations(2)
        '[[1, 2], [3, 4]]',  # chunked(2)
        '[[1, 2, 3], [4]]',  # chunked(3)
        '[[1, 2, 3], [2, 3, 4]]',  # windowed(3)
        '[[1, 2], [2, 3], [3, 4]]',  # pairwise()
        '[4, 3, 2, 1]',      # reversed()
        '[1, 2, 3, 4, 1, 2, 3, 4]',  # cycle(2)
        '[1, 2]',            # take_while(lt3)
        '[3, 4]',            # drop_while(lt3)
        '15',                 # for over nums total
    ]),
    ('test_option.ox', [
        'Some(42)',
        'None',
        '99',
        'None',
        'Some(20)',
        'None',
        '10',
        '77',
        '30',
        'Some(hello)',
        'hello',
        'Some(3.14)',
        '3.14',
    ]),
    ('test_result.ox', [
        'Ok(5)',
        'Err(division by zero)',
        '5',
        'Ok(42)',
        'Err(not a number)',
        'Err(empty string)',
        '99',
    ]),
    ('test_strings.ox', [
        '16',           # len("Hello, Oxybelis!")
        'e',            # str_get(s, 1)
        'H',            # str_get(s, 0)
        'Hello',        # str_sub(s, 0, 5)
        'Oxy',          # str_sub(s, 7, 10)
        '',             # str_sub(s, 3, 3)
        'true',         # "abc" == "abc"
        'false',        # "abc" == "xyz"
        'true',         # "abc" != "xyz"
        'foobar',       # a + b
        'true',         # is_digit("5")
        'false',        # is_digit("a")
        'true',         # is_alpha("x")
        'false',        # is_alpha("9")
        'true',         # is_alnum("Z")
        'false',        # is_alnum("_")
        '42',           # to_int("42")
        '3.14',         # to_float("3.14")
        '42',           # str(42)
        '3.140000',     # str(3.14) (std::to_string precision)
        'true',         # str(true)
        'false',        # str(false)
        '[a, b, c]',    # str_split
        "'hello'",      # str_trim
        "'hello  '",    # str_trim_start
        "'  hello'",    # str_trim_end
        'hello there',  # str_replace
        'a/b/c',        # str_replace_all
        'a,b,c',        # str_join
        'x',            # str_join single
        'HELLO WORLD',  # to_upper
        'hello world',  # to_lower
        'true',         # starts_with true
        'false',        # starts_with false
        'true',         # ends_with true
        'false',        # ends_with false
        'hahaha',       # str_repeat
        'olleh',        # str_reverse
        'Some(6)',      # str_find found
        'None',         # str_find not found
        'end',
    ]),
    ('test_modules.ox', [
        'Some(hello world)',
        'Some(3.14159)',
        'Some(true)',
        'Some(null)',
        '"hello\\"world"',  # json.escape output — contains literal backslash
    ]),
    ('test_classes.ox', [
        '3',
        '4',
        '10',
        '20',
        '42',
        'hello',
        '3.14',
        'true',
        '[1, 2]',
    ]),
    ('test_path.ox', [
        'foo/bar',
        'foo/bar/baz',
        'foo/bar',
        '/usr/bin',
        '[foo, bar]',
        '[foo, bar]',
        '[foo, bar]',
        'foo',
        'foo/bar',
        '',
        '/',
        'bar',
        'baz',
        'foo',
        'foo',
        'foo',
        'foo.tar',
        '.hidden',
        'foo',
        '.txt',
        '.gz',
        '',
        '',
        'foo/bar',
        'bar',
        '/foo/baz',
        'foo',
        '.',
    ]),
    ('test_fs.ox', [
        'cwd_ok',
        'true',
        'false',
        'true',
        'true',
        'false',
        'listed',
        'true',
        'true',
        'hello fs!',
        'true',
        'hello fs!',
        'false',
        'true',
        'hello fs!',
        '4',
        'hello world',
        'foo bar',
        'hello again',
        'baz',
        'hello world',
        'hello again',
        'false',
        'false',
        'false',
        'false',
    ]),
    ('test_generators.ox', [
        '=== count_to(5) ===',
        '0',
        '1',
        '2',
        '3',
        '4',
        '=== range_from(2, 6) ===',
        '2',
        '3',
        '4',
        '5',
        '=== even_up_to(10) ===',
        '0',
        '2',
        '4',
        '6',
        '8',
    ]),
]

# ── Helpers ────────────────────────────────────────────────────

def color(s, code):
    return f"\033[{code}m{s}\033[0m" if sys.stdout.isatty() else s

def red(s):    return color(s, 91)
def green(s):  return color(s, 92)
def yellow(s): return color(s, 93)
def dim(s):    return color(s, 90)

def compile_and_run(test_file):
    """Returns (returncode, stdout_lines, stderr_text)."""
    cpp_file = test_file.replace('.ox', '.cpp')
    exe_file = test_file.replace('.ox', '.exe')

    # Step 1: Compile .ox → .cpp → .exe
    r = subprocess.run(
        [sys.executable, COMPILER, test_file],
        capture_output=True, text=True, timeout=60,
        cwd=TESTS_DIR
    )
    if r.returncode != 0:
        return (r.returncode, [], r.stderr or r.stdout)

    # Step 2: Run .exe
    r = subprocess.run(
        [os.path.join(TESTS_DIR, exe_file)],
        capture_output=True, text=True, timeout=30,
        cwd=TESTS_DIR
    )
    if r.returncode != 0:
        return (r.returncode, [], r.stderr or r.stdout)

    lines = r.stdout.strip().splitlines()
    return (0, lines, '')


def run_tests():
    failures = 0
    total = len(TESTS)

    print(f"{'='*60}")
    print(f"  Oxybelis Test Runner")
    print(f"  {total} test suites")
    print(f"{'='*60}\n")

    for name, expected_lines in TESTS:
        test_path = os.path.join(TESTS_DIR, name)
        if not os.path.exists(test_path):
            print(f"  {red('SKIP')}  {name}  (file not found)")
            continue

        rc, got_lines, err = compile_and_run(name)
        if rc != 0:
            print(f"  {red('FAIL')}  {name}")
            print(f"        {dim('compiler/runtime error:')}")
            for line in err.strip().splitlines()[:10]:
                print(f"        {dim(line)}")
            failures += 1
            continue

        # Compare output
        if expected_lines == "IGNORE":
            print(f"  {green('PASS')}  {name}")
            continue

        # Normalize both: strip trailing whitespace
        expected = [l.strip() for l in expected_lines]
        got = [l.strip() for l in got_lines]

        if got == expected:
            print(f"  {green('PASS')}  {name}")
        else:
            print(f"  {red('FAIL')}  {name}")
            diff = list(difflib.unified_diff(
                expected, got,
                fromfile='expected', tofile='got',
                lineterm=''
            ))
            for line in diff[:20]:
                if line.startswith('+'):
                    print(f"      {green(line)}")
                elif line.startswith('-'):
                    print(f"      {red(line)}")
                elif line.startswith('@'):
                    print(f"      {dim(line)}")
                else:
                    print(f"      {line}")
            if len(diff) > 20:
                print(f"      {dim('...')}")
            failures += 1

    # Summary
    passed = total - failures
    print(f"\n{'='*60}")
    if failures == 0:
        print(f"  {green('ALL PASS')}  ({passed}/{total})")
    else:
        print(f"  {red(f'{failures} FAILURES')}  ({passed}/{total})")
    print(f"{'='*60}")
    return failures


if __name__ == '__main__':
    sys.exit(run_tests())
