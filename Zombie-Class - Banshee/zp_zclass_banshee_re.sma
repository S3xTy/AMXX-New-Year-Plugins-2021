#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <xs>
#include <reapi>
#include <zombieplague>

/* ~ [ Macroses ] ~ */
#define LOWER_LIMIT_OF_ENTITIES			100

#define PrecacheArray(%0,%1) 			for(new i; i < sizeof %1; i++) engfunc(EngFunc_Precache%0, %1[i])
#define IsEntityUser(%0) 				(%0 && 0 < MaxClients < 33 && is_user_connected(%0))
#define _is_user_zombie(%0) 			zp_get_user_zombie(%0)
#define _is_banshee_zombie_class(%0) 	(zp_get_user_zombie_class(%0) == gl_iZClassID)

#define BIT_ADD(%0,%1)					(%0 |= BIT(%1))
#define BIT_SUB(%0,%1)					(%0 &= ~BIT(%1))
#define BIT_VALID(%0,%1)				bool: ((%0 & BIT(%1)) ? true : false)

/* ~ [ Weapon List ] ~ */
new const WEAPONLIST_PATH[] =			"x_re/zombie_claws";
new const WEAPONLIST_SPRITE[] =			"sprites/x_re/640hud184.spr";

/* ~ [ Zombie Class Settings ] ~ */
new const ZC_CLASS_NAME[] = 			"Banshee";
new const ZC_CLASS_INFO[] = 			"Pulling by Bats";
new const ZC_CLASS_MODEL[] = 			"zc_witch_zombie";
new const ZC_CLASS_CLAW[] = 			"v_knife_witch.mdl";
const ZC_CLASS_HEALTH = 				1400;
const ZC_CLASS_SPEED = 					260;
const Float: ZC_CLASS_GRAVITY = 		0.873;
const Float: ZC_CLASS_KNOCK = 			1.3;
const Float: ZC_CLASS_BATS_WAIT = 		15.0;

/* ~ [ Entity: Bats ] ~ */
new const ENTITY_BATS_CLASSNAME[] = 	"ent_banshee_bats_x";
new const ENTITY_BATS_MODEL[] = 		"models/x_re/bat_witch.mdl";
new const ENTITY_BATS_SPRITE[] =		"sprites/x_re/ef_bat.spr";
new const ENTITY_BATS_SOUNDS[][] =
{
	"x_re/witch_zombie/zombi_banshee_laugh.wav",
	"x_re/witch_zombie/zombi_banshee_pulling_fail.wav",
	"x_re/witch_zombie/zombi_banshee_pulling_fire.wav",
};
const Float: ENTITY_BATS_SPEED =		600.0;
const Float: ENTITY_BATS_CATCH_SPEED =	200.0;
const Float: ENTITY_BATS_LIFETIME =		3.0;

/* ~ [ Params ] ~ */
new gl_iZClassID;
new gl_iMaxEntities;
new gl_iszModelIndex_Effect;
new gl_bitPlayerCathced, gl_bitPlayerSkillActive;
new Float: gl_flAbilityWait[MAX_PLAYERS + 1];

enum {
	eWitchSound_Laugh = 0,
	eWitchSound_Fail,
	eWitchSound_Fire,
};

/* ~ [ AMX Mod X ] ~ */
public plugin_init()
{
	register_plugin("[RE:ZCore] ZClass: Banshee", "1.0", "xUnicorn");

	/* -> ReAPI -> */
	RegisterHookChain(RG_CSGameRules_RestartRound, "CGame_RestartRound_Post", true);

	/* -> HamSandwich -> */
	RegisterHam(Ham_Item_Deploy, "weapon_knife", "CKnife_Deploy_Post", true);
	RegisterHam(Ham_Item_PostFrame, "weapon_knife", "CKnife_PostFrame_Pre", false);

	/* -> Client Commands -> */
	register_clcmd("drop", "Command_HookDrop");
	register_clcmd(WEAPONLIST_PATH, "Command_HookWeapon");

	/* -> Other -> */
	gl_iMaxEntities = global_get(glb_maxEntities);
}

public plugin_precache()
{
	/* -> Precache Model -> */
	engfunc(EngFunc_PrecacheModel, ENTITY_BATS_MODEL);

	/* -> Precache Sound -> */
	PrecacheArray(Sound, ENTITY_BATS_SOUNDS);

	/* -> Precache Generic -> */
	engfunc(EngFunc_PrecacheGeneric, fmt("sprites/%s.txt", WEAPONLIST_PATH));
	engfunc(EngFunc_PrecacheGeneric, WEAPONLIST_SPRITE);

	/* -> Model Index -> */
	gl_iszModelIndex_Effect = engfunc(EngFunc_PrecacheModel, ENTITY_BATS_SPRITE);

	/* -> Register Zombie Class -> */
	gl_iZClassID = zp_register_zombie_class(ZC_CLASS_NAME, ZC_CLASS_INFO, ZC_CLASS_MODEL, ZC_CLASS_CLAW, ZC_CLASS_HEALTH, ZC_CLASS_SPEED, ZC_CLASS_GRAVITY, ZC_CLASS_KNOCK);
}

public client_putinserver(pPlayer)
{
	gl_bitPlayerCathced = 0;
	gl_bitPlayerSkillActive = 0;
}

public Command_HookWeapon(const pPlayer)
{
	engclient_cmd(pPlayer, "weapon_knife");
	return PLUGIN_HANDLED;
}

public Command_HookDrop(const pPlayer)
{
	if(!is_user_alive(pPlayer) || !_is_user_zombie(pPlayer) || !_is_banshee_zombie_class(pPlayer) || zp_get_user_nemesis(pPlayer)) return PLUGIN_CONTINUE;

	new pActiveItem = get_member(pPlayer, m_pActiveItem);
	if(!is_nullent(pActiveItem) && get_member(pActiveItem, m_iId) != WEAPON_KNIFE) return PLUGIN_CONTINUE;

	if(!BIT_VALID(gl_bitPlayerSkillActive, pPlayer) && gl_flAbilityWait[pPlayer] < get_gametime())
	{
		if(CPlayer_Create_Bats(pPlayer))
		{
			UTIL_SendWeaponAnim(pPlayer, 2);
			UTIL_PlayerAnimation(pPlayer, "skill1");

			set_member(pPlayer, m_flNextAttack, ENTITY_BATS_LIFETIME);
			set_member(pActiveItem, m_Weapon_flTimeWeaponIdle, 221/30.0);

			BIT_ADD(gl_bitPlayerSkillActive, pPlayer);
		}

		return PLUGIN_HANDLED;
	}

	return PLUGIN_CONTINUE;
}

/* -> [ Zombie Plague ] -> */
public zp_user_infected_post(pPlayer)
{
	new pKnife = rg_find_weapon_bpack_by_name(pPlayer, "weapon_knife");
	if(!is_nullent(pKnife))
	{
		gl_flAbilityWait[pPlayer] = get_gametime();

		if(_is_banshee_zombie_class(pPlayer))
			rg_set_iteminfo(pKnife, ItemInfo_pszName, WEAPONLIST_PATH);
		else rg_set_iteminfo(pKnife, ItemInfo_pszName, "weapon_knife");

		UTIL_WeaponList(pPlayer, pKnife);
	}
}

public zp_user_humanized_post(pPlayer) CPlayer_Reset_KnifeValues(pPlayer);

/* ~ [ ReAPI ] ~ */
public CGame_RestartRound_Post()
{
	gl_bitPlayerCathced = 0;
	gl_bitPlayerSkillActive = 0;

	for(new pPlayer = 1; pPlayer <= MaxClients; pPlayer++)
	{
		if(!is_user_connected(pPlayer)) continue;

		CPlayer_Reset_KnifeValues(pPlayer);
		gl_flAbilityWait[pPlayer] = get_gametime();
	}

	new pEntity = NULLENT;
	while((pEntity = rg_find_ent_by_class(pEntity, ENTITY_BATS_CLASSNAME)))
		if(!is_nullent(pEntity)) UTIL_KillEntity(pEntity);
}

/* ~ [ HamSandwich ] ~ */
public CKnife_Deploy_Post(const pItem)
{
	if(is_nullent(pItem)) return;

	new pPlayer = get_member(pPlayer, m_pPlayer);
	if(!_is_user_zombie(pPlayer) || !_is_banshee_zombie_class(pPlayer)) return;

	if(gl_flAbilityWait[pPlayer] > get_gametime())
	{
		UTIL_AmmoX(
			pPlayer,
			get_member(pItem, m_Weapon_iPrimaryAmmoType),
			floatround(gl_flAbilityWait[pPlayer] - get_gametime())
		);
	}
	else
	{
		set_member(pItem, m_Weapon_iPrimaryAmmoType, -1);
		rg_set_iteminfo(pItem, ItemInfo_iMaxAmmo1, -1);
		UTIL_WeaponList(pPlayer, pItem);
	}
}

public CKnife_PostFrame_Pre(const pItem)
{
	if(is_nullent(pItem)) return HAM_IGNORED;

	new pPlayer = get_member(pPlayer, m_pPlayer);
	if(!_is_user_zombie(pPlayer) || !_is_banshee_zombie_class(pPlayer)) return HAM_IGNORED;

	if(gl_flAbilityWait[pPlayer] > get_gametime())
	{
		UTIL_AmmoX(
			pPlayer,
			get_member(pItem, m_Weapon_iPrimaryAmmoType),
			floatround(gl_flAbilityWait[pPlayer] - get_gametime())
		);
	}
	else if((gl_flAbilityWait[pPlayer] - get_gametime()) < 1.0 && get_member(pItem, m_Weapon_iPrimaryAmmoType))
	{
		set_member(pItem, m_Weapon_iPrimaryAmmoType, -1);
		rg_set_iteminfo(pItem, ItemInfo_iMaxAmmo1, -1);
		UTIL_WeaponList(pPlayer, pItem);
	}

	return HAM_IGNORED;
}

/* ~ [ Other ] ~ */
public CPlayer_Reset_KnifeValues(const pPlayer)
{
	new pKnife = rg_find_weapon_bpack_by_name(pPlayer, "weapon_knife");
	if(!is_nullent(pKnife))
	{
		rg_set_iteminfo(pKnife, ItemInfo_pszName, "weapon_knife");
		set_member(pKnife, m_Weapon_iPrimaryAmmoType, -1);
		rg_set_iteminfo(pKnife, ItemInfo_iMaxAmmo1, -1);

		UTIL_WeaponList(pPlayer, pKnife);
	}
}

public CPlayer_Set_SkillWait(const pPlayer, const Float: flWaitTime)
{
	new pKnife = rg_find_weapon_bpack_by_name(pPlayer, "weapon_knife");
	if(!is_nullent(pKnife))
	{
		set_member(pKnife, m_Weapon_iPrimaryAmmoType, 15);
		rg_set_iteminfo(pKnife, ItemInfo_iMaxAmmo1, floatround(flWaitTime));

		UTIL_WeaponList(pPlayer, pKnife);
		UTIL_CurWeapon(pPlayer, true, get_member(pKnife, m_iId), -1);
	}

	gl_flAbilityWait[pPlayer] = get_gametime() + flWaitTime;
	BIT_SUB(gl_bitPlayerSkillActive, pPlayer);
}

public CPlayer_Create_Bats(const pPlayer)
{
	if(gl_iMaxEntities - engfunc(EngFunc_NumberOfEntities) <= LOWER_LIMIT_OF_ENTITIES) return NULLENT;

	new pEntity = rg_create_entity("info_target");
	if(is_nullent(pEntity)) return NULLENT;

	new Float: vecOrigin[3]; get_entvar(pPlayer, var_origin, vecOrigin);
	new Float: vecViewOfs[3]; get_entvar(pPlayer, var_view_ofs, vecViewOfs);
	new Float: vecViewAngle[3]; get_entvar(pPlayer, var_v_angle, vecViewAngle);
	new Float: vecForward[3]; angle_vector(vecViewAngle, ANGLEVECTOR_FORWARD, vecForward);
	new Float: vecVelocity[3]; xs_vec_copy(vecForward, vecVelocity);
	new Float: vecAngles[3];

	// Start Origin
	xs_vec_mul_scalar(vecForward, 10.0, vecForward);
	xs_vec_add(vecViewOfs, vecForward, vecViewOfs);
	xs_vec_add(vecOrigin, vecViewOfs, vecOrigin);

	// Speed for missile
	xs_vec_mul_scalar(vecVelocity, ENTITY_BATS_SPEED, vecVelocity);

	set_entvar(pEntity, var_classname, ENTITY_BATS_CLASSNAME);
	set_entvar(pEntity, var_solid, SOLID_TRIGGER);
	set_entvar(pEntity, var_movetype, MOVETYPE_FLY);
	set_entvar(pEntity, var_owner, pPlayer);
	set_entvar(pEntity, var_velocity, vecVelocity);
	set_entvar(pEntity, var_origin, vecOrigin);
	set_entvar(pEntity, var_ltime, get_gametime() + ENTITY_BATS_LIFETIME);
	set_entvar(pEntity, var_nextthink, get_gametime());

	engfunc(EngFunc_VecToAngles, vecVelocity, vecAngles);
	set_entvar(pEntity, var_angles, vecAngles);

	UTIL_SetEntityAnim(pEntity);

	engfunc(EngFunc_SetModel, pEntity, ENTITY_BATS_MODEL);
	engfunc(EngFunc_SetSize, pEntity, Float: {-10.0, -10.0, -8.0}, Float: {10.0, 10.0, 8.0});
	rh_emit_sound2(pEntity, 0, CHAN_WEAPON, ENTITY_BATS_SOUNDS[eWitchSound_Fire]);

	SetTouch(pEntity, "CBats_Touch");
	SetThink(pEntity, "CBats_Think");

	return true;
}

public CBats_Touch(const pEntity, const pTouch)
{
	if(is_nullent(pEntity)) return;

	new pOwner = get_entvar(pEntity, var_owner);
	if(pTouch == pOwner) return;

	new Float: vecOrigin[3]; get_entvar(pEntity, var_origin, vecOrigin);
	if(!IsEntityUser(pTouch) || engfunc(EngFunc_PointContents, vecOrigin) == CONTENTS_SKY)
	{
		CBats_Destroy(pEntity, pOwner);
		return;
	}

	if(!_is_user_zombie(pTouch) && !BIT_VALID(gl_bitPlayerCathced, pTouch))
	{
		BIT_ADD(gl_bitPlayerCathced, pTouch);

		rh_emit_sound2(pOwner, 0, CHAN_VOICE, ENTITY_BATS_SOUNDS[eWitchSound_Laugh]);

		set_entvar(pEntity, var_movetype, MOVETYPE_FOLLOW);
		set_entvar(pEntity, var_aiment, pTouch);
		set_entvar(pEntity, var_ltime, get_gametime() + ENTITY_BATS_LIFETIME);
		set_entvar(pEntity, var_nextthink, get_gametime());

		UTIL_SetEntityAnim(pEntity, 1);
		UTIL_PlayerAnimation(pOwner, "skill1_loop");

		set_member(pOwner, m_flNextAttack, ENTITY_BATS_LIFETIME);
	}
}

public CBats_Think(const pEntity)
{
	if(is_nullent(pEntity)) return;

	new pOwner = get_entvar(pEntity, var_owner);
	if(get_entvar(pEntity, var_ltime) < get_gametime())
	{
		CBats_Destroy(pEntity, pOwner);
		return;
	}

	new Float: vecVelocity[3];
	new pVictim = get_entvar(pEntity, var_aiment);
	if(!is_nullent(pVictim) && IsEntityUser(pVictim))
	{
		new Float: vecOrigin[3]; get_entvar(pOwner, var_origin, vecOrigin);
		new Float: vecVictimOrigin[3]; get_entvar(pVictim, var_origin, vecVictimOrigin);

		if(xs_vec_distance(vecOrigin, vecVictimOrigin) <= 64.0 || !is_user_alive(pVictim) || _is_user_zombie(pVictim))
		{
			CBats_Destroy(pEntity, pOwner);
			BIT_SUB(gl_bitPlayerCathced, pVictim);

			return;
		}
		else
		{
			UTIL_GetSpeedVector(vecVictimOrigin, vecOrigin, ENTITY_BATS_CATCH_SPEED, vecVelocity);
			set_entvar(pVictim, var_velocity, vecVelocity);
		}
	}

	get_entvar(pOwner, var_velocity, vecVelocity);
	vecVelocity[0] *= 0.0; vecVelocity[1] *= 0.0;
	set_entvar(pOwner, var_velocity, vecVelocity);

	set_entvar(pEntity, var_nextthink, get_gametime());
}

public CBats_Destroy(const pEntity, const pOwner)
{
	if(is_nullent(pEntity)) return;

	new Float: vecOrigin[3]; get_entvar(pEntity, var_origin, vecOrigin);

	CPlayer_Set_SkillWait(pOwner, ZC_CLASS_BATS_WAIT);
	UTIL_SendWeaponAnim(pOwner, 6);
	UTIL_PlayerAnimation(pOwner, "idle1");

	set_member(pOwner, m_flNextAttack, 0.0);

	UTIL_CreateExplosion(gl_iszModelIndex_Effect, vecOrigin, 0.0, 16, 32, 2|4|8);
	rh_emit_sound2(pEntity, 0, CHAN_WEAPON, ENTITY_BATS_SOUNDS[eWitchSound_Fail]);

	UTIL_KillEntity(pEntity);
}

/* ~ [ Stocks ] ~ */
stock UTIL_KillEntity(const pEntity)
{
	// https://github.com/baso88/SC_AngelScript/wiki/TE_KILLBEAM
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
	write_byte(TE_KILLBEAM);
	write_short(pEntity);
	message_end();

	set_entvar(pEntity, var_flags, FL_KILLME);
	set_entvar(pEntity, var_nextthink, get_gametime());
}

stock UTIL_SendWeaponAnim(const pPlayer, const iAnim)
{
	set_entvar(pPlayer, var_weaponanim, iAnim);

	message_begin(MSG_ONE, SVC_WEAPONANIM, .player = pPlayer);
	write_byte(iAnim);
	write_byte(0);
	message_end();
}

stock UTIL_SetEntityAnim(const pEntity, const iSequence = 0)
{
	set_entvar(pEntity, var_frame, 1.0);
	set_entvar(pEntity, var_framerate, 1.0);
	set_entvar(pEntity, var_animtime, get_gametime());
	set_entvar(pEntity, var_sequence, iSequence);
}

stock UTIL_PlayerAnimation(const pPlayer, const szAnim[])
{
	new iAnimDesired, Float: flFrameRate, Float: flGroundSpeed, bool: bLoops;
	if((iAnimDesired = lookup_sequence(pPlayer, szAnim, flFrameRate, bLoops, flGroundSpeed)) == -1)
		iAnimDesired = 0;

	UTIL_SetEntityAnim(pPlayer, iAnimDesired);
	
	set_member(pPlayer, m_fSequenceLoops, bLoops);
	set_member(pPlayer, m_fSequenceFinished, 0);
	set_member(pPlayer, m_flFrameRate, flFrameRate);
	set_member(pPlayer, m_flGroundSpeed, flGroundSpeed);
	set_member(pPlayer, m_flLastEventCheck, get_gametime());
	set_member(pPlayer, m_Activity, ACT_RANGE_ATTACK1);
	set_member(pPlayer, m_IdealActivity, ACT_RANGE_ATTACK1);
	set_member(pPlayer, m_flLastFired, get_gametime());
}

stock UTIL_GetSpeedVector(const Float: vecOrigin1[3], const Float: vecOrigin2[3], const Float: flSpeed, Float: vecVelocity[3]) 
{
	xs_vec_sub(vecOrigin2, vecOrigin1, vecVelocity);
	new Float: flLen = xs_vec_len(vecVelocity);
	xs_vec_mul_scalar(vecVelocity, flSpeed / flLen, vecVelocity);

	return true;
}

stock UTIL_AmmoX(const pPlayer, const iAmmoType, const iValue)
{
	static iMsgId_AmmoX;
	if(iMsgId_AmmoX || (iMsgId_AmmoX = get_user_msgid("AmmoX")))
	{
		message_begin(MSG_ONE, iMsgId_AmmoX, .player = pPlayer);
		write_byte(iAmmoType);
		write_byte(iValue);
		message_end();
	}
}

stock UTIL_CurWeapon(const pPlayer, const bool: bIsActive, const iWeaponId, const iClipAmmo)
{
	static iMsgId_CurWeapon;
	if(iMsgId_CurWeapon || (iMsgId_CurWeapon = get_user_msgid("CurWeapon")))
	{
		message_begin_f(MSG_ONE, iMsgId_CurWeapon, .player = pPlayer);
		write_byte(bIsActive);
		write_byte(iWeaponId);
		write_byte(iClipAmmo);
		message_end();
	}
}

stock UTIL_WeaponList(const pPlayer, const pItem)
{
	static iMsgId_Weaponlist, szWeaponName[32];
	if(iMsgId_Weaponlist || (iMsgId_Weaponlist = get_user_msgid("WeaponList")))
	{
		rg_get_iteminfo(pItem, ItemInfo_pszName, szWeaponName, charsmax(szWeaponName));

		message_begin(MSG_ONE, iMsgId_Weaponlist, .player = pPlayer);
		write_string(szWeaponName);
		write_byte(get_member(pItem, m_Weapon_iPrimaryAmmoType));
		write_byte(rg_get_iteminfo(pItem, ItemInfo_iMaxAmmo1));
		write_byte(get_member(pItem, m_Weapon_iSecondaryAmmoType));
		write_byte(rg_get_iteminfo(pItem, ItemInfo_iMaxAmmo2));
		write_byte(rg_get_iteminfo(pItem, ItemInfo_iSlot));
		write_byte(rg_get_iteminfo(pItem, ItemInfo_iPosition));
		write_byte(rg_get_iteminfo(pItem, ItemInfo_iId));
		write_byte(rg_get_iteminfo(pItem, ItemInfo_iFlags));
		message_end();
	}
}

stock UTIL_CreateExplosion(const iszModelIndex, const Float: vecOrigin[3], const Float: flUp, const iScale, const iFramerate, const iFlags)
{
	message_begin_f(MSG_PAS, SVC_TEMPENTITY, vecOrigin);
	write_byte(TE_EXPLOSION);
	write_coord_f(vecOrigin[0]);
	write_coord_f(vecOrigin[1]);
	write_coord_f(vecOrigin[2] + flUp);
	write_short(iszModelIndex);
	write_byte(iScale); // Scale
	write_byte(iFramerate); // Framerate
	write_byte(iFlags); // Flags
	message_end();
}
