#define SCRAMBLE_CACHE_LEN 20

/*
	Datum based languages. Easily editable and modular.
*/

/datum/language
	var/name = "an unknown language"  // Fluff name of language if any.
	var/desc = "A language."          // Short description for 'Check Languages'.
	var/speech_verb = "says"          // 'says', 'hisses', 'farts'.
	var/ask_verb = "asks"             // Used when sentence ends in a ?
	var/exclaim_verb = "exclaims"     // Used when sentence ends in a !
	var/whisper_verb                  // Optional. When not specified speech_verb + quietly/softly is used instead.
	var/signlang_verb = list("signs", "gestures") // list of emotes that might be displayed if this language has NONVERBAL or SIGNLANG flags
	var/colour = "body"               // CSS style to use for strings in this language.
	var/key = "x"                     // Character used to speak in language eg. :o for Unathi.
	var/flags = 0                     // Various language flags.
	var/native                        // If set, non-native speakers will have trouble speaking.
	var/list/syllables                // Used when scrambling text for a non-speaker.
	var/list/space_chance = 55        // Likelihood of getting a space in the random scramble string
	var/machine_understands = 1		  // Whether machines can parse and understand this language
	var/list/partial_understanding	  // List of languages that can /somehwat/ understand it, format is: name = chance of understanding a word


/datum/language/proc/get_random_name(var/gender, name_count=2, syllable_count=4, syllable_divisor=2)
	if(!syllables || !syllables.len)
		if(gender==FEMALE)
			return capitalize(pick(first_names_female)) + " " + capitalize(pick(last_names))
		else
			return capitalize(pick(first_names_male)) + " " + capitalize(pick(last_names))

	var/full_name = ""
	var/new_name = ""

	for(var/i = 0;i<name_count;i++)
		new_name = ""
		for(var/x = rand(floor(syllable_count/syllable_divisor),syllable_count);x>0;x--)
			new_name += pick(syllables)
		full_name += " [capitalize(lowertext(new_name))]"

	return "[trim(full_name)]"

/datum/language
	var/list/scramble_cache = list()

/datum/language/proc/scramble(var/input, var/list/known_languages)
	var/understand_chance = 0
	for(var/datum/language/L in known_languages)
		if(partial_understanding && partial_understanding[L.name])
			understand_chance += partial_understanding[L.name]
		if(L.partial_understanding && L.partial_understanding[name])
			understand_chance += L.partial_understanding[name] * 0.5
	var/scrambled_text = ""
	var/list/words = splittext(input, " ")
	for(var/w in words)
		if(prob(understand_chance))
			scrambled_text += " [w] "
		else
			var/nword = scramble_word(w)
			var/ending = copytext(scrambled_text, length(scrambled_text)-1)
			if(findtext(ending,"."))
				nword = capitalize(nword)
			else if(findtext(ending,"!"))
				nword = capitalize(nword)
			else if(findtext(ending,"?"))
				nword = capitalize(nword)
			scrambled_text += nword
	scrambled_text = replacetext_char(scrambled_text,"  "," ")
	scrambled_text = capitalize(scrambled_text)
	scrambled_text = trim(scrambled_text)
	var/ending = copytext(scrambled_text, length(scrambled_text))
	if(ending == ".")
		scrambled_text = copytext(scrambled_text,1,length(scrambled_text)-1)

	var/input_ending = copytext(input, length(input))
	if(input_ending in list("!","?","."))
		scrambled_text += input_ending

	return scrambled_text

/datum/language/proc/scramble_word(var/input)
	if(!syllables || !syllables.len)
		return stars(input)

	// If the input is cached already, move it to the end of the cache and return it
	if(input in scramble_cache)
		var/n = scramble_cache[input]
		scramble_cache -= input
		scramble_cache[input] = n
		return n

	var/input_size = length(input)
	var/scrambled_text = ""
	var/capitalize = 0

	while(length(scrambled_text) < input_size)
		var/next = pick(syllables)
		if(capitalize)
			next = capitalize(next)
			capitalize = 0
		scrambled_text += next
		var/chance = rand(100)
		if(chance <= 5)
			scrambled_text += ". "
			capitalize = 1
		else if(chance > 5 && chance <= space_chance)
			scrambled_text += " "

	// Add it to cache, cutting old entries if the list is too long
	scramble_cache[input] = scrambled_text
	if(scramble_cache.len > SCRAMBLE_CACHE_LEN)
		scramble_cache.Cut(1, scramble_cache.len-SCRAMBLE_CACHE_LEN-1)

	return scrambled_text

/datum/language/proc/format_message(message, verb)
	return "[verb], <span class='message'><span class='[colour]'>\"[capitalize(message)]\"</span></span>"

/datum/language/proc/format_message_plain(message, verb)
	return "[verb], \"[capitalize(message)]\""

/datum/language/proc/format_message_radio(message, verb)
	return "[verb], <span class='[colour]'>\"[capitalize(message)]\"</span>"

/datum/language/proc/get_talkinto_msg_range(message)
	// if you yell, you'll be heard from two tiles over instead of one
	return (copytext(message, length(message)) == "!") ? 2 : 1

/datum/language/proc/broadcast(var/mob/living/speaker,var/message,var/speaker_mask)
	log_say("(HIVE) [message]", speaker)

	if(!speaker_mask) speaker_mask = speaker.name
	message = format_message(message, get_spoken_verb(message))

	for(var/mob/player in player_list)
		player.hear_broadcast(src, speaker, speaker_mask, message)

/mob/proc/hear_broadcast(var/datum/language/language, var/mob/speaker, var/speaker_name, var/message)
	if((language in languages) && language.check_special_condition(src))
		var/msg = "<i><span class='game say'>[language.name], <span class='name'>[speaker_name]</span> [message]</span></i>"
		src << msg

/mob/new_player/hear_broadcast(var/datum/language/language, var/mob/speaker, var/speaker_name, var/message)
	return

/mob/observer/dead/hear_broadcast(var/datum/language/language, var/mob/speaker, var/speaker_name, var/message)
	if(speaker.name == speaker_name || antagHUD)
		to_chat(src, "<i><span class='game say'>[language.name], <span class='name'>[speaker_name]</span> ([ghost_follow_link(speaker, src)]) [message]</span></i>")
	else
		to_chat(src, "<i><span class='game say'>[language.name], <span class='name'>[speaker_name]</span> [message]</span></i>")

/datum/language/proc/check_special_condition(var/mob/other)
	return 1

/datum/language/proc/get_spoken_verb(var/msg_end)
	switch(msg_end)
		if("!")
			return exclaim_verb
		if("?")
			return ask_verb
	return speech_verb

/datum/language/proc/can_speak_special(mob/speaker)
	. = TRUE
	if(ishuman(speaker))
		var/mob/living/carbon/human/H = speaker
		if(H.species.has_organ[O_VOICE] && !(flags & SIGNLANG) && !(flags & NONVERBAL)) // Does the species need a voicebox? Is the language even spoken?
			var/obj/item/organ/internal/voicebox/vocal = H.internal_organs_by_name[O_VOICE]
			if(!vocal || vocal.is_broken() || vocal.mute)
				return FALSE
			if(src.name in vocal.blacklist_languages)
				return FALSE

// Language handling.
/mob/proc/add_language(var/language)

	var/datum/language/new_language = all_languages[language]

	if(!istype(new_language) || (new_language in languages))
		return 0

	languages.Add(new_language)
	return 1

/mob/proc/remove_language(var/rem_language)
	var/datum/language/L = all_languages[rem_language]
	. = (L in languages)
	languages.Remove(L)

/mob/living/remove_language(rem_language)
	var/datum/language/L = all_languages[rem_language]
	if(default_language == L)
		default_language = null
	return ..()

// Can we speak this language, as opposed to just understanding it?
/mob/proc/can_speak(datum/language/speaking)
//Prevents someone from speaking a null language.
	if(!speaking)
		log_debug("[src] attempted to speak a null language.")
		return FALSE

	if (only_species_language && speaking != all_languages[species_language])
		to_world("-1")
		return FALSE

	if(!speaking.can_speak_special(src))
		to_world("0")
		return FALSE

	if(universal_speak)
		return TRUE
	if(speaking && (speaking.flags & INNATE))
		return TRUE
	if(speaking in src.languages)
		return TRUE

	// return (speaking.can_speak_special(src) &&
	// (universal_speak || (speaking && (speaking.flags & INNATE)) || (speaking in src.languages))
	// )

/mob/proc/get_language_prefix()
	if(client && client.prefs.language_prefixes && client.prefs.language_prefixes.len)
		return client.prefs.language_prefixes[1]

	return config.language_prefixes[1]

/mob/proc/is_language_prefix(var/prefix)
	if(client && client.prefs.language_prefixes && client.prefs.language_prefixes.len)
		return prefix in client.prefs.language_prefixes

	return prefix in config.language_prefixes

//TBD
/mob/verb/check_languages()
	set name = "Check Known Languages"
	set category = "IC"
	set src = usr

	var/dat = "<b><font size = 5>Known Languages</font></b><br/><br/>"

	for(var/datum/language/L in languages)
		if(!(L.flags & NONGLOBAL))
			dat += "<b>[L.name] ([get_language_prefix()][L.key])</b><br/>[L.desc]<br/><br/>"

	src << browse(dat, "window=checklanguage")
	return

/mob/living/check_languages()
	var/dat = "<b><font size = 5>Known Languages</font></b><br/><br/>"

	if(default_language)
		dat += "Current default language: [default_language] - <a href='byond://?src=\ref[src];default_lang=reset'>reset</a><br/><br/>"

	for(var/datum/language/L in languages)
		if(!(L.flags & NONGLOBAL))
			if(L == default_language)
				dat += "<b>[L.name] ([get_language_prefix()][L.key])</b> - default - <a href='byond://?src=\ref[src];default_lang=reset'>reset</a><br/>[L.desc]<br/><br/>"
			else if (can_speak(L))
				dat += "<b>[L.name] ([get_language_prefix()][L.key])</b> - <a href='byond://?src=\ref[src];default_lang=\ref[L]'>set default</a><br/>[L.desc]<br/><br/>"
			else
				dat += "<b>[L.name] ([get_language_prefix()][L.key])</b> - cannot speak!<br/>[L.desc]<br/><br/>"

	src << browse(dat, "window=checklanguage")

/mob/living/Topic(href, href_list)
	if(href_list["default_lang"])
		if(href_list["default_lang"] == "reset")
			if (species_language)
				set_default_language(all_languages[species_language])
			else
				set_default_language(null)
		else
			var/datum/language/L = locate(href_list["default_lang"])
			if(L && (L in languages))
				set_default_language(L)
		check_languages()
		return 1
	else
		return ..()

/proc/transfer_languages(var/mob/source, var/mob/target, var/except_flags)
	for(var/datum/language/L in source.languages)
		if(L.flags & except_flags)
			continue
		target.add_language(L.name)

#undef SCRAMBLE_CACHE_LEN