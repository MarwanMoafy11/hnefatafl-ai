/* ============================================================
   controller.pl — Game Controller for Hnefatafl
   CS361: Artificial Intelligence — Cairo University

   NO libraries used. All predicates written from scratch.

   Handles:
     - Switching turns between human and computer
     - Reading human moves from stdin
     - Calling AI (alpha-beta) for computer moves
     - Detecting end of game
     - Printing the board after each move

   Attackers always move first.
   ============================================================ */

:- [game].   % load game logic (also has no libraries)

% ---------------------------------------------------------------
% Custom Helper Predicates 
% ---------------------------------------------------------------

% my_length(+List, -Length)
my_length([], 0).
my_length([_|T], N) :-
    my_length(T, N1),
    N is N1 + 1.

% my_member(+Elem, +List)
my_member_c(X, [X|_]) :- !.
my_member_c(X, [_|T]) :- my_member_c(X, T).

% ---------------------------------------------------------------
% Board Printing
% ---------------------------------------------------------------

print_board(Board) :-
    nl,
    write('    '),
    print_col_headers(0), nl,
    write('    '),
    print_separator(0), nl,
    print_rows(Board, 0),
    nl.

print_col_headers(11) :- !.
print_col_headers(C) :-
    ( C < 10 -> format("  ~w ", [C]) ; format(" ~w ", [C]) ),
    C1 is C + 1,
    print_col_headers(C1).

print_separator(11) :- !.
print_separator(C) :-
    write('----'),
    C1 is C + 1,
    print_separator(C1).

print_rows(_, 11) :- !.
print_rows(Board, R) :-
    ( R < 10 -> format(" ~w | ", [R]) ; format("~w | ", [R]) ),
    print_row_cells(Board, R, 0), nl,
    R1 is R + 1,
    print_rows(Board, R1).

print_row_cells(_, _, 11) :- !.
print_row_cells(Board, R, C) :-
    get_cell(Board, R, C, Cell),
    cell_symbol(R, C, Cell, Sym),
    format(" ~w  ", [Sym]),
    C1 is C + 1,
    print_row_cells(Board, R, C1).

cell_symbol(R, C, empty,    'X') :- corner(R, C), !.
cell_symbol(5, 5, empty,    'T') :- !.
cell_symbol(_, _, empty,    '.') :- !.
cell_symbol(_, _, attacker, 'A') :- !.
cell_symbol(_, _, defender, 'D') :- !.
cell_symbol(_, _, king,     'K') :- !.

% ---------------------------------------------------------------
% Format move for display
% ---------------------------------------------------------------

format_move(move(Fr, Fc, Tr, Tc)) :-
    format("(~w,~w) -> (~w,~w)", [Fr, Fc, Tr, Tc]).

% ---------------------------------------------------------------
% Human Move Input
% ---------------------------------------------------------------

get_human_move(Board, Player, Move) :-
    legal_moves(Board, Player, LegalMoves),
    my_length(LegalMoves, N),
    format("Your turn (~w). Legal moves available: ~w~n", [Player, N]),
    format("Enter move as: move(FromRow,FromCol,ToRow,ToCol).~n"),
    format("Example: move(0,3,2,3).~n"),
format("(or type quit. to exit)~n"),
write("> "),
read_move(LegalMoves, Move).

read_move(LegalMoves, Move) :-
    read(Input),
    ( Input == quit ->
        format("Goodbye!~n"), halt
    ; Input = move(Fr, Fc, Tr, Tc),
      my_member_c(move(Fr, Fc, Tr, Tc), LegalMoves) ->
        Move = move(Fr, Fc, Tr, Tc)
    ;
        format("Invalid move. Try again.~n> "),
        read_move(LegalMoves, Move)
    ).

% ---------------------------------------------------------------
% Game Loop
% ---------------------------------------------------------------

play_game(HumanSide, Difficulty) :-
    initial_board(Board),
    format("~n=== HNEFATAFL [Prolog Edition] ===~n"),
    format("You play  : ~w~n", [HumanSide]),
    format("Difficulty: ~w~n", [Difficulty]),
    format("Attackers move first.~n"),
    format("Enter moves as: move(FromRow,FromCol,ToRow,ToCol).~n~n"),
    print_board(Board),
    game_loop(Board, attackers, HumanSide, Difficulty).

game_loop(Board, Current, HumanSide, Difficulty) :-
    check_winner(Board, Winner),
    ( Winner \= none ->
        format("~n=== GAME OVER: ~w win! ===~n", [Winner]),
        ( Winner == HumanSide ->
            format("*** YOU WIN! Congratulations! ***~n")
        ;
            format("*** YOU LOSE! Better luck next time. ***~n")
        )
    ;
        legal_moves(Board, Current, Moves),
        ( Moves == [] ->
            opponent(Current, Opp),
            format("~w has no legal moves. ~w wins!~n", [Current, Opp]),
            ( Opp == HumanSide ->
                format("*** YOU WIN! Congratulations! ***~n")
            ;
                format("*** YOU LOSE! Better luck next time. ***~n")
            )
        ;
            make_move(Board, Current, HumanSide, Difficulty, Move),
            apply_move(Board, Move, NewBoard),
            print_board(NewBoard),
            opponent(Current, Next),
            game_loop(NewBoard, Next, HumanSide, Difficulty)
        )
    ).

make_move(Board, Current, HumanSide, _, Move) :-
    Current == HumanSide, !,
    get_human_move(Board, Current, Move).
make_move(Board, Current, _, Difficulty, Move) :-
    format("AI (~w) is thinking...~n", [Current]),
    choose_move(Board, Current, Difficulty, Move),
    format("AI plays: "),
    format_move(Move), nl.

% ---------------------------------------------------------------
% Entry Point
% ---------------------------------------------------------------

start :-
    format("~n=== HNEFATAFL ===~n"),
    format("Pick your side:~n"),
    format("  1) Defenders  (escape with the king)~n"),
    format("  2) Attackers  (capture the king)~n> "),
    read(SideChoice),
    ( SideChoice == 2 -> Side = attackers ; Side = defenders ),
    format("Pick difficulty:~n"),
    format("  1) Easy   (depth 1)~n"),
    format("  2) Medium (depth 3)~n"),
    format("  3) Hard   (depth 5)~n> "),
    read(DiffChoice),
    ( DiffChoice == 1 -> Diff = easy
    ; DiffChoice == 3 -> Diff = hard
    ; Diff = medium
    ),
    play_game(Side, Diff).

:- initialization(start, main).
