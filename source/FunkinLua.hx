#if LUA_ALLOWED
import llua.Lua;
import llua.LuaL;
import llua.State;
import llua.Convert;
#end

import flixel.FlxG;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.text.FlxText;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxPoint;
import flixel.util.FlxTimer;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.util.FlxColor;
#if sys
import sys.FileSystem;
import sys.io.File;
#end
import Type.ValueType;
import Controls;
import DialogueBoxPsych;

using StringTools;

class FunkinLua {
	public static var Function_Stop = 1;
	public static var Function_Continue = 0;

	#if LUA_ALLOWED
	public var lua:State = null;
	#end

	var lePlayState:PlayState = null;
	var scriptName:String = '';
	var gonnaClose:Bool = false;

	public var accessedProps:Map<String, Dynamic> = null;
	public function new(script:String) {
		#if LUA_ALLOWED
		lua = LuaL.newstate();
		LuaL.openlibs(lua);
		Lua.init_callbacks(lua);

		//trace('Lua version: ' + Lua.version());
		//trace("LuaJIT version: " + Lua.versionJIT());

		var result:Dynamic = LuaL.dofile(lua, script);
		var resultStr:String = Lua.tostring(lua, result);
		if(resultStr != null && result != 0) {
			lime.app.Application.current.window.alert(resultStr, 'Error on .LUA script!');
			trace('Error on .LUA script! ' + resultStr);
			lua = null;
			return;
		}
		scriptName = script;
		trace('Lua file loaded succesfully:' + script);

		#if (haxe >= "4.0.0")
		accessedProps = new Map();
		#else
		accessedProps = new Map<String, Dynamic>();
		#end

		var curState:Dynamic = FlxG.state;
		lePlayState = curState;

		// Lua shit
		set('Function_Stop', Function_Stop);
		set('Function_Continue', Function_Continue);
		set('luaDebugMode', false);
		set('luaDeprecatedWarnings', true);

		// Song/Week shit
		set('curBpm', Conductor.bpm);
		set('bpm', PlayState.SONG.bpm);
		set('scrollSpeed', PlayState.SONG.speed);
		set('crochet', Conductor.crochet);
		set('stepCrochet', Conductor.stepCrochet);
		set('songLength', FlxG.sound.music.length);
		set('songName', PlayState.SONG.song);
		set('startedCountdown', false);

		set('isStoryMode', PlayState.isStoryMode);
		set('difficulty', PlayState.storyDifficulty);
		set('weekRaw', PlayState.storyWeek);
		set('week', WeekData.weeksList[PlayState.storyWeek]);
		set('seenCutscene', PlayState.seenCutscene);

		// Camera poo
		set('cameraX', 0);
		set('cameraY', 0);
		
		// Screen stuff
		set('screenWidth', FlxG.width);
		set('screenHeight', FlxG.height);

		// PlayState cringe ass nae nae bullcrap
		set('curBeat', 0);
		set('curStep', 0);

		set('score', 0);
		set('misses', 0);
		set('ghostMisses', 0);
		set('hits', 0);

		set('rating', 0);
		set('ratingName', '');
		
		set('inGameOver', false);
		set('mustHitSection', false);
		set('botPlay', PlayState.cpuControlled);

		for (i in 0...4) {
			set('defaultPlayerStrumX' + i, 0);
			set('defaultPlayerStrumY' + i, 0);
			set('defaultOpponentStrumX' + i, 0);
			set('defaultOpponentStrumY' + i, 0);
		}

		// Some settings, no jokes
		set('downscroll', ClientPrefs.downScroll);
		set('middlescroll', ClientPrefs.middleScroll);
		set('framerate', ClientPrefs.framerate);
		set('ghostTapping', ClientPrefs.ghostTapping);
		set('hideHud', ClientPrefs.hideHud);
		set('hideTime', ClientPrefs.hideTime);
		set('cameraZoomOnBeat', ClientPrefs.camZooms);
		set('flashingLights', ClientPrefs.flashing);
		set('noteOffset', ClientPrefs.noteOffset);
		set('lowQuality', ClientPrefs.lowQuality);

		//stuff 4 noobz like you B)
		Lua_helper.add_callback(lua, "getProperty", function(variable:String) {
			var killMe:Array<String> = variable.split('.');
			if(killMe.length > 1) {
				var coverMeInPiss:Dynamic = Reflect.getProperty(lePlayState, killMe[0]);
				for (i in 1...killMe.length-1) {
					coverMeInPiss = Reflect.getProperty(coverMeInPiss, killMe[i]);
				}
				return Reflect.getProperty(coverMeInPiss, killMe[killMe.length-1]);
			}
			return Reflect.getProperty(lePlayState, variable);
		});
		Lua_helper.add_callback(lua, "setProperty", function(variable:String, value:Dynamic) {
			var killMe:Array<String> = variable.split('.');
			if(killMe.length > 1) {
				var coverMeInPiss:Dynamic = Reflect.getProperty(lePlayState, killMe[0]);
				for (i in 1...killMe.length-1) {
					coverMeInPiss = Reflect.getProperty(coverMeInPiss, killMe[i]);
				}
				return Reflect.setProperty(coverMeInPiss, killMe[killMe.length-1], value);
			}
			return Reflect.setProperty(lePlayState, variable, value);
		});
		Lua_helper.add_callback(lua, "getPropertyFromGroup", function(obj:String, index:Int, variable:Dynamic) {
			if(Std.isOfType(Reflect.getProperty(lePlayState, obj), FlxTypedGroup)) {
				return Reflect.getProperty(Reflect.getProperty(lePlayState, obj).members[index], variable);
			}

			var leArray:Dynamic = Reflect.getProperty(lePlayState, obj)[index];
			if(leArray != null) {
				if(Type.typeof(variable) == ValueType.TInt) {
					return leArray[variable];
				}
				return Reflect.getProperty(leArray, variable);
			}
			luaTrace("Object #" + index + " from group: " + obj + " doesn't exist!");
			return null;
		});
		Lua_helper.add_callback(lua, "setPropertyFromGroup", function(obj:String, index:Int, variable:Dynamic, value:Dynamic) {
			if(Std.isOfType(Reflect.getProperty(lePlayState, obj), FlxTypedGroup)) {
				return Reflect.setProperty(Reflect.getProperty(lePlayState, obj).members[index], variable, value);
			}

			var leArray:Dynamic = Reflect.getProperty(lePlayState, obj)[index];
			if(leArray != null) {
				if(Type.typeof(variable) == ValueType.TInt) {
					return leArray[variable] = value;
				}
				return Reflect.setProperty(leArray, variable, value);
			}
		});
		Lua_helper.add_callback(lua, "removeFromGroup", function(obj:String, index:Int, dontKill:Bool = false, dontDestroy:Bool = false) {
			if(Std.isOfType(Reflect.getProperty(lePlayState, obj), FlxTypedGroup)) {
				var sex = Reflect.getProperty(lePlayState, obj).members[index];
				if(!dontKill)
					sex.kill();
				Reflect.getProperty(lePlayState, obj).remove(sex, true);
				if(!dontDestroy)
					sex.destroy();
				return;
			}
			Reflect.getProperty(lePlayState, obj).remove(Reflect.getProperty(lePlayState, obj)[index]);
		});

		Lua_helper.add_callback(lua, "getPropertyFromClass", function(classVar:String, variable:String) {
			var killMe:Array<String> = variable.split('.');
			if(killMe.length > 1) {
				var coverMeInPiss:Dynamic = Reflect.getProperty(Type.resolveClass(classVar), killMe[0]);
				for (i in 1...killMe.length-1) {
					coverMeInPiss = Reflect.getProperty(coverMeInPiss, killMe[i]);
				}
				return Reflect.getProperty(coverMeInPiss, killMe[killMe.length-1]);
			}
			return Reflect.getProperty(Type.resolveClass(classVar), variable);
		});
		Lua_helper.add_callback(lua, "setPropertyFromClass", function(classVar:String, variable:String, value:Dynamic) {
			var killMe:Array<String> = variable.split('.');
			if(killMe.length > 1) {
				var coverMeInPiss:Dynamic = Reflect.getProperty(Type.resolveClass(classVar), killMe[0]);
				for (i in 1...killMe.length-1) {
					coverMeInPiss = Reflect.getProperty(coverMeInPiss, killMe[i]);
				}
				return Reflect.setProperty(coverMeInPiss, killMe[killMe.length-1], value);
			}
			return Reflect.setProperty(Type.resolveClass(classVar), variable, value);
		});

		//shitass stuff for epic coders like me B)  *image of obama giving himself a medal*
		Lua_helper.add_callback(lua, "accessPropertyFirst", function(tag:String, classVar:String, variable:String) {
			accessedProps.set(tag , Reflect.getProperty(classVar != null ? Type.resolveClass(classVar) : lePlayState, variable));
		});
		Lua_helper.add_callback(lua, "accessPropertyFromGroupFirst", function(tag:String, classVar:String, obj:String, index:Int, variable:Dynamic) {
			if(Std.isOfType(Reflect.getProperty(classVar != null ? Type.resolveClass(classVar) : lePlayState, variable), FlxTypedGroup)) {
				accessedProps.set(tag, Reflect.getProperty(Reflect.getProperty(classVar != null ? Type.resolveClass(classVar) : lePlayState, obj).members[index], variable));
			}

			var leArray:Dynamic = Reflect.getProperty(classVar != null ? Type.resolveClass(classVar) : lePlayState, variable)[index];
			if(leArray != null) {
				if(Type.typeof(variable) == ValueType.TInt) {
					accessedProps.set(tag, leArray[variable]);
				}
				accessedProps.set(tag, Reflect.getProperty(leArray, variable));
			}
		});
		Lua_helper.add_callback(lua, "accessProperty", function(tag:String, variable:String) {
			if(accessedProps.exists(tag)) {
				accessedProps.set(tag, Reflect.getProperty(accessedProps.get(tag), variable));
			}
			luaTrace("Accessed property " + tag + " doesn't exist!");
		});
		Lua_helper.add_callback(lua, "accessPropertyFromGroup", function(tag:String, index:Int, variable:Dynamic) {
			if(!accessedProps.exists(tag)) {
				luaTrace("Accessed property " + tag + " doesn't exist!");
				return;
			}

			if(Std.isOfType(accessedProps.get(tag), FlxTypedGroup)) {
				accessedProps.set(tag, Reflect.getProperty(accessedProps.get(tag).members[index], variable));
			}

			var leArray:Dynamic = accessedProps.get(tag)[index];
			if(leArray != null) {
				if(Type.typeof(variable) == ValueType.TInt) {
					accessedProps.set(tag, leArray[variable]);
				}
				accessedProps.set(tag, Reflect.getProperty(leArray, variable));
			}
		});
		Lua_helper.add_callback(lua, "getAccessedPropertyValue", function(tag:String, variable:String) {
			if(accessedProps.exists(tag)) {
				return Reflect.getProperty(accessedProps.get(tag), variable);
			}
			luaTrace("Accessed property " + tag + " doesn't exist!");
			return null;
		});
		Lua_helper.add_callback(lua, "setAccessedPropertyValue", function(tag:String, variable:String, value:Dynamic) {
			if(accessedProps.exists(tag)) {
				return Reflect.setProperty(accessedProps.get(tag), variable, value);
			}
		});
		Lua_helper.add_callback(lua, "getAccessedPropertyValueFromGroup", function(tag:String, index:Int, variable:Dynamic) {
			if(accessedProps.exists(tag)) {
				if(Std.isOfType(accessedProps.get(tag), FlxTypedGroup)) {
					return Reflect.getProperty(accessedProps.get(tag).members[index], variable);
				}

				var leArray:Dynamic = accessedProps.get(tag)[index];
				if(leArray != null) {
					if(Type.typeof(variable) == ValueType.TInt) {
						return leArray[variable];
					}
					return Reflect.getProperty(leArray, variable);
				}
			}
			luaTrace("Accessed property " + tag + " doesn't exist!");
			return null;
		});
		Lua_helper.add_callback(lua, "setAccessedPropertyValueFromGroup", function(tag:String, index:Int, variable:Dynamic, value:Dynamic) {
			if(accessedProps.exists(tag)) {
				if(Std.isOfType(accessedProps.get(tag), FlxTypedGroup)) {
					return Reflect.setProperty(accessedProps.get(tag).members[index], variable, value);
				}

				var leArray:Dynamic = accessedProps.get(tag)[index];
				if(leArray != null) {
					if(Type.typeof(variable) == ValueType.TInt) {
						return leArray[variable] = value;
					}
					return Reflect.setProperty(leArray, variable, value);
				}
			}
		});
		
		// gay ass tweens
		Lua_helper.add_callback(lua, "doTweenX", function(tag:String, vars:String, value:Dynamic, duration:Float, ease:String) {
			var penisExam:Dynamic = tweenShit(tag, vars);
			if(penisExam != null) {
				lePlayState.modchartTweens.set(tag, FlxTween.tween(penisExam, {x: value}, duration, {ease: getFlxEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						call('onTweenCompleted', [tag]);
						lePlayState.modchartTweens.remove(tag);
					}
				}));
			} else {
				luaTrace('Couldnt find object: ' + vars);
			}
		});
		Lua_helper.add_callback(lua, "doTweenY", function(tag:String, vars:String, value:Dynamic, duration:Float, ease:String) {
			var penisExam:Dynamic = tweenShit(tag, vars);
			if(penisExam != null) {
				lePlayState.modchartTweens.set(tag, FlxTween.tween(penisExam, {y: value}, duration, {ease: getFlxEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						call('onTweenCompleted', [tag]);
						lePlayState.modchartTweens.remove(tag);
					}
				}));
			} else {
				luaTrace('Couldnt find object: ' + vars);
			}
		});
		Lua_helper.add_callback(lua, "doTweenAlpha", function(tag:String, vars:String, value:Dynamic, duration:Float, ease:String) {
			var penisExam:Dynamic = tweenShit(tag, vars);
			if(penisExam != null) {
				lePlayState.modchartTweens.set(tag, FlxTween.tween(penisExam, {alpha: value}, duration, {ease: getFlxEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						call('onTweenCompleted', [tag]);
						lePlayState.modchartTweens.remove(tag);
					}
				}));
			} else {
				luaTrace('Couldnt find object: ' + vars);
			}
		});
		Lua_helper.add_callback(lua, "doTweenZoom", function(tag:String, vars:String, value:Dynamic, duration:Float, ease:String) {
			var penisExam:Dynamic = tweenShit(tag, vars);
			if(penisExam != null) {
				lePlayState.modchartTweens.set(tag, FlxTween.tween(penisExam, {zoom: value}, duration, {ease: getFlxEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						call('onTweenCompleted', [tag]);
						lePlayState.modchartTweens.remove(tag);
					}
				}));
			} else {
				luaTrace('Couldnt find object: ' + vars);
			}
		});
		Lua_helper.add_callback(lua, "doTweenColor", function(tag:String, vars:String, targetColor:String, duration:Float, ease:String) {
			var penisExam:Dynamic = tweenShit(tag, vars);
			if(penisExam != null) {
				var color:Int = Std.parseInt(targetColor);
				if(!targetColor.startsWith('0x')) color = Std.parseInt('0xff' + targetColor);

				lePlayState.modchartTweens.set(tag, FlxTween.color(penisExam, duration, penisExam.color, color, {ease: getFlxEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						lePlayState.modchartTweens.remove(tag);
						call('onTweenCompleted', [tag]);
					}
				}));
			} else {
				luaTrace('Couldnt find object: ' + vars);
			}
		});
		Lua_helper.add_callback(lua, "cancelTween", function(tag:String) {
			cancelTween(tag);
		});

		Lua_helper.add_callback(lua, "runTimer", function(tag:String, time:Float = 1, loops:Int = 1) {
			cancelTimer(tag);
			lePlayState.modchartTimers.set(tag, new FlxTimer().start(time, function(tmr:FlxTimer) {
				if(tmr.finished) {
					lePlayState.modchartTimers.remove(tag);
				}
				call('onTimerCompleted', [tag, tmr.loops, tmr.loopsLeft]);
			}, loops));
		});
		Lua_helper.add_callback(lua, "cancelTimer", function(tag:String) {
			cancelTimer(tag);
		});

		/*Lua_helper.add_callback(lua, "getPropertyAdvanced", function(varsStr:String) {
			var variables:Array<String> = varsStr.replace(' ', '').split(',');
			var leClass:Class<Dynamic> = Type.resolveClass(variables[0]);
			if(variables.length > 2) {
				var curProp:Dynamic = Reflect.getProperty(leClass, variables[1]);
				if(variables.length > 3) {
					for (i in 2...variables.length-1) {
						curProp = Reflect.getProperty(curProp, variables[i]);
					}
				}
				return Reflect.getProperty(curProp, variables[variables.length-1]);
			} else if(variables.length == 2) {
				return Reflect.getProperty(leClass, variables[variables.length-1]);
			}
			return null;
		});
		Lua_helper.add_callback(lua, "setPropertyAdvanced", function(varsStr:String, value:Dynamic) {
			var variables:Array<String> = varsStr.replace(' ', '').split(',');
			var leClass:Class<Dynamic> = Type.resolveClass(variables[0]);
			if(variables.length > 2) {
				var curProp:Dynamic = Reflect.getProperty(leClass, variables[1]);
				if(variables.length > 3) {
					for (i in 2...variables.length-1) {
						curProp = Reflect.getProperty(curProp, variables[i]);
					}
				}
				return Reflect.setProperty(curProp, variables[variables.length-1], value);
			} else if(variables.length == 2) {
				return Reflect.setProperty(leClass, variables[variables.length-1], value);
			}
		});*/
		
		//stupid bietch ass functions
		Lua_helper.add_callback(lua, "addScore", function(value:Int = 0) {
			lePlayState.songScore += value;
			lePlayState.RecalculateRating();
		});
		Lua_helper.add_callback(lua, "addMisses", function(value:Int = 0) {
			lePlayState.songMisses += value;
			lePlayState.RecalculateRating();
		});
		Lua_helper.add_callback(lua, "addHits", function(value:Int = 0) {
			lePlayState.songHits += value;
			lePlayState.RecalculateRating();
		});
		Lua_helper.add_callback(lua, "setScore", function(value:Int = 0) {
			lePlayState.songScore = value;
			lePlayState.RecalculateRating();
		});
		Lua_helper.add_callback(lua, "setMisses", function(value:Int = 0) {
			lePlayState.songMisses = value;
			lePlayState.RecalculateRating();
		});
		Lua_helper.add_callback(lua, "setHits", function(value:Int = 0) {
			lePlayState.songHits = value;
			lePlayState.RecalculateRating();
		});
		
		Lua_helper.add_callback(lua, "getColorFromHex", function(color:String) {
			if(!color.startsWith('0x')) color = '0xff' + color;
			return Std.parseInt(color);
		});
		Lua_helper.add_callback(lua, "keyJustPressed", function(name:String) {
			var key:Bool = false;
			switch(name) {
				case 'left': key = lePlayState.getControl('NOTE_LEFT_P');
				case 'down': key = lePlayState.getControl('NOTE_DOWN_P');
				case 'up': key = lePlayState.getControl('NOTE_UP_P');
				case 'right': key = lePlayState.getControl('NOTE_RIGHT_P');
				case 'accept': key = lePlayState.getControl('ACCEPT');
				case 'back': key = lePlayState.getControl('BACK');
				case 'pause': key = lePlayState.getControl('PAUSE');
				case 'reset': key = lePlayState.getControl('RESET');
			}
			return key;
		});
		Lua_helper.add_callback(lua, "keyPressed", function(name:String) {
			var key:Bool = false;
			switch(name) {
				case 'left': key = lePlayState.getControl('NOTE_LEFT');
				case 'down': key = lePlayState.getControl('NOTE_DOWN');
				case 'up': key = lePlayState.getControl('NOTE_UP');
				case 'right': key = lePlayState.getControl('NOTE_RIGHT');
			}
			return key;
		});
		Lua_helper.add_callback(lua, "keyReleased", function(name:String) {
			var key:Bool = false;
			switch(name) {
				case 'left': key = lePlayState.getControl('NOTE_LEFT_R');
				case 'down': key = lePlayState.getControl('NOTE_DOWN_R');
				case 'up': key = lePlayState.getControl('NOTE_UP_R');
				case 'right': key = lePlayState.getControl('NOTE_RIGHT_R');
			}
			return key;
		});
		Lua_helper.add_callback(lua, "addCharacterToList", function(name:String, type:String) {
			var charType:Int = 0;
			switch(type.toLowerCase()) {
				case 'dad': charType = 1;
				case 'gf' | 'girlfriend': charType = 2;
			}
			lePlayState.addCharacterToList(name, charType);
		});
		Lua_helper.add_callback(lua, "triggerEvent", function(name:String, arg1:Dynamic, arg2:Dynamic) {
			var value1:String = arg1;
			var value2:String = arg2;
			lePlayState.triggerEventNote(name, value1, value2);
			//trace('Triggered event: ' + name + ', ' + value1 + ', ' + value2);
		});
		Lua_helper.add_callback(lua, "playSound", function(sound:String, volume:Float = 1) {
			FlxG.sound.play(Paths.sound(sound), volume);
		});

		Lua_helper.add_callback(lua, "startCountdown", function(variable:String) {
			lePlayState.startCountdown();
		});
		Lua_helper.add_callback(lua, "getSongPosition", function() {
			return Conductor.songPosition;
		});

		Lua_helper.add_callback(lua, "getCharacterX", function(type:String) {
			switch(type.toLowerCase()) {
				case 'dad':
					return lePlayState.DAD_X;
				case 'gf' | 'girlfriend':
					return lePlayState.GF_X;
				default:
					return lePlayState.BF_X;
			}
		});
		Lua_helper.add_callback(lua, "setCharacterX", function(type:String, value:Float) {
			switch(type.toLowerCase()) {
				case 'dad':
					lePlayState.DAD_X = value;
					lePlayState.dadGroup.forEachAlive(function (char:Character) {
						char.x = lePlayState.DAD_X + char.positionArray[0];
					});
				case 'gf' | 'girlfriend':
					lePlayState.BF_X = value;
					lePlayState.boyfriendGroup.forEachAlive(function (char:Boyfriend) {
						char.x = lePlayState.BF_X + char.positionArray[0];
					});
				default:
					lePlayState.GF_X = value;
					lePlayState.gfGroup.forEachAlive(function (char:Character) {
						char.x = lePlayState.GF_X + char.positionArray[0];
					});
			}
		});
		Lua_helper.add_callback(lua, "getCharacterY", function(type:String) {
			switch(type.toLowerCase()) {
				case 'dad':
					return lePlayState.DAD_Y;
				case 'gf' | 'girlfriend':
					return lePlayState.GF_Y;
				default:
					return lePlayState.BF_Y;
			}
		});
		Lua_helper.add_callback(lua, "setCharacterY", function(type:String, value:Float) {
			switch(type.toLowerCase()) {
				case 'dad':
					lePlayState.DAD_Y = value;
					lePlayState.dadGroup.forEachAlive(function (char:Character) {
						char.y = lePlayState.DAD_Y + char.positionArray[1];
					});
				case 'gf' | 'girlfriend':
					lePlayState.GF_Y = value;
					lePlayState.gfGroup.forEachAlive(function (char:Character) {
						char.y = lePlayState.GF_Y + char.positionArray[1];
					});
				default:
					lePlayState.BF_Y = value;
					lePlayState.boyfriendGroup.forEachAlive(function (char:Boyfriend) {
						char.y = lePlayState.BF_Y + char.positionArray[1];
					});
			}
		});
		Lua_helper.add_callback(lua, "cameraSetTarget", function(target:String) {
			var isDad:Bool = false;
			if(target == 'dad') {
				isDad = true;
			}
			lePlayState.moveCamera(isDad);
		});
		Lua_helper.add_callback(lua, "setRatingPercent", function(value:Float) {
			lePlayState.ratingPercent = value;
		});
		Lua_helper.add_callback(lua, "setRatingString", function(value:String) {
			lePlayState.ratingString = value;
		});
		Lua_helper.add_callback(lua, "getMouseX", function(camera:String) {
			var cam:FlxCamera = cameraFromString(camera);
			return FlxG.mouse.getScreenPosition(cam).x;
		});
		Lua_helper.add_callback(lua, "getMouseY", function(camera:String) {
			var cam:FlxCamera = cameraFromString(camera);
			return FlxG.mouse.getScreenPosition(cam).y;
		});
		Lua_helper.add_callback(lua, "characterPlayAnim", function(character:String, anim:String, ?forced:Bool = false) {
			switch(character.toLowerCase()) {
				case 'dad':
					if(lePlayState.dad.animOffsets.exists(anim))
						lePlayState.dad.playAnim(anim, forced);
				case 'gf' | 'girlfriend':
					if(lePlayState.gf.animOffsets.exists(anim))
						lePlayState.gf.playAnim(anim, forced);
				default: 
					if(lePlayState.boyfriend.animOffsets.exists(anim))
						lePlayState.boyfriend.playAnim(anim, forced);
			}
		});
		Lua_helper.add_callback(lua, "characterDance", function(character:String) {
			switch(character.toLowerCase()) {
				case 'dad': lePlayState.dad.dance();
				case 'gf' | 'girlfriend': lePlayState.gf.dance();
				default: lePlayState.boyfriend.dance();
			}
		});

		Lua_helper.add_callback(lua, "makeLuaSprite", function(tag:String, image:String, x:Float, y:Float) {
			resetSpriteTag(tag);
			var leSprite:ModchartSprite = new ModchartSprite(x, y);
			if(image != null && image.length > 0) {
				leSprite.loadGraphic(Paths.image(image));
			}
			leSprite.antialiasing = ClientPrefs.globalAntialiasing;
			lePlayState.modchartSprites.set(tag, leSprite);
			leSprite.active = false;
		});
		Lua_helper.add_callback(lua, "luaSpriteMakeGraphic", function(tag:String, width:Int, height:Int, color:String) {
			if(lePlayState.modchartSprites.exists(tag)) {
				var colorNum:Int = Std.parseInt(color);
				if(!color.startsWith('0x')) colorNum = Std.parseInt('0xff' + color);

				lePlayState.modchartSprites.get(tag).makeGraphic(width, height, colorNum);
			}
		});
		Lua_helper.add_callback(lua, "makeAnimatedLuaSprite", function(tag:String, image:String, x:Float, y:Float) {
			resetSpriteTag(tag);
			var leSprite:ModchartSprite = new ModchartSprite(x, y);
			leSprite.frames = Paths.getSparrowAtlas(image);
			leSprite.antialiasing = ClientPrefs.globalAntialiasing;
			lePlayState.modchartSprites.set(tag, leSprite);
		});

		Lua_helper.add_callback(lua, "luaSpriteAddAnimationByPrefix", function(tag:String, name:String, prefix:String, framerate:Int = 24, loop:Bool = true) {
			if(lePlayState.modchartSprites.exists(tag)) {
				var cock:ModchartSprite = lePlayState.modchartSprites.get(tag);
				cock.animation.addByPrefix(name, prefix, framerate, loop);
				if(cock.animation.curAnim == null) {
					cock.animation.play(name, true);
				}
			}
		});
		Lua_helper.add_callback(lua, "luaSpriteAddAnimationByIndices", function(tag:String, name:String, prefix:String, indices:String, framerate:Int = 24) {
			if(lePlayState.modchartSprites.exists(tag)) {
				var strIndices:Array<String> = indices.trim().split(',');
				var die:Array<Int> = [];
				for (i in 0...strIndices.length) {
					die.push(Std.parseInt(strIndices[i]));
				}
				var pussy:ModchartSprite = lePlayState.modchartSprites.get(tag);
				pussy.animation.addByIndices(name, prefix, die, '', framerate, false);
				if(pussy.animation.curAnim == null) {
					pussy.animation.play(name, true);
				}
			}
		});
		Lua_helper.add_callback(lua, "luaSpritePlayAnimation", function(tag:String, name:String, forced:Bool = false) {
			if(lePlayState.modchartSprites.exists(tag)) {
				lePlayState.modchartSprites.get(tag).animation.play(name, forced);
			}
		});
		
		Lua_helper.add_callback(lua, "setLuaSpriteScrollFactor", function(tag:String, scrollX:Float, scrollY:Float) {
			if(lePlayState.modchartSprites.exists(tag)) {
				lePlayState.modchartSprites.get(tag).scrollFactor.set(scrollX, scrollY);
			}
		});
		Lua_helper.add_callback(lua, "addLuaSprite", function(tag:String, front:Bool = false) {
			if(lePlayState.modchartSprites.exists(tag)) {
				var shit:ModchartSprite = lePlayState.modchartSprites.get(tag);
				if(!shit.wasAdded) {
					if(front) {
						lePlayState.foregroundGroup.add(shit);
					} else {
						lePlayState.backgroundGroup.add(shit);
					}
					shit.isInFront = front;
					shit.wasAdded = true;
				}
			}
		});
		Lua_helper.add_callback(lua, "scaleLuaSprite", function(tag:String, x:Float, y:Float) {
			if(lePlayState.modchartSprites.exists(tag)) {
				var shit:ModchartSprite = lePlayState.modchartSprites.get(tag);
				shit.scale.set(x, y);
				shit.updateHitbox();
			}
		});
		Lua_helper.add_callback(lua, "removeLuaSprite", function(tag:String) {
			resetSpriteTag(tag);
		});

		Lua_helper.add_callback(lua, "getPropertyLuaSprite", function(tag:String, variable:String) {
			if(lePlayState.modchartSprites.exists(tag)) {
				var killMe:Array<String> = variable.split('.');
				if(killMe.length > 1) {
					var coverMeInPiss:Dynamic = Reflect.getProperty(lePlayState.modchartSprites.get(tag), killMe[0]);
					for (i in 1...killMe.length-1) {
						coverMeInPiss = Reflect.getProperty(coverMeInPiss, killMe[i]);
					}
					return Reflect.getProperty(coverMeInPiss, killMe[killMe.length-1]);
				}
				return Reflect.getProperty(lePlayState.modchartSprites.get(tag), variable);
			}
			luaTrace("Lua sprite with tag: " + tag + " doesn't exist!");
			return null;
		});
		Lua_helper.add_callback(lua, "setPropertyLuaSprite", function(tag:String, variable:String, value:Dynamic) {
			if(lePlayState.modchartSprites.exists(tag)) {
				var killMe:Array<String> = variable.split('.');
				if(killMe.length > 1) {
					var coverMeInPiss:Dynamic = Reflect.getProperty(lePlayState.modchartSprites.get(tag), killMe[0]);
					for (i in 1...killMe.length-1) {
						coverMeInPiss = Reflect.getProperty(coverMeInPiss, killMe[i]);
					}
					return Reflect.setProperty(coverMeInPiss, killMe[killMe.length-1], value);
				}
				return Reflect.setProperty(lePlayState.modchartSprites.get(tag), variable, value);
			}
			luaTrace("Lua sprite with tag: " + tag + " doesn't exist!");
		});
		Lua_helper.add_callback(lua, "setLuaSpriteCamera", function(tag:String, camera:String = '') {
			if(lePlayState.modchartSprites.exists(tag)) {
				lePlayState.modchartSprites.get(tag).cameras = [cameraFromString(camera)];
				return true;
			}
			luaTrace("Lua sprite with tag: " + tag + " doesn't exist!");
			return false;
		});
		Lua_helper.add_callback(lua, "startDialogue", function(dialogueFile:String, music:String = null) {
			var path:String = Paths.modsJson(Paths.formatToSongPath(PlayState.SONG.song) + '/' + dialogueFile);
			luaTrace('Trying to load dialogue: ' + path);

			if(FileSystem.exists(path)) {
				var shit:DialogueFile = DialogueBoxPsych.parseDialogue(path);
				if(shit.dialogue.length > 0) {
					lePlayState.startDialogue(shit, music);
					luaTrace('Successfully loaded dialogue');
				} else {
					luaTrace('Your dialogue file is badly formatted!');
				}
			} else {
				luaTrace('Dialogue file not found');
				lePlayState.startCountdown();
			}
		});
		Lua_helper.add_callback(lua, "startVideo", function(videoFile:String) {
			#if VIDEOS_ALLOWED
			if(FileSystem.exists(Paths.modsVideo(videoFile))) {
				lePlayState.videoIntro(videoFile);
			} else {
				luaTrace('Video file not found: ' + videoFile);
			}
			#else
			lePlayState.startCountdown();
			#end
		});

		Lua_helper.add_callback(lua, "musicFadeIn", function(duration:Float, fromValue:Float = 0, toValue:Float = 1) {
			FlxG.sound.music.fadeIn(duration, fromValue, toValue);
		});
		Lua_helper.add_callback(lua, "musicFadeOut", function(duration:Float, toValue:Float = 0) {
			FlxG.sound.music.fadeOut(duration, toValue);
		});

		Lua_helper.add_callback(lua, "debugPrint", function(text:String) {
			luaTrace(text, true, false);
		});
		Lua_helper.add_callback(lua, "close", function(printMessage:Bool) {
			if(!gonnaClose) {
				if(printMessage) {
					luaTrace('Stopping lua script in 100ms: ' + scriptName);
				}
				var leTimer:FlxTimer = new FlxTimer().start(0.1, function(tmr:FlxTimer) {
					stop();
				});
			}
			gonnaClose = true;
		});
		call('onCreate', []);
		#end
	}

	function resetSpriteTag(tag:String) {
		if(!lePlayState.modchartSprites.exists(tag)) {
			return;
		}
		
		var pee:ModchartSprite = lePlayState.modchartSprites.get(tag);
		pee.kill();
		if(pee.wasAdded) {
			if(pee.isInFront) {
				lePlayState.foregroundGroup.remove(pee, true);
			} else {
				lePlayState.backgroundGroup.remove(pee, true);
			}
		}
		pee.destroy();
		lePlayState.modchartSprites.remove(tag);
	}

	function cancelTween(tag:String) {
		if(lePlayState.modchartTweens.exists(tag)) {
			lePlayState.modchartTweens.get(tag).cancel();
			lePlayState.modchartTweens.get(tag).destroy();
			lePlayState.modchartTweens.remove(tag);
		}
	}

	function tweenShit(tag:String, vars:String) {
		cancelTween(tag);
		var variables:Array<String> = vars.replace(' ', '').split('.');
		var sexyProp:Dynamic = Reflect.getProperty(lePlayState, variables[0]);
		if(sexyProp == null && lePlayState.modchartSprites.exists(variables[0])) {
			sexyProp = lePlayState.modchartSprites.get(variables[0]);
		}

		for (i in 1...variables.length) {
			sexyProp = Reflect.getProperty(sexyProp, variables[i]);
		}
		return sexyProp;
	}

	function cancelTimer(tag:String) {
		if(lePlayState.modchartTimers.exists(tag)) {
			var theTimer:FlxTimer = lePlayState.modchartTimers.get(tag);
			theTimer.cancel();
			theTimer.destroy();
			lePlayState.modchartTimers.remove(tag);
		}
	}

	//Better optimized than using some getProperty shit or idk
	function getFlxEaseByString(?ease:String = '') {
		switch(ease.toLowerCase()) {
			case 'backin': return FlxEase.backIn;
			case 'backinout': return FlxEase.backInOut;
			case 'backout': return FlxEase.backOut;
			case 'bouncein': return FlxEase.bounceIn;
			case 'bounceinout': return FlxEase.bounceInOut;
			case 'bounceout': return FlxEase.bounceOut;
			case 'circin': return FlxEase.circIn;
			case 'circinout': return FlxEase.circInOut;
			case 'circout': return FlxEase.circOut;
			case 'cubein': return FlxEase.cubeIn;
			case 'cubeinout': return FlxEase.cubeInOut;
			case 'cubeout': return FlxEase.cubeOut;
			case 'elasticin': return FlxEase.elasticIn;
			case 'elasticinout': return FlxEase.elasticInOut;
			case 'elasticout': return FlxEase.elasticOut;
			case 'expoin': return FlxEase.expoIn;
			case 'expoinout': return FlxEase.expoInOut;
			case 'expoout': return FlxEase.expoOut;
			case 'quadin': return FlxEase.quadIn;
			case 'quadinout': return FlxEase.quadInOut;
			case 'quadout': return FlxEase.quadOut;
			case 'quartin': return FlxEase.quartIn;
			case 'quartinout': return FlxEase.quartInOut;
			case 'quartout': return FlxEase.quartOut;
			case 'quintin': return FlxEase.quintIn;
			case 'quintinout': return FlxEase.quintInOut;
			case 'quintout': return FlxEase.quintOut;
			case 'sinein': return FlxEase.sineIn;
			case 'sineinout': return FlxEase.sineInOut;
			case 'sineout': return FlxEase.sineOut;
			case 'smoothstepin': return FlxEase.smoothStepIn;
			case 'smoothstepinout': return FlxEase.smoothStepInOut;
			case 'smoothstepout': return FlxEase.smoothStepInOut;
			case 'smootherstepin': return FlxEase.smootherStepIn;
			case 'smootherstepinout': return FlxEase.smootherStepInOut;
			case 'smootherstepout': return FlxEase.smootherStepOut;
		}
		return FlxEase.linear;
	}

	function cameraFromString(cam:String):FlxCamera {
		switch(cam.toLowerCase()) {
			case 'camhud' | 'hud': return lePlayState.camHUD;
			case 'camother' | 'other': return lePlayState.camOther;
		}
		return lePlayState.camGame;
	}

	public function luaTrace(text:String, ignoreCheck:Bool = false, deprecated:Bool = false) {
		#if LUA_ALLOWED
		if(ignoreCheck || getBool('luaDebugMode')) {
			if(deprecated && !getBool('luaDeprecatedWarnings')) {
				return;
			}
			lePlayState.addTextToDebug(text);
			trace(text);
		}
		#end
	}
	
	public function call(event:String, args:Array<Dynamic>):Dynamic {
		#if LUA_ALLOWED
		if(lua == null) {
			return Function_Continue;
		}

		Lua.getglobal(lua, event);

		for (arg in args) {
			Convert.toLua(lua, arg);
		}

		var result:Null<Int> = Lua.pcall(lua, args.length, 1, 0);
		if(result != null && resultIsAllowed(lua, result)) {
			/*var resultStr:String = Lua.tostring(lua, result);
			var error:String = Lua.tostring(lua, -1);
			Lua.pop(lua, 1);*/
			if(Lua.type(lua, -1) == Lua.LUA_TSTRING) {
				var error:String = Lua.tostring(lua, -1);
				if(error == 'attempt to call a nil value') { //Makes it ignore warnings and not break stuff if you didn't put the functions on your lua file
					return Function_Continue;
				}
			}
			var conv:Dynamic = Convert.fromLua(lua, result);
			//Lua.pop(lua, 1);
			return conv;
		}
		#end
		return Function_Continue;
	}

	#if LUA_ALLOWED
	function resultIsAllowed(leLua:State, leResult:Null<Int>) { //Makes it ignore warnings
		switch(Lua.type(leLua, leResult)) {
			case Lua.LUA_TNIL | Lua.LUA_TBOOLEAN | Lua.LUA_TNUMBER | Lua.LUA_TSTRING | Lua.LUA_TTABLE:
				return true;
		}
		return false;
	}
	#end

	public function set(variable:String, data:Dynamic) {
		#if LUA_ALLOWED
		if(lua == null) {
			return;
		}

		Convert.toLua(lua, data);
		Lua.setglobal(lua, variable);
		#end
	}

	#if LUA_ALLOWED
	public function getBool(variable:String) {
		var result:String = null;
		Lua.getglobal(lua, variable);
		result = Convert.fromLua(lua, -1);
		Lua.pop(lua, 1);

		if(result == null) {
			return false;
		}

		// YES! FINALLY IT WORKS
		//trace('variable: ' + variable + ', ' + result);
		return (result == 'true');
	}
	#end

	public function stop() {
		#if LUA_ALLOWED
		if(lua == null) {
			return;
		}

		if(accessedProps != null) {
			accessedProps.clear();
		}
		lePlayState.removeLua(this);
		Lua.close(lua);
		lua = null;
		#end
	}
}

class ModchartSprite extends FlxSprite
{
	public var wasAdded:Bool = false;
	public var isInFront:Bool = false;
}

class DebugLuaText extends FlxText
{
	private var disableTime:Float = 6;
	public var parentGroup:FlxTypedGroup<DebugLuaText>; 
	public function new(text:String, parentGroup:FlxTypedGroup<DebugLuaText>) {
		this.parentGroup = parentGroup;
		super(10, 10, 0, text, 16);
		setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		scrollFactor.set();
		borderSize = 1;
	}

	override function update(elapsed:Float) {
		super.update(elapsed);
		disableTime -= elapsed;
		if(disableTime <= 0) {
			kill();
			parentGroup.remove(this);
			destroy();
		}
		else if(disableTime < 1) alpha = disableTime;
	}
}