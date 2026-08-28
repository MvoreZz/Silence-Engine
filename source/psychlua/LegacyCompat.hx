package psychlua;

#if LUA_ALLOWED
/**
 * Additive compatibility for Psych 0.6.3 / 0.7.3 Lua APIs.
 * Does NOT remove or replace 1.0.4 callbacks — only registers missing names.
 */
class LegacyCompat
{
	public static function implement(funk:FunkinLua):Void
	{
		var lua:State = funk.lua;
		var game = PlayState.instance;

		// ----- 0.6.3 unique -----
		Lua_helper.add_callback(lua, "getPropertyAdvanced", function(varsStr:String) {
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
		});

		Lua_helper.add_callback(lua, "setPropertyAdvanced", function(varsStr:String, value:Dynamic) {
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
		});

		Lua_helper.add_callback(lua, "changePresence", function(details:String, state:Null<String>, ?smallImageKey:String, ?hasStartTimestamp:Bool, ?endTimestamp:Float) {
			#if DISCORD_ALLOWED
			try {
				// 1.0.4 Discord API may differ slightly — best effort
				DiscordClient.changePresence(details, state, smallImageKey, hasStartTimestamp, endTimestamp);
			} catch (e:Dynamic) {
				try { DiscordClient.changePresence(details, state); } catch (e2:Dynamic) {}
			}
			#end
		});

		Lua_helper.add_callback(lua, "vibration", function(milliseconds:Int) {
			#if android
			try {
				lime.ui.Haptic.vibrate(milliseconds, milliseconds);
			} catch (e:Dynamic) {}
			#end
		});

		// ----- shared 0.6.3 / 0.7.3 (safe if already registered — re-register same behavior) -----
		Lua_helper.add_callback(lua, "getHits", function() {
			return PlayState.instance != null ? PlayState.instance.songHits : 0;
		});
		Lua_helper.add_callback(lua, "getMisses", function() {
			return PlayState.instance != null ? PlayState.instance.songMisses : 0;
		});
		Lua_helper.add_callback(lua, "getScore", function() {
			return PlayState.instance != null ? PlayState.instance.songScore : 0;
		});

		Lua_helper.add_callback(lua, "getGlobalFromScript", function(luaFile:String, global:String) {
			if (PlayState.instance == null || PlayState.instance.luaArray == null) return;
			for (luaInstance in PlayState.instance.luaArray) {
				if (luaInstance.scriptName != null && luaInstance.scriptName.indexOf(luaFile) != -1) {
					Lua.getglobal(luaInstance.lua, global);
					if (Lua.isnumber(luaInstance.lua, -1))
						Lua.pushnumber(lua, Lua.tonumber(luaInstance.lua, -1));
					else if (Lua.isstring(luaInstance.lua, -1))
						Lua.pushstring(lua, Lua.tostring(luaInstance.lua, -1));
					else if (Lua.isboolean(luaInstance.lua, -1))
						Lua.pushboolean(lua, Lua.toboolean(luaInstance.lua, -1));
					else
						Lua.pushnil(lua);
					Lua.pop(luaInstance.lua, 1);
					return;
				}
			}
		});

		Lua_helper.add_callback(lua, "setGlobalFromScript", function(luaFile:String, global:String, val:Dynamic) {
			if (PlayState.instance == null || PlayState.instance.luaArray == null) return;
			for (luaInstance in PlayState.instance.luaArray) {
				if (luaInstance.scriptName != null && luaInstance.scriptName.indexOf(luaFile) != -1) {
					luaInstance.set(global, val);
					return;
				}
			}
		});

		Lua_helper.add_callback(lua, "getGlobals", function(luaFile:String) {
			if (PlayState.instance == null || PlayState.instance.luaArray == null) return;
			for (luaInstance in PlayState.instance.luaArray) {
				if (luaInstance.scriptName != null && luaInstance.scriptName.indexOf(luaFile) != -1) {
					Lua.newtable(lua);
					var tableIdx = Lua.gettop(lua);
					Lua.pushvalue(luaInstance.lua, Lua.LUA_GLOBALSINDEX);
					while (Lua.next(luaInstance.lua, -2) != 0) {
						var pop:Int = 0;
						if (Lua.isnumber(luaInstance.lua, -2)) { Lua.pushnumber(lua, Lua.tonumber(luaInstance.lua, -2)); pop++; }
						else if (Lua.isstring(luaInstance.lua, -2)) { Lua.pushstring(lua, Lua.tostring(luaInstance.lua, -2)); pop++; }
						else if (Lua.isboolean(luaInstance.lua, -2)) { Lua.pushboolean(lua, Lua.toboolean(luaInstance.lua, -2)); pop++; }
						if (Lua.isnumber(luaInstance.lua, -1)) { Lua.pushnumber(lua, Lua.tonumber(luaInstance.lua, -1)); pop++; }
						else if (Lua.isstring(luaInstance.lua, -1)) { Lua.pushstring(lua, Lua.tostring(luaInstance.lua, -1)); pop++; }
						else if (Lua.isboolean(luaInstance.lua, -1)) { Lua.pushboolean(lua, Lua.toboolean(luaInstance.lua, -1)); pop++; }
						if (pop == 2) Lua.rawset(lua, tableIdx);
						Lua.pop(luaInstance.lua, 1);
					}
					Lua.pop(luaInstance.lua, 1);
					Lua.pushvalue(lua, tableIdx);
					return;
				}
			}
		});

		// 0.6.3 / 0.7.3 video: startVideo("file") — already on 1.0.4 with optional args; no override

		// 0.6.3 shader note: initLuaShader / setSpriteShader exist on 1.0.4 ShaderFunctions
	}
}
#end
