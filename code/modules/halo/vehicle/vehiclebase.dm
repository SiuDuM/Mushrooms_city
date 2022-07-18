/obj/manhattan/vehicles
	name = "Vehicle"
	desc = "Vehicle"
	density = 1
	layer = ABOVE_MOB_LAYER

	var/active = 1
	var/guns_disabled = 0
	var/movement_destroyed = 0
	var/block_enter_exit //Set this to block entering/exiting.
	var/can_traverse_zs = 0

	var/next_move_input_at = 0//When can we send our next movement input?
	var/moving_x = 0
	var/moving_y = 0
	var/last_moved_axis = 0 //1 = X axis, 2 = Y axis.
	var/list/speed = list(0,0) //The delay on movement in these directions.
	var/drag = 1 //How much do we slow down per tick if no input is applied in a direction?
	var/min_speed = 5 //What's the highest delay we can have?
	var/max_speed = 1//What's the lowest number we can go to in terms of delay?
	var/acceleration = 1 //By how much does our speed change per input?
	var/braking_mode = 0 //1 = brakes active, -1 = purposefully reducing drag to slide.
	var/can_space_move = 0

	//Advanced Damage Handling
	var/datum/component_profile/comp_prof = /datum/component_profile

	var/list/sprite_offsets = list("1" = list(0,0),"2" = list(0,0),"4" = list(0,0),"8" = list(0,0)) //Handled Directionally. Numbers correspond to directions

	//Passenger Management
	var/list/occupants = list(1,1) //Contains all occupants of the vehicle including the driver. First 2 values defines max passengers /gunners. Format: [MobRef] = [PositionName]
	var/list/passengers = list()
	var/list/exposed_positions = list("driver" = 0.0,"gunner" = 0.0,"passenger" = 0.0) //Assoc. Value is the chance of hitting this position

	//Cargo
	var/used_cargo_space = 0
	var/cargo_capacity = 0
	var/capacity_flag = ITEMSIZE_SMALL
	var/list/cargo_contents = list()
	var/list/ammo_containers = list() //Ammunition containers in the form of ammo magazines.

	//Vehicle ferrying//
	var/vehicle_size = ITEM_SIZE_VEHICLE//The size of the vehicle, used by vehicle cargo ferrying to determine allowed amount and allowed size.
	var/vehicle_carry_size = 0		//the max size of a carried vehicle
	var/obj/manhattan/vehicles/carried_vehicle

	var/vehicle_view_modifier = 1 //The view-size modifier to apply to the occupants of the vehicle.
	var/move_sound = null
	var/collision_sound = 'sound/effects/clang.ogg'

	var/datum/mobile_spawn/spawn_datum //Setting this makes this a mobile spawn point.

	var/datum/gas_mixture/internal_air = null//If this is new()'d, the vehicle provides air to the occupants.
	//I would make it require refilling, but that's likely to just be boring tedium for players.

	light_power = 6
	light_range = 6

	var/list/compatible_details

/obj/manhattan/vehicles/verb/toggle_headlights()
	set name = "Toggle Headlights"
	set category = "Vehicle"
	set src in view(1)
	var/mob/living/user = usr
	if(!istype(user) || !(user in get_occupants_in_position("driver")))
		to_chat(user,"<span class = 'notice'>You must be the driver of [src] to toggle the headlights.</span>")
		return

	if(light_range == 0)
		to_chat(user,"<span class = 'notice'>You toggle [src]'s headlights on.</span>")
		set_light(initial(light_range))
	else
		to_chat(user,"<span class = 'notice'>You toggle [src]'s headlights off.</span>")
		set_light(0)

/obj/manhattan/vehicles/New()
	. = ..()
	comp_prof = new comp_prof(src)
	processing_objects += src
	update_object_sprites()
	if(light_range != 0)
		verbs += /obj/manhattan/vehicles/verb/toggle_headlights
		set_light(0) //Switch off at spawn.
	cargo_capacity = base_storage_capacity(capacity_flag)

/obj/manhattan/vehicles/attack_generic(var/mob/living/simple_animal/attacker,var/damage,var/text)
	visible_message("<span class = 'danger'>[attacker] [text] [src]</span>")
	var/pos_to_dam = should_damage_occ()
	if(!isnull(pos_to_dam))
		var/list/occ_list = get_occupants_in_position(pos_to_dam)
		if(isnull(occ_list) || !occ_list.len)
			return 1
		var/mob/mob_to_hit = pick(occ_list)
		if(isnull(mob_to_hit))
			return 1
		attacker.UnarmedAttack(mob_to_hit)
	comp_prof.take_component_damage(damage,"brute")

/obj/manhattan/vehicles/proc/display_ammo_status(var/mob/user)
	for(var/m in ammo_containers)
		var/obj/item/ammo_magazine/mag = m
		var/msg = "is full!"
		if(mag.stored_ammo.len >= mag.initial_ammo * 0.75)
			msg = "is about 3 quarters full."
		else if(mag.stored_ammo.len > mag.initial_ammo * 0.5)
			msg = "is about half full."
		else if(mag.stored_ammo.len > mag.initial_ammo * 0.25)
			msg = "is about a quarter full."
		to_chat(user,"<span class = 'notice'>[src]'s [mag] [msg]</span>")

/obj/manhattan/vehicles/examine(var/mob/user)
	. = ..()
	if(!active)
		to_chat(user,"[src]'s engine is inactive.")
	if(guns_disabled)
		to_chat(user,"[src]'s guns are damaged beyond use.")
	if(movement_destroyed)
		to_chat(user,"[src]'s movement is damaged beyond use.")
	if(cargo_capacity)
		if(!src.Adjacent(user))
			if(used_cargo_space > 0)
				to_chat(user,"<span>It looks like there is something in the cargo hold.</span>")
		else
			to_chat(user,"<span>It's cargo hold contains [used_cargo_space] of [cargo_capacity] units of cargo ([round(100*used_cargo_space/cargo_capacity)]% full).</span>")
	if(carried_vehicle)
		to_chat(user,"<span>It has a [carried_vehicle] mounted on it.</span>")

	show_occupants_contained(user)

	display_ammo_status(user)

/obj/manhattan/vehicles/proc/pick_valid_exit_loc()
	var/list/valid_exit_locs = list()
	for(var/turf/t in locs)
		for(var/turf/t_2 in range(1,t))
			if(!(t_2 in locs) && t_2.density == 0)
				valid_exit_locs |= t
				break
	if(valid_exit_locs.len == 0)
		return null
	return pick(valid_exit_locs)

/obj/manhattan/vehicles/Destroy()
	processing_objects -= src
	kick_occupants()
	. = ..()

/obj/manhattan/vehicles/proc/on_death()
	explosion(loc,-1,-1,2,5)
	movement_destroyed = 1
	guns_disabled = 1
	icon_state = "[initial(icon_state)]_destroyed"
/*	if(spawn_datum)
		spawn_datum.is_spawn_active = 0*/

/obj/manhattan/vehicles/proc/inactive_pilot_effects() //Overriden on a vehicle-by-vehicle basis.

/obj/manhattan/vehicles/process()
	if(world.time % 3)
		comp_prof.give_gunner_weapons(src)
		update_object_sprites()
		if(active)
			var/list/drivers = get_occupants_in_position("driver")
			if(!drivers.len || isnull(drivers) || movement_destroyed)
				inactive_pilot_effects()
/*	if(spawn_datum)
		spawn_datum.process_resource_regen()*/

/obj/manhattan/vehicles/proc/update_object_sprites() //This is modified on a vehicle-by-vehicle basis to render mobsprites etc, a basic render of playerheads in the top right is used if no overidden.
	underlays.Cut()
	overlays.Cut()
//	var/occupant_counter = 0
//	for(var/mob/living/carbon/human/h in occupants)
//		occupant_counter++
//		var/gender_suffix = "m"
//		if(h.gender == "female")
//			gender_suffix = "f"
//		var/image/head_bg = image('code/modules/halo/vehicles/headrep_base.dmi',"base")
//		var/image/mob_head = image(h.species.icobase,icon_state = "head_[gender_suffix]",dir = SOUTH)
//		var/shift_by
//		if(occupant_counter*9 >= bound_width) //Don't bother with more than one line of heads
//			return
//		if(occupant_counter*9 >= bound_width/2) //Handles basic occupant representation by creating small images of their heads and then shifting them in the top left corner of the icon.
//			shift_by = (occupant_counter*9) - 16 //*9 multiplier is applied to lower the amount of overlap on the head icons.
//		else
//			shift_by = -16 + (occupant_counter*9)
//		var/icon/mob_head_icon = new(mob_head.icon,mob_head.icon_state,SOUTH)
//		var/extra_shiftby_y = 0
//		if(mob_head_icon.Height() > 32)
//			extra_shiftby_y = mob_head_icon.Height() - 32
//		mob_head.pixel_y = ((bound_height-(32 + extra_shiftby_y)) + 3) + h.species.pixel_offset_y
//		head_bg.pixel_y = (bound_height-32) + 3 + h.species.pixel_offset_y
//		mob_head.pixel_x = shift_by + h.species.pixel_offset_x
//		head_bg.pixel_x = shift_by + h.species.pixel_offset_x
//		overlays += head_bg
//		overlays += mob_head

/obj/manhattan/vehicles/verb/verb_toggle_brakes()
	set name = "Toggle Brakes"
	set category = "Vehicle"
	set src in view(1)

	var/mob/living/user = usr
	if(!istype(user))
		return

	var/list/driver_list = get_occupants_in_position("driver")
	var/is_driver = FALSE
	for(var/mob/driver in driver_list)
		if(user == driver)
			is_driver = TRUE
			break
	if(!is_driver)
		to_chat(user,"<span class = 'notice'>You need to be the driver to do that.</span>")
		return

	toggle_brakes(user)

/obj/manhattan/vehicles/proc/toggle_brakes(var/mob/toggler)
	var/message = ""
	switch(braking_mode)
		if(0)
			braking_mode = 1
			drag *= 3
			message = "Braking system enabled."
		if(1)
			braking_mode = 0
			drag = initial(drag)
			message = "Braking system disabled."
		if(-1)
			message = "Enable brake safeties first."

	if(toggler)
		to_chat(toggler,"<span class = 'notice'>[message]</span>")

/obj/manhattan/vehicles/verb/verb_toggle_brake_safeties()
	set name = "Toggle Brake Safeties"
	set category = "Vehicle"
	set src in view(1)

	var/mob/living/user = usr
	if(!istype(user))
		return

	var/list/driver_list = get_occupants_in_position("driver")
	var/is_driver = FALSE
	for(var/mob/driver in driver_list)
		if(user == driver)
			is_driver = TRUE
			break
	if(!is_driver)
		to_chat(user,"<span class = 'notice'>You need to be the driver to do that.</span>")
		return

	toggle_brake_safeties(user)

/obj/manhattan/vehicles/proc/toggle_brake_safeties(var/mob/toggler)
	var/message = ""
	switch(braking_mode)
		if(0)
			braking_mode = -1
			drag /= 2
			message = "Braking system safeties disabled."
		if(-1)
			braking_mode = 0
			drag = initial(drag)
			message = "Braking system safeties enabled."
		if(1)
			message = "Disable the brakes first."

	if(toggler)
		to_chat(toggler,"<span class = 'notice'>[message]</span>")

/obj/manhattan/vehicles/Move(var/newloc,var/newdir)
	if(abs(speed[1]) > abs(speed[2]))
		if(speed[1] > 0)
			newdir = EAST
		else
			newdir = WEST
	else
		if(speed[2] > 0)
			newdir = NORTH
		else
			newdir = SOUTH
	if(anchored)
		anchored = 0
		. = ..()
		anchored = 1
	else
		. = ..()
	update_object_sprites()

/obj/manhattan/vehicles/fall()
	if(can_traverse_zs && active)
		return
	. = ..()

/obj/manhattan/vehicles/proc/collide_with_obstacle(var/atom/obstacle)
	if(istype(obstacle,/mob/living))
		var/mob/living/hit_mob = obstacle
		playsound(loc,collision_sound,100,0,4)
		hit_mob.Weaken(2) //No damage for now, let's just knock them over.
	else
		moving_x = 0
		moving_y = 0
		last_moved_axis = 0
		speed[1] = 0
		speed[2] = 0
	visible_message("<span class = 'notice'>[src] collides wth [obstacle]</span>")

/obj/manhattan/vehicles/Bump(var/atom/obstacle)
	..()
	. = collide_with_obstacle(obstacle)

/obj/manhattan/vehicles/proc/drag_slowdown(var/index,var/slowdown_amount = drag)
	if(speed[index] > 0)
		speed[index] = max(speed[index] - drag,0)
	else
		speed[index] = min(speed[index] + drag,0)

/obj/manhattan/vehicles/proc/movement_loop(var/speed_index_target = 1)
	var/noprocstart = 0
	if(moving_x || moving_y)
		noprocstart = 1
	switch(speed_index_target)
		if(1)
			moving_x = 1
		if(2)
			moving_y = 1
	if(noprocstart)
		return
	spawn()
		while (moving_x || moving_y)
			var/delay = max(min_speed - vector_modulus(speed), max_speed)
			sleep(delay)

			glide_size = 0

			for(var/mob/occupant in occupants)
				if(!ismob(occupant))
					continue

				occupant.update_glide(delay)

				if(!glide_size)
					glide_size = occupant.glide_size

			if(speed[1] == 0)
				moving_x = 0
			else
				if(speed[1] > 0)
					last_move = EAST
					. = Move(get_step(loc,EAST),EAST)
				else
					last_move = WEST
					. = Move(get_step(loc,WEST),WEST)

			if(speed[2] == 0)
				moving_y = 0
			else
				if(speed[2] > 0)
					last_move = NORTH
					. = Move(get_step(loc,NORTH),NORTH)
				else
					last_move = SOUTH
					. = Move(get_step(loc,SOUTH),SOUTH)
			var/list/index_list = list(1,2)
			for(var/index in index_list)
				if(last_moved_axis == index)
					continue
				drag_slowdown(index)
			if(world.time >= next_move_input_at)
				last_moved_axis = 0
			if(move_sound && world.time % 2 == 0)
				playsound(loc,move_sound,75,0,4)

/obj/manhattan/vehicles/bullet_act(var/obj/item/projectile/P, var/def_zone)
	var/pos_to_dam = should_damage_occ()
	var/mob/mob_to_dam
	if(movement_destroyed)
		var/list/mobs = list()
		for(var/mob/m in occupants)
			mobs += m
		if(mobs.len == 0)
			return
		mob_to_dam = pick(mobs)
		if(!isnull(mob_to_dam))
			mob_to_dam.bullet_act(P)
			return
	if(!isnull(pos_to_dam))
		var/should_continue = damage_occupant(pos_to_dam,P)
		if(!should_continue)
			return
	comp_prof.take_component_damage(P.get_structure_damage(),P.damtype)
	visible_message("<span class = 'danger'>[P] hits [src]!</span>")

/obj/manhattan/vehicles/ex_act(var/severity)
	comp_prof.take_comp_explosion_dam(severity)
	for(var/position in exposed_positions)
		for(var/mob/living/m in get_occupants_in_position(position))
			m.apply_damage((250/severity)*(exposed_positions[position]/100),BRUTE,,m.run_armor_check(null,"bomb"))

/obj/manhattan/vehicles/relaymove(var/mob/user, var/direction)
	if(world.time < next_move_input_at)
		return 0
	if(movement_destroyed)
		to_chat(user,"<span class = 'notice'>[src] is in no state to move!</span>")
		return 0
	if(!active)
		to_chat(user,"<span class = 'notice'>[src] needs to be active to move!</span>")
		return 0
	if(!(user in get_occupants_in_position("driver")))
		return -1 //doesn't return 0 so we can differentiate this from the other problems for simple mobs.

	if(!(direction in list(NORTH, SOUTH, EAST, WEST)))
		var/dirturn = 45
		if(prob(50))
			dirturn = -45
		direction = turn(direction,dirturn)
	switch(direction)
		if(NORTH)
			last_moved_axis = 2
			speed[2] = min(speed[2] + acceleration, min_speed)
		if(SOUTH)
			last_moved_axis = 2
			speed[2] = max(speed[2] - acceleration, -min_speed)
		if(EAST)
			last_moved_axis = 1
			speed[1] = min(speed[1] + acceleration, min_speed)
		if(WEST)
			last_moved_axis = 1
			speed[1] = max(speed[1] - acceleration, -min_speed)
	if(braking_mode == 1) //If we're braking, we don't get the leeway in movement.
		last_moved_axis = 0

	if(speed[1] != 0 && !moving_x)
		spawn()
			movement_loop(1)
	else if(speed[2] != 0 && !moving_y)
		spawn()
			movement_loop(2)

	next_move_input_at = world.time + acceleration
	return 1

/obj/manhattan/vehicles/verb/verb_inspect_components()
	set name = "Inspect Components"
	set category = "Vehicle"
	set src in view(1)

	var/mob/living/user = usr
	if(!istype(user))
		return

	comp_prof.inspect_components(user)

/obj/manhattan/vehicles/attack_hand(var/mob/user)
	if(user.a_intent != "harm")
		if(!enter_as_position(user,"driver"))
			if(!enter_as_position(user,"gunner"))
				enter_as_position(user,"passenger")
	else
		. = ..()

/*/obj/vehicles/attack_ghost(var/mob/observer/ghost/user)
	if(spawn_datum && spawn_datum.is_spawn_active)
		spawn_datum.handle_spawn(user,src)*/

/obj/manhattan/vehicles/attackby(var/obj/item/I,var/mob/user)
	if(elevation > user.elevation || elevation > I.elevation)
		to_chat(user,"<span class = 'notice'>[name] is too far away to interact with!</span>")
		return
	if(!istype(I))
		return
	if(istype(I,/obj/item/weapon/grab))
		handle_grab_attack(I,user)
		return
	if(user.a_intent == I_HURT)
		if(comp_prof.is_repair_tool(I))
			comp_prof.repair_inspected_with_tool(I,user)
			return
		if(istype(I,/obj/item/stack))
			comp_prof.repair_inspected_with_sheet(I,user)
			return
		. = ..()
		user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
		var/pos_to_dam = should_damage_occ()
		if(!isnull(pos_to_dam))
			damage_occupant(pos_to_dam,I,user)
			return
		comp_prof.take_component_damage(I.force,I.damtype)
		return
	put_cargo_item(user,I)
