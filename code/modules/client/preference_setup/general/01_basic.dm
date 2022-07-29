datum/preferences
	var/biological_gender = MALE
	var/identifying_gender = MALE

datum/preferences/proc/set_biological_gender(var/gender)
	biological_gender = gender
	identifying_gender = gender

/datum/category_item/player_setup_item/general/basic
	name = "Basic"
	sort_order = 1

/datum/category_item/player_setup_item/general/basic/load_character(var/savefile/S)
	S["real_name"]				>> pref.real_name
	S["nickname"]				>> pref.nickname
//	S["name_is_always_random"]	>> pref.be_random_name
	S["gender"]				>> pref.biological_gender
	S["id_gender"]				>> pref.identifying_gender
	S["age"]					>> pref.age
	S["birth_day"]				>> pref.birth_day
	S["birth_month"]			>> pref.birth_month
	S["birth_year"]			>> pref.birth_year
	S["spawnpoint"]			>> pref.spawnpoint
	S["OOC_Notes"]				>> pref.metadata
	S["email"]				>> pref.email
	S["existing_character"]		>> pref.existing_character
	S["played"]				>> pref.played
	S["unique_id"]				>> pref.unique_id
	S["silent_join"]			>> pref.silent_join

/datum/category_item/player_setup_item/general/basic/save_character(var/savefile/S)
	S["real_name"]				<< pref.real_name
	if(pref.client)
		send_output(pref.client, pref.real_name, "lobbybrowser:change_cname")
	S["nickname"]				<< pref.nickname
//	S["name_is_always_random"]	<< pref.be_random_name
	S["gender"]				<< pref.biological_gender
	S["id_gender"]				<< pref.identifying_gender
	S["age"]					<< pref.age
	S["birth_day"]				<< pref.birth_day
	S["birth_month"]			<< pref.birth_month
	S["birth_year"]			<< pref.birth_year
	S["spawnpoint"]			<< pref.spawnpoint
	S["OOC_Notes"]				<< pref.metadata
	S["email"]				<< pref.email
	S["existing_character"]		<< pref.existing_character
	S["played"]				<< pref.played
	S["unique_id"]				<< pref.unique_id
	S["silent_join"]			<< pref.silent_join

/datum/category_item/player_setup_item/general/basic/delete_character()
	if(pref.played)
		pref.characters_created += pref.real_name

	pref.real_name = null
	pref.nickname = null
//	pref.be_random_name = null
	pref.biological_gender = null
	pref.identifying_gender = null
	pref.age = null
	pref.birth_day = null
	pref.birth_month = null
	pref.birth_year = null
	pref.spawnpoint = null
	pref.metadata = null
	pref.existing_character = null
	pref.played = null
	delete_persistent_inventory(pref.unique_id)
	pref.unique_id = null
	if(fdel("data/persistent/emails/[pref.email].sav"))
		pref.email = null
	pref.silent_join = null


/datum/category_item/player_setup_item/general/basic/sanitize_character()

	pref.biological_gender  = sanitize_inlist(pref.biological_gender, get_genders(), pick(get_genders()))
	pref.identifying_gender = (pref.identifying_gender in all_genders_define_list) ? pref.identifying_gender : pref.biological_gender
	// pref.real_name		= sanitize_name(pref.real_name, pref.species, is_FBP())
	change_real_name(sanitize_name(pref.real_name, pref.species, is_FBP()))
	if(!pref.real_name || (pref.real_name in pref.characters_created))
		pref.real_name      = random_name(pref.identifying_gender, pref.species)

	if(!pref.birth_year)
		adjust_year()

	pref.age                = sanitize_integer(pref.age, get_min_age(), get_max_age(), initial(pref.age))
	pref.birth_day          = sanitize_integer(pref.birth_day, 1, 31, initial(pref.birth_day))
	pref.birth_month        = sanitize_integer(pref.birth_month, 1, 12, initial(pref.birth_month))


	pref.nickname		= sanitize_name(pref.nickname)
	pref.spawnpoint         = sanitize_inlist(pref.spawnpoint, spawntypes, initial(pref.spawnpoint))
//	pref.be_random_name     = sanitize_integer(pref.be_random_name, 0, 1, initial(pref.be_random_name))
	if(!pref.unique_id)
		pref.unique_id			= md5("[pref.client_ckey][rand(30,50)]")

	if(!pref.email)
		var/new_email = SSemails.generate_email(pref.real_name)

		if(!ntnet_global.does_email_exist(new_email) || !SSemails.check_persistent_email(new_email))
			pref.email = new_email



// Moved from /datum/preferences/proc/copy_to()
/datum/category_item/player_setup_item/general/basic/copy_to_mob(var/mob/living/carbon/human/character)
	if(config.humans_need_surnames && !is_FBP())
		var/firstspace = findtext(pref.real_name, " ")
		var/name_length = length(pref.real_name)
		if(!firstspace)	//we need a surname
			pref.real_name += " [pick(last_names)]"
		else if(firstspace == name_length)
			pref.real_name += "[pick(last_names)]"

	if(is_FBP() && !pref.real_name)
		pref.real_name = "[pick(last_names)]"

	character.real_name = pref.real_name
	character.name = character.real_name
	if(character.dna)
		character.dna.real_name = character.real_name

	character.nickname = pref.nickname

	character.gender = pref.biological_gender
	character.identifying_gender = pref.identifying_gender
	character.age = pref.age
	character.birth_year = pref.birth_year
	character.birth_month = pref.birth_month

F

/datum/category_item/player_setup_item/general/basic/content()
	. = list()
	. += "<h1>Основное:</h1><hr>"
	if(!pref.existing_character)
		. += "Установите здесь общие сведения о вашем персонаже. После того, как ваше имя, возраст и пол установлены, <b>вы не можете изменить их снова.</b> Ваш псевдоним и языки можно изменить, однако вы автоматически состаритесь.<br><br>"
	. += "<b>Имя:</b><br>"
	if(!pref.existing_character)
		. += "<a href='?src=\ref[src];rename=1'><b>[pref.real_name]</b></a><br>"
		. += "<a href='?src=\ref[src];random_name=1'>Случайное Имя</A><br>"
	else
		. += "[pref.real_name]<br>"
//	. += "<a href='?src=\ref[src];always_random_name=1'>Always Random Name: [pref.be_random_name ? "Yes" : "No"]</a><br>"
	. += "<b>Биологический пол:</b><br>"
	if(!pref.existing_character)
		. += "<a href='?src=\ref[src];bio_gender=1'><b>[gender2text(pref.biological_gender)]</b></a><br>"
	else
		. += "[gender2text(pref.biological_gender)]<br>"

	. += "<b>Возраст:</b><br>"
	. += "<a href='?src=\ref[src];age=1'>[pref.age] ([age2agedescription(pref.age)])</a><br><br>"

	. += "<b>Почтовый адрес:</b><br>"

	if(!pref.existing_character)
		. += "Почта: <a href='?src=\ref[src];email_domain=1'>[pref.email]</a><br><br>"
	else
		. += "Логин: [pref.email]<br>Пароль: [SSemails.get_persistent_email_password(pref.email)] <br><br>"

	if(pref.existing_character)
		. += "<b>Уникальное ИД:</b> [pref.unique_id]<br>"


	. += "<b>Дата рождения:</b><br>"

	if(!pref.existing_character)
		. += "<a href='?src=\ref[src];birth_day=1'>[pref.birth_day]</a>/"
		. += "<a href='?src=\ref[src];birth_month=1'>[pref.birth_month]</a>/"
		. += "[pref.birth_year]<br><br>"
	else
		. += "[pref.birth_day]/[pref.birth_month]/[pref.birth_year]<br><br>"

	. += "<b>Точка захода</b>:<br> <a href='?src=\ref[src];spawnpoint=1'>[pref.spawnpoint]</a><br>"
	. += "<b>Тихое прибытие</b>:<br> <a href='?src=\ref[src];silent_join=1'>[(pref.silent_join) ? "Yes" : "No"]</a><br>"

	if(config.allow_Metadata)
		. += "<b>OOC Заметки:</b><br> <a href='?src=\ref[src];metadata=1'> Edit </a><br>"
	. = jointext(.,null)
/datum/category_item/player_setup_item/general/basic/proc/change_real_name(newname)
	pref.real_name = newname
	if(pref.client)
		send_output(pref.client, newname, "lobbybrowser:change_cname")
/datum/category_item/player_setup_item/general/basic/OnTopic(var/href,var/list/href_list, var/mob/user)
	if(href_list["rename"])
		var/raw_name = input(user, "Выберите имя персонажа:", "Имя персонажа")  as text|null
		if (!isnull(raw_name) && CanUseTopic(user))
			var/new_name = sanitize_name(raw_name, pref.species, is_FBP())

			if(new_name in pref.characters_created)
				to_chat(user, "<span class='warning'>Вы больше не можете играть за этого персонажа. Напишите администрации, если это ошибка.</span>")
				return TOPIC_NOACTION

			if(new_name)
				change_real_name(new_name)
				// pref.real_name = new_name
				// send_output(pref.client, pref.real_name, "lobbybrowser:change_cname")
				return TOPIC_REFRESH
			else
				to_chat(user, "<span class='warning'>Неправильное имя. Ваше имя должно содержать как минимум 2 и как максимум [MAX_NAME_LEN] символов. Оно может содержать только символы A-Z, a-z, -, ' и .</span>")
				return TOPIC_NOACTION

	else if(href_list["random_name"])
		change_real_name(random_name(pref.identifying_gender, pref.species))
		// pref.real_name = random_name(pref.identifying_gender, pref.species)
		// send_output(pref.client, pref.real_name, "lobbybrowser:change_cname")
		return TOPIC_REFRESH
/*
	else if(href_list["always_random_name"])
		pref.be_random_name = !pref.be_random_name
		return TOPIC_REFRESH
*/
	else if(href_list["nickname"])
		var/raw_nickname = input(user, "Выберите прозвище вашего персонажа:", "Character Nickname")  as text|null
		if (!isnull(raw_nickname) && CanUseTopic(user))
			var/new_nickname = sanitize_name(raw_nickname, pref.species, is_FBP())
			if(new_nickname)
				pref.nickname = new_nickname
				return TOPIC_REFRESH
			else
				to_chat(user, "<span class='warning'>Неправильное имя. Ваше имя должно содержать как минимум 2 и как максимум [MAX_NAME_LEN] символов. Оно может содержать только символы A-Z, a-z, -, ' и .</span>")
				return TOPIC_NOACTION

	else if(href_list["bio_gender"])
		var/new_gender = input(user, "Choose your character's biological gender:", "Character Preference", pref.biological_gender) as null|anything in get_genders()
		if(new_gender && CanUseTopic(user))
			pref.set_biological_gender(new_gender)
		return TOPIC_REFRESH_UPDATE_PREVIEW

	else if(href_list["id_gender"])
		var/new_gender = input(user, "Выберите пол вашего персонажа:", "Character Preference", pref.identifying_gender) as null|anything in all_genders_define_list
		if(new_gender && CanUseTopic(user))
			pref.identifying_gender = new_gender
		return TOPIC_REFRESH

	else if(href_list["age"])
		var/min_age = get_min_age()
		var/max_age = get_max_age()
		var/new_age = input(user, "Выберите возраст вашего персонажа:\n([min_age]-[max_age])", "Character Preference", pref.age) as num|null
		if(new_age && CanUseTopic(user))
			pref.age = max(min(round(text2num(new_age)), max_age), min_age)
			adjust_year()
			return TOPIC_REFRESH


	else if(href_list["email_domain"])
		var/list/domains = using_map.usable_email_tlds
		var/prefix = input(user, "Выберите имя пользователя почты вашего персонажа.", "Email Username")  as text|null
		if(!prefix)
			return

		var/domain = input(user, "Выберите домен вашей почты?", "Email Provider") as null|anything in domains
		if(!domain)
			return

		var/full_email = "[prefix]@[domain]"

		if(full_email && SSemails.check_persistent_email(full_email))
			alert(user, "Эта почта уже существует.")
			return

		if(full_email && !SSemails.check_persistent_email(pref.email))
			SSemails.new_persistent_email(full_email)


		fcopy("data/persistent/emails/[pref.email].sav","data/persistent/emails/[full_email].sav")
		fdel("data/persistent/emails/[pref.email].sav")
		SSemails.change_persistent_email_address(pref.email, full_email)

		pref.email = "[prefix]@[domain]"


		return TOPIC_REFRESH


	else if(href_list["birth_day"])
		var/min_day = 1
		var/max_day

		if(pref.birth_month in THIRTY_ONE_DAY_MONTHS) //Please don't look, I have shame.
			max_day = 31

		if(pref.birth_month in THIRTY_DAY_MONTHS)
			max_day = 30

		if(pref.birth_month in TWENTY_EIGHT_DAY_MONTHS)
			max_day = 28

		var/new_day = input(user, "Выберите день рождения вашего персонажа:\n([min_day]-[max_day])", "Character Preference", pref.birth_day) as num|null
		if(new_day && CanUseTopic(user))
			pref.birth_day = max(min(round(text2num(new_day)), max_day), min_day)
			adjust_year()
			return TOPIC_REFRESH

	else if(href_list["birth_month"])
		var/month_min = 1
		var/month_max = 12

		var/new_month = input(user, "Выберите месяц рождения вашего персонажа:\n([month_min]-[month_max])", "Character Preference", pref.birth_month) as num|null
		if(new_month && CanUseTopic(user))
			pref.birth_month = max(min(round(text2num(new_month)), month_max), month_min)
			if(pref.birth_month in THIRTY_DAY_MONTHS)
				if(pref.birth_day > 30)
					pref.birth_day = 30
			if(pref.birth_month in TWENTY_EIGHT_DAY_MONTHS)
				if(pref.birth_day > 28)
					pref.birth_day = 28
			adjust_year()
			return TOPIC_REFRESH

	else if(href_list["spawnpoint"])
		var/list/spawnkeys = list()
		for(var/spawntype in spawntypes)
			spawnkeys += spawntype
		var/choice = input(user, "Где бы вы хотели появляться при позднем заходе в раунд?") as null|anything in spawnkeys
		if(!choice || !spawntypes[choice] || !CanUseTopic(user))	return TOPIC_NOACTION
		pref.spawnpoint = choice
		return TOPIC_REFRESH

	else if(href_list["metadata"])
		var/new_metadata = sanitize(input(user, "Введите общедоступную для других игроков информацию:", "Game Preference" , pref.metadata) as message|null)
		if(new_metadata && CanUseTopic(user))
			pref.metadata = new_metadata
			return TOPIC_REFRESH

	else if(href_list["silent_join"])
		if(CanUseTopic(user))
			pref.silent_join = !pref.silent_join
			return TOPIC_REFRESH

	return ..()

/datum/category_item/player_setup_item/general/basic/proc/get_genders()
	var/datum/species/S
	if(pref.species)
		S = all_species[pref.species]
	else
		S = all_species[SPECIES_HUMAN]
	var/list/possible_genders = S.genders
	if(!pref.organ_data || pref.organ_data[BP_TORSO] != "cyborg")
		return possible_genders
	possible_genders = possible_genders.Copy()
	possible_genders |= NEUTER
	return possible_genders

/datum/category_item/player_setup_item/general/basic/proc/adjust_year()
	//this should only be set once, ever
	pref.birth_year = (get_game_year() - pref.age)

	//if it hasn't been their most recent birthday yet...
	if((get_game_month() < pref.birth_month) && (get_game_day() < pref.birth_day))
		pref.birth_year --

	return TOPIC_REFRESH
