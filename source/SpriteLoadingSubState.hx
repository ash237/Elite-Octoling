package;

import flixel.util.typeLimit.OneOfTwo;
import flixel.util.FlxTimer;
import flixel.util.FlxSignal;
import flixel.FlxState;
import flixel.util.typeLimit.OneOfFour;
import flixel.math.FlxPoint;
import flixel.util.typeLimit.OneOfThree;
import flixel.system.FlxAssets.FlxGraphicAsset;
import haxe.macro.Type.AbstractType;
import flixel.FlxObject;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.addons.transition.FlxTransitionableState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.input.keyboard.FlxKey;
import flixel.system.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
// import notifier.Notifier;

/**
    TODO:
      - ACTUAL FRONTEND
      - IMPLEMENT BG SPRITE RENDER (X)
      - TIDY UP CODE
      - ADD WAY TO GET SPRITE REFERENCE IN PLAYSTATE (FOR ANIMATIONS)
      - lmao idk what else i really gotta piss rn so yeah ill finish this tomorrow
**/

class SpriteLoadingSubState extends FlxSubState {
    private var _objects:Array<ObjectProperties> = [];
    private var _parent:Dynamic;
    private var _loaded:Map<Int, Bool>;
    private var _callback:Void->Void;

    private var started:Bool = false;
    private var doneLoading:FlxTypedSignal<Bool->Void>;

    private var darkShit:FlxSprite;

    private static var lastLoadedID:FlxTypedSignal<Int->Void>;
    public static var spriteLoadedCallbacks:Map<String, Dynamic->Void> = [
        "test" => function(obj:Dynamic):Void {
            trace("Test sprite callback!");
        }, "addToSpecialChars" => function(obj:Dynamic):Void {
            PlayState.specialCharacters.set(obj.ID, obj); 
        }
    ];

    override function create() {

        super.create();
    }

    private function startLoading() {
        darkShit = new FlxSprite(0, 0).makeGraphic(1280, 720, FlxColor.BLACK);
        darkShit.alpha = 0.6;
        add(darkShit);

        started = true;
        startLoadingObject(_objects[0]);
    }

    private function onSpriteLoaded(id:Int = -1) {
        _loaded.set(id, true);
        checkIfDone();

        for (i in 0..._objects.length) {
            var obj = _objects[i];
            if (!( _loaded.exists(obj.id) )) {
                startLoadingObject(obj);
                return;
            }
        }
    }

    private function checkIfDone() {
        var done = true;

        for (i in _objects) {
            if (!(_loaded.exists(i.id))) {
                trace (i.id + " is not loaded!");
                done = false;
            }
        }

        trace("done? " + (done ? "yes" : "no"));
        if (done) loadingComplete();
    }

    private function loadingComplete() {
        trace("Done loading!");
    
        new FlxTimer().start(2, function(t:FlxTimer) {
            if (_callback != null) _callback();
            this.close();
        });
    }

    private function startLoadingObject(obj:ObjectProperties) {
        trace("Test loading sequence! Loaded obj with id: " + obj.id);

        var res:Dynamic = ObjectPropertyManager.parseProperties(obj);
            _parent.add(res);

        // TODO: ACTUALLY MAKE THE SPRITES. THIS SHOULD GO EASILY.
    }

    public function setToLoadObjects(objects:Array<ObjectProperties>) {
        this._objects = objects;
    }

    public function setCallback(callback:Void->Void) {
        this._callback = callback;
    }

    public function init(curState:FlxStateTypes) {
        _loaded = new Map<Int, Bool>();

        lastLoadedID = new FlxTypedSignal<Int->Void>();
        lastLoadedID.add((val:Int) -> {
            this.onSpriteLoaded(val);
        });

        _parent = curState;

        trace("Loading");
        startLoading();
    }

    public static function spriteLoaded(id:Int = -1) {
        lastLoadedID.dispatch(id);
    }
}

class ObjectPropertyManager {
    public static function jsonToProperties(jsonPath:String) {
        // TODO: add this later cuz lazy rn
    }

    public static function parseProperties(obj:ObjectProperties):Dynamic {
        var res:Dynamic = 0;
        var pos = parsePosition(obj.position);

        var _onLoad = () -> { SpriteLoadingSubState.spriteLoaded(obj.id); }
        if (obj.onLoad != null) _onLoad = obj.onLoad;
        
        if (obj.isCharacter != null) {
            if (obj.isCharacter) {
                res = new Character(pos.x, pos.y, obj.character, obj.isPlayer, false);
                res.setLoadedCallback(_onLoad);
                obj.res = res;
                res.loadCharacter();
            } else {
                // FileSystem.absolutePath(relPath:String) : Get absolute path;
                var animationArray:Array<String> = null;
                var scf:FlxPoint = new FlxPoint(1, 1);
                if (obj.properties.scrollFactor != null) scf = parsePosition(obj.properties.scrollFactor);
                if (obj.properties != null) {
                    if (obj.properties.animations != null) animationArray = cast obj.properties.animations;
                }

                res = new BGSprite(obj.path, pos.x, pos.y, scf.x, scf.y, animationArray, false, _onLoad);
                res.setLoadedCallback(_onLoad);
                obj.res = res;
                res.loadBGSpriteGraphic();
            }
        } else {
            // FileSystem.absolutePath(relPath:String) : Get absolute path;
            var animationArray:Array<String> = null;
            var scf:FlxPoint = new FlxPoint(1, 1);
            if (obj.properties.scrollFactor != null) scf = parsePosition(obj.properties.scrollFactor);
            if (obj.properties != null) {
                if (obj.properties.animations != null) animationArray = cast obj.properties.animations;
            }

            res = new BGSprite(obj.path, pos.x, pos.y, scf.x, scf.y, animationArray, false, _onLoad);
            res.setLoadedCallback(_onLoad);
            obj.res = res;
            res.loadBGSpriteGraphic();
        }

        res.ID = obj.id;
        return res;
    }

    public static function parsePosition(pos:ObjectPosition):FlxPoint {
        var res:FlxPoint = new FlxPoint();
        var type = Std.string($type(pos));

        switch (type) {
            case "FlxPoint":
                res = pos;
            default:
                res.x = pos[0];
                res.y = pos[1];
        }

        trace(res);
        
        return res;
    }
}

typedef FlxStateTypes = OneOfFour<FlxState, FlxSubState, MusicBeatState, MusicBeatSubstate>;
typedef ObjectPosition = OneOfThree<FlxPoint, Array<Float>, Array<Int>>;
typedef ObjectProperties = {
    // Type (Sprite, object, etc.) in string form
	@:optional var type:String;

	// Position (FlxPoint, Array<Float>)
	@:optional var position:ObjectPosition;

	// path (String)
	@:optional var path:String;

	// Function to run when graphic is loaded
	@:optional var onLoad:Void->Void;

    // Identification.
    @:optional var id:Int;

    // CHARACTER CONDITIONS
    @:optional var isPlayer:Bool; // Whether or not new Character is player.
    @:optional var isCharacter:Bool; // Whether or not new object is Character.
    @:optional var character:String; // Name of the character; only used if isCharacter is true.

    // PROPERTIES
    @:optional var properties:ObjectPropertyData;

    // RESULT : DON'T MODIFY
    @:optional var res:OneOfTwo<BGSprite, Character>;
}

typedef ObjectPropertyData = {
    // Animations (Strings, names)
    @:optional var animations:Array<String>;

    // Scroll Factor
    @:optional var scrollFactor:ObjectPosition;

    // Callback choice (string, hardcoded)
    @:optional var doAfter:String;
}