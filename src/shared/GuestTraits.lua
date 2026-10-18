-- GuestTraits (ModuleScript)
-- The list of traits a guest can have, and the functions that use it.
-- A ModuleScript is a script that other scripts can load with require().
-- It doesn't run on its own. It holds data and functions to share.
--
-- Every trait is something Dracula likes about a victim, based on Bram
-- Stoker's Dracula and older vampire folklore. Each one has:
--   id       short code name the scripts use
--   name     readable name
--   category which group of reasons it belongs to
--   points   how much it adds to the guest's "victim score" (higher = tastier)
--   clue     what the player can SEE or HEAR during the day
--   counter  the night-time protection that cancels the points
--            (nil = nothing cancels it, it just makes the guest a likelier target)
--
-- Counters we plan to build: CloseWindow, LockDoor, Garlic, Crucifix,
-- MoveRoom, UncoverMirror, Bandage, KeepAwayFromCrypt.

local GuestTraits = {}

GuestTraits.Traits = {
	-- WHAT DRACULA WANTS: healthy blood
	{ id = "YoungHealthy", name = "Young and healthy", category = "Healthy blood", points = 2,
		clue = "Jogs around the castle, eats a big breakfast, rosy cheeks.", counter = nil },
	{ id = "FreshCut", name = "Fresh cut or wound", category = "Healthy blood", points = 2,
		clue = "Has a bandage, or cut themselves at check-in.", counter = "Bandage" },
	{ id = "BigAppetite", name = "Big appetite", category = "Healthy blood", points = 1,
		clue = "Orders steak, red wine and dessert.", counter = nil },

	-- EASY TO REACH AT NIGHT
	{ id = "Sleepwalker", name = "Sleepwalks", category = "Easy to reach", points = 2,
		clue = "Their check-in form has a note about sleepwalking.", counter = "LockDoor" },
	{ id = "OpenWindow", name = "Leaves the window open", category = "Easy to reach", points = 2,
		clue = "Complains the room is stuffy and asks for fresh air.", counter = "CloseWindow" },
	{ id = "InvitesStrangers", name = "Invites strangers in", category = "Easy to reach", points = 2,
		clue = "Overly friendly. Says 'come on in!' to anyone who knocks.", counter = "LockDoor" },
	{ id = "NightOwl", name = "Night owl", category = "Easy to reach", points = 1,
		clue = "Asks 'is the bar open late?' or 'can I explore at night?'", counter = nil },
	{ id = "HeavySleeper", name = "Heavy sleeper", category = "Easy to reach", points = 1,
		clue = "Brought earplugs and a sleep mask, asks not to be disturbed.", counter = nil },

	-- NOBODY WOULD NOTICE THEY'RE GONE
	{ id = "Alone", name = "Travelling alone", category = "Nobody would notice", points = 2,
		clue = "Single booking, no phone calls home.", counter = nil },
	{ id = "FarFromHome", name = "Far from home", category = "Nobody would notice", points = 1,
		clue = "Luggage tags from the other side of the world. Laughs at the garlic.", counter = nil },
	{ id = "IsolatedRoom", name = "Wants an isolated room", category = "Nobody would notice", points = 2,
		clue = "Asks for the 'quietest room in the castle'.", counter = "MoveRoom" },

	-- NO PROTECTION
	{ id = "HatesGarlic", name = "Hates garlic", category = "No protection", points = 1,
		clue = "Refuses the garlic bread, asks to take down the garlic wreath.", counter = "Garlic" },
	{ id = "NoHolyItems", name = "No holy items", category = "No protection", points = 2,
		clue = "No crucifix or rosary in their luggage. Skips the chapel tour.", counter = "Crucifix" },
	{ id = "Sceptic", name = "Doesn't believe in vampires", category = "No protection", points = 1,
		clue = "Mocks the castle's legends at check-in.", counter = nil },
	{ id = "CoversMirrors", name = "Covers the mirrors", category = "No protection", points = 1,
		clue = "Turns the room's mirror to face the wall.", counter = "UncoverMirror" },

	-- DRAWS DRACULA'S ATTENTION
	{ id = "Snoop", name = "Snoops on his secrets", category = "Attention", points = 2,
		clue = "Caught near the Crypt, or asking staff about the owner.", counter = "KeepAwayFromCrypt" },
	{ id = "Rude", name = "Rude to the host", category = "Attention", points = 1,
		clue = "Complains loudly at the front desk.", counter = nil },
	{ id = "AlreadyBitten", name = "Already bitten once", category = "Attention", points = 3,
		clue = "Pale, tired in the day, avoids sunlight, wears a scarf over two small marks.", counter = nil },
}

------------------------------------------------------------------
-- FUNCTION: rollTraits
-- Picks `count` DIFFERENT traits at random and returns them as a list.
-- (A list in Luau is a table, and the first item is number 1, not 0
-- like in Python.)
------------------------------------------------------------------
function GuestTraits.rollTraits(count)
	-- Copy the list so we don't scramble the original
	local pool = {}
	for _, trait in ipairs(GuestTraits.Traits) do
		table.insert(pool, trait)
	end

	-- Take `count` random items out of the copy, one at a time.
	-- Removing each pick means the same trait can't be chosen twice.
	local picked = {}
	for _ = 1, math.min(count, #pool) do
		local index = math.random(1, #pool)
		table.insert(picked, table.remove(pool, index))
	end
	return picked
end

------------------------------------------------------------------
-- FUNCTION: victimScore
-- Adds up the points of a guest's traits. Dracula goes for the highest
-- score. `appliedCounters` is a table like { Garlic = true } of the
-- protections in place. A trait whose counter is applied adds 0.
------------------------------------------------------------------
function GuestTraits.victimScore(traits, appliedCounters)
	appliedCounters = appliedCounters or {}
	local score = 0
	for _, trait in ipairs(traits) do
		-- Skip the trait if it has a counter and that counter is in place
		if not (trait.counter and appliedCounters[trait.counter]) then
			score = score + trait.points
		end
	end
	return score
end

return GuestTraits
