//Used to process and handle roundstart quirks
// - quirk strings are used for faster checking in code
// - quirk datums are stored and hold different effects, as well as being a vector for applying quirk string
SUBSYSTEM_DEF(quirks)
	name = "Traits"
	init_order = INIT_ORDER_QUIRKS
	priority   = FIRE_PRIORITY_QUIRKS
	flags      = SS_BACKGROUND
	wait       = 50

	var/list/processing = list()
	var/list/currentrun = list()

	var/list/quirks = list()		//Assoc. list of all roundstart quirk datum types; "name" = /path/
	var/list/quirk_points = list()	//Assoc. list of quirk names and their "point cost"; positive numbers are good quirks, and negative ones are bad
	var/list/quirk_objects = list()	//A list of all quirk objects in the game, since some may process
	var/list/quirk_blacklist = list() //A list a list of quirks that can not be used with each other. Format: list(quirk1,quirk2),list(quirk3,quirk4)
	var/list/quirk_blacklist_species = list() // Contains quirks and their list of blacklisted species.

/datum/controller/subsystem/quirks/Initialize(timeofday)
	if(!quirks.len)
		SetupQuirks()

	quirk_blacklist = list(
		list(QUIRK_LIGHT_DRINKER, QUIRK_ALCOHOL_TOLERANCE),
		list(QUIRK_STRONG_MIND, QUIRK_TOURETTE),
		list(QUIRK_BLIND, QUIRK_NEARSIGHTED),
		list(QUIRK_LOW_PAIN_THRESHOLD, QUIRK_HIGH_PAIN_THRESHOLD)
		)

	..()

/datum/controller/subsystem/quirks/stat_entry()
	..("P:[processing.len]")

/datum/controller/subsystem/quirks/fire(resumed = 0)
	if (!resumed)
		src.currentrun = processing.Copy()
	//cache for sanic speed (lists are references anyways)
	var/list/currentrun = src.currentrun

	while(currentrun.len)
		var/datum/thing = currentrun[currentrun.len]
		currentrun.len--

		if(QDELETED(thing))
			processing -= thing
		else
			thing.process()

		if (MC_TICK_CHECK)
			return

/proc/cmp_quirk_asc(datum/quirk/A, datum/quirk/B)
	var/a_sign = num2sign(initial(A.value) * -1)
	var/b_sign = num2sign(initial(B.value) * -1)

	// Neutral traits go last.
	if(a_sign == 0)
		a_sign = 2
	if(b_sign == 0)
		b_sign = 2

	var/a_name = initial(A.name)
	var/b_name = initial(B.name)

	if(a_sign != b_sign)
		return a_sign - b_sign
	else
		return sorttext(b_name, a_name)

/datum/controller/subsystem/quirks/proc/SetupQuirks()
	// Sort by Positive, Negative, Neutral; and then by name
	var/list/quirk_list = sortList(subtypesof(/datum/quirk), /proc/cmp_quirk_asc)

	for(var/quirk_type in quirk_list)
		var/datum/quirk/T = new quirk_type
		quirks[T.name] = quirk_type
		quirk_points[T.name] = T.value

		var/list/incompat = T.get_incompatible_species()
		if(incompat.len)
			quirk_blacklist_species[T.name] = incompat

/datum/controller/subsystem/quirks/proc/AssignQuirks(mob/living/user, client/C, spawn_effects)
	GenerateQuirks(C)
	for(var/V in C.prefs.character_quirks)
		user.add_quirk(V, spawn_effects)

/datum/controller/subsystem/quirks/proc/GenerateQuirks(client/user)
	if(user.prefs.character_quirks.len)
		return
	user.prefs.character_quirks = user.prefs.all_quirks



/mob/living/proc/add_quirk(quirk, spawn_effects)
	if(HAS_TRAIT(src, quirk))
		return
	if(!SSquirks || !SSquirks.quirks[quirk])
		return
	var/datum/quirk/T = SSquirks.quirks[quirk]
	new T (src, spawn_effects)
	return TRUE

/mob/living/proc/remove_quirk(quirk)
	var/datum/quirk/T = roundstart_quirks[quirk]
	if(T)
		qdel(T)
		return TRUE

/mob/living/proc/has_quirk(quirktype)
	return roundstart_quirks[quirktype]