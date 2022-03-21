# wumpus-world
Team project with Khaoula Ait Soussi for CSC 4301 Intro to AI. 
Report by Leila Farah Moussa.

## Overview
This report describes the work we did for the mini-project implementing an intelligent knowledge based agent trying to navigate Wumpus' World. The agent collects perceptions and reasons about them to deduce probabilities of the wumpus or pit existing somewhere. The goal is simply to kill the wumpus without dying. Grabbing the gold is simply a bonus.

### Usage
To run the program with the 3 world configurations (world_a, world_b, world_c) we've provided, run the 2 following commands in swipl:
```
[main], [heuristic], [initial_states], [world_*]. % * is a, b, or c.
start_game().
```
_Note on consulting: Sometimes, at least in our experience, the first command where the 4 files are consulted does not seem to work, though it gives no errors, as indicated by the second command malfunctioning. In these cases, simply re-consulting these files was enough to ensure correct execution. Also, do not mind the warnings issued by Prolog as they are inconsequential._

_Note on execution: You'd have to advance the execution of the loop within swipl using `;`. We couldn't find a solution to this, but it's not very important._

## Code and docs
In this section, I describe the general control flow and the most important predicates.

`start_game()` launches a loop (predicate `loop()`) following the logic: perceive -> act -> check whether the game ended -> update KB for relevant details.

The `perceptions/1` predicate updates a list of 4 perceptions: Stench, Breeze, Glitter, Scream. Each one is defined based on general facts or properties of the world and these perceptions. Note that we did not make any use of the Bump perceptions that is common in other resources on Wumpus World. This is because the meaning of Bump is fundamentally related the Direction property of the agent (North, West, South, East), which we also chose not to implement, in favor of a much simpler approach of defining the boundaries of the world and the valid rooms within it and simply moving freely.

The most important predicate, related to the part on *acting*, is `heuristic/1`. This predicate takes the list of perceptions and goes through a bunch of rules that may apply to each value of the list looking for the best actions or actions to carry out next. The order of the rules in `heuristic.pl` is, of course, important for the logical flow.

Some heuristic predicates simply assert new knowledge into the KB, notably making a guess on whether a wumpus or pit might be in an adjacent room. They might rule out the possibility of them existing, using the `has_pit(_, no)` or `has_wumpus(_, no)` rules, choose to say `yes` alternatively, or simply speculate (`maybe`). These 3 posisbilities for a guess have some precedence over each other. For example, if we already asserted "yes" or "no", we shouldn't be allowed to decrease our certainty by asserting "maybe" later, because that would hurt our performance. Other heuristics decide whether to move (travel) or to shoot (with certainty or with uncertainty). Simpler heuristics simply issue an action unilterally (like grab_gold).

Perhaps the most important part of the heuristics is deciding where to move if we must move. That's what the risk factor is called (referred to in the code as partial_score and total_current_score, not to be confounded with the player's score indicating remaining life). We chose a very simple way to approach the risk factor: the higher the potential danger, the higher it is. By default, all rooms have a risk factor of 0. Those with "maybe" for a danger have a lower partial score than a "yes" for a danger. These partial scores are summed into an aggregate total current score for each explorable cell. An explorable cell, define by `explorableRooms/1`, is one that we have enough knowledge about, at least in principle, to move into. Thus, explorable rooms are scored and updated at each iteration. If ever choose to travel, we select the one with the lowest score (which may or may not be totally safe).

Sometimes though, traveling and shooting are not enough to end the game somehow. The agent might get stuck moving in familiar places. That's why we enforce an ultimatum: if we're past the timestamp 10 and we're still playing, just moving anywhere random. That's a high priority rule. The empirical assumption here is that most if not all the local knowledge we could accumulate is already accumulated by time 10 (or even before). So if we're still wandering around the same area at that point, we might as well take a leap of faith and move somewhere random within the grid.

## Worlds

We define 3 configurations. They're defined in pl files in this repo. Please take a look at the other MD files in this repo to see the trace of execution of each world and some information on the final states/knowledge for each.

### Worlds A and B
We consistently and deterministically manage to win in this world by ending up shooting the wumpus. Our heuristics that assert has_wumpus(_, yes) and has_pit(_, yes) are quite accurate in both these worlds. We always manage to ascertain where the wumpus is after a few moves. Then the heuristic that tells us to shoot when certain where the wumpus is gets triggered and the game is always won. This outcome came as a result of some tweaking of the rules and rearranging of their order to get greater accuracy in our guesses.

### World C
We don't do as well in this configuration. Execution drags on for much longer because we get stuck in the local area of rooms (1, 1), (1, 2), and (2, 1). We don't gather any new information about them, but out current_safest_cell heuristic always tells us to go somewhere there. This turned out to be a major weakness: we seem to prioritize visited cells while selecting the next place to move to. This causes the player to get stuck. If it weren't for the T > 10 ultimatum I mentioned, the player would keep moving between (1, 2) and (2, 1) until it runs out of life. We tried to mitigate this by enforcing not moving somwhere we **just** were, but we don't go farther than one timestamp ago. In that sense, the agent moves from (1, 2) to (2, 1) because each one is 2 timestamps before the current moment, so we're free to move there. We tried to think of an alternative move heuristic independent on scoring, using some contrived data structure like a queue, to enqueue rooms we would like to explore next, while enforcing some reduced repetitiveness, but we did not have quite enough time to pursue that implementation alternative.

The player also seems to get stuck because it sometimes falsely assumes that a pit exists where it does not. If we improve the accuracy or has_pit assertions, we cna decrease this paralysis and move more freely and gather more information that might allow us to eventually kill the wumpus.

Finally, the outcome of world C can be either: falling, getting eaten, shooting at the wrong place, winning, or running out of life. 4 out of these 5 outcomes are accompanied with traces in the repo. It all depends on where the last random move landed.

## Future work
To improve the accuracy of our agent, we would focus on:
- [ ] Reducing the probability of getting stuck in local areas by encouraging traveling to novel explorable rooms. The fine line to tread here is that sometimes, we indeed do prefer to go to places we've just been, while in other situations, we'd like to steer away from them. We enforced this with an ultimatum, but a more elegant approach would be better.
- [ ] Increasing the accuracy of has_pit() and has_wumpus() assertions. We don't really have a big problem with "maybe" assertions because they are simply uncertainties. However, if we expect "yes" and "no" assertions to truly guide us with certainty, we must reduce the places where we say has_pit(_, yes) so as to not paralyze our movement. No and yes go hand in hand, so improving one's accuracy is likely to improve the other's as well.
- [ ] Coming up with new rules that ascertain the existence of a pit, as the current rule we are using over generalizes and leads to over-confident assertions, which translate in some configurations, like world C, into getting stuck in local areas (paralysis).

