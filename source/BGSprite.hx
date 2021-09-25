package;

import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;

class BGSprite extends FlxSprite
{
	private var idleAnim:String;
	private var graphicLoadedCallback:Void->Void;
	private var animArray:Array<String>;
	private var image:String;
	private var loop:Bool;
	public function new(image:String, x:Float = 0, y:Float = 0, ?scrollX:Float = 1, ?scrollY:Float = 1, ?animArray:Array<String> = null, ?loop:Bool = false, ?GLCallback:Void->Void = null, ?halt:Bool = false) {
		super(x, y);

		this.animArray = animArray;
		this.image = image;
		this.loop = loop;
		scrollFactor.set(scrollX, scrollY);
		
		if (!halt) {
			loadBGSpriteGraphic();
		}

		scrollFactor.set(scrollX, scrollY);
		//antialiasing = ClientPrefs.globalAntialiasing;

		graphicLoadedCallback = GLCallback;
	}
	
	public function loadBGSpriteGraphic():Void {
		if (animArray != null) {
			frames = Paths.getSparrowAtlas(image);
			for (i in 0...animArray.length) {
				var anim:String = animArray[i];
				animation.addByPrefix(anim, anim, 24, loop);
				if(idleAnim == null) {
					idleAnim = anim;
					animation.play(anim);
				}
			}
		} else {
			if(image != null) {
				loadGraphic(Paths.image(image));
			}
			active = false;
		}
	}

	public function setLoadedCallback(?GLCallback:Void->Void = null) {
		try { graphicLoadedCallback = GLCallback; } catch(e) {}
	}

	public function dance(?forceplay:Bool = false) {
		if(idleAnim != null) {
			animation.play(idleAnim, forceplay);
		}
	}

	public function setIdle(idle:String) {
		idleAnim = idle;
		dance();
	}

	override function graphicLoaded():Void {
		if (graphicLoadedCallback != null) graphicLoadedCallback();
	}
}