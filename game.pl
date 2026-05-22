/* ============================================================
   Hnefatafl — Full Game Logic in Prolog
   CS361: Artificial Intelligence — Cairo University

   NO external libraries used. All predicates implemented
   from scratch including list operations, math helpers,
   board access, move generation, captures, utility function,
   and alpha-beta pruning.

   Board: flat list of 121 atoms (11x11 grid)
   Index = Row * 11 + Col  (0-based)
   ============================================================ */



% my_nth0(+Index, +List, -Element)
my_nth0(0, [H|_], H) :- !.
my_nth0(N, [_|T], E) :-
    N > 0,
    N1 is N - 1,
    my_nth0(N1, T, E).

% my_set_nth0(+Index, +List, +Value, -NewList)
my_set_nth0(0, [_|T], Val, [Val|T]) :- !.
my_set_nth0(N, [H|T], Val, [H|T2]) :-
    N > 0,
    N1 is N - 1,
    my_set_nth0(N1, T, Val, T2).

% my_member(+Elem, +List)
my_member(X, [X|_]) :- !.
my_member(X, [_|T]) :- my_member(X, T).

% make_list(+N, +Elem, -List)
make_list(0, _, []) :- !.
make_list(N, E, [E|T]) :-
    N > 0,
    N1 is N - 1,
    make_list(N1, E, T).

% count_in_list(+Elem, +List, -Count)
count_in_list(_, [], 0).
count_in_list(E, [E|T], N) :-
    !,
    count_in_list(E, T, N1),
    N is N1 + 1.
count_in_list(E, [_|T], N) :-
    count_in_list(E, T, N).

% my_min(+A, +B, -Min)
my_min(A, B, A) :- A =< B, !.
my_min(_, B, B).

% my_max(+A, +B, -Max)
my_max(A, B, A) :- A >= B, !.
my_max(_, B, B).

% min_of_list(+List, -Min)
min_of_list([X], X).
min_of_list([H|T], Min) :-
    min_of_list(T, MinT),
    my_min(H, MinT, Min).

% place_pieces(+Piece, +PosList, +BoardIn, -BoardOut)
place_pieces(_, [], B, B).
place_pieces(Piece, [(R,C)|Rest], Bin, Bout) :-
    set_cell(Bin, R, C, Piece, Bmid),
    place_pieces(Piece, Rest, Bmid, Bout).

% ---------------------------------------------------------------
% Board Constants
% ---------------------------------------------------------------
board_size(11).
throne(5, 5).
corner(0,  0).
corner(0, 10).
corner(10, 0).
corner(10,10).

special_square(R, C) :- corner(R, C).
special_square(5, 5).

in_bounds(R, C) :-
    R >= 0, R < 11,
    C >= 0, C < 11.

index(R, C, Idx) :-
    Idx is R * 11 + C.

% ---------------------------------------------------------------
% Cell Access
% ---------------------------------------------------------------
get_cell(Board, R, C, Cell) :-
    index(R, C, Idx),
    my_nth0(Idx, Board, Cell).

set_cell(Board, R, C, Cell, NewBoard) :-
    index(R, C, Idx),
    my_set_nth0(Idx, Board, Cell, NewBoard).

% ---------------------------------------------------------------
% Initial Board
% ---------------------------------------------------------------
initial_board(Board) :-
    make_list(121, empty, Board0),
    set_cell(Board0, 5, 5, king, B1),
    place_pieces(defender,
        [(3,5),(4,4),(4,5),(4,6),
         (5,3),(5,4),(5,6),(5,7),
         (6,4),(6,5),(6,6),(7,5)],
        B1, B2),
    place_pieces(attacker,
        [(0,3),(0,4),(0,5),(0,6),(0,7),(1,5),
         (10,3),(10,4),(10,5),(10,6),(10,7),(9,5),
         (3,0),(4,0),(5,0),(6,0),(7,0),(5,1),
         (3,10),(4,10),(5,10),(6,10),(7,10),(5,9)],
        B2, Board).

% ---------------------------------------------------------------
% Piece Ownership
% ---------------------------------------------------------------
belongs_to(attacker, attackers).
belongs_to(defender, defenders).
belongs_to(king,     defenders).

% ---------------------------------------------------------------
% Legal Moves
% ---------------------------------------------------------------
direction(-1,  0).
direction( 1,  0).
direction( 0, -1).
direction( 0,  1).

legal_moves(Board, Player, Moves) :-
    findall(move(Fr,Fc,Tr,Tc),
        ( between(0, 10, Fr),
          between(0, 10, Fc),
          get_cell(Board, Fr, Fc, Piece),
          belongs_to(Piece, Player),
          direction(Dr, Dc),
          slide(Board, Fr, Fc, Dr, Dc, Piece, Tr, Tc)
        ),
        Moves).

slide(Board, R, C, Dr, Dc, Piece, Tr, Tc) :-
    R1 is R + Dr, C1 is C + Dc,
    slide_step(Board, R1, C1, Dr, Dc, Piece, Tr, Tc).

slide_step(Board, R, C, Dr, Dc, Piece, Tr, Tc) :-
    in_bounds(R, C),
    get_cell(Board, R, C, empty),
    ( special_square(R, C) ->
        ( Piece == king ->
            Tr = R, Tc = C
        ;
            R1 is R + Dr, C1 is C + Dc,
            slide_step(Board, R1, C1, Dr, Dc, Piece, Tr, Tc)
        )
    ;
        ( Tr = R, Tc = C
        ; R1 is R + Dr, C1 is C + Dc,
          slide_step(Board, R1, C1, Dr, Dc, Piece, Tr, Tc)
        )
    ).

% ---------------------------------------------------------------
% Apply Move and Resolve Captures
% ---------------------------------------------------------------
apply_move(Board, move(Fr, Fc, Tr, Tc), NewBoard) :-
    get_cell(Board, Fr, Fc, Piece),
    set_cell(Board, Fr, Fc, empty, B1),
    set_cell(B1,    Tr, Tc, Piece, B2),
    resolve_captures(B2, Tr, Tc, NewBoard).

resolve_captures(Board, R, C, NewBoard) :-
    get_cell(Board, R, C, Mover),
    resolve_dir(Board, R, C, Mover, -1, 0, B1),
    resolve_dir(B1,   R, C, Mover,  1, 0, B2),
    resolve_dir(B2,   R, C, Mover,  0,-1, B3),
    resolve_dir(B3,   R, C, Mover,  0, 1, NewBoard).

resolve_dir(Bin, R, C, Mover, Dr, Dc, Bout) :-
    Ar is R + Dr, Ac is C + Dc,
    ( in_bounds(Ar, Ac) ->
        get_cell(Bin, Ar, Ac, Adj),
        ( Adj \= empty, \+ same_side(Mover, Adj) ->
            ( Adj == king ->
                ( king_captured(Bin, Ar, Ac) ->
                    set_cell(Bin, Ar, Ac, empty, Bout)
                ;   Bout = Bin
                )
            ;
                Fr is Ar + Dr, Fc is Ac + Dc,
                ( hostile_square(Bin, Fr, Fc, Adj) ->
                    set_cell(Bin, Ar, Ac, empty, Bout)
                ;   Bout = Bin
                )
            )
        ;   Bout = Bin
        )
    ;   Bout = Bin
    ).

same_side(attacker, attacker).
same_side(defender, defender).
same_side(defender, king).
same_side(king,     defender).
same_side(king,     king).

hostile_square(Board, R, C, TargetPiece) :-
    in_bounds(R, C),
    get_cell(Board, R, C, Occ),
    ( Occ == empty, special_square(R, C) -> true
    ; TargetPiece == attacker -> Occ == defender
    ; Occ == attacker
    ).

king_captured(Board, Kr, Kc) :-
    king_side_blocked(Board, Kr, Kc, -1,  0),
    king_side_blocked(Board, Kr, Kc,  1,  0),
    king_side_blocked(Board, Kr, Kc,  0, -1),
    king_side_blocked(Board, Kr, Kc,  0,  1).

king_side_blocked(Board, Kr, Kc, Dr, Dc) :-
    Nr is Kr + Dr, Nc is Kc + Dc,
    ( \+ in_bounds(Nr, Nc) -> true
    ; get_cell(Board, Nr, Nc, Cell),
      ( Cell == attacker -> true
      ; Cell == empty, special_square(Nr, Nc)
      )
    ).

% ---------------------------------------------------------------
% Win Conditions
% ---------------------------------------------------------------
find_king(Board, Kr, Kc) :-
    between(0, 10, Kr),
    between(0, 10, Kc),
    get_cell(Board, Kr, Kc, king), !.

check_winner(Board, defenders) :-
    find_king(Board, Kr, Kc),
    corner(Kr, Kc), !.
check_winner(Board, attackers) :-
    \+ find_king(Board, _, _), !.
check_winner(_, none).

is_terminal(Board) :-
    check_winner(Board, W), W \= none.

% ---------------------------------------------------------------
% Utility / Evaluation Function
% ---------------------------------------------------------------
win_score(100000).

evaluate(Board, Player, Score) :-
    check_winner(Board, Winner),
    ( Winner \= none ->
        win_score(W),
        ( Winner == Player -> Score = W ; Score is -W )
    ;
        heuristic(Board, Player, Score)
    ).

heuristic(Board, Player, Score) :-
    count_in_list(attacker, Board, Attackers),
    count_in_list(defender, Board, Defenders),
    Material is Attackers - Defenders * 2,
    find_king(Board, Kr, Kc),
    king_dist_to_corner(Kr, Kc, Dist),
    count_attackers_near_king(Board, Kr, Kc, NearKing),
    ( king_clear_path(Board, Kr, Kc) -> PathBonus = 10000 ; PathBonus = 0 ),
    AttackerScore is Material + Dist * 3 + NearKing * 5 - PathBonus,
    ( Player == attackers -> Score = AttackerScore
    ; Score is -AttackerScore
    ).

king_dist_to_corner(Kr, Kc, Dist) :-
    D1 is abs(Kr)    + abs(Kc),
    D2 is abs(Kr)    + abs(Kc-10),
    D3 is abs(Kr-10) + abs(Kc),
    D4 is abs(Kr-10) + abs(Kc-10),
    min_of_list([D1,D2,D3,D4], Dist).

count_attackers_near_king(Board, Kr, Kc, N) :-
    check_adj_attacker(Board, Kr, Kc, -1,  0, N1),
    check_adj_attacker(Board, Kr, Kc,  1,  0, N2),
    check_adj_attacker(Board, Kr, Kc,  0, -1, N3),
    check_adj_attacker(Board, Kr, Kc,  0,  1, N4),
    N is N1 + N2 + N3 + N4.

check_adj_attacker(Board, Kr, Kc, Dr, Dc, 1) :-
    Nr is Kr + Dr, Nc is Kc + Dc,
    in_bounds(Nr, Nc),
    get_cell(Board, Nr, Nc, attacker), !.
check_adj_attacker(_, _, _, _, _, 0).

king_clear_path(Board, Kr, Kc) :-
    corner(Cr, Cc),
    ( Kr =:= Cr ->
        ( Cc > Kc -> Step = 1 ; Step = -1 ),
        path_clear_row(Board, Kr, Kc, Cc, Step)
    ; Kc =:= Cc ->
        ( Cr > Kr -> Step = 1 ; Step = -1 ),
        path_clear_col(Board, Kc, Kr, Cr, Step)
    ), !.

path_clear_row(_, _, C, C, _) :- !.
path_clear_row(Board, R, C, Cc, Step) :-
    Cn is C + Step,
    ( Cn =:= Cc -> true
    ; get_cell(Board, R, Cn, empty),
      path_clear_row(Board, R, Cn, Cc, Step)
    ).

path_clear_col(_, _, R, R, _) :- !.
path_clear_col(Board, C, R, Cr, Step) :-
    Rn is R + Step,
    ( Rn =:= Cr -> true
    ; get_cell(Board, Rn, C, empty),
      path_clear_col(Board, C, Rn, Cr, Step)
    ).

% ---------------------------------------------------------------
% Alpha-Beta Pruning
% ---------------------------------------------------------------
difficulty_depth(easy,   1).
difficulty_depth(medium, 3).
difficulty_depth(hard,   5).

opponent(attackers, defenders).
opponent(defenders, attackers).

choose_move(Board, Player, Difficulty, BestMove) :-
    difficulty_depth(Difficulty, Depth),
    legal_moves(Board, Player, Moves),
    Moves \= [],
    win_score(W),
    NegInf is -W,
    opponent(Player, Opp),
    D1 is Depth - 1,
    ab_root(Board, Moves, Opp, Player, D1, NegInf, W, _BestScore, BestMove).

ab_root(_, [], _, _, _, BestScore, _, BestScore, _).
ab_root(Board, [Move|Rest], Opp, RootPlayer, Depth, Alpha, Beta, BestScore, BestMove) :-
    apply_move(Board, Move, NewBoard),
    ab(NewBoard, Opp, RootPlayer, Depth, Alpha, Beta, Score0),
    Score is -Score0,
    ( Score > Alpha ->
        Alpha1 = Score,
        TmpBest = Move
    ;
        Alpha1 = Alpha,
        TmpBest = _
    ),
    ab_root(Board, Rest, Opp, RootPlayer, Depth, Alpha1, Beta, RestScore, RestMove),
    ( nonvar(RestMove), RestScore >= Alpha1 ->
        BestScore = RestScore, BestMove = RestMove
    ; nonvar(TmpBest) ->
        BestScore = Alpha1, BestMove = TmpBest
    ;
        BestScore = Alpha, BestMove = Move
    ).

ab(Board, _Current, RootPlayer, _Depth, _Alpha, _Beta, Score) :-
    is_terminal(Board), !,
    evaluate(Board, RootPlayer, Score).
ab(Board, _Current, RootPlayer, 0, _Alpha, _Beta, Score) :- !,
    evaluate(Board, RootPlayer, Score).
ab(Board, Current, RootPlayer, Depth, Alpha, Beta, Score) :-
    legal_moves(Board, Current, Moves),
    ( Moves == [] ->
        win_score(W),
        ( Current == RootPlayer -> Score is -W ; Score = W )
    ;
        opponent(Current, Next),
        D1 is Depth - 1,
        ( Current == RootPlayer ->
            ab_max(Board, Moves, Next, RootPlayer, D1, Alpha, Beta, Score)
        ;
            ab_min(Board, Moves, Next, RootPlayer, D1, Alpha, Beta, Score)
        )
    ).

ab_max(_, [], _, _, _, Alpha, _, Alpha).
ab_max(Board, [Move|Rest], Next, RootPlayer, Depth, Alpha, Beta, Score) :-
    ( Alpha >= Beta ->
        Score = Alpha
    ;
        apply_move(Board, Move, NewBoard),
        ab(NewBoard, Next, RootPlayer, Depth, Alpha, Beta, S),
        my_max(Alpha, S, Alpha1),
        ab_max(Board, Rest, Next, RootPlayer, Depth, Alpha1, Beta, Score)
    ).

ab_min(_, [], _, _, _, Beta, _, Beta).
ab_min(Board, [Move|Rest], Next, RootPlayer, Depth, Alpha, Beta, Score) :-
    ( Beta =< Alpha ->
        Score = Beta
    ;
        apply_move(Board, Move, NewBoard),
        ab(NewBoard, Next, RootPlayer, Depth, Alpha, Beta, S),
        my_min(Beta, S, Beta1),
        ab_min(Board, Rest, Next, RootPlayer, Depth, Alpha, Beta1, Score)
    ).

% ---------------------------------------------------------------
% Interface for Python Bridge
% ---------------------------------------------------------------
:- dynamic memo_board/1.

run_query(initial_board) :-
    initial_board(B),
    format("~w~n", [B]).

run_query(legal_moves(BoardAtom, Player)) :-
    term_to_atom(Board, BoardAtom),
    legal_moves(Board, Player, Moves),
    format("~w~n", [Moves]).

run_query(apply_move(BoardAtom, MoveAtom)) :-
    term_to_atom(Board, BoardAtom),
    term_to_atom(Move,  MoveAtom),
    apply_move(Board, Move, NewBoard),
    format("~w~n", [NewBoard]).

run_query(check_winner(BoardAtom)) :-
    term_to_atom(Board, BoardAtom),
    check_winner(Board, W),
    format("~w~n", [W]).

run_query(choose_move(BoardAtom, Player, Difficulty)) :-
    term_to_atom(Board, BoardAtom),
    ( choose_move(Board, Player, Difficulty, BestMove) ->
        format("~w~n", [BestMove])
    ;
        format("none~n", [])
    ).

run_query(evaluate(BoardAtom, Player)) :-
    term_to_atom(Board, BoardAtom),
    evaluate(Board, Player, Score),
    format("~w~n", [Score]).
