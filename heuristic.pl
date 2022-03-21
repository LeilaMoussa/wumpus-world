% `abolish` and `dynamic` are required for predicates that are asserted or retracted at runtime.
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

% Three utility predicates that help us check whether we are sure there is a pit or wumpus in some room.
no_surrounding_pit(room(A,B)) :- adjacent(room(X,Y), room(A, B)), not(has_pit(room(X,Y), yes)).
no_surrounding_wumpus(room(A,B)) :- adjacent(room(X,Y), room(A, B)), not(has_wumpus(room(X,Y), yes)).
all_adjacent_visited(room(A,B)) :- adjacent(room(X,Y), room(A, B)), not(visited(room(X,Y), _)) , !, fail.

% These predicates allow us to assert has_*(_, yes), where * is the danger.
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

% These predicates are simply abstractions of the TELL interface.
% We wrote these early on, but we really could have gone without them,
% in favor of a more straightforward way of adding perceptions to the knowledge base.
tell_kb(breeze, room(X, Y)) :- retractall(breeze(room(X, Y))), assertz(breeze(room(X,Y))).
tell_kb(stench, room(X, Y)) :- retractall(stench(room(X, Y))), assertz(stench(room(X,Y))).
tell_kb(glitter, room(X, Y)) :- retractall(glitter(room(X, Y))), assertz(glitter(room(X,Y))).
tell_kb(scream) :- assertz(scream(yes)).

% The following predicates execute the best action to carry out next,
% based on current knowledge, perceptions, and conditions.

% If you perceive a scream, you've won.
heuristic([_, _, _, yes]) :-  write('Congrats... You won!'), halt.

% Opportunistically grab the gold.
heuristic([_, _, yes, _]) :- position(room(X, Y), _), tell_kb(glitter, room(X, Y)), grab_gold().

% If we're passed the 10th timestamp and we haven't already won or lost, prod the agent
% into traveling somewhere new at random.
heuristic(_) :- position(room(X, Y), T), T > 10, random(0, 5, A), random(0, 5, B),
                explorableRooms(E), member(room(A, B), E), not(visited(room(A, B), _)), !,
                travel(room(X, Y), room(A, B), T).

% If you perceive a stench, update guesses about surrounding rooms.
heuristic([yes, _, _, _]) :- position(room(X, Y), T), adjacent(room(A, B), room(X, Y)),
                            % room(1, 1) could never have a wumpus.
                            room(A, B) \== room(1, 1),
                            % Don't override certainties with uncertainties.
                            not(has_pit(room(A, B), yes)),
                            not(has_pit(room(A, B), no)),
                            not(has_wumpus(room(A, B), yes)),
                            not(has_wumpus(room(A, B), no)),
                            % Avoid redundancy in the KB.
                            not(has_wumpus(room(A, B), maybe)),
                            asserta(has_wumpus(room(A, B), maybe)).

% If you sense a stench, rule out the non-adjacent rooms to you that you previously thought
% contained or may have contained a wumpus.
heuristic([yes, _, _, _]) :- (has_wumpus(room(X, Y), yes); has_wumpus(room(X, Y), maybe)),
                          position(R, T),
                          not(adjacent(room(X, Y), R)),
                          retractall(has_wumpus(room(X, Y), _)),
                          asserta(has_wumpus(room(X, Y), no)).

% Once you're sure where the wumpus is and you're in a position to shoot at it, shoot.
heuristic([yes, _, _, _]) :- position(room(X, Y), T), tell_kb(stench, room(X, Y)), adjacent(room(X, Y), room(A, B)),
                          has_wumpus(room(A,B), yes), !, shoot(room(A, B), T).

% There may be a pit surrounding a breeze.
heuristic([_, yes, _, _]) :- position(room(X, Y), T), tell_kb(breeze, room(X, Y)),
                            adjacent(room(X, Y), room(A, B)),
                            room(A, B) \== room(1, 1),
                            not(has_pit(room(A, B), yes)),
                            not(has_pit(room(A, B), no)),
                            not(has_wumpus(room(A, B), yes)),
                            not(has_wumpus(room(A, B), no)),
                            retractall(has_pit(room(A, B), maybe)),
                            asserta(has_pit(room(A, B), maybe)).

% There's definitely no pit adjacent to a non-breezy room.
heuristic([_, no, _, _]) :- position(room(X, Y), T), adjacent(room(A, B), room(X, Y)),
                            retractall(has_pit(room(A, B), _)),
                            asserta(has_pit(room(A, B), no)).

% If not sure where the wumpus is, move to the safest explorable room.
heuristic([yes, _, _, _]) :- position(room(X, Y), T), tell_kb(stench, room(X, Y)), current_safest_cell(room(A, B)),
                                          findall(R, visited(R, T), V),
                                          % Make sure we weren't *just* in that place we're about to move to.
                                          nth0(0, V, Last),
                                          room(A, B) \== Last, !,
                                          travel(room(X, Y), room(A, B), T).

% If not sure where the wumpus is, and the safest room is not practical, shoot any random adjacent room where there may be the wumpus.
heuristic([yes, _, _, _]) :- position(room(X, Y), T), tell_kb(stench, room(X, Y)), adjacent(room(X, Y), room(A, B)),
                            has_wumpus(room(A,B), maybe), !, shoot(room(A, B), T).

% There's definitely no wumpus around if we don't sense a stench.
heuristic([no, _, _, _]) :- position(room(X, Y), T), adjacent(room(A, B), room(X, Y)),
                            retractall(has_wumpus(room(A, B), _)),
                            asserta(has_wumpus(room(A, B), no)).

% If there's no perception of danger, just move anywhere safe.
heuristic([no, no, _, _]) :- position(room(X, Y), T), adjacent(room(X, Y), room(A, B)), asserta(safe(room(A, B))),
                            retractall(has_wumpus(room(A, B), _)), retractall(has_pit(room(A, B), _)),
                            asserta(has_wumpus(room(A, B), no)), asserta(has_pit(room(A, B), no)),
                            current_safest_cell(room(C, D)),
                            travel(room(X, Y), room(C, D), T).

% Move away from the potential danger of a pit.
heuristic([_, yes, _, _]) :- current_safest_cell(room(C, D)), position(room(X, Y), T),
                            travel(room(X, Y), room(C, D), T).

% Define the rooms we would like to be free to explore:
% visited, adjacent, and adjacent to visited, because the assumption is that we have some hunch on them.
explorableRooms(L) :- position(room(X,Y), _),
                      findall(room(A,B), adjacent(room(X, Y), room(A, B)), L1),
                      findall(room(C,D), visited(room(C,D),_), L2),
                      findall(L3, adjacent_to_visited(L3) ,L4),
                      flatten(L4, L5),
                      append([L1, L2, L5], R),
                      remove_duplicates(R, L).

% Utility predicates.
adjacent_to_visited(L) :- visited(room(X,Y), _), findall(room(A,B), adjacent(room(X, Y), room(A, B)), L).

remove_duplicates([], []).
remove_duplicates([Head | Tail], Result) :-
    member(Head, Tail), !,
    remove_duplicates(Tail, Result).
remove_duplicates([Head | Tail], [Head | Result]) :-
    remove_duplicates(Tail, Result).

% Find the room with the minimum total current risk factor.
current_safest_cell(room(X, Y)) :- findall(S, total_current_score(room(_, _), S), L),
                                  min_list(L, MinScore),
                                  min_score_room(MinScore, room(X, Y)),
                                  position(room(A, B), T),
                                  room(A, B) \== room(X, Y), !.
% Utility.
min_score_room(MinVal, room(X, Y)) :- total_current_score(room(X, Y), MinVal).

% Always keep track of the risk factor of each explorable room.
total_current_score(room(X, Y), S) :- safe(room(X, Y)), S is 0.
total_current_score(room(X, Y), S) :- findall(P, partial_score(room(X, Y), P), L), sum_list(L, S).

% A high risk factor, or score, is associated with dangerous or potentially dangerous rooms.
partial_score(room(X, Y), S) :- explorableRooms(E), member(room(X, Y), E), has_pit(room(X, Y), yes), S is 2000.
partial_score(room(X, Y), S) :- explorableRooms(E), member(room(X, Y), E), has_wumpus(room(X, Y), yes), S is 2000.
partial_score(room(X, Y), S) :- explorableRooms(E), member(room(X, Y), E), has_pit(room(X, Y), maybe), S is 500.
partial_score(room(X, Y), S) :- explorableRooms(E), member(room(X, Y), E), has_wumpus(room(X, Y), maybe), S is 900.
partial_score(room(X, Y), Def) :- Def is 0.
