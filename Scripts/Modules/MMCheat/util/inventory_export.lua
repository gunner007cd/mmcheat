local enc = require("MMCheat/i18n/encoding")
local utils = require("MMCheat/util/utils")

local M = {}

local function bool_text(v)
	return v and "Yes" or "No"
end

local function clean_cell(v)
	if v == nil then
		return ""
	end
	local s = tostring(v)
	s = s:gsub("\t", " "):gsub("\r", " "):gsub("\n", " ")
	return s
end

local function safe_number(v, fallback)
	local n = tonumber(v)
	if n == nil then
		return fallback or 0
	end
	return n
end

-- MMExtension arrays throw when an invalid index is read. Never probe one
-- directly unless it is behind this guard.
local function safe_array_get(arr, index)
	if not arr or index == nil then
		return nil
	end
	index = tonumber(index)
	if not index then
		return nil
	end

	local ok_count, count = pcall(function()
		return tonumber(arr.Count)
	end)
	if ok_count and count and (index < 0 or index >= count) then
		return nil
	end

	local ok, value = pcall(function()
		return arr[index]
	end)
	if ok then
		return value
	end
	return nil
end

local function safe_decode(v)
	if v == nil then
		return ""
	end
	local ok, decoded = pcall(enc.decode, v)
	if ok and decoded ~= nil then
		return decoded
	end
	return tostring(v)
end

local function safe_field(obj, field, fallback)
	if not obj then
		return fallback
	end
	local ok, value = pcall(function()
		return obj[field]
	end)
	if ok and value ~= nil then
		return value
	end
	return fallback
end

local function safe_item_method(item, method_name)
	if not item then
		return nil
	end
	local ok, value = pcall(function()
		local fn = item[method_name]
		if type(fn) == "function" then
			return fn(item)
		end
		return nil
	end)
	if ok then
		return value
	end
	return nil
end

local function safe_char_method(char, method_name)
	if not char then
		return nil
	end
	local ok, value = pcall(function()
		local fn = char[method_name]
		if type(fn) == "function" then
			return fn(char)
		end
		return nil
	end)
	if ok then
		return value
	end
	return nil
end

local function safe_char_method_1(char, method_name, arg1)
	if not char then
		return nil
	end
	local ok, value = pcall(function()
		local fn = char[method_name]
		if type(fn) == "function" then
			return fn(char, arg1)
		end
		return nil
	end)
	if ok then
		return value
	end
	return nil
end

-- Read only the numeric Material field for every item. Notes is intentionally
-- touched only for actual Artifact/Relic rows; reading Notes across every item
-- caused a hard CTD in this Merge/Revamp setup.
local function item_material_id(info)
	if not info then
		return 0
	end
	local ok, value = pcall(function()
		return info.Material
	end)
	if not ok then
		return 0
	end
	return tonumber(value) or 0
end

local function material_name(id)
	id = tonumber(id) or 0
	if id == 1 then return "Artifact" end
	if id == 2 then return "Relic" end
	if id == 3 then return "Special" end
	return "Normal"
end

local function intrinsic_notes(info, material_id)
	if not info or (material_id ~= 1 and material_id ~= 2) then
		return ""
	end
	local ok, value = pcall(function()
		return info.Notes
	end)
	if not ok or value == nil then
		return ""
	end
	return safe_decode(value)
end

local function std_bonus_info(item)
	local id = tonumber(item.Bonus) or 0
	if id <= 0 then
		return 0, "", "", 0
	end

	local row = safe_array_get(Game.StdItemsTxt, id - 1)
	if row then
		return id,
			safe_decode(row.NameAdd or ""),
			safe_decode(row.BonusStat or ""),
			tonumber(item.BonusStrength) or 0
	end

	local stats_names = nil
	pcall(function()
		stats_names = Game.StatsNames
	end)
	local stat_name = safe_array_get(stats_names, id - 1)
	return id, "", safe_decode(stat_name or ""), tonumber(item.BonusStrength) or 0
end

local function special_bonus_info(item)
	local id = tonumber(item.Bonus2) or 0
	if id <= 0 then
		return 0, "", ""
	end

	local row = safe_array_get(Game.SpcItemsTxt, id - 1)
	if not row then
		return id, "", ""
	end
	return id,
		safe_decode(row.NameAdd or ""),
		safe_decode(row.BonusStat or "")
end

local function is_equipped(char, item_index)
	if not char or not char.EquippedItems then
		return false
	end
	for j = 0, char.EquippedItems.Count - 1 do
		if char.EquippedItems[j] == item_index then
			return true
		end
	end
	return false
end

local function item_record(char, party_slot, item_index)
	local item = char.Items[item_index]
	if not item or item.Number == 0 then
		return nil
	end

	local info = safe_array_get(Game.ItemsTxt, item.Number)
	if not info then
		return nil
	end

	local std_id, std_name, std_stat, std_strength = std_bonus_info(item)
	local spc_id, spc_name, spc_stat = special_bonus_info(item)

	local identified_name = safe_item_method(item, "GetIdentifiedName")
	local current_name = safe_item_method(item, "GetName")
	local item_value = safe_item_method(item, "GetValue")

	local material_id = item_material_id(info)
	local notes = intrinsic_notes(info, material_id)

	return {
		character = safe_decode(char.Name or ""),
		party_slot = party_slot,
		item_slot = item_index,
		equipped = is_equipped(char, item_index),
		base_item = safe_decode(info.Name or ""),
		unidentified_name = safe_decode(info.NotIdentifiedName or ""),
		display_name = safe_decode(identified_name or info.Name or ""),
		current_name = safe_decode(current_name or identified_name or info.Name or ""),
		item_id = item.Number,
		item_value = tonumber(item_value) or tonumber(info.Value) or 0,
		material_id = material_id,
		material_type = material_name(material_id),
		intrinsic_notes = notes,
		standard_bonus_id = std_id,
		standard_name_add = std_name,
		standard_bonus_stat = std_stat,
		standard_strength = std_strength,
		special_bonus_id = spc_id,
		special_name_add = spc_name,
		special_bonus_stat = spc_stat,
		charges = tonumber(item.Charges) or 0,
		max_charges = tonumber(item.MaxCharges) or 0,
		identified = not not item.Identified,
		stolen = not not item.Stolen,
		broken = not not item.Broken,
		hardened = not not item.Hardened,
		refundable = not not item.Refundable,
		temporary_bonus = not not item.TemporaryBonus,
		owner = tonumber(item.Owner) or 0,
	}
end

local function mastery_name(mastery)
	mastery = tonumber(mastery) or 0
	if mastery == 1 then return "Basic" end
	if mastery == 2 then return "Expert" end
	if mastery == 3 then return "Master" end
	if mastery == 4 then return "Grandmaster" end
	return "Not learned"
end

local function split_skill_safe(raw)
	local ok, level, mastery = pcall(SplitSkill, raw or 0)
	if ok then
		return tonumber(level) or 0, tonumber(mastery) or 0
	end
	return 0, 0
end

local function collect_skills(char, party_slot, char_name)
	local rows = {}
	local skill_defs = {}
	for key, value in pairs(const.Skills or {}) do
		if type(value) == "number" then
			table.insert(skill_defs, { key = key, value = value })
		end
	end
	table.sort(skill_defs, function(a, b)
		if a.value == b.value then
			return tostring(a.key) < tostring(b.key)
		end
		return a.value < b.value
	end)

	local seen_ids = {}
	for _, def in ipairs(skill_defs) do
		local skill_id = def.value
		if not seen_ids[skill_id] then
			seen_ids[skill_id] = true
			local raw = safe_array_get(char.Skills, skill_id)
			raw = tonumber(raw) or 0
			local rank, mastery = split_skill_safe(raw)

			if rank > 0 then
				local skill_name = safe_decode(safe_array_get(Game.SkillNames, skill_id) or def.key)
				local effective_raw = safe_char_method_1(char, "GetSkill", skill_id)
				if effective_raw == nil then
					effective_raw = raw
				end
				local effective_rank, effective_mastery = split_skill_safe(effective_raw)
				if effective_rank <= 0 then
					effective_rank, effective_mastery = rank, mastery
				end
				table.insert(rows, {
					character = char_name,
					party_slot = party_slot,
					skill_id = skill_id,
					skill_key = tostring(def.key),
					skill_name = skill_name,
					rank = rank,
					mastery = mastery,
					mastery_name = mastery_name(mastery),
					raw_value = raw,
					effective_rank = effective_rank,
					effective_mastery = effective_mastery,
					effective_mastery_name = mastery_name(effective_mastery),
					effective_raw_value = tonumber(effective_raw) or raw,
				})
			end
		end
	end
	return rows
end

local function get_effective_resistance(char, res)
	if Game.Version ~= 6 then
		local damage_kind = nil
		pcall(function()
			if const.Damage then
				damage_kind = const.Damage[res]
			end
		end)
		if damage_kind ~= nil then
			local v = safe_char_method_1(char, "GetResistance", damage_kind)
			if v ~= nil then return tonumber(v) end
		end
	else
		local method_map = {
			Fire = "GetFireResistance",
			Elec = "GetElectricityResistance",
			Cold = "GetColdResistance",
			Poison = "GetPoisonResistance",
			Magic = "GetMagicResistance",
		}
		local method = method_map[res]
		if method then
			local v = safe_char_method(char, method)
			if v ~= nil then return tonumber(v) end
		end
	end
	return nil
end

local function collect_character_record(char, party_slot)
	local name = safe_decode(safe_field(char, "Name", "Character " .. tostring(party_slot)))
	local class_id = safe_number(safe_field(char, "Class", 0), 0)
	local class_name = tostring(class_id)
	local ok_class, resolved_class = pcall(utils.class_name, class_id)
	if ok_class and resolved_class then
		class_name = resolved_class
	end

	local rec = {
		name = name,
		party_slot = party_slot,
		class_id = class_id,
		class_name = class_name,
		level_base = safe_number(safe_field(char, "LevelBase", 1), 1),
		level_bonus = safe_number(safe_field(char, "LevelBonus", 0), 0),
		level_effective = safe_number(safe_char_method(char, "GetLevel"),
			safe_number(safe_field(char, "LevelBase", 1), 1) + safe_number(safe_field(char, "LevelBonus", 0), 0)),
		experience = safe_number(safe_field(char, "Exp", safe_field(char, "Experience", 0)), 0),
		skill_points = safe_number(safe_field(char, "SkillPoints", 0), 0),
		hp_current = safe_number(safe_field(char, "HP", safe_field(char, "HitPoints", 0)), 0),
		hp_full = safe_number(safe_char_method(char, "GetFullHP"), 0),
		sp_current = safe_number(safe_field(char, "SP", safe_field(char, "SpellPoints", 0)), 0),
		sp_full = safe_number(safe_char_method(char, "GetFullSP"), 0),
		ac_base = safe_number(safe_char_method(char, "GetBaseArmorClass"), 0),
		ac_bonus_stored = safe_number(safe_field(char, "ArmorClassBonus", 0), 0),
		ac_effective = safe_number(safe_char_method(char, "GetArmorClass"), 0),
		melee_attack = safe_number(safe_char_method(char, "GetMeleeAttack"), 0),
		melee_damage_min = safe_number(safe_char_method(char, "GetMeleeDamageMin"), 0),
		melee_damage_max = safe_number(safe_char_method(char, "GetMeleeDamageMax"), 0),
		melee_damage_range = safe_decode(safe_char_method(char, "GetMeleeDamageRangeText") or ""),
		melee_recovery = safe_number(safe_char_method_1(char, "GetAttackDelay", false), 0),
		ranged_attack = safe_number(safe_char_method(char, "GetRangedAttack"), 0),
		ranged_damage_min = safe_number(safe_char_method(char, "GetRangedDamageMin"), 0),
		ranged_damage_max = safe_number(safe_char_method(char, "GetRangedDamageMax"), 0),
		ranged_damage_range = safe_decode(safe_char_method(char, "GetRangedDamageRangeText") or ""),
		ranged_recovery = safe_number(safe_char_method_1(char, "GetAttackDelay", true), 0),
		stats = {},
		resistances = {},
		items = {},
		skills = {},
	}

	for _, stat in ipairs(utils.get_7stats()) do
		local base = safe_number(safe_field(char, stat .. "Base", 0), 0)
		local bonus = safe_number(safe_field(char, stat .. "Bonus", 0), 0)
		local effective = safe_char_method(char, "Get" .. stat)
		effective = tonumber(effective)
		if effective == nil then
			effective = base + bonus
		end
		rec.stats[stat] = {
			base = base,
			bonus = bonus,
			stored_total = base + bonus,
			effective = effective,
			extra = effective - (base + bonus),
		}
	end

	for _, res in ipairs(utils.get_res()) do
		local base = safe_number(safe_field(char, res .. "ResistanceBase", 0), 0)
		local bonus = safe_number(safe_field(char, res .. "ResistanceBonus", 0), 0)
		local effective = get_effective_resistance(char, res)
		if effective == nil then
			effective = base + bonus
		end
		rec.resistances[res] = {
			base = base,
			bonus = bonus,
			stored_total = base + bonus,
			effective = effective,
			extra = effective - (base + bonus),
		}
	end

	for item_index = 1, char.Items.Count do
		local r = item_record(char, party_slot, item_index)
		if r then
			table.insert(rec.items, r)
		end
	end

	rec.skills = collect_skills(char, party_slot, name)
	return rec
end

local function collect_party()
	local chars = {}
	if not Party or not Party.Players then
		return chars
	end
	for party_index = 0, (Party.Count or 0) - 1 do
		local char = Party.Players[party_index]
		if char then
			table.insert(chars, collect_character_record(char, party_index + 1))
		end
	end
	return chars
end

local function collect_party_record()
	local game_time = safe_number(safe_field(Game, "Time", 0), 0)
	local t = nil
	local ok_time, resolved = pcall(utils.timestamp_to_time, game_time)
	if ok_time then
		t = resolved
	end
	t = t or { years = 0, months = 0, days = 0, hours = 0, minutes = 0, ticks = 0 }

	local day_of_week = ""
	local ok_dow, dow = pcall(utils.date_to_dayofweek, t.days or 1)
	if ok_dow and dow then day_of_week = dow end

	local rep_raw = safe_number(safe_field(Party, "Reputation", 0), 0)
	local rep_display = rep_raw
	local ok_rep, rep = pcall(utils.mm6or78, rep_raw, 0 - rep_raw)
	if ok_rep and rep ~= nil then rep_display = rep end

	local rep_desc = ""
	local ok_desc, desc = pcall(utils.rep_to_desc, rep_display)
	if ok_desc and desc then rep_desc = safe_decode(desc) end

	return {
		game_version = safe_number(safe_field(Game, "Version", 0), 0),
		game_time_raw = game_time,
		year = safe_number(t.years, 0),
		month = safe_number(t.months, 0),
		day = safe_number(t.days, 0),
		hour = safe_number(t.hours, 0),
		minute = safe_number(t.minutes, 0),
		tick = safe_number(t.ticks, 0),
		day_of_week = safe_decode(day_of_week),
		date_text = string.format("%04d-%02d-%02d %02d:%02d",
			safe_number(t.years, 0), safe_number(t.months, 0), safe_number(t.days, 0),
			safe_number(t.hours, 0), safe_number(t.minutes, 0)),
		gold = safe_number(safe_field(Party, "Gold", 0), 0),
		bank_gold = safe_number(safe_field(Party, "BankGold", 0), 0),
		food = safe_number(safe_field(Party, "Food", 0), 0),
		reputation_raw = rep_raw,
		reputation = rep_display,
		reputation_desc = rep_desc,
		party_count = safe_number(safe_field(Party, "Count", 0), 0),
		min_melee_recovery = safe_number(safe_field(Game, "MinMeleeRecoveryTime", 0), 0),
	}
end

local function modifier_text(r)
	local parts = {}
	if r.standard_bonus_id > 0 then
		local s = r.standard_name_add
		if r.standard_bonus_stat ~= "" then
			s = s .. (s ~= "" and " - " or "") .. r.standard_bonus_stat
		end
		if r.standard_strength ~= 0 then
			s = s .. (s ~= "" and " " or "") .. tostring(r.standard_strength)
		end
		if s == "" then
			s = "Standard bonus ID " .. tostring(r.standard_bonus_id) .. " strength " .. tostring(r.standard_strength)
		else
			s = s .. " [ID " .. tostring(r.standard_bonus_id) .. "]"
		end
		table.insert(parts, "Standard: " .. s)
	end
	if r.special_bonus_id > 0 then
		local s = r.special_name_add
		if r.special_bonus_stat ~= "" then
			s = s .. (s ~= "" and " - " or "") .. r.special_bonus_stat
		end
		if s == "" then
			s = "Special bonus ID " .. tostring(r.special_bonus_id)
		else
			s = s .. " [ID " .. tostring(r.special_bonus_id) .. "]"
		end
		table.insert(parts, "Special: " .. s)
	end
	if #parts == 0 then
		return "None"
	end
	return table.concat(parts, "; ")
end

local function write_inventory_text(path, chars, stamp)
	local f, err = io.open(path, "w")
	if not f then
		return nil, err
	end
	f:write("MMCheat Party Inventory Dump\n")
	f:write("Generated: " .. stamp .. "\n")
	f:write("Party members: " .. tostring(#chars) .. "\n\n")
	for _, c in ipairs(chars) do
		f:write("=== " .. c.name .. " (Party slot " .. tostring(c.party_slot) .. ") ===\n")
		for _, eq in ipairs({ true, false }) do
			f:write(eq and "-- EQUIPPED --\n" or "-- INVENTORY --\n")
			for _, r in ipairs(c.items) do
				if r.equipped == eq then
					f:write(string.format("[%d] %s\n", r.item_slot, r.display_name ~= "" and r.display_name or r.base_item))
					if r.display_name ~= r.base_item then
						f:write("    Base item: " .. r.base_item .. "\n")
					end
					if r.material_id ~= 0 then
						f:write("    Material: " .. r.material_type .. " [" .. tostring(r.material_id) .. "]\n")
					end
					if r.intrinsic_notes ~= "" then
						f:write("    Intrinsic notes: " .. clean_cell(r.intrinsic_notes) .. "\n")
					end
					f:write("    Modifiers: " .. modifier_text(r) .. "\n")
					f:write(string.format("    Item ID: %d | Value: %d | Charges: %d/%d | Identified: %s | Broken: %s | Hardened: %s | Stolen: %s\n",
						r.item_id, r.item_value, r.charges, r.max_charges, bool_text(r.identified), bool_text(r.broken),
						bool_text(r.hardened), bool_text(r.stolen)))
				end
			end
		end
		f:write("\n")
	end
	f:close()
	return true
end

local function write_inventory_tsv(path, chars)
	local f, err = io.open(path, "w")
	if not f then
		return nil, err
	end
	local header = {
		"Character", "PartySlot", "ItemSlot", "Equipped", "DisplayName", "CurrentName", "BaseItem", "UnidentifiedName", "ItemID", "Value",
		"MaterialID", "MaterialType", "IntrinsicNotes",
		"StandardBonusID", "StandardNameAdd", "StandardBonusStat", "StandardStrength",
		"SpecialBonusID", "SpecialNameAdd", "SpecialBonusStat",
		"Charges", "MaxCharges", "Identified", "Stolen", "Broken", "Hardened", "Refundable",
		"TemporaryBonus", "Owner"
	}
	f:write(table.concat(header, "\t") .. "\n")
	for _, c in ipairs(chars) do
		for _, r in ipairs(c.items) do
			local row = {
				r.character, r.party_slot, r.item_slot, bool_text(r.equipped), r.display_name, r.current_name,
				r.base_item, r.unidentified_name, r.item_id, r.item_value,
				r.material_id, r.material_type, r.intrinsic_notes,
				r.standard_bonus_id, r.standard_name_add, r.standard_bonus_stat, r.standard_strength,
				r.special_bonus_id, r.special_name_add, r.special_bonus_stat,
				r.charges, r.max_charges, bool_text(r.identified), bool_text(r.stolen), bool_text(r.broken),
				bool_text(r.hardened), bool_text(r.refundable), bool_text(r.temporary_bonus), r.owner
			}
			for i = 1, #row do row[i] = clean_cell(row[i]) end
			f:write(table.concat(row, "\t") .. "\n")
		end
	end
	f:close()
	return true
end

local function write_characters_tsv(path, chars)
	local f, err = io.open(path, "w")
	if not f then return nil, err end

	local header = {
		"Character", "PartySlot", "ClassID", "Class", "LevelBase", "LevelBonus", "LevelEffective", "Experience", "SkillPoints",
		"HPCurrent", "HPFull", "SPCurrent", "SPFull", "ACBase", "ACBonusStored", "ACEffective",
		"MeleeAttack", "MeleeDamageMin", "MeleeDamageMax", "MeleeDamageRange", "MeleeRecovery",
		"RangedAttack", "RangedDamageMin", "RangedDamageMax", "RangedDamageRange", "RangedRecovery"
	}
	for _, stat in ipairs(utils.get_7stats()) do
		table.insert(header, stat .. "Base")
		table.insert(header, stat .. "BonusStored")
		table.insert(header, stat .. "StoredTotal")
		table.insert(header, stat .. "Effective")
		table.insert(header, stat .. "ExternalBonus")
	end
	for _, res in ipairs(utils.get_res()) do
		table.insert(header, res .. "ResistanceBase")
		table.insert(header, res .. "ResistanceBonusStored")
		table.insert(header, res .. "ResistanceStoredTotal")
		table.insert(header, res .. "ResistanceEffective")
		table.insert(header, res .. "ResistanceExternalBonus")
	end
	f:write(table.concat(header, "\t") .. "\n")

	for _, c in ipairs(chars) do
		local row = {
			c.name, c.party_slot, c.class_id, c.class_name, c.level_base, c.level_bonus, c.level_effective, c.experience, c.skill_points,
			c.hp_current, c.hp_full, c.sp_current, c.sp_full, c.ac_base, c.ac_bonus_stored, c.ac_effective,
			c.melee_attack, c.melee_damage_min, c.melee_damage_max, c.melee_damage_range, c.melee_recovery,
			c.ranged_attack, c.ranged_damage_min, c.ranged_damage_max, c.ranged_damage_range, c.ranged_recovery
		}
		for _, stat in ipairs(utils.get_7stats()) do
			local s = c.stats[stat]
			table.insert(row, s.base)
			table.insert(row, s.bonus)
			table.insert(row, s.stored_total)
			table.insert(row, s.effective)
			table.insert(row, s.extra)
		end
		for _, res in ipairs(utils.get_res()) do
			local s = c.resistances[res]
			table.insert(row, s.base)
			table.insert(row, s.bonus)
			table.insert(row, s.stored_total)
			table.insert(row, s.effective)
			table.insert(row, s.extra)
		end
		for i = 1, #row do row[i] = clean_cell(row[i]) end
		f:write(table.concat(row, "\t") .. "\n")
	end
	f:close()
	return true
end

local function write_skills_tsv(path, chars)
	local f, err = io.open(path, "w")
	if not f then return nil, err end
	local header = {
		"Character", "PartySlot", "SkillID", "SkillKey", "SkillName",
		"Rank", "MasteryID", "Mastery", "RawValue",
		"EffectiveRank", "EffectiveMasteryID", "EffectiveMastery", "EffectiveRawValue"
	}
	f:write(table.concat(header, "\t") .. "\n")
	for _, c in ipairs(chars) do
		for _, s in ipairs(c.skills) do
			local row = {
				s.character, s.party_slot, s.skill_id, s.skill_key, s.skill_name,
				s.rank, s.mastery, s.mastery_name, s.raw_value,
				s.effective_rank, s.effective_mastery, s.effective_mastery_name, s.effective_raw_value
			}
			for i = 1, #row do row[i] = clean_cell(row[i]) end
			f:write(table.concat(row, "\t") .. "\n")
		end
	end
	f:close()
	return true
end

local function write_party_tsv(path, party_rec, stamp)
	local f, err = io.open(path, "w")
	if not f then return nil, err end
	local header = {
		"Generated", "GameVersion", "GameTimeRaw", "GameDate", "Year", "Month", "Day", "DayOfWeek", "Hour", "Minute", "Tick",
		"PartyCount", "Gold", "BankGold", "Food", "ReputationRaw", "Reputation", "ReputationDescription", "MinMeleeRecovery"
	}
	local row = {
		stamp, party_rec.game_version, party_rec.game_time_raw, party_rec.date_text,
		party_rec.year, party_rec.month, party_rec.day, party_rec.day_of_week, party_rec.hour, party_rec.minute, party_rec.tick,
		party_rec.party_count, party_rec.gold, party_rec.bank_gold, party_rec.food,
		party_rec.reputation_raw, party_rec.reputation, party_rec.reputation_desc, party_rec.min_melee_recovery
	}
	for i = 1, #row do row[i] = clean_cell(row[i]) end
	f:write(table.concat(header, "\t") .. "\n")
	f:write(table.concat(row, "\t") .. "\n")
	f:close()
	return true
end

local function write_snapshot_text(path, chars, party_rec, stamp)
	local f, err = io.open(path, "w")
	if not f then return nil, err end

	f:write("MMCheat Party Snapshot\n")
	f:write("Generated: " .. stamp .. "\n")
	f:write("Game date: " .. party_rec.date_text)
	if party_rec.day_of_week ~= "" then f:write(" (" .. party_rec.day_of_week .. ")") end
	f:write("\n")
	f:write(string.format("Gold: %d | Bank: %d | Food: %d | Reputation: %d %s | Melee recovery floor: %d\n\n",
		party_rec.gold, party_rec.bank_gold, party_rec.food, party_rec.reputation,
		party_rec.reputation_desc ~= "" and ("(" .. party_rec.reputation_desc .. ")") or "",
		party_rec.min_melee_recovery))

	for _, c in ipairs(chars) do
		f:write(string.format("=== %s | %s | Level %d | XP %d | Skill Points %d ===\n",
			c.name, c.class_name, c.level_effective, c.experience, c.skill_points))
		f:write(string.format("HP %d/%d | SP %d/%d | AC %d\n",
			c.hp_current, c.hp_full, c.sp_current, c.sp_full, c.ac_effective))
		f:write(string.format("Melee: Attack %d | Damage %d-%d%s | Recovery %d\n",
			c.melee_attack, c.melee_damage_min, c.melee_damage_max,
			c.melee_damage_range ~= "" and (" [" .. c.melee_damage_range .. "]") or "", c.melee_recovery))
		f:write("Stats (effective): ")
		local stat_parts = {}
		for _, stat in ipairs(utils.get_7stats()) do
			table.insert(stat_parts, stat .. " " .. tostring(c.stats[stat].effective))
		end
		f:write(table.concat(stat_parts, " | ") .. "\n")
		f:write("Resistances (effective): ")
		local res_parts = {}
		for _, res in ipairs(utils.get_res()) do
			table.insert(res_parts, res .. " " .. tostring(c.resistances[res].effective))
		end
		f:write(table.concat(res_parts, " | ") .. "\n")
		f:write("Skills: ")
		local skill_parts = {}
		for _, s in ipairs(c.skills) do
			local label = s.skill_name .. " " .. tostring(s.rank) .. " " .. s.mastery_name
			if s.effective_rank ~= s.rank or s.effective_mastery ~= s.mastery then
				label = label .. " (effective " .. tostring(s.effective_rank) .. " " .. s.effective_mastery_name .. ")"
			end
			table.insert(skill_parts, label)
		end
		f:write(#skill_parts > 0 and table.concat(skill_parts, "; ") or "None")
		f:write("\n")
		f:write("Equipped: ")
		local equipped_parts = {}
		for _, r in ipairs(c.items) do
			if r.equipped then
				table.insert(equipped_parts, r.display_name ~= "" and r.display_name or r.base_item)
			end
		end
		f:write(#equipped_parts > 0 and table.concat(equipped_parts, "; ") or "None")
		f:write("\n\n")
	end

	f:close()
	return true
end

local function write_or_error(writer, path, ...)
	local ok, err = writer(path, ...)
	if not ok then
		return nil, "Could not write " .. path .. ": " .. tostring(err)
	end
	return true
end

function M.export()
	local chars = collect_party()
	if #chars == 0 then
		return nil, "No active party members were found."
	end
	local party_rec = collect_party_record()

	local stamp_file = os.date("%Y%m%d_%H%M%S")
	local stamp_text = os.date("%Y-%m-%d %H:%M:%S")
	local dir = "Scripts/Modules/MMCheat/"

	local files = {
		inventory_tsv_timestamped = dir .. "MMCheat_inventory_" .. stamp_file .. ".tsv",
		characters_tsv_timestamped = dir .. "MMCheat_characters_" .. stamp_file .. ".tsv",
		skills_tsv_timestamped = dir .. "MMCheat_skills_" .. stamp_file .. ".tsv",
		party_tsv_timestamped = dir .. "MMCheat_party_" .. stamp_file .. ".tsv",
	}

	-- Intentionally write only the four timestamped TSV files.
	-- Collection logic is unchanged from the last confirmed-working snapshot exporter.
	local ok, err
	ok, err = write_or_error(write_inventory_tsv, files.inventory_tsv_timestamped, chars); if not ok then return nil, err end
	ok, err = write_or_error(write_characters_tsv, files.characters_tsv_timestamped, chars); if not ok then return nil, err end
	ok, err = write_or_error(write_skills_tsv, files.skills_tsv_timestamped, chars); if not ok then return nil, err end
	ok, err = write_or_error(write_party_tsv, files.party_tsv_timestamped, party_rec, stamp_text); if not ok then return nil, err end

	files.characters = #chars
	return files
end

return M
