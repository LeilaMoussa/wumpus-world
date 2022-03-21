% Initial states common to all worlds.
position(room(1, 1), 0).
score(100).
wumpus_alive().
player_alive().
visited(room(1, 1), 0).
has_pit(room(1, 1), no).
has_wumpus(room(1, 1), no).
gold(room(1, 1)) :- false.
did_shoot(_ , _) :- false.
scream(no).
safe(room(1, 1)).
