package psychlua;

#if LUA_ALLOWED
import llua.Lua;
import llua.LuaL;
import llua.State;
import llua.Lua.Lua_helper;
import llua.Convert;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.util.FlxColor;

/**
 * Additive 0.6.3 / 0.7.3 Lua only.
 * Does NOT re-register setProperty / getProperty / FromGroup / FromClass
 * (those stay on 1.0.4 ReflectionFunctions — overriding them broke custom note textures).
 */
class LegacyCompat
{
	public static function implement(funk:FunkinLua):Void
	{
		var lua:State = funk.lua;

		// ----- Score shortcuts (0.6.3 / 0.7.3) -----
		Lua_helper.add_callback(lua, "getHits", function() {
			return PlayState.instance != null ? PlayState.instance.songHits : 0;
		});
		Lua_helper.add_callback(lua, "getMisses", function() {
			return PlayState.instance != null ? PlayState.instance.songMisses : 0;
		});
		Lua_helper.add_callback(lua, "getScore", function() {
			return PlayState.instance != null ? PlayState.instance.songScore : 0;
		});
		Lua_helper.add_callback(lua, "getSongHits", function() {
			return PlayState.instance != null ? PlayState.instance.songHits : 0;
		});
		Lua_helper.add_callback(lua, "getSongMisses", function() {
			return PlayState.instance != null ? PlayState.instance.songMisses : 0;
		});
		Lua_helper.add_callback(lua, "getSongScore", function() {
			return PlayState.instance != null ? PlayState.instance.songScore : 0;
		});

		// ----- Cross-script globals -----
		Lua_helper.add_callback(lua, "getGlobalFromScript", function(luaFile:String, global:String) {
			if (luaFile == null || global == null) return null;
			var path = normalizeLuaPath(luaFile);
			if (PlayState.instance == null) return null;
			for (luaInstance in PlayState.instance.luaArray)
			{
				if (luaInstance == null || luaInstance.lua == null || luaInstance.scriptName == null) continue;
				if (luaInstance.scriptName == path
					|| StringTools.endsWith(luaInstance.scriptName, path)
					|| StringTools.endsWith(luaInstance.scriptName, luaFile)
					|| StringTools.endsWith(luaInstance.scriptName, luaFile + ".lua"))
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
			if (PlayState.instance == null) return false;
			for (luaInstance in PlayState.instance.luaArray)
			{
				if (luaInstance == null || luaInstance.lua == null || luaInstance.scriptName == null) continue;
				if (luaInstance.scriptName == path
					|| StringTools.endsWith(luaInstance.scriptName, path)
					|| StringTools.endsWith(luaInstance.scriptName, luaFile)
					|| StringTools.endsWith(luaInstance.scriptName, luaFile + ".lua"))
				{
					Convert.toLua(luaInstance.lua, val);
					Lua.setglobal(luaInstance.lua, global);
					return true;
				}
			}
			return false;
		});

		Lua_helper.add_callback(lua, "getGlobals", function(luaFile:String) {
			return luaFile != null;
		});

		// ----- Advanced property (0.6.3 unique names) -----
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

		// ----- Discord / haptic -----
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

		// ----- Character / video aliases -----
		Lua_helper.add_callback(lua, "changeCharacter", function(charType:String, charName:String) {
			if (PlayState.instance == null) return false;
			try {
				PlayState.instance.changeCharacter(charType, charName);
				return true;
			} catch (e:Dynamic) {
				return false;
			}
		});

		Lua_helper.add_callback(lua, "startVideo063", function(videoFile:String) {
			#if VIDEOS_ALLOWED
			if (PlayState.instance != null) {
				PlayState.instance.startVideo063(videoFile);
				return true;
			}
			#end
			return false;
		});

		// Shader: do NOT override ShaderFunctions — already on 1.0.4
	}

	static function normalizeLuaPath(luaFile:String):String
	{
		if (luaFile == null) return '';
		if (StringTools.endsWith(luaFile, '.lua')) return luaFile;
		return luaFile + '.lua';
	}
}
#end
