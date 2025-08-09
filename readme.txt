Offerings 0.0.1

Sacrifice unwanted items, at altars throughout the world, to enhance wands and flasks.

1. Place what to enhance on the upper altar.
2. Place offerings on the lower altar.
3. Pick up the item on the upper altar.

WAND MERGING
============
  * Spread - Cast Delay - Reload: LOWEST
  * Capacity: HIGHEST
  * Mana Charge - Mana Max: DIMINISHING SUM
  * Shuffle - Simulcast: IGNORE

FLASK MERGING
=============
  * Size: SUM
  * 

DIMINISHING SUM
===============
TL;DR The more similar the stats are, the better the result will be.
The formula is pretty forgiving! Don't feel bad for mulching bad wands.

Logic/Math:
  1. SORT
  2. TAKE WORST PAIR: W (worst) and N (next worst)
  3. RESULT = N + (W/N)^0.5 * W
  4. REPEAT UNTIL LIST EMPTY    

SECRETS
=======
  You can offer things besides wands and flasks
