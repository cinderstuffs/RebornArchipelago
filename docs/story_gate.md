## Why is there a story gate option? What does that even mean?

In Pokémon Reborn, your progress is made through story, dialogues, your actions, dialogues with NPCs. Of course, this means one of the main roadblocks are gym battles.

Because the story is tied to gym battles, getting the gym badge still wouldn't progress the story. For example, if you obtain Julia's badge before defeating her, you still have to battle her to progress the story; and if you defeat her and don't get her badge, the game doesn't care and still lets you move on.
This negates the effects of badges on the progression when randomized, which, in my opinion, goes against AP and randomizers' spirit where you should freely explore the world in any order, even if it gets chaotic.

Making the game open world would be very complicated for now, at least until the game's logic and locations aren't fully mapped. For now, the best thing I can do is to allow progression by acquiring badges only.

This choice is up to the player when creating their `.yaml`. The `leader` value lets the game's default behaviour, the `badge` value applies this logic, while `both` applies... well, both.

While you're still free to play the way they want, please note that this apworld was designed with `badge` as the intended way to play. Most decisions were taken with this option in mind, and most tests were made with the game configured that way.

## What happens if I pick badge as the story gate?

Once you reach the point of the story where a gym leader can be fought, the game will look for their badge in your inventory. If you have it, the story will progress as if you've defeated the gym.

If you defeat a gym leader but don't have their badge, the story is blocked until you get it. This behavior also applies if you pick `both`.

If you chose to not shuffle badges, the game works the same as vanilla.

## At what point exactly am I able to progress once I have the badge?

Gym leaders can be split into 2 categories. First are those where all story flags are on **before** entering their gym or section, like Julia or Shelly. Those leaders are easier to handle because there's less things to consider. Therefore, as soon as you've completed all story events prior to their gym or section, you're able to move on with the story.

The second category are leaders where at least one story flag is turned on in a section that is made for this leader. What I mean by **section** are mainly gyms, but also cities or entire parts of the map that you visit mainly (if not only) for this gym leader.

Let's take an example: for Aya, the 5th gym leader from Byxbysion Wasteland, the game wants you to go through the entire section, go to her gym, battle Ace and Fern, read through some dialogue... and then you can battle her. If the `badge` story gate rule was applied the same way as the first category of gym leaders, you would be able to skip her battle only now; meaning that in order to skip her section, you had to... do her section. Moreover, since you just went through the whole Byxbysion map, you have no reason to backtrack and not battle her since she's in front of you, which ruins the point of the rule.

Most gym leaders belong to this category, and to avoid making the rule inefficient with them, I moved the point where you can progress for those leaders. Most changes are pretty arbitrary and are subject to change in the future.

| Gym leader      | When do you unlock their battle (vanilla) | Change made through story gate once badge is acquired |
| ------------ | ----------- | ----- |
| Julia | After completing Mossdeep Industrial | Nothing |
| Florinia | After talking to Fern in her gym | Jasper Ward can be accessed as soon as you've freed Obsidia Park from Team Meteor. |
| Shelly | After going in the orphanage for the first time and going back to her gym | Nothing
| Shade | After activating the 4 generators in the gym | After Charlotte asks you to go see Shade, the cutscene of the children's kidnapping runs, then a message reminds you to go to Jasper Ward to meet Cain to progress. The cutscene runs as soon as you get the badge, but if you already have it when Charlotte made her request, the game waits for you to leave Underground Railnet first, to avoid any softlocks due to boulders and rocks
| Aya | After defeating Fern in her gym | Cain is available at the gate between Reborn City and Byxbysion for his battle |
| Serra | After defeating Bennett in her gym | Once Laura asks for the Herbal Extract, Chrysolia Forest's PokéMart appears if you have the badge. If you get it after her request, a message will tell you upon getting it, and Serra will also remind you in her house.
| Noel | After the debrief in Belrose Manse following the rescue of whoever got kidnapped by Team Meteor | Nothing
| Radomus | After completing his gym puzzles | Team Meteor will attack Vanhanen Castle right after rescuing Gossip Gardevoir. Elias will "escort" you out when you get in the living-room. You can still battle Radomus at this point, but if you follow Elias, you won't be able to until getting access to 7th Street
| Luna | After defeating Bennett in Iolia Valley | Gate to Agate City gets opened after rescuing Luna from Subseven Sanctum |

## Do gym leaders disappear?

No. Gym leaders stay available until you beat them, if you want to get their checks later. In fact, you can use this to bypass level caps and have easier battles.

For gym leaders that skip more than their battle, skipped content is also available for later, including checks. For example, in Aya's case, Ace and Fern can still be battled.

## What's your idea behind developping that?

As I said above, the game's progression is heavily tied to its story. In order to have a complete randomized experience, I want to break this rule, and make the progression rely less on the story, and more on the items, to achieve a full open world.

This idea will be pushed further as I'm making progress on this apworld, learning more on how the game handles its story and roadblocks, and seeing more possibilities to provide progress through items.

It is possible this option ends up removed and replaced by something else in a future release, but for now, this is the best option I have, and it will probably stay that way until the entire game is mapped.

## Any roadmap or plans for improvement?

Julia: make Victoria appear in front of Julia's gym right after getting your starter, and skip Mossdeep Industrial

Florinia: give early access to Jasper Ward, skipping the Obsidia segment

And, of course, do the remaining gym leaders