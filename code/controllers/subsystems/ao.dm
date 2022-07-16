SUBSYSTEM_DEF(ao)
	name = "Ambient Occlusion"
	init_order = INIT_ORDER_AO
	wait = 1
	runlevels = RUNLEVELS_DEFAULT | RUNLEVEL_LOBBY
	var/list/queue = list()
	var/list/cache = list()

/datum/controller/subsystem/ao/stat_entry()
	..("P:[queue.len]")

/datum/controller/subsystem/ao/fire(resumed = 0, no_mc_tick = FALSE)
	var/list/curr = queue
	while (curr.len)
		var/turf/target = curr[curr.len]
		curr.len--

		if (!QDELETED(target))
			if (target.ao_queued == AO_UPDATE_REBUILD)
				var/old_n = target.ao_neighbors
				target.calculate_ao_neighbors()
				if (old_n != target.ao_neighbors)
					target.update_ao()
			else
				target.update_ao()
			target.ao_queued = AO_UPDATE_NONE

		if (no_mc_tick)
			CHECK_TICK
		else if (MC_TICK_CHECK)
			return