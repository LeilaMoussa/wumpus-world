:- abolish(stench/1).
:- abolish(breeze/1).
:- abolish(glitter/1).
:- abolish(scream/1).
:- abolish(safe/1).
:- abolish(visited/2).
:- abolish(has_wumpus/2).
:- abolish(has_pit/2).
:- abolish(current_safest_cell/1).

:- dynamic([
  stench/1,
  breeze/1,
  glitter/1,
  scream/1,
  safe/1,
  visited/2,
  has_wumpus/2,
  has_pit/2,
  current_safest_cell/1
]).

no_surrounding_pit(room(A,B)) :- adjacent(room(X,Y), room(A, B)), not(has_pit(room(X,Y), yes)).

no_surrounding_wumpus(room(A,B)) :- adjacent(room(X,Y), room(A, B)), not(has_wumpus(room(X,Y), yes)).

all_adjacent_visited(room(A,B)) :- adjacent(room(X,Y), room(A, B)), not(visited(room(X,Y), _)) , !, fail.

check_for_pit() :- breeze(room(A,B)), adjacent(room(X,Y), room(A, B)), (no_surrounding_pit(room(A,B)); all_adjacent_visited(room(A,B))),
          room(X, Y) \== room(1, 1),
          not(has_pit(room(X, Y), no)),
          not(has_wumpus(room(X, Y), yes)),
          retractall(has_pit(room(X, Y), _)),
          asserta(has_pit(room(X, Y), yes)).

check_for_wumpus() :- stench(room(A,B)), adjacent(room(X,Y), room(A, B)), (no_surrounding_wumpus(room(A,B)); all_adjacent_visited(room(A,B))),
          room(X, Y) \== room(1, 1),
          not(has_wumpus(room(X, Y), no)), % otherwise, I say yes after having said no
          retractall(has_wumpus(room(X, Y), _)),
          asserta(has_wumpus(room(X, Y), yes)).

has_wumpus(room(X,Y), no) :- position(room(A, B), _), adjacent(room(X,Y), room(A, B)), not(stench(room(A,B))), !.

has_wumpus(room(X,Y), no) :- has_pit(room(X,Y), yes).

has_wumpus(room(X,Y), maybe) :- not(has_wumpus(room(X, Y), yes)), not(has_wumpus(room(X, Y), no)), not(has_pit(room(X,Y), yes)),
                                adjacent(room(X,Y), room(A, B)) , stench(room(A,B)), !.

tell_kb(breeze, room(X, Y)) :- retractall(breeze(room(X, Y))), assertz(breeze(room(X,Y))).
tell_kb(stench, room(X, Y)) :- retractall(stench(room(X, Y))), assertz(stench(room(X,Y))).
tell_kb(glitter, room(X, Y)) :- retractall(glitter(room(X, Y))), assertz(glitter(room(X,Y))).
tell_kb(scream) :- assertz(scream(yes)).

% HEURISTICS
heuristic([_, _, _, yes]) :-  write('Congrats... You won!'), halt.

% opportunistically grab the gold
heuristic([_, _, yes, _]) :- position(room(X, Y), _), tell_kb(glitter, room(X, Y)), grab_gold().

% To just get it over with:
heuristic(_) :- position(room(X, Y), T), T > 10, random(0, 5, A), random(0, 5, B),
                explorableRooms(E), member(room(A, B), E), not(visited(room(A, B), _)), !,
                travel(room(X, Y), room(A, B), T).

heuristic([yes, _, _, _]) :- position(room(X, Y), T), adjacent(room(A, B), room(X, Y)),
                            room(A, B) \== room(1, 1),
                            not(has_pit(room(A, B), yes)),
                            not(has_pit(room(A, B), no)),
                            not(has_wumpus(room(A, B), yes)),
                            not(has_wumpus(room(A, B), no)),
                            not(has_wumpus(room(A, B), maybe)), % to avoid redundancy
                            asserta(has_wumpus(room(A, B), maybe)).

% if i sense a stench and i said wumpus maybe or wumpus yes for a non adjacent cell to me
% make them no
heuristic([yes, _, _, _]) :- (has_wumpus(room(X, Y), yes); has_wumpus(room(X, Y), maybe)),
                          position(R, T),
                          not(adjacent(room(X, Y), R)),
                          retractall(has_wumpus(room(X, Y), _)),
                          asserta(has_wumpus(room(X, Y), no)).

heuristic([yes, _, _, _]) :- position(room(X, Y), T), tell_kb(stench, room(X, Y)), adjacent(room(X, Y), room(A, B)),
                                          has_wumpus(room(A,B), yes), !, shoot(room(A, B), T).

heuristic([_, yes, _, _]) :- position(room(X, Y), T), tell_kb(breeze, room(X, Y)),
                            adjacent(room(X, Y), room(A, B)),
                            room(A, B) \== room(1, 1),
                            not(has_pit(room(A, B), yes)),
                            not(has_pit(room(A, B), no)),
                            not(has_wumpus(room(A, B), yes)),
                            not(has_wumpus(room(A, B), no)),
                            retractall(has_pit(room(A, B), maybe)),
                            asserta(has_pit(room(A, B), maybe)).

heuristic([_, no, _, _]) :- position(room(X, Y), T), adjacent(room(A, B), room(X, Y)),
                            retractall(has_pit(room(A, B), _)),
                            asserta(has_pit(room(A, B), no)).

% If not sure where the wumpus is, move to the safest explorable room
heuristic([yes, _, _, _]) :- position(room(X, Y), T), tell_kb(stench, room(X, Y)), current_safest_cell(room(A, B)),
                                          findall(R, visited(R, T), V),
                                          nth0(0, V, Last),
                                          room(A, B) \== Last, !,
                                          travel(room(X, Y), room(A, B), T).

% If not sure where the wumpus is, and no adjacent room is maybe safe, shoot any random adjacent room where there may be the wumpus
heuristic([yes, _, _, _]) :- position(room(X, Y), T), tell_kb(stench, room(X, Y)), adjacent(room(X, Y), room(A, B)),
                            has_wumpus(room(A,B), maybe), !, shoot(room(A, B), T).

heuristic([no, _, _, _]) :- position(room(X, Y), T), adjacent(room(A, B), room(X, Y)),
                            retractall(has_wumpus(room(A, B), _)),
                            asserta(has_wumpus(room(A, B), no)).

heuristic([no, no, _, _]) :- position(room(X, Y), T), adjacent(room(X, Y), room(A, B)), asserta(safe(room(A, B))),
                            retractall(has_wumpus(room(A, B), _)), retractall(has_pit(room(A, B), _)),
                            asserta(has_wumpus(room(A, B), no)), asserta(has_pit(room(A, B), no)),
                            current_safest_cell(room(C, D)),
                            travel(room(X, Y), room(C, D), T).

heuristic([_, yes, _, _]) :- current_safest_cell(room(C, D)), position(room(X, Y), T),
                            travel(room(X, Y), room(C, D), T).

explorableRooms(L) :- position(room(X,Y), _),
                      findall(room(A,B), adjacent(room(X, Y), room(A, B)), L1),
                      findall(room(C,D), visited(room(C,D),_), L2),
                      findall(L3, adjacent_to_visited(L3) ,L4),
                      flatten(L4, L5),
                      append([L1, L2, L5], R),
                      remove_duplicates(R, L).

adjacent_to_visited(L) :- visited(room(X,Y), _), findall(room(A,B), adjacent(room(X, Y), room(A, B)), L).

remove_duplicates([], []).
remove_duplicates([Head | Tail], Result) :-
    member(Head, Tail), !,
    remove_duplicates(Tail, Result).
remove_duplicates([Head | Tail], [Head | Result]) :-
    remove_duplicates(Tail, Result).

current_safest_cell(room(X, Y)) :- findall(S, total_current_score(room(_, _), S), L),
                                  min_list(L, MinScore),
                                  min_score_room(MinScore, room(X, Y)),
                                  position(room(A, B), T),
                                  room(A, B) \== room(X, Y), !.

min_score_room(MinVal, room(X, Y)) :- total_current_score(room(X, Y), MinVal).

total_current_score(room(X, Y), S) :- safe(room(X, Y)), S is 0.
total_current_score(room(X, Y), S) :- findall(P, partial_score(room(X, Y), P), L), sum_list(L, S).

partial_score(room(X, Y), S) :- explorableRooms(E), member(room(X, Y), E), has_pit(room(X, Y), yes), S is 2000.
partial_score(room(X, Y), S) :- explorableRooms(E), member(room(X, Y), E), has_wumpus(room(X, Y), yes), S is 2000.
partial_score(room(X, Y), S) :- explorableRooms(E), member(room(X, Y), E), has_pit(room(X, Y), maybe), S is 500.
partial_score(room(X, Y), S) :- explorableRooms(E), member(room(X, Y), E), has_wumpus(room(X, Y), maybe), S is 900.
partial_score(room(X, Y), Def) :- Def is 0.
