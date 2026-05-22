"""
gui.py — Hnefatafl GUI (Pygame only, zero game logic).

This file contains ONLY:
  - Window drawing
  - Mouse/keyboard input handling
  - Menu rendering

ALL game logic (moves, captures, win detection, alpha-beta, turns)
is implemented in Prolog (game.pl) and called via bridge.py.

Run with:  python gui.py
"""

import sys
import pygame

from bridge import (
    EMPTY, ATTACKER, DEFENDER, KING,
    ATTACKERS, DEFENDERS,
    BOARD_SIZE, CORNERS, THRONE,
    initial_board,
    get_legal_moves,
    apply_move,
    check_winner,
    choose_move,
    get_cell,
    board_to_2d,
)

# Window / visual constants
CELL_SIZE   = 55
MARGIN      = 20
INFO_HEIGHT = 70
WINDOW_W    = MARGIN * 2 + CELL_SIZE * BOARD_SIZE
WINDOW_H    = MARGIN * 2 + CELL_SIZE * BOARD_SIZE + INFO_HEIGHT

COLOR_BG          = (240, 230, 200)
COLOR_BOARD       = (210, 180, 140)
COLOR_GRID        = (100,  70,  40)
COLOR_THRONE      = (180, 140,  90)
COLOR_CORNER      = (120,  80,  40)
COLOR_ATTACKER    = ( 30,  30,  30)
COLOR_DEFENDER    = (250, 250, 250)
COLOR_KING        = (220, 180,  40)
COLOR_KING_BORDER = (120,  80,   0)
COLOR_SELECT      = (255, 230,  30)
COLOR_LEGAL_DOT   = ( 80, 200,  80)
COLOR_TEXT        = ( 30,  30,  30)
COLOR_INFO_BG     = (200, 180, 140)
COLOR_BTN         = (180, 135,  75)
COLOR_BTN_HOVER   = (200, 160, 100)
COLOR_BTN_BORDER  = ( 70,  45,  15)
COLOR_WIN_BG      = (240, 200, 100)


def cell_rect(r, c):
    return pygame.Rect(MARGIN + c * CELL_SIZE, MARGIN + r * CELL_SIZE, CELL_SIZE, CELL_SIZE)


def pixel_to_cell(x, y):
    if x < MARGIN or y < MARGIN:
        return None
    c = (x - MARGIN) // CELL_SIZE
    r = (y - MARGIN) // CELL_SIZE
    if 0 <= r < BOARD_SIZE and 0 <= c < BOARD_SIZE:
        return (int(r), int(c))
    return None


def draw_board(screen, board_flat, selected, legal_targets, status, font, small_font):
    screen.fill(COLOR_BG)
    board = board_to_2d(board_flat)

    for r in range(BOARD_SIZE):
        for c in range(BOARD_SIZE):
            rect = cell_rect(r, c)
            if (r, c) in CORNERS:
                bg = COLOR_CORNER
            elif (r, c) == THRONE:
                bg = COLOR_THRONE
            else:
                bg = COLOR_BOARD
            pygame.draw.rect(screen, bg, rect)
            pygame.draw.rect(screen, COLOR_GRID, rect, 1)
            if (r, c) in CORNERS:
                lbl = small_font.render("X", True, (200, 160, 100))
                screen.blit(lbl, lbl.get_rect(center=rect.center))
            elif (r, c) == THRONE and board[r][c] == EMPTY:
                lbl = small_font.render("T", True, (160, 120, 60))
                screen.blit(lbl, lbl.get_rect(center=rect.center))

    if selected is not None:
        pygame.draw.rect(screen, COLOR_SELECT, cell_rect(*selected), 4)

    for (r, c) in legal_targets:
        center = cell_rect(r, c).center
        pygame.draw.circle(screen, COLOR_LEGAL_DOT, center, 9)
        pygame.draw.circle(screen, COLOR_GRID, center, 9, 1)

    for r in range(BOARD_SIZE):
        for c in range(BOARD_SIZE):
            piece = board[r][c]
            if piece == EMPTY:
                continue
            rect = cell_rect(r, c)
            cx, cy = rect.center
            radius = CELL_SIZE // 2 - 5
            if piece == ATTACKER:
                pygame.draw.circle(screen, COLOR_ATTACKER, (cx, cy), radius)
                pygame.draw.circle(screen, (80, 80, 80), (cx, cy), radius, 2)
            elif piece == DEFENDER:
                pygame.draw.circle(screen, COLOR_DEFENDER, (cx, cy), radius)
                pygame.draw.circle(screen, COLOR_GRID, (cx, cy), radius, 2)
            elif piece == KING:
                pygame.draw.circle(screen, COLOR_KING, (cx, cy), radius)
                pygame.draw.circle(screen, COLOR_KING_BORDER, (cx, cy), radius, 3)
                crown = font.render("K", True, COLOR_KING_BORDER)
                screen.blit(crown, crown.get_rect(center=(cx, cy)))

    info_rect = pygame.Rect(0, MARGIN + CELL_SIZE * BOARD_SIZE, WINDOW_W, INFO_HEIGHT)
    pygame.draw.rect(screen, COLOR_INFO_BG, info_rect)
    pygame.draw.line(screen, COLOR_GRID, (0, info_rect.top), (WINDOW_W, info_rect.top), 2)
    txt = font.render(status, True, COLOR_TEXT)
    screen.blit(txt, txt.get_rect(midleft=(MARGIN, info_rect.centery)))


def draw_button(screen, rect, label, font, hovered=False):
    color = COLOR_BTN_HOVER if hovered else COLOR_BTN
    pygame.draw.rect(screen, color, rect, border_radius=7)
    pygame.draw.rect(screen, COLOR_BTN_BORDER, rect, 2, border_radius=7)
    txt = font.render(label, True, COLOR_TEXT)
    screen.blit(txt, txt.get_rect(center=rect.center))


def show_menu(screen, font, big_font, small_font):
    # Groups: defenders and attackers, each with 3 difficulty buttons
    # Layout: title -> section label -> 3 buttons -> gap -> section label -> 3 buttons
    BTN_W, BTN_H = 320, 44
    GAP = 8          # gap between buttons in same group
    GROUP_GAP = 24   # extra gap between the two groups

    # Pre-calculate y positions
    TITLE_Y  = 38
    SUB_Y    = 68
    DEF_LBL_Y = 100
    # 3 defender buttons
    DEF_Y = [DEF_LBL_Y + 18 + i * (BTN_H + GAP) for i in range(3)]
    # attacker section starts after last defender button + group gap
    ATK_LBL_Y = DEF_Y[-1] + BTN_H + GROUP_GAP
    ATK_Y = [ATK_LBL_Y + 18 + i * (BTN_H + GAP) for i in range(3)]

    def_options = [
        ("Defenders - Easy",   DEFENDERS, 'easy'),
        ("Defenders - Medium", DEFENDERS, 'medium'),
        ("Defenders - Hard",   DEFENDERS, 'hard'),
    ]
    atk_options = [
        ("Attackers - Easy",   ATTACKERS, 'easy'),
        ("Attackers - Medium", ATTACKERS, 'medium'),
        ("Attackers - Hard",   ATTACKERS, 'hard'),
    ]

    while True:
        mouse_pos = pygame.mouse.get_pos()
        screen.fill(COLOR_BG)

        # Title
        t1 = big_font.render("HNEFATAFL", True, (80, 45, 10))
        t2 = font.render("Viking Chess  -  Prolog Edition", True, (100, 65, 20))
        screen.blit(t1, t1.get_rect(center=(WINDOW_W // 2, TITLE_Y)))
        screen.blit(t2, t2.get_rect(center=(WINDOW_W // 2, SUB_Y)))

        # Section labels
        def_lbl = small_font.render("-- Play as Defenders --", True, (80, 50, 10))
        atk_lbl = small_font.render("-- Play as Attackers --", True, (80, 50, 10))
        screen.blit(def_lbl, def_lbl.get_rect(center=(WINDOW_W // 2, DEF_LBL_Y)))
        screen.blit(atk_lbl, atk_lbl.get_rect(center=(WINDOW_W // 2, ATK_LBL_Y)))

        # Draw buttons and collect rects
        btn_rects = []
        all_options = []
        for i, (label, side, diff) in enumerate(def_options):
            rect = pygame.Rect((WINDOW_W - BTN_W) // 2, DEF_Y[i], BTN_W, BTN_H)
            btn_rects.append(rect)
            all_options.append((side, diff))
            draw_button(screen, rect, label, font, rect.collidepoint(mouse_pos))
        for i, (label, side, diff) in enumerate(atk_options):
            rect = pygame.Rect((WINDOW_W - BTN_W) // 2, ATK_Y[i], BTN_W, BTN_H)
            btn_rects.append(rect)
            all_options.append((side, diff))
            draw_button(screen, rect, label, font, rect.collidepoint(mouse_pos))

        pygame.display.flip()

        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit()
                sys.exit(0)
            if event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
                for i, rect in enumerate(btn_rects):
                    if rect.collidepoint(event.pos):
                        return all_options[i][0], all_options[i][1]


def draw_game_over(screen, big_font, font, winner, human_side):
    overlay = pygame.Surface((WINDOW_W, WINDOW_H), pygame.SRCALPHA)
    overlay.fill((0, 0, 0, 140))
    screen.blit(overlay, (0, 0))
    box = pygame.Rect(WINDOW_W // 2 - 190, WINDOW_H // 2 - 90, 380, 180)
    pygame.draw.rect(screen, COLOR_WIN_BG, box, border_radius=12)
    pygame.draw.rect(screen, COLOR_BTN_BORDER, box, 3, border_radius=12)

    if winner == human_side:
        outcome_color = (0, 120, 0)
        outcome_text  = "🏆  YOU WIN!"
    else:
        outcome_color = (160, 0, 0)
        outcome_text  = "💀  YOU LOSE!"

    t1 = big_font.render("GAME OVER", True, COLOR_TEXT)
    t2 = font.render(outcome_text, True, outcome_color)
    t3 = font.render(f"({winner.upper()} win the game)", True, (80, 60, 20))
    screen.blit(t1, t1.get_rect(center=(WINDOW_W // 2, box.top + 28)))
    screen.blit(t2, t2.get_rect(center=(WINDOW_W // 2, box.top + 62)))
    screen.blit(t3, t3.get_rect(center=(WINDOW_W // 2, box.top + 92)))

    btn_rect = pygame.Rect(WINDOW_W // 2 - 100, box.top + 120, 200, 44)
    mouse_pos = pygame.mouse.get_pos()
    draw_button(screen, btn_rect, "Play Again", font, btn_rect.collidepoint(mouse_pos))
    return btn_rect


def _opponent(player):
    return DEFENDERS if player == ATTACKERS else ATTACKERS


def process_click(board, current, cell, selected, legal_targets):
    # All legal moves come from Prolog
    legal_moves = get_legal_moves(board, current)

    # Complete a move if clicking a legal target
    if selected is not None and cell in legal_targets:
        # Build the move and find a matching Prolog move
        matching = [m for m in legal_moves if m[0] == selected and m[1] == cell]
        if matching:
            new_board = apply_move(board, matching[0])   # Prolog applies move + captures
            return None, [], new_board, _opponent(current)
        # Landed on a legal-target dot but Prolog didn't confirm — deselect cleanly
        return None, [], board, current

    # Select a friendly piece
    r, c = cell
    piece = get_cell(board, r, c)
    is_friendly = (
        (current == ATTACKERS and piece == ATTACKER) or
        (current == DEFENDERS and piece in (DEFENDER, KING))
    )
    if is_friendly:
        targets = [to for (frm, to) in legal_moves if frm == cell]
        return cell, targets, board, current

    # Clicking empty / enemy deselects
    return None, [], board, current


def main():
    pygame.init()
    screen     = pygame.display.set_mode((WINDOW_W, WINDOW_H))
    pygame.display.set_caption("Hnefatafl - Prolog Edition")
    big_font   = pygame.font.SysFont("arial", 30, bold=True)
    font       = pygame.font.SysFont("arial", 18, bold=True)
    small_font = pygame.font.SysFont("arial", 14)

    while True:
        human_side, difficulty = show_menu(screen, font, big_font, small_font)

        board         = initial_board()
        current       = ATTACKERS
        selected      = None
        legal_targets = []
        game_over     = False
        winner        = None
        status        = ""
        play_again_btn = None
        clock         = pygame.time.Clock()
        restart       = False

        while not restart:
            if not game_over:
                winner = check_winner(board)
                if winner is not None:
                    game_over = True
                    if winner == human_side:
                        status = f"🏆 YOU WIN! ({winner} win the game)"
                    else:
                        status = f"💀 YOU LOSE! ({winner} win the game)"

            if not game_over:
                if current == human_side:
                    status = f"Your turn ({current}) - click a piece to select"
                else:
                    status = f"AI ({current}) is thinking..."

            draw_board(screen, board, selected, legal_targets, status, font, small_font)
            if game_over:
                play_again_btn = draw_game_over(screen, big_font, font, winner, human_side)
            pygame.display.flip()

            if not game_over and current != human_side:
                pygame.time.wait(200)
                move = choose_move(board, current, difficulty)
                if move is None:
                    game_over = True
                    no_moves_side = current
                    winning_side  = _opponent(current)
                    if winning_side == human_side:
                        status = f"🏆 YOU WIN! ({no_moves_side} has no moves)"
                    else:
                        status = f"💀 YOU LOSE! ({no_moves_side} has no moves)"
                    winner = winning_side
                else:
                    board   = apply_move(board, move)
                    current = _opponent(current)
                selected      = None
                legal_targets = []
                continue

            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    pygame.quit()
                    return
                if event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
                    if game_over and play_again_btn and play_again_btn.collidepoint(event.pos):
                        restart = True
                        break
                    if not game_over:
                        cell = pixel_to_cell(*event.pos)
                        if cell is not None:
                            selected, legal_targets, board, current = process_click(
                                board, current, cell, selected, legal_targets
                            )

            clock.tick(30)


if __name__ == "__main__":
    main()
