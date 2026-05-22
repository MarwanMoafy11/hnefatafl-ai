"""
bridge.py — Python ↔ Prolog bridge for Hnefatafl.

All game logic lives in game.pl (SWI-Prolog).
This module calls SWI-Prolog via subprocess and parses the results.

Board representation (Python side):
  A flat list of 121 strings, same order as Prolog:
  'empty', 'attacker', 'defender', 'king'
  Index = row * 11 + col

Move representation (Python side):
  ((from_row, from_col), (to_row, to_col))
"""

import subprocess
import os
import re
import sys

# Path to game.pl — same directory as this file
_PROLOG_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "game.pl")
BOARD_SIZE = 11

# ---------- Piece / player constants (mirror board.py naming) ----------
EMPTY    = 'empty'
ATTACKER = 'attacker'
DEFENDER = 'defender'
KING     = 'king'
ATTACKERS = 'attackers'
DEFENDERS = 'defenders'

CORNERS = [(0,0),(0,10),(10,0),(10,10)]
THRONE  = (5, 5)

# ---------- Low-level Prolog call ----------

def _call_prolog(goal: str) -> str:
    """
    Pass the goal via stdin using swipl's -t flag for top-level goal.
    The board is passed as a quoted atom, so we use term_to_atom/2 in Prolog
    to reconstruct it. Here we just pipe everything as a script.
    """
    import tempfile, os
    # Write a standalone script that loads game.pl then runs the goal
    prolog_file = _PROLOG_FILE.replace('\\', '/')
    script = f":- use_module(library(lists)).\n:- ['{prolog_file}'].\n:- {goal}, halt.\n:- halt(1).\n"
    with tempfile.NamedTemporaryFile(mode='w', suffix='.pl', delete=False) as tf:
        tf.write(script)
        tmp_path = tf.name
    try:
        cmd = ["swipl", "--quiet", tmp_path]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
        out = result.stdout.strip()
        if not out and result.returncode != 0:
            raise RuntimeError(
                f"Prolog error.\nGoal: {goal[:200]}\nStderr: {result.stderr[:400]}"
            )
        return out
    finally:
        os.unlink(tmp_path)


# ---------- Board serialisation helpers ----------

def board_to_prolog(board: list) -> str:
    """Python flat list → Prolog atom string '[empty,attacker,...]'."""
    inner = ",".join(board)
    return f"[{inner}]"


def prolog_to_board(text: str) -> list:
    """Parse Prolog list atom '[empty,attacker,...]' → Python list."""
    text = text.strip()
    if text.startswith("[") and text.endswith("]"):
        text = text[1:-1]
    if not text:
        return []
    return [tok.strip() for tok in text.split(",")]


def board_to_2d(board: list):
    """Flat 121-element list → 11×11 list of lists."""
    return [board[r*BOARD_SIZE:(r+1)*BOARD_SIZE] for r in range(BOARD_SIZE)]


def board_to_flat(board_2d) -> list:
    """11×11 list of lists → flat 121-element list."""
    return [cell for row in board_2d for cell in row]


# ---------- Move serialisation helpers ----------

def move_to_prolog(move) -> str:
    """((fr,fc),(tr,tc)) → 'move(fr,fc,tr,tc)'."""
    (fr, fc), (tr, tc) = move
    return f"move({fr},{fc},{tr},{tc})"


def prolog_to_move(text: str):
    """'move(fr,fc,tr,tc)' → ((fr,fc),(tr,tc))."""
    text = text.strip()
    m = re.match(r'move\((\d+),(\d+),(\d+),(\d+)\)', text)
    if not m:
        return None
    fr, fc, tr, tc = map(int, m.groups())
    return ((fr, fc), (tr, tc))


def prolog_to_moves(text: str):
    """Parse a list of move/4 terms from Prolog output."""
    text = text.strip()
    if text in ("[]", ""):
        return []
    # Remove outer brackets
    if text.startswith("[") and text.endswith("]"):
        text = text[1:-1]
    # Split on move( boundaries
    raw_moves = re.findall(r'move\(\d+,\d+,\d+,\d+\)', text)
    return [prolog_to_move(m) for m in raw_moves if prolog_to_move(m)]


# ---------- Public API ----------

def initial_board() -> list:
    """Return the starting board as a flat Python list."""
    out = _call_prolog("run_query(initial_board)")
    return prolog_to_board(out)


def get_legal_moves(board: list, player: str) -> list:
    """Return list of moves for player."""
    board_atom = board_to_prolog(board)
    goal = f"run_query(legal_moves('{board_atom}',{player}))"
    out = _call_prolog(goal)
    return prolog_to_moves(out)


def apply_move(board: list, move) -> list:
    """Apply move to board and return new board."""
    board_atom = board_to_prolog(board)
    move_atom  = move_to_prolog(move)
    goal = f"run_query(apply_move('{board_atom}','{move_atom}'))"
    out = _call_prolog(goal)
    return prolog_to_board(out)


def check_winner(board: list):
    """Return 'attackers', 'defenders', or None."""
    board_atom = board_to_prolog(board)
    goal = f"run_query(check_winner('{board_atom}'))"
    out = _call_prolog(goal).strip()
    if out == 'none':
        return None
    return out


def is_terminal(board: list) -> bool:
    return check_winner(board) is not None


def choose_move(board: list, player: str, difficulty: str = 'medium'):
    """Ask Prolog alpha-beta for the best move."""
    board_atom = board_to_prolog(board)
    goal = f"run_query(choose_move('{board_atom}',{player},{difficulty}))"
    out = _call_prolog(goal).strip()
    if out == 'none':
        return None
    return prolog_to_move(out)


def find_king(board: list):
    """Return (row, col) of the king, or None."""
    for i, cell in enumerate(board):
        if cell == KING:
            return (i // BOARD_SIZE, i % BOARD_SIZE)
    return None


def get_cell(board: list, r: int, c: int) -> str:
    return board[r * BOARD_SIZE + c]


# ---------- Quick self-test ----------
if __name__ == "__main__":
    print("Testing bridge...")
    b = initial_board()
    print(f"Board length: {len(b)}  (expected 121)")
    print(f"King at: {find_king(b)}  (expected (5, 5))")

    atk_moves = get_legal_moves(b, ATTACKERS)
    def_moves = get_legal_moves(b, DEFENDERS)
    print(f"Attacker moves: {len(atk_moves)}  (expected 116)")
    print(f"Defender moves: {len(def_moves)}  (expected 60)")

    best = choose_move(b, ATTACKERS, 'easy')
    print(f"AI easy move: {best}")

    b2 = apply_move(b, best)
    print(f"Winner after 1 move: {check_winner(b2)}  (expected None)")
    print("Bridge OK.")
