#define SSMINING_STATE_IDLE 0
#define SSMINING_STATE_CLEANING 1
#define SSMINING_STATE_GENERATING 2

#define MINING_TOTAL_FREE_LEVEL 0.4
#define MINING_FREE_LEVEL 0.5
#define MINING_STONE_LEVEL 0.7

SUBSYSTEM_DEF(mining)
	name = "Mining"
	flags = SS_BACKGROUND
	wait = 10 SECONDS
	var/mining_state = SSMINING_STATE_IDLE
	var/obj/effect/mining_generation_marker/marker
	var/list/obj/structure/mine_dull/dulls
	var/list/turf/cache

	var/scale = 0.3
	var/offset = 0
	var/octaves = 4
	var/ydisplace = 0.5

	var/next_invasion = 0

/datum/controller/subsystem/mining/Initialize()
	. = ..()
	marker = locate(/obj/effect/mining_generation_marker)

/datum/controller/subsystem/mining/proc/clean()
	if(mining_state)
		return
	mining_state = SSMINING_STATE_CLEANING

	for(var/turf/T in block(get_turf(marker), locate(marker.x + marker.w - 1, marker.y - marker.h + 1, marker.z)))
		for(var/A in T.contents)
			if(istype(A, /obj/effect/mining_generation_marker))
				continue
			if(isobserver(A))
				continue
			qdel(A)

		T.ChangeTurf(/turf/simulated/floor)

		CHECK_TICK

	dulls = null
	next_invasion = 0

	mining_state = SSMINING_STATE_IDLE

/datum/controller/subsystem/mining/proc/generate_turf(x, y, f, floor_type)
	var/turf/simulated/floor/mining/T = locate(marker.x + x, marker.y - y, marker.z)
	var/floor = f <= MINING_FREE_LEVEL

	if(f <= MINING_TOTAL_FREE_LEVEL)
		T = T.ChangeTurf(floor_type)
	else if(f <= MINING_FREE_LEVEL)
		T = T.ChangeTurf(floor_type)
		if(prob(30))
			new /obj/effect/decal/cleanable/dirt(T)
	else// if(f <= MINING_STONE_LEVEL)
		T = T.ChangeTurf(/turf/simulated/mineral/mining)
		var/turf/simulated/mineral/M = T
		M.floor_type = floor_type
		M.floor_seed = global.random2d_seed

	if(floor)
		T.generate(global.random2d_seed)

	return T


/datum/controller/subsystem/mining/proc/generate_structures()
	var/list/turf/L = cache.Copy()

	var/list/decl/mine_structure/structures = list()
	for(var/P in subtypesof(/decl/mine_structure))
		var/decl/mine_structure/S = new P
		if(prob(S.chance))
			structures += S

	if(!structures.len)
		return

	// TODO: rewrite
	for(var/decl/mine_structure/S as anything in structures)
		var/amount = rand(S.min_amount, S.max_amount)
		var/generated = 0

		do
			var/turf/T = pick(L)
			if(!ISINRANGE(L[T], S.min_level, S.max_level))
				continue
			L -= T
			S.generate(T)
			++generated
			CHECK_TICK
		while(generated < amount)

/datum/controller/subsystem/mining/proc/generate()
	if(mining_state)
		return
	mining_state = SSMINING_STATE_GENERATING

	global.random2d_seed = rand(1, 130000)

	var/floor_type = pick(typesof(/turf/simulated/floor/mining))

	cache = list()

	for(var/y in marker.h-1 to 0 step -1)
		for(var/x in 0 to marker.w-1)
			var/f = offset + perlin_noise(x + y * ydisplace, y, scale = src.scale, octaves = src.octaves)
			cache[generate_turf(x, y, f, floor_type)] = f

			CHECK_TICK

	generate_structures()

	seed_submaps(list(marker.z), rand(50, 150), /turf/simulated/floor/mining, /datum/map_template/mine)

	for(var/turf/simulated/floor/T as anything in cache)
		T.regenerate_ao()
		CHECK_TICK

	cache = null

	mining_state = SSMINING_STATE_IDLE

/datum/controller/subsystem/mining/proc/start_invasion()
	set waitfor = FALSE

	for(var/obj/structure/mine_dull/D as anything in dulls)
		for(var/i in 1 to rand(5, 10))
			spawn(i * 50 + rand(0, 100))
				new /obj/random/mob/spider/mutant(get_turf(D))

/datum/controller/subsystem/mining/fire(resumed)
	if(next_invasion && world.time > next_invasion)
		start_invasion()
		next_invasion = 0
