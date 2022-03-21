% `abolish` and `dynamic` are required for predicates that are asserted or retracted at runtime.
:- abolish(position/2).
:- abolish(wumpus_alive/0).
:- abolish(gold/1).
:- abolish(visited/2).
:- abolish(did_shoot/2).
:- abolish(score/1).

:- dynamic([
  position/2,
  wumpus_alive/0,
  gold/1,
  visited/2,
  did_shoot/2,
  score/1,
  glitter/1,
  pit/1,
  player_alive/0,
  parent/2
]).

% Utility functions describing properties of any world.
valid(X) :- X is 1; X is 2; X is 3; X is 4.
in_bounds(X, Y) :- valid(X), valid(Y).
room(X, Y) :- in_bounds(X, Y).
adjacent(room(X, Y), room(A, B)) :- room(X, Y), room(A, B),
                                    (A is X-1, B is Y ;
                                    A is X+1, B is Y ;
                                    A is X, B is Y-1 ;
                                    A is X, B is Y+1).

safe(room(X, Y)) :- visited(room(X, Y), _), !.
safe(room(X, Y)) :- has_wumpus(room(X, Y), no), has_pit(room(X, Y), no).
visited(room(X, Y), _) :- asserta(safe(room(X, Y))).

% SENSORS
breeze(room(X, Y), yes) :- pit(room(A, B)), adjacent(room(X, Y), room(A, B)), !.
breeze(room(_, _), no).
glitter(room(X, Y), yes) :- gold(room(X, Y)).
glitter(room(_, _), no).
stench(room(X, Y), yes) :- wumpus(room(A, B)), adjacent(room(X, Y), room(A, B)), !.
stench(room(_, _), no).
scream(yes) :- dead().
scream(no).

% The list of perceptions is updated iteratively.
perceptions([Stench, Breeze, Glitter, Scream]) :- position(room(X, Y), T),
                                                  stench(room(X,Y), Stench),
                                                  format("[IN Perceptions] : Stench percept in room(~w,~w): ~w!~n", [X,Y,Stench]),
                                                  breeze(room(X,Y), Breeze),
                                                  format("[IN Perceptions] : Breeze percept in room(~w,~w): ~w!~n", [X,Y,Breeze]),
                                                  glitter(room(X,Y), Glitter),
                                                  format("[IN Perceptions] : Glitter percept in room(~w,~w): ~w!~n", [X,Y,Glitter]),
                                                  scream(Scream),
                                                  format("[IN Perceptions] : Percepts in room(~w,~w) at time ~w: [~w,~w,~w,~w]!~n", [X,Y,T,Stench,Breeze,Glitter,Scream]),!.

% ACTIONS
% Travel from anywhere in the world to anywhere else, not just adjacent rooms,
% with the assumption that this is onlt ever used when there exists a path between the start and the destination
% that is fully safe.
travel(room(X, Y), room(A, B), T) :- position(room(X, Y), T), room(A,B) \== room(X,Y),
                Xdiff is abs(A - X),
                Ydiff is abs(B - Y),
                Manhatt is Xdiff + Ydiff,
								retractall(position(_, _)),
                Z is T + Manhatt,
								asserta(position(room(A, B), Z)),
								asserta(visited(room(A, B), Z)),
								score(S),
                C is S - Manhatt,
								retractall(score(_)),
								asserta(score(C)), format("Traveled from room(~w,~w) to room(~w,~w) at time ~w~n", [X,Y,A,B,T]),
                asserta(safe(room(A, B))), !.

% Gold gives you 100 points, but the action of grabbing costs one point.
grab_gold() :- position(room(X, Y), T), gold(room(X, Y)),
				retractall(gold(_)),
				retractall(glitter(_)),
        score(S),
        C is S + 100 - 1,
        retractall(score(_)),
        asserta(score(C)),
        format("Grabbed gold from room(~w,~w) at time ~w~n", [X,Y,T]).

% Only shoot if you haven't shot already and if you're adjacent to your target.
shoot(room(X, Y), T) :- position(room(A, B), T), adjacent(room(X, Y), room(A, B)), not(did_shoot(_, _)),
 					retractall(did_shoot(_, _)),
 					asserta(did_shoot(X, Y)),
 					score(S),
 					C is S - 10,
 					retractall(score(_)),
 					asserta(score(C)),
 					format("Shot room(~w,~w) at time ~w~n", [X,Y,T]), !.

% The wumpus is dead if you shot at the room where it is.
dead() :- did_shoot(X, Y), wumpus(room(X, Y)), retractall(wumpus_alive()).

% You fall into a pit if you move to a room containing a pit.
fall(T) :- position(room(X, Y), T), pit(room(X, Y)),
		score(S),
		C is S - 1000,
		retractall(score(_)),
		asserta(score(C)),
		retractall(player_alive()).

% Similarly, you can be eaten by the wumpus.
eaten(T) :- position(room(X, Y), T), wumpus(room(X, Y)),
		score(S),
		C is S - 1000,
		retractall(score(_)),
		asserta(score(C)),
		retractall(player_alive()).

% The entry point to the game.
start_game() :- loop(0).

% Don't loop more than 199 times.
loop(200) :- write('Game Over... Too much time spent!'), nl, !, halt.

% In each iteration, update the perceptions, act on them, then decide whether to end the game
% due to death (fall, eaten, life running out), loss (missed your shot), or if you win.
loop(Iter) :-
  perceptions(L),
  format("[IN LOOP] : Perceptions in loop iter ~w: ~w!~n", [Iter,L]),
  heuristic(L),
  position(room(X, Y), T),
  (fall(T) -> (
    format("Game Over... You fell in a pit in room(~w,~w) at time ~w!~n", [X,Y,T]), !, halt
  );
  eaten(T) -> (
    format("Game Over... You were eaten by the wumpus in room(~w,~w) at time ~w!~n", [X,Y,T]), !, halt
  );
  score(S),
  S < 1 -> (
	format("Game Over... Your life ran out in room(~w,~w) at time ~w!~n", [X,Y,T]), !, halt
  );
  dead() -> (
    format("You won!"), !, halt
  );
  (did_shoot(_, _), wumpus_alive() -> (
    format("Missed your shot -- no way to win."), !, halt
  ));
  % It's useful after each action to reflect on your knowledge and update the useful bits:
  % here, trying to deduce whether a pit or a wumpus exist for certain somewhere close to where we visited.
  check_for_wumpus(); check_for_pit());
  Next is Iter + 1,
  loop(Next).
