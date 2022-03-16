% ideally, we would order the rules in terms of meaning (actions, sensors, score-keeping, etc.) while preserving correctness for search

:- abolish(position/2).
:- abolish(wumpus_alive/0).
:- abolish(gold/1).
:- abolish(visited/2).
:- abolish(did_shoot/0).

:- dynamic([
  position/2,
  wumpus_alive/0,
  gold/1,
  visited/2,
  did_shoot/0,
  score/1,
  glitter/1,
  did_grab/0,
  pit/1,
  player_alive/0,
  parent/2
]).

valid(X) :- X is 1; X is 2; X is 3; X is 4.
in_bounds(X, Y) :- valid(X), valid(Y).
room(X, Y) :- in_bounds(X, Y).
adjacent(room(X, Y), room(A, B)) :- room(X, Y), room(A, B),
                                    (A is X-1, B is Y ;
									A is X+1, B is Y ;
									A is X, B is Y-1 ;
									A is X, B is Y+1).

safe(room(X, Y)) :- visited(room(X, Y), _), !.
%safe(room(X, Y)) :- not(pit(room(X, Y))), not(wumpus(room(X, Y))).

% SENSORS
breeze(room(X, Y), yes) :- pit(room(A, B)), adjacent(room(X, Y), room(A, B)), !.
breeze(room(_, _), no).
glitter(room(X, Y), yes) :- gold(room(X, Y)).
glitter(room(_, _), no).
stench(room(X, Y), yes) :- write('1.2.1'), wumpus(room(A, B)), adjacent(room(X, Y), room(A, B)), !.
stench(room(_, _), no) :- write('1.2.2').
scream(yes) :- write('waaa'), not(wumpus_alive()), !.
scream(no) :- write('should be here ').

perceptions([Stench, Breeze, Glitter, Scream]) :- write('1.1'), position(room(X, Y), _),
write('1.2'),
                                                  stench(room(X,Y), Stench),
												  write('1.3'),
                                                  breeze(room(X,Y), Breeze),
												  write('1.4'),
                                                  glitter(room(X,Y), Glitter),
												  write('1.5'),
                                                  scream(Scream),
												  write('1.6'), !.

% GOLD STATE
has_gold() :- did_grab(), not(climb()).

% ACTIONS
% move from room(X, Y) to room(A, B) -- atomic move
% NOTE: it could be a problem is A, B is the same as X, Y. If it happens repeatedly, the program might not terminate in a reasonable time, or at all.
move(room(X, Y), room(A, B), T) :- A \== X, B \== Y, position(room(X, Y), T), adjacent(room(X, Y), room(A, B)),
								retractall(position(_, _)),
								Z is T+1,
								asserta(position(room(A, B), Z)),
								assertz(visited(room(A, B), Z)),
								asserta(parent(room(X, Y), room(A, B))),
								score(S),
								C is S - 1,
								retractall(score(_)),
								asserta(score(C)), format("Moved from room(~w,~w) to room(~w,~w) at time ~w~n", [X,Y,A,B,T]), !.

grab_gold(T) :- position(room(X, Y), T), gold(room(X, Y)),
						retractall(gold(_)),
						retractall(glitter(_)),
						score(S),
						C is S + 100 - 1,
						retractall(score(_)),
						asserta(score(C)),
						retractall(did_grab()),
						asserta(did_grab()),
						format("Grabbed gold from room(~w,~w) at time ~w~n", [X,Y,T]).


% no need for the two first rules position(room(X, Y), T), adjacent(room(X, Y), room(A, B)) because we would only call move once we check for these
shoot(room(X, Y)) :- write('shooting'), nl, position(room(A, B), _), adjacent(room(X, Y), room(A, B)), not(did_shoot()),
 					retractall(did_shoot()),
 					asserta(did_shoot()),
 					score(S),
 					C is S - 10,
 					retractall(score(_)),
 					asserta(score(C)), !.

% Note: kill is not an action that is actively performed by the agent.
% It is just an abstraction to verify the death of the Wumpus.
kill() :- shoot(room(X, Y)), wumpus(room(X, Y)),
 		retractall(wumpus_alive()),
 		retractall(wumpus(room(X, Y))).

/* climb(T) :- P is T-1, position(room(X, Y), P), pit(room(X, Y)),
				did_grab(), has_gold(),
				retractall(has_gold()),
				score(S),
				C is S - 1000 - 1,
                retractall(score(_)),
                asserta(score(C)). */

fall(T) :- position(room(X, Y), T), pit(room(X, Y)),
		score(S),
		C is S - 1000,
		retractall(score(_)),
		asserta(score(C)),
		retractall(player_alive()).

eaten(T) :- position(room(X, Y), T), wumpus(room(X, Y)),
		score(S),
		C is S - 1000,
		retractall(score(_)),
		asserta(score(C)),
		retractall(player_alive()).

start_game() :- loop(0).

loop(200) :- write('Game Over... Too much time spent!'), nl, !. % halt(),

loop(T) :-
  write('1'),
  perceptions(L),
  write('2'),
  heuristic(L),
  write('3'),
  position(room(X, Y), T),
  write('4'),
  (fall(T) -> (
	  write('5'),
    format("Game Over... You fell in a pit in room(~w,~w) at time ~w!~n", [X,Y,T]),
	halt
  );
  eaten(T) -> (
	  write('6'),
    format("Game Over... You were eaten by the wumpus in room(~w,~w) at time ~w!~n", [X,Y,T]),
	halt
  );
  score(S),
  S < 0 -> (
	  write('7'),
	format("Game Over... Your life ran out in room(~w,~w) at time ~w!~n", [X,Y,T]),
	halt
  ));
  write('8'),
  Iter is T + 1,
  loop(Iter).
