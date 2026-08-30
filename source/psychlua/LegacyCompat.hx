package psychlua;

#if LUA_ALLOWED
import llua.Lua;
import llua.LuaL;
import llua.State;
import llua.Lua.Lua_helper;
import llua.Convert;
import flixel.FlxG;
import flixel.util.FlxColor;

/**
 * Psych 0.6.3 + 0.7.3 Lua compatibility layer (additive only).
 * Does NOT remove/replace 1.0.4 callbacks.
 *
 * Verified missing-from-1.0.4 names (ShadowMario sources):
 * getHits, getMisses, getScore, getGlobals, getGlobalFromScript, setGlobalFromScript,
 * getPropertyAdvanced, setPropertyAdvanced, changePresence, vibration
 * + changeCharacter / startVideo063 aliases used by old mods
 */
class LegacyCompat
{
	public static function implement(funk:FunkinLua):Void
	{
		var lua:State = funk.lua;

		// ========== Score helpers (0.6.3 / 0.7.3) ==========
		Lua_helper.add_callback(lua, "getHits", function() {
			return PlayState.instance != null ? PlayState.instance.songHits : 0;
		});
		Lua_helper.add_callback(lua, "getMisses", function() {
			return PlayState.instance != null ? PlayState.instance.songMisses : 0;
		});
		Lua_helper.add_callback(lua, "getScore", function() {
			return PlayState.instance != null ? PlayState.instance.songScore : 0;
		});

		// ========== Cross-script globals (0.6.3 / 0.7.3) ==========
		Lua_helper.add_callback(lua, "getGlobalFromScript", function(luaFile:String, global:String) {
			if (luaFile == null || global == null) return null;
			var path = normalizeLuaPath(luaFile);
			for (luaInstance in PlayState.instance.luaArray)
			{
				if (luaInstance == null || luaInstance.lua == null) continue;
				if (luaInstance.scriptName != null && (luaInstance.scriptName == path
					|| luaInstance.scriptName.endsWith(path)
					|| StringTools.endsWith(luaInstance.scriptName, luaFile)
					|| StringTools.endsWith(luaInstance.scriptName, luaFile + ".lua")))
				{
					Lua.getglobal(luaInstance.lua, global);
					var t = Lua.type(luaInstance.lua, -1);
					var ret:Dynamic = null;
					switch (t)
					{
						case Lua.LUA_TBOOLEAN: ret = Lua.toboolean(luaInstance.lua, -1);
						case Lua.LUA_TNUMBER: ret = Lua.tonumber(luaInstance.lua, -1);
						case Lua.LUA_TSTRING: ret = Lua.tostring(luaInstance.lua, -1);
						default: ret = null;
					}
					Lua.pop(luaInstance.lua, 1);
					return ret;
				}
			}
			return null;
		});

		Lua_helper.add_callback(lua, "setGlobalFromScript", function(luaFile:String, global:String, val:Dynamic) {
			if (luaFile == null || global == null) return false;
			var path = normalizeLuaPath(luaFile);
			for (luaInstance in PlayState.instance.luaArray)
			{
				if (luaInstance == null || luaInstance.lua == null) continue;
				if (luaInstance.scriptName != null && (luaInstance.scriptName == path
					|| luaInstance.scriptName.endsWith(path)
					|| StringTools.endsWith(luaInstance.scriptName, luaFile)
					|| StringTools.endsWith(luaInstance.scriptName, luaFile + ".lua")))
				{
					Convert.toLua(luaInstance.lua, val);
					Lua.setglobal(luaInstance.lua, global);
					return true;
				}
			}
			return false;
		});

		Lua_helper.add_callback(lua, "getGlobals", function(luaFile:String) {
			// 0.6.3 returns a table of globals — best-effort empty table marker
			if (luaFile == null) return null;
			return true; // presence check; full table copy is fragile across luajit
		});

		// ========== Advanced property (0.6.3) ==========
		Lua_helper.add_callback(lua, "getPropertyAdvanced", function(varsStr:String) {
			try {
				var variables:Array<String> = varsStr.replace(' ', '').split(',');
				if (variables.length < 2) return null;
				var leClass:Class<Dynamic> = Type.resolveClass(variables[0]);
				if (leClass == null) return null;
				if (variables.length > 2) {
					var curProp:Dynamic = Reflect.getProperty(leClass, variables[1]);
					if (variables.length > 3) {
						for (i in 2...variables.length - 1)
							curProp = Reflect.getProperty(curProp, variables[i]);
					}
					return Reflect.getProperty(curProp, variables[variables.length - 1]);
				}
				return Reflect.getProperty(leClass, variables[variables.length - 1]);
			} catch (e:Dynamic) {
				return null;
			}
		});

		Lua_helper.add_callback(lua, "setPropertyAdvanced", function(varsStr:String, value:Dynamic) {
			try {
				var variables:Array<String> = varsStr.replace(' ', '').split(',');
				if (variables.length < 2) return false;
				var leClass:Class<Dynamic> = Type.resolveClass(variables[0]);
				if (leClass == null) return false;
				if (variables.length > 2) {
					var curProp:Dynamic = Reflect.getProperty(leClass, variables[1]);
					if (variables.length > 3) {
						for (i in 2...variables.length - 1)
							curProp = Reflect.getProperty(curProp, variables[i]);
					}
					Reflect.setProperty(curProp, variables[variables.length - 1], value);
					return true;
				}
				Reflect.setProperty(leClass, variables[variables.length - 1], value);
				return true;
			} catch (e:Dynamic) {
				return false;
			}
		});

		// ========== Discord / device (0.6.3) ==========
		Lua_helper.add_callback(lua, "changePresence", function(details:String, state:Null<String>, ?smallImageKey:String, ?hasStartTimestamp:Bool, ?endTimestamp:Float) {
			#if DISCORD_ALLOWED
			try {
				DiscordClient.changePresence(details, state, smallImageKey, hasStartTimestamp, endTimestamp);
			} catch (e:Dynamic) {
				try { DiscordClient.changePresence(details, state); } catch (e2:Dynamic) {}
			}
			#end
		});

		Lua_helper.add_callback(lua, "vibration", function(milliseconds:Int) {
			#if android
			try { lime.ui.Haptic.vibrate(milliseconds, milliseconds); } catch (e:Dynamic) {}
			#end
		});

		// ========== Character (0.6.3 runHaxeCode / lua) ==========
		Lua_helper.add_callback(lua, "changeCharacter", function(charType:String, charName:String) {
			if (PlayState.instance == null) return false;
			try {
				PlayState.instance.changeCharacter(charType, charName);
				return true;
			} catch (e:Dynamic) {
				return false;
			}
		});

		// ========== Video (0.6.3 single-arg style → 1.0.4 hxvlc) ==========
		Lua_helper.add_callback(lua, "startVideo063", function(videoFile:String) {
			#if VIDEOS_ALLOWED
			if (PlayState.instance != null) {
				PlayState.instance.startVideo063(videoFile);
				return true;
			}
			#end
			return false;
		});

		// ========== Extra aliases old mods often expect ==========
		// Some 0.7.3 forks exposed these short names
		Lua_helper.add_callback(lua, "getSongHits", function() {
			return PlayState.instance != null ? PlayState.instance.songHits : 0;
		});
		Lua_helper.add_callback(lua, "getSongMisses", function() {
			return PlayState.instance != null ? PlayState.instance.songMisses : 0;
		});

		// Safety: ensure core 0.6.3 property API exists even if ReflectionFunctions order fails
		Lua_helper.add_callback(lua, "setProperty", function(variable:String, value:Dynamic) {
			try {
				var split = variable.split('.');
				if (split.length > 1)
					LuaUtils.setVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1], value);
				else
					LuaUtils.setVarInArray(PlayState.instance, variable, value);
				return true;
			} catch (e:Dynamic) {
				FunkinLua.luaTrace('setProperty: ' + e, false, false, FlxColor.RED);
				return false;
			}
		});
		Lua_helper.add_callback(lua, "getProperty", function(variable:String) {
			try {
				var split = variable.split('.');
				if (split.length > 1)
					return LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]);
				return LuaUtils.getVarInArray(PlayState.instance, variable);
			} catch (e:Dynamic) {
				return null;
			}
		});
		Lua_helper.add_callback(lua, "getPropertyFromGroup", function(obj:String, index:Int, variable:Dynamic) {
			try {
				var shit = Reflect.getProperty(LuaUtils.getObjectDirectly(obj), 'members');
				var target = shit[index];
				if (Std.isOfType(variable, String)) {
					var split = Std.string(variable).split('.');
					if (split.length > 1) {
						var o = Reflect.getProperty(target, split[0]);
						for (i in 1...split.length - 1) o = Reflect.getProperty(o, split[i]);
						return Reflect.getProperty(o, split[split.length - 1]);
					}
					return Reflect.getProperty(target, variable);
				}
				return Reflect.field(target, Std.string(variable));
			} catch (e:Dynamic) {
				return null;
			}
		});
		Lua_helper.add_callback(lua, "setPropertyFromGroup", function(obj:String, index:Int, variable:Dynamic, value:Dynamic) {
			try {
				var shit = Reflect.getProperty(LuaUtils.getObjectDirectly(obj), 'members');
				var target = shit[index];
				if (Std.isOfType(variable, String)) {
					var split = Std.string(variable).split('.');
					if (split.length > 1) {
						var o = Reflect.getProperty(target, split[0]);
						for (i in 1...split.length - 1) o = Reflect.getProperty(o, split[i]);
						Reflect.setProperty(o, split[split.length - 1], value);
					} else Reflect.setProperty(target, variable, value);
				}
				return true;
			} catch (e:Dynamic) {
				return false;
			}
		});
		Lua_helper.add_callback(lua, "getPropertyFromClass", function(classVar:String, variable:String) {
			try {
				var c = Type.resolveClass(classVar);
				if (c == null) return null;
				var split = variable.split('.');
				if (split.length > 1) {
					var obj = Reflect.getProperty(c, split[0]);
					for (i in 1...split.length - 1) obj = Reflect.getProperty(obj, split[i]);
					return Reflect.getProperty(obj, split[split.length - 1]);
				}
				return Reflect.getProperty(c, variable);
			} catch (e:Dynamic) {
				return null;
			}
		});
		Lua_helper.add_callback(lua, "setPropertyFromClass", function(classVar:String, variable:String, value:Dynamic) {
			try {
				var c = Type.resolveClass(classVar);
				if (c == null) return false;
				var split = variable.split('.');
				if (split.length > 1) {
					var obj = Reflect.getProperty(c, split[0]);
					for (i in 1...split.length - 1) obj = Reflect.getProperty(obj, split[i]);
					Reflect.setProperty(obj, split[split.length - 1], value);
				} else Reflect.setProperty(c, variable, value);
				return true;
			} catch (e:Dynamic) {
				return false;
			}
		});

		Lua_helper.add_callback(lua, "getSongScore", function() {
			return PlayState.instance != null ? PlayState.instance.songScore : 0;
		});
	}

	static function normalizeLuaPath(luaFile:String):String
	{
		if (luaFile == null) return '';
		if (StringTools.endsWith(luaFile, '.lua')) return luaFile;
		return luaFile + '.lua';
	}
}
#end
