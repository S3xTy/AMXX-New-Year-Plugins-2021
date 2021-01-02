/*
 * Weapon by xUnicorn (t3rkecorejz)
 *
 * Thanks a lot:
 *
 * Chrescoe1 & batcoh (Phenix) — First base code
 * KORD_12.7 & 406 (Nightfury) — I'm taken some functions from this authors
 * D34, 404 & fl0wer — Some help
 */

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <xs>
#include <reapi>
#include <zombieplague>

/* ~ [ Macroses ] ~ */
#define CUSTOM_WEAPONLIST 				// Comment this line if u dont need weapon list

#if defined CUSTOM_WEAPONLIST
	#define DEFAULT_FOV						89
#else
	#define DEFAULT_FOV						90
#endif

#define var_max_frame 					var_yaw_speed // pEntity
#define var_first_sprite				var_iuser1 // pEntity

#define _is_user_zombie					zp_get_user_zombie
#define IsCustomWeapon(%0) 				(get_entvar(%0, var_impulse) == WEAPON_SPECIAL_CODE)
#define GetItemClip(%0) 				get_member(%0, m_Weapon_iClip)
#define IsDefaultFOV(%0)				(get_member(%0, m_iFOV) == DEFAULT_FOV)
#define PrecacheArray(%0,%1)			for(new i; i < sizeof %1; i++) engfunc(EngFunc_Precache%0, %1[i])

/* ~ [ Extra Item ] ~ */
new const EXTRA_ITEM_NAME[] = 			"\y[Special] \wFG-Launcher";
const EXTRA_ITEM_COST = 				0;

/* ~ [ Weapon Settings ] ~ */
new const WEAPON_REFERENCE[] = 			"weapon_ump45";
new const WEAPON_ANIMATION[] = 			"rifle";
new const WEAPON_NATIVE[] = 			"zp_give_user_fglauncher";
new const WEAPON_MODEL_VIEW[] = 		"models/x_re/v_fglauncher.mdl";
new const WEAPON_MODEL_PLAYER[] = 		"models/x_re/p_fglauncher.mdl";
new const WEAPON_MODEL_WORLD[] = 		"models/x_re/w_fglauncher.mdl";
new const WEAPON_SOUNDS[][] =
{
	"weapons/fglauncher-1.wav", // 0
	"weapons/firecracker_explode.wav", // 1
	"weapons/firecracker-wick.wav", // 2
	"weapons/fglauncher_clipin1.wav", // 3
	"weapons/fglauncher_clipin2.wav", // 4
	"weapons/fglauncher_clipin3.wav", // 5
	"weapons/fglauncher_clipout1.wav", // 6
	"weapons/fglauncher_clipout2.wav", // 7
	"weapons/fglauncher_clipout2.wav", // 8
	"weapons/fglauncher_draw.wav" // 9
};
#if defined CUSTOM_WEAPONLIST
	new const WEAPON_WEAPONLIST[] = 	"x_re/weapon_fglauncher";
	new const WEAPON_RESOURCES[][] =
	{
		// Custom resources precache, sprites for example
		"sprites/x_re/640hud7.spr",
		"sprites/x_re/640hud86.spr",
		"sprites/x_re/scope_vip_grenade.spr"
	};
#endif

const WEAPON_MODEL_WORLD_BODY = 		0;
const WEAPON_SPECIAL_CODE = 			29122020;

const WEAPON_MAX_CLIP = 				10;
const WEAPON_DEFAULT_AMMO = 			40;
const Float: WEAPON_RATE = 				0.75;

/* ~ [ Entity: Missile ] ~ */
new const ENTITY_MISSILE_REFERENCE[] =	"info_target";
new const ENTITY_MISSILE_CLASSNAME[] =	"ent_missile_fglauncher";
new const ENTITY_MISSILE_MODEL[] =		"models/x_re/s_oicw.mdl"
new const ENTITY_MISSILE_SPRITES[][] =
{
	"sprites/x_re/fg_spark1.spr", // 0
	"sprites/x_re/fg_spark2.spr", // 1
	"sprites/x_re/fg_spark3.spr", // 2
	"sprites/laserbeam.spr" // 4
};
const Float: ENTITY_MISSILE_SPEED =		350.0;
const Float: ENTITY_MISSILE_LIFETIME =	1.5;
const Float: ENTITY_MISSILE_NEXTTHINK =	0.1;
const Float: ENTITY_MISSILE_RADIUS = 	200.0;
const Float: ENTITY_MISSILE_DAMAGE =	350.0;
const ENTITY_MISSILE_DMGTYPE =			DMG_BULLET|DMG_GRENADE;

/* ~ [ Weapon Animations ] ~ */
enum _: eAnimList
{
	WEAPON_ANIM_IDLE = 0,
	WEAPON_ANIM_SHOOT,
	WEAPON_ANIM_RELOAD,
	WEAPON_ANIM_DRAW
};

enum _: eSprites
{
	eSprite_Spark1 = 0,
	eSprite_Spark2,
	eSprite_Spark3,
	eSprite_Trail
};

#define WEAPON_ANIM_IDLE_TIME 			51/30.0
#define WEAPON_ANIM_SHOOT_TIME 			39/30.0
#define WEAPON_ANIM_RELOAD_TIME 		151/30.0
#define WEAPON_ANIM_DRAW_TIME 			31/30.0

/* ~ [ Params ] ~ */
new gl_iItemID;
new gl_iszModelIndex_Sprites[sizeof ENTITY_MISSILE_SPRITES];
#if defined CUSTOM_WEAPONLIST
	new gl_iMsgID_Weaponlist;
#endif

/* ~ [ AMX Mod X ] ~ */
public plugin_init()
{
	register_plugin("[ZP] Weapon: FG-Launcher", "2.0", "xUnicorn (t3rkecorejz)");

	/* -> Register on Extra-Items -> */
	gl_iItemID = zp_register_extra_item(EXTRA_ITEM_NAME, EXTRA_ITEM_COST, ZP_TEAM_HUMAN);

	/* -> Fakemeta -> */
	register_forward(FM_UpdateClientData, "FM_Hook_UpdateClientData_Post", true);

	/* -> ReAPI -> */
	RegisterHookChain(RG_CWeaponBox_SetModel, "CWeaponBox_SetModel_Pre", false);

	/* -> HamSandwich -> */
	RegisterHam(Ham_Spawn, WEAPON_REFERENCE, "CWeapon_Spawn_Post", true);

	#if defined CUSTOM_WEAPONLIST
		RegisterHam(Ham_CS_Item_GetMaxSpeed, WEAPON_REFERENCE, "CWeapon_GetMaxSpeed_Pre", false);
	#endif
	RegisterHam(Ham_Item_Deploy, WEAPON_REFERENCE, "CWeapon_Deploy_Post", true);
	RegisterHam(Ham_Item_Holster, WEAPON_REFERENCE, "CWeapon_Holster_Post", true);

	#if defined CUSTOM_WEAPONLIST
		RegisterHam(Ham_Item_AddToPlayer, WEAPON_REFERENCE, "CWeapon_AddToPlayer_Post", true);
	#endif

	RegisterHam(Ham_Weapon_Reload, WEAPON_REFERENCE, "CWeapon_Reload_Post", true);
	RegisterHam(Ham_Weapon_WeaponIdle, WEAPON_REFERENCE, "CWeapon_WeaponIdle_Pre", false);
	RegisterHam(Ham_Weapon_PrimaryAttack, WEAPON_REFERENCE, "CWeapon_PrimaryAttack_Pre", false);
	RegisterHam(Ham_Weapon_SecondaryAttack, WEAPON_REFERENCE, "CWeapon_SecondaryAttack_Pre", false);

	RegisterHam(Ham_Think, "env_sprite", "CSprite_Think_Post", true);

	/* -> Messages -> */
	#if defined CUSTOM_WEAPONLIST
		gl_iMsgID_Weaponlist = get_user_msgid("WeaponList");
	#endif
}

public plugin_precache()
{
	#if defined CUSTOM_WEAPONLIST
		/* -> Hook Weapon -> */
		register_clcmd(WEAPON_WEAPONLIST, "Command_HookWeapon");

		/* -> Precache Generic -> */
		engfunc(EngFunc_PrecacheGeneric, fmt("sprites/%s.txt", WEAPON_WEAPONLIST));

		PrecacheArray(Generic, WEAPON_RESOURCES);
	#endif

	/* -> Precache Models -> */
	engfunc(EngFunc_PrecacheModel, WEAPON_MODEL_VIEW);
	engfunc(EngFunc_PrecacheModel, WEAPON_MODEL_PLAYER);
	engfunc(EngFunc_PrecacheModel, WEAPON_MODEL_WORLD);
	engfunc(EngFunc_PrecacheModel, ENTITY_MISSILE_MODEL);
	
	/* -> Precache Sounds -> */
	PrecacheArray(Sound, WEAPON_SOUNDS);

	/* -> Model Index -> */
	for(new i; i < sizeof ENTITY_MISSILE_SPRITES; i++)
		gl_iszModelIndex_Sprites[i] = engfunc(EngFunc_PrecacheModel, ENTITY_MISSILE_SPRITES[i]);
}

public plugin_natives() register_native(WEAPON_NATIVE, "Command_GiveWeapon", 1);

#if defined CUSTOM_WEAPONLIST
	public Command_HookWeapon(const pPlayer)
	{
		engclient_cmd(pPlayer, WEAPON_REFERENCE);
		return PLUGIN_HANDLED;
	}
#endif

public Command_GiveWeapon(const pPlayer)
{
	new pItem = rg_give_custom_item(pPlayer, WEAPON_REFERENCE, GT_DROP_AND_REPLACE, WEAPON_SPECIAL_CODE);
	if(is_nullent(pItem)) return NULLENT;

	return pItem;
}

/* ~ [ Zombie Plague ] ~ */
public zp_extra_item_selected(pPlayer, iItemID)
{
	if(iItemID == gl_iItemID)
		Command_GiveWeapon(pPlayer);
}

/* ~ [ Fakemeta ] ~ */
public FM_Hook_UpdateClientData_Post(const pPlayer, const iSendWeapons, const CD_Handle)
{
	if(!is_user_alive(pPlayer)) return;

	static pActiveItem; pActiveItem = get_member(pPlayer, m_pActiveItem);
	if(is_nullent(pActiveItem) || !IsCustomWeapon(pActiveItem)) return;

	set_cd(CD_Handle, CD_flNextAttack, get_gametime() + 0.001);
}

/* ~ [ ReAPI ] ~ */
public CWeaponBox_SetModel_Pre(const pWeaponBox)
{
	if(is_nullent(pWeaponBox)) return HC_CONTINUE;

	new pItem = UTIL_GetWeaponBoxItem(pWeaponBox);
	if(is_nullent(pItem) || !IsCustomWeapon(pItem)) return HC_CONTINUE;

	SetHookChainArg(2, ATYPE_STRING, WEAPON_MODEL_WORLD);
	set_entvar(pWeaponBox, var_body, WEAPON_MODEL_WORLD_BODY);

	return HC_CONTINUE;
}

/* ~ [ HamSandwich ] ~ */
public CWeapon_Spawn_Post(const pItem)
{
	if(is_nullent(pItem) || !IsCustomWeapon(pItem)) return;

	set_member(pItem, m_Weapon_iClip, WEAPON_MAX_CLIP);
	set_member(pItem, m_Weapon_iDefaultAmmo, WEAPON_DEFAULT_AMMO);
	set_member(pItem, m_Weapon_bHasSecondaryAttack, true);
	rg_set_iteminfo(pItem, ItemInfo_iMaxClip, WEAPON_MAX_CLIP);
	rg_set_iteminfo(pItem, ItemInfo_iMaxAmmo1, WEAPON_DEFAULT_AMMO);

	#if defined CUSTOM_WEAPONLIST
		rg_set_iteminfo(pItem, ItemInfo_pszName, WEAPON_WEAPONLIST);
	#endif
}

#if defined CUSTOM_WEAPONLIST
	public CWeapon_GetMaxSpeed_Pre(const pItem)
	{
		static pPlayer;
		if(!CheckItem(pItem, pPlayer)) return HAM_IGNORED;

		UTIL_UpdateHideWeapon(pPlayer, get_member(pPlayer, m_iHideHUD) | HIDEHUD_CROSSHAIR);
		UTIL_SetUserFOV(pPlayer, DEFAULT_FOV);

		return HAM_IGNORED;
	}
#endif

public CWeapon_Deploy_Post(const pItem)
{
	static pPlayer;
	if(!CheckItem(pItem, pPlayer)) return;

	set_entvar(pPlayer, var_viewmodel, WEAPON_MODEL_VIEW);
	set_entvar(pPlayer, var_weaponmodel, WEAPON_MODEL_PLAYER);

	UTIL_SendWeaponAnim(pPlayer, WEAPON_ANIM_DRAW);

	set_member(pItem, m_Weapon_flTimeWeaponIdle, WEAPON_ANIM_DRAW_TIME);
	set_member(pPlayer, m_flNextAttack, WEAPON_ANIM_DRAW_TIME);
	set_member(pPlayer, m_szAnimExtention, WEAPON_ANIMATION);
}

public CWeapon_Holster_Post(const pItem)
{
	static pPlayer;
	if(!CheckItem(pItem, pPlayer)) return;

	#if defined CUSTOM_WEAPONLIST
		UTIL_UpdateHideWeapon(pPlayer, get_member(pPlayer, m_iHideHUD) & ~HIDEHUD_CROSSHAIR);
	#endif
	UTIL_SetUserFOV(pPlayer, 90);

	set_member(pItem, m_Weapon_flTimeWeaponIdle, 1.0);
	set_member(pPlayer, m_flNextAttack, 1.0);
}

#if defined CUSTOM_WEAPONLIST
	public CWeapon_AddToPlayer_Post(const pItem, const pPlayer)
	{
		new iWeaponKey = get_entvar(pItem, var_impulse);
		if(iWeaponKey != 0 && iWeaponKey != WEAPON_SPECIAL_CODE) return;

		UTIL_WeaponList(pPlayer, pItem);
	}
#endif

public CWeapon_Reload_Post(const pItem)
{
	static pPlayer;
	if(!CheckItem(pItem, pPlayer)) return;

	if(!get_member(pPlayer, m_rgAmmo, get_member(pItem, m_Weapon_iPrimaryAmmoType))) return;
	if(GetItemClip(pItem) >= rg_get_iteminfo(pItem, ItemInfo_iMaxClip)) return;

	UTIL_SetUserFOV(pPlayer);
	UTIL_SendWeaponAnim(pPlayer, WEAPON_ANIM_RELOAD);

	set_member(pPlayer, m_flNextAttack, WEAPON_ANIM_RELOAD_TIME);
	set_member(pItem, m_Weapon_flTimeWeaponIdle, WEAPON_ANIM_RELOAD_TIME);
}

public CWeapon_WeaponIdle_Pre(const pItem)
{
	static pPlayer;
	if(!CheckItem(pItem, pPlayer)) return HAM_IGNORED;
	if(get_member(pItem, m_Weapon_flTimeWeaponIdle) > 0.0) return HAM_IGNORED;

	UTIL_SendWeaponAnim(pPlayer, WEAPON_ANIM_IDLE);
	set_member(pItem, m_Weapon_flTimeWeaponIdle, WEAPON_ANIM_IDLE_TIME);

	return HAM_SUPERCEDE;
}

public CWeapon_PrimaryAttack_Pre(const pItem)
{
	static pPlayer;
	if(!CheckItem(pItem, pPlayer)) return HAM_IGNORED;

	new iClip = GetItemClip(pItem);
	if(!iClip)
	{
		ExecuteHam(Ham_Weapon_PlayEmptySound, pItem);
		set_member(pItem, m_Weapon_flNextPrimaryAttack, 0.2);

		return HAM_SUPERCEDE;
	}

	CMissile_Create(pPlayer, pItem);
	UTIL_SendWeaponAnim(pPlayer, WEAPON_ANIM_SHOOT);
	UTIL_SendPlayerAnim(pPlayer, WEAPON_ANIMATION);
	rh_emit_sound2(pPlayer, 0, CHAN_ITEM, WEAPON_SOUNDS[0]);

	UTIL_WeaponKickBack(pItem, pPlayer, 2.0, 0.5, 0.5, 0.0125, 5.0, 2.25, 9);

	iClip--;
	set_member(pItem, m_Weapon_iClip, iClip);
	set_member(pItem, m_Weapon_flNextPrimaryAttack, WEAPON_RATE);
	set_member(pItem, m_Weapon_flNextSecondaryAttack, WEAPON_RATE);
	set_member(pItem, m_Weapon_flTimeWeaponIdle, WEAPON_ANIM_SHOOT_TIME);

	return HAM_SUPERCEDE;
}

public CWeapon_SecondaryAttack_Pre(const pItem)
{
	static pPlayer;
	if(!CheckItem(pItem, pPlayer)) return HAM_IGNORED;

	UTIL_SetUserFOV(pPlayer, IsDefaultFOV(pPlayer) ? 55 : DEFAULT_FOV);

	set_member(pPlayer, m_flNextAttack, 0.2);

	return HAM_SUPERCEDE;
}

public CMissile_Create(const pPlayer, const pItem)
{
	new pEntity = rg_create_entity(ENTITY_MISSILE_REFERENCE);
	if(is_nullent(pEntity)) return NULLENT;

	new Float: vecOrigin[3]; UTIL_GetWeaponPosition(pPlayer, 50.0, 10.0, -4.0, vecOrigin);
	new Float: vecViewAngle[3]; get_entvar(pPlayer, var_v_angle, vecViewAngle);
	new Float: vecForward[3]; angle_vector(vecViewAngle, ANGLEVECTOR_FORWARD, vecForward);
	new Float: vecVelocity[3]; xs_vec_copy(vecForward, vecVelocity);
	new Float: vecAngles[3];

	// Speed for missile
	xs_vec_mul_scalar(vecVelocity, ENTITY_MISSILE_SPEED, vecVelocity);

	set_entvar(pEntity, var_classname, ENTITY_MISSILE_CLASSNAME);
	set_entvar(pEntity, var_movetype, MOVETYPE_TOSS);
	set_entvar(pEntity, var_solid, SOLID_TRIGGER);
	set_entvar(pEntity, var_owner, pPlayer);
	set_entvar(pEntity, var_dmg_inflictor, pItem);
	set_entvar(pEntity, var_velocity, vecVelocity);
	set_entvar(pEntity, var_gravity, 0.3);
	set_entvar(pEntity, var_ltime, get_gametime() + ENTITY_MISSILE_LIFETIME);
	set_entvar(pEntity, var_nextthink, get_gametime());

	engfunc(EngFunc_VecToAngles, vecVelocity, vecAngles);
	set_entvar(pEntity, var_angles, vecAngles);

	engfunc(EngFunc_SetOrigin, pEntity, vecOrigin);
	engfunc(EngFunc_SetModel, pEntity, ENTITY_MISSILE_MODEL);

	rh_emit_sound2(pEntity, 0, CHAN_BODY, WEAPON_SOUNDS[2]);

	SetThink(pEntity, "CMissile_Think");
	SetTouch(pEntity, "CMissile_Touch");

	// https://github.com/baso88/SC_AngelScript/wiki/TE_BEAMFOLLOW
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
	write_byte(TE_BEAMFOLLOW);
	write_short(pEntity);
	write_short(gl_iszModelIndex_Sprites[eSprite_Trail]); // Model Index
	write_byte(7); // Life
	write_byte(3); // Width
	write_byte(255); // Red
	write_byte(127); // Green
	write_byte(127); // Blue
	write_byte(200); // Alpha
	message_end();

	return pEntity;
}

public CMissile_Think(const pEntity)
{
	if(is_nullent(pEntity)) return;

	static pOwner; pOwner = get_entvar(pEntity, var_owner);
	if(is_nullent(pOwner) || _is_user_zombie(pOwner))
	{
		UTIL_KillEntity(pEntity);
		return;
	}

	if(get_entvar(pEntity, var_ltime) < get_gametime())
	{
		CMissile_Explode(pEntity);
		return;
	}

	static Float: vecOrigin[3]; get_entvar(pEntity, var_origin, vecOrigin);
	engfunc(EngFunc_ParticleEffect, vecOrigin, Float: { 0.0, 0.0, 1000.0 }, 127.0, 25.0);

	// https://github.com/baso88/SC_AngelScript/wiki/TE_SPARKS
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
	write_byte(TE_SPARKS);
	write_coord_f(vecOrigin[0]);
	write_coord_f(vecOrigin[1]);
	write_coord_f(vecOrigin[2]);
	message_end();

	set_entvar(pEntity, var_nextthink, get_gametime() + ENTITY_MISSILE_NEXTTHINK);
}

public CMissile_Touch(const pEntity, const pTouch)
{
	if(is_nullent(pEntity)) return;

	CMissile_Explode(pEntity);
}

public CMissile_Explode(const pEntity)
{
	static Float: vecOrigin[3]; get_entvar(pEntity, var_origin, vecOrigin);

	// Effects
	UTIL_CreateExplosion(vecOrigin, 5.0, gl_iszModelIndex_Sprites[eSprite_Spark1], 12, 30, 4|8);
	UTIL_CreateExplosion(vecOrigin, 20.0, gl_iszModelIndex_Sprites[eSprite_Spark3], 10, 20, 4|8);
	rh_emit_sound2(pEntity, 0, CHAN_ITEM, WEAPON_SOUNDS[1]);

	// https://github.com/baso88/SC_AngelScript/wiki/TE_WORLDDECAL
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
	write_byte(TE_WORLDDECAL);
	write_coord_f(vecOrigin[0]);
	write_coord_f(vecOrigin[1]);
	write_coord_f(vecOrigin[2]);
	write_byte(random_num(46, 48));
	message_end();

	// Generate color
	new Float: flColor[3];
	flColor[0] = random_float(0.0, 255.0);
	flColor[1] = random_float(0.0, 255.0);
	flColor[2] = random_float(0.0, 255.0);

	CMissileSprite_Create(ENTITY_MISSILE_SPRITES[1], vecOrigin, flColor, true);

	// Do damage
	static pInflictor; pInflictor = get_entvar(pEntity, var_dmg_inflictor);
	if(!is_nullent(pInflictor) && IsCustomWeapon(pInflictor))
	{
		static pVictim; pVictim = NULLENT;
		static pOwner; pOwner = get_entvar(pEntity, var_owner);
		static Float: vecVictimOrigin[3], Float: flDamage;

		while((pVictim = engfunc(EngFunc_FindEntityInSphere, pVictim, vecOrigin, ENTITY_MISSILE_RADIUS)) > 0)
		{
			if(pVictim == pOwner || is_user_alive(pVictim) && !rg_is_player_can_takedamage(pVictim, pOwner))
				continue;

			if(get_entvar(pVictim, var_solid) == SOLID_BSP && ~get_entvar(pVictim, var_spawnflags) & SF_BREAK_TRIGGER_ONLY)
				flDamage = ENTITY_MISSILE_DAMAGE;
			else
			{
				get_entvar(pVictim, var_origin, vecVictimOrigin);

				if((flDamage = UTIL_CalculateDamage(vecOrigin, vecVictimOrigin, ENTITY_MISSILE_DAMAGE, ENTITY_MISSILE_RADIUS)) <= 0.0)
					continue;
			}

			ExecuteHamB(Ham_TakeDamage, pVictim, pInflictor, pOwner, flDamage, ENTITY_MISSILE_DMGTYPE);
		}
	}

	UTIL_KillEntity(pEntity);
}

public CMissileSprite_Create(const szSprite[], Float: vecOrigin[3], const Float: flColor[3], const bool: bFirst)
{
	if(global_get(glb_maxEntities) - engfunc(EngFunc_NumberOfEntities) < 100) return NULLENT;

	new pSprite = rg_create_entity("env_sprite");
	if(is_nullent(pSprite)) return NULLENT;

	new Float: vecEndPos[3]; xs_vec_copy(vecOrigin, vecEndPos);
	vecEndPos[0] += (random(2) ? -1.0 : 1.0) * random_float(20.0, 40.0);
	vecEndPos[1] += (random(2) ? -1.0 : 1.0) * random_float(20.0, 40.0);
	vecEndPos[2] += random_float(250.0, 300.0);

	new Float: vecVelocity[3]; xs_vec_sub(vecEndPos, vecOrigin, vecVelocity);
	xs_vec_normalize(vecVelocity, vecVelocity);
	xs_vec_mul_scalar(vecVelocity, random_float(150.0, 200.0), vecVelocity);

	vecOrigin[0] = vecEndPos[0];
	vecOrigin[1] = vecEndPos[1];
	vecOrigin[2] += random_float(20.0, 40.0);

	set_entvar(pSprite, var_classname, "ent_missile_spr");
	set_entvar(pSprite, var_spawnflags, SF_SPRITE_ONCE);
	set_entvar(pSprite, var_frame, 0.0);
	set_entvar(pSprite, var_framerate, 48.0);
	set_entvar(pSprite, var_max_frame, float(engfunc(EngFunc_ModelFrames, engfunc(EngFunc_ModelIndex, szSprite))));
	set_entvar(pSprite, var_rendercolor, flColor);
	set_entvar(pSprite, var_rendermode, kRenderTransAdd);
	set_entvar(pSprite, var_renderamt, random_float(100.0, 180.0));
	set_entvar(pSprite, var_scale, random_float(0.8, 1.0));
	set_entvar(pSprite, var_velocity, vecVelocity);
	set_entvar(pSprite, var_first_sprite, bFirst);

	engfunc(EngFunc_SetModel, pSprite, szSprite);
	engfunc(EngFunc_SetOrigin, pSprite, vecOrigin);
	dllfunc(DLLFunc_Spawn, pSprite);

	set_entvar(pSprite, var_movetype, MOVETYPE_NOCLIP);

	return pSprite;
}

public CSprite_Think_Post(const pSprite)
{
	if(is_nullent(pSprite)) return;
	if(FClassnameIs(pSprite, "ent_missile_spr"))
	{
		static Float: flFrame; get_entvar(pSprite, var_frame, flFrame);
		if(flFrame >= get_entvar(pSprite, var_max_frame))
		{
			UTIL_KillEntity(pSprite);
			return;
		}

		if(get_entvar(pSprite, var_first_sprite) == true)
		{
			if(flFrame < get_entvar(pSprite, var_max_frame) && ((floatround(flFrame) % 5) == 0))
			{
				static Float: vecOrigin[3]; get_entvar(pSprite, var_origin, vecOrigin);
				static Float: flColor[3]; get_entvar(pSprite, var_rendercolor, flColor);

				CMissileSprite_Create(ENTITY_MISSILE_SPRITES[1], vecOrigin, flColor, false);
			}
		}
	}
}

/* ~ [ Stocks ] ~ */
bool: CheckItem(const pItem, &pPlayer)
{
	if(is_nullent(pItem) || !IsCustomWeapon(pItem)) return false;

	pPlayer = get_member(pItem, m_pPlayer);
	if(is_nullent(pPlayer) || !is_user_connected(pPlayer)) return false;

	return true;
}

stock UTIL_KillEntity(const pEntity)
{
	// https://github.com/baso88/SC_AngelScript/wiki/TE_KILLBEAM
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
	write_byte(TE_KILLBEAM);
	write_short(pEntity);
	message_end();

	set_entvar(pEntity, var_flags, get_entvar(pEntity, var_flags) | FL_KILLME);
	set_entvar(pEntity, var_nextthink, get_gametime());

	SetThink(pEntity, "");
	SetTouch(pEntity, "");
}

stock Float: UTIL_CalculateDamage(const Float: vecOrigin[3], const Float: vecVictimOrigin[3], const Float: flDamage, const Float: flRadius)
	return (flDamage - xs_vec_distance(vecOrigin, vecVictimOrigin) * (flDamage / flRadius)) * 1.5;

#if defined CUSTOM_WEAPONLIST
	stock UTIL_UpdateHideWeapon(const pPlayer, const bitsFlags)
	{
		if(is_nullent(pPlayer)) return;

		static iMsgId_HideWeapon;
		if(!iMsgId_HideWeapon) iMsgId_HideWeapon = get_user_msgid("HideWeapon");

		message_begin(MSG_ONE, iMsgId_HideWeapon, .player = pPlayer);
		write_byte(bitsFlags);
		message_end();

		set_member(pPlayer, m_iHideHUD, bitsFlags);
		set_member(pPlayer, m_iClientHideHUD, bitsFlags);
	}
#endif

stock UTIL_SetUserFOV(const pPlayer, const iFOV = DEFAULT_FOV)
{
	static iMsgId_SetFOV;
	if(!iMsgId_SetFOV) iMsgId_SetFOV = get_user_msgid("SetFOV");

	message_begin(MSG_ONE, iMsgId_SetFOV, .player = pPlayer);
	write_byte(iFOV);
	message_end();

	set_entvar(pPlayer, var_fov, iFOV);
	set_member(pPlayer, m_iFOV, iFOV);
}

stock UTIL_SendWeaponAnim(const pPlayer, const iAnim)
{
	set_entvar(pPlayer, var_weaponanim, iAnim);

	message_begin(MSG_ONE, SVC_WEAPONANIM, .player = pPlayer);
	write_byte(iAnim);
	write_byte(0);
	message_end();
}

stock UTIL_PlayerAnimation(const pPlayer, const szAnim[])
{
	new iAnimDesired, Float: flFrameRate, Float: flGroundSpeed, bool: bLoops;
	if((iAnimDesired = lookup_sequence(pPlayer, szAnim, flFrameRate, bLoops, flGroundSpeed)) == -1)
		iAnimDesired = 0;

	set_entvar(pPlayer, var_frame, 0.0);
	set_entvar(pPlayer, var_framerate, 1.0);
	set_entvar(pPlayer, var_animtime, get_gametime());
	set_entvar(pPlayer, var_sequence, iAnimDesired);
	
	set_member(pPlayer, m_fSequenceLoops, bLoops);
	set_member(pPlayer, m_fSequenceFinished, 0);
	set_member(pPlayer, m_flFrameRate, flFrameRate);
	set_member(pPlayer, m_flGroundSpeed, flGroundSpeed);
	set_member(pPlayer, m_flLastEventCheck, get_gametime());
	set_member(pPlayer, m_Activity, ACT_RANGE_ATTACK1);
	set_member(pPlayer, m_IdealActivity, ACT_RANGE_ATTACK1);
	set_member(pPlayer, m_flLastFired, get_gametime());
}

stock UTIL_SendPlayerAnim(const pPlayer, const szAnim[])
{
	static szAnimation[64];
	formatex(szAnimation, charsmax(szAnimation), get_entvar(pPlayer, var_flags) & FL_DUCKING ? "crouch_shoot_%s" : "ref_shoot_%s", szAnim);
	UTIL_PlayerAnimation(pPlayer, szAnimation);
}

stock UTIL_CreateExplosion(const Float: vecOrigin[3], const Float: flUp, const iszModelIndex, const iScale, const iFrameRate, const iFlags)
{
	// https://github.com/baso88/SC_AngelScript/wiki/TE_EXPLOSION
	message_begin_f(MSG_PAS, SVC_TEMPENTITY, vecOrigin);
	write_byte(TE_EXPLOSION); // TE
	write_coord_f(vecOrigin[0]); // Position X
	write_coord_f(vecOrigin[1]); // Position Y
	write_coord_f(vecOrigin[2] + flUp); // Position Z
	write_short(iszModelIndex); // Model Index
	write_byte(iScale); // Scale
	write_byte(iFrameRate); // Framerate
	write_byte(iFlags); // Flags
	message_end();
}

#if defined CUSTOM_WEAPONLIST
	stock UTIL_WeaponList(const pPlayer, const pItem)
	{
		new szWeaponName[32]; rg_get_iteminfo(pItem, ItemInfo_pszName, szWeaponName, charsmax(szWeaponName));

		message_begin(MSG_ONE, gl_iMsgID_Weaponlist, .player = pPlayer);
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
#endif

stock UTIL_GetWeaponPosition(const pPlayer, const Float: flForward, const Float: flRight, const Float: flUp, Float: vecStart[]) 
{
	static Float: vecOrigin[3]; get_entvar(pPlayer, var_origin, vecOrigin);
	static Float: vecViewOfs[3]; get_entvar(pPlayer, var_view_ofs, vecViewOfs);
	xs_vec_add(vecOrigin, vecViewOfs, vecOrigin);
	
	static Float: vecViewAngle[3]; get_entvar(pPlayer, var_v_angle, vecViewAngle);
	static Float: vecForward[3]; angle_vector(vecViewAngle, ANGLEVECTOR_FORWARD, vecForward);
	static Float: vecRight[3]; angle_vector(vecViewAngle, ANGLEVECTOR_RIGHT, vecRight);
	static Float: vecUp[3]; angle_vector(vecViewAngle, ANGLEVECTOR_UP, vecUp);
	
	vecStart[0] = vecOrigin[0] + vecForward[0] * flForward + vecRight[0] * flRight + vecUp[0] * flUp;
	vecStart[1] = vecOrigin[1] + vecForward[1] * flForward + vecRight[1] * flRight + vecUp[1] * flUp;
	vecStart[2] = vecOrigin[2] + vecForward[2] * flForward + vecRight[2] * flRight + vecUp[2] * flUp;
}

stock UTIL_WeaponKickBack(const pItem, const pPlayer, Float: flUpBase, Float: flLateralBase, Float: flUpModifier, Float: flLateralModifier, Float: flUpMax, Float: flLateralMax, iDirectionChange)
{
	new Float: flKickUp;
	new Float: flKickLateral;
	new iShotsFired = get_member(pItem, m_Weapon_iShotsFired);
	new iDirection = get_member(pItem, m_Weapon_iDirection);
	new Float: vecPunchangle[3]; get_entvar(pPlayer, var_punchangle, vecPunchangle);

	if(iShotsFired == 1)
	{
		flKickUp = flUpBase;
		flKickLateral = flLateralBase;
	}
	else
	{
		flKickUp = iShotsFired * flUpModifier + flUpBase;
		flKickLateral = iShotsFired * flLateralModifier + flLateralBase;
	}

	vecPunchangle[0] -= flKickUp;

	if(vecPunchangle[0] < -flUpMax)
		vecPunchangle[0] = -flUpMax;

	if(iDirection)
	{
		vecPunchangle[1] += flKickLateral;
		if(vecPunchangle[1] > flLateralMax)
			vecPunchangle[1] = flLateralMax;
	}
	else
	{
		vecPunchangle[1] -= flKickLateral;
		if(vecPunchangle[1] < -flLateralMax)
			vecPunchangle[1] = -flLateralMax;
	}

	if(!random_num(0, iDirectionChange))
		set_member(pItem, m_Weapon_iDirection, iDirection);

	set_entvar(pPlayer, var_punchangle, vecPunchangle);
}

stock UTIL_GetWeaponBoxItem(const pWeaponBox)
{
	new pItem;
	for(new iSlot = 0; iSlot < MAX_ITEM_TYPES; iSlot++)
	{
		pItem = get_member(pWeaponBox, m_WeaponBox_rgpPlayerItems, iSlot);
		if(!is_nullent(pItem))
			return pItem;
	}

	return 0;
}
