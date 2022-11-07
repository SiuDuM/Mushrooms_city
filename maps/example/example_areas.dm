// Elevator areas.
/area/turbolift/example_top
	name = "lift (top floor)"
	lift_floor_label = "Floor 2"
	lift_floor_name = "Top Floor"
	lift_announce_str = "Arriving at Top Floor."

/area/turbolift/example_ground
	name = "lift (ground floor)"
	lift_floor_label = "Floor 1"
	lift_floor_name = "First Floor"
	lift_announce_str = "Arriving at First Floor."
	base_turf = /turf/simulated/floor

/area/example_mine_lift
	name = "example mine lift"
	requires_power = FALSE

/area/mine
	name = "mine"
	requires_power = FALSE
	should_objects_be_saved = FALSE
