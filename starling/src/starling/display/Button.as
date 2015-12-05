// =================================================================================================
//
//	Starling Framework
//	Copyright 2011-2015 Gamua. All Rights Reserved.
//
//	This program is free software. You can redistribute and/or modify it
//	in accordance with the terms of the accompanying license agreement.
//
// =================================================================================================

package starling.display
{
    import flash.geom.Rectangle;
    import flash.ui.Mouse;
    import flash.ui.MouseCursor;
    
    import starling.events.Event;
    import starling.events.Touch;
    import starling.events.TouchEvent;
    import starling.events.TouchPhase;
    import starling.text.TextField;
    import starling.textures.Texture;
    import starling.utils.HAlign;
    import starling.utils.VAlign;

    /** Dispatched when the user triggers the button. Bubbles. */
    [Event(name="triggered", type="starling.events.Event")]
    
    /** A simple button composed of an image and, optionally, text.
     *  
     *  <p>You can use different textures for various states of the button. If you're providing
     *  only an up state, the button is simply scaled a little when it is touched.</p>
     *
     *  <p>In addition, you can overlay text on the button. To customize the text, you can use
     *  properties equivalent to those of the TextField class. Move the text to a certain position
     *  by updating the <code>textBounds</code> property.</p>
     *  
     *  <p>To react on touches on a button, there is special <code>Event.TRIGGERED</code> event.
     *  Use this event instead of normal touch events. That way, users can cancel button
     *  activation by moving the mouse/finger away from the button before releasing.</p>
     */
    public class Button extends DisplayObjectContainer
    {
        private static const MAX_DRAG_DIST:Number = 50;
        
        private var _upState:Texture;
        private var _downState:Texture;
        private var _overState:Texture;
        private var _disabledState:Texture;
        
        private var _contents:Sprite;
        private var _body:Image;
        private var _textField:TextField;
        private var _textBounds:Rectangle;
        private var _overlay:Sprite;
        
        private var _scaleWhenDown:Number;
        private var _scaleWhenOver:Number;
        private var _alphaWhenDown:Number;
        private var _alphaWhenDisabled:Number;
        private var _useHandCursor:Boolean;
        private var _enabled:Boolean;
        private var _state:String;
        private var _triggerBounds:Rectangle;

        /** Creates a button with a set of state-textures and (optionally) some text.
         *  Any state that is left 'null' will display the up-state texture. Beware that all
         *  state textures should have the same dimensions. */
        public function Button(upState:Texture, text:String="", downState:Texture=null,
                               overState:Texture=null, disabledState:Texture=null)
        {
            if (upState == null) throw new ArgumentError("Texture 'upState' cannot be null");
            
            _upState = upState;
            _downState = downState;
            _overState = overState;
            _disabledState = disabledState;

            _state = ButtonState.UP;
            _body = new Image(upState);
            _scaleWhenDown = downState ? 1.0 : 0.9;
            _scaleWhenOver = _alphaWhenDown = 1.0;
            _alphaWhenDisabled = disabledState ? 1.0: 0.5;
            _enabled = true;
            _useHandCursor = true;
            _textBounds = new Rectangle(0, 0, _body.width, _body.height);
            _triggerBounds = new Rectangle();
            
            _contents = new Sprite();
            _contents.addChild(_body);
            addChild(_contents);
            addEventListener(TouchEvent.TOUCH, onTouch);
            
            this.touchGroup = true;
            this.text = text;
        }
        
        /** @inheritDoc */
        public override function dispose():void
        {
            // text field might be disconnected from parent, so we have to dispose it manually
            if (_textField)
                _textField.dispose();
            
            super.dispose();
        }
        
        /** Readjusts the dimensions of the button according to its current state texture.
         *  Call this method to synchronize button and texture size after assigning a texture
         *  with a different size. Per default, this method also resets the bounds of the
         *  button's text. */
        public function readjustSize(resetTextBounds:Boolean=true):void
        {
            _body.readjustSize();

            if (resetTextBounds && _textField != null)
                textBounds = new Rectangle(0, 0, _body.width, _body.height);
        }

        private function createTextField():void
        {
            if (_textField == null)
            {
                _textField = new TextField(_textBounds.width, _textBounds.height, "");
                _textField.vAlign = VAlign.CENTER;
                _textField.hAlign = HAlign.CENTER;
                _textField.touchable = false;
                _textField.autoScale = true;
                _textField.batchable = true;
            }
            
            _textField.width  = _textBounds.width;
            _textField.height = _textBounds.height;
            _textField.x = _textBounds.x;
            _textField.y = _textBounds.y;
        }
        
        private function onTouch(event:TouchEvent):void
        {
            Mouse.cursor = (_useHandCursor && _enabled && event.interactsWith(this)) ?
                MouseCursor.BUTTON : MouseCursor.AUTO;
            
            var touch:Touch = event.getTouch(this);
            var isWithinBounds:Boolean;

            if (!_enabled)
            {
                return;
            }
            else if (touch == null)
            {
                state = ButtonState.UP;
            }
            else if (touch.phase == TouchPhase.HOVER)
            {
                state = ButtonState.OVER;
            }
            else if (touch.phase == TouchPhase.BEGAN && _state != ButtonState.DOWN)
            {
                _triggerBounds = getBounds(stage, _triggerBounds);
                _triggerBounds.inflate(MAX_DRAG_DIST, MAX_DRAG_DIST);

                state = ButtonState.DOWN;
            }
            else if (touch.phase == TouchPhase.MOVED)
            {
                isWithinBounds = _triggerBounds.contains(touch.globalX, touch.globalY);

                if (_state == ButtonState.DOWN && !isWithinBounds)
                {
                    // reset button when finger is moved too far away ...
                    state = ButtonState.UP;
                }
                else if (_state == ButtonState.UP && isWithinBounds)
                {
                    // ... and reactivate when the finger moves back into the bounds.
                    state = ButtonState.DOWN;
                }
            }
            else if (touch.phase == TouchPhase.ENDED && _state == ButtonState.DOWN)
            {
                state = ButtonState.UP;
                if (!touch.cancelled) dispatchEventWith(Event.TRIGGERED, true);
            }
        }
        
        /** The current state of the button. The corresponding strings are found
         *  in the ButtonState class. */
        public function get state():String { return _state; }
        public function set state(value:String):void
        {
            _state = value;
            _contents.x = _contents.y = 0;
            _contents.scaleX = _contents.scaleY = _contents.alpha = 1.0;

            switch (_state)
            {
                case ButtonState.DOWN:
                    setStateTexture(_downState);
                    _contents.alpha = _alphaWhenDown;
                    _contents.scaleX = _contents.scaleY = _scaleWhenDown;
                    _contents.x = (1.0 - _scaleWhenDown) / 2.0 * _body.width;
                    _contents.y = (1.0 - _scaleWhenDown) / 2.0 * _body.height;
                    break;
                case ButtonState.UP:
                    setStateTexture(_upState);
                    break;
                case ButtonState.OVER:
                    setStateTexture(_overState);
                    _contents.scaleX = _contents.scaleY = _scaleWhenOver;
                    _contents.x = (1.0 - _scaleWhenOver) / 2.0 * _body.width;
                    _contents.y = (1.0 - _scaleWhenOver) / 2.0 * _body.height;
                    break;
                case ButtonState.DISABLED:
                    setStateTexture(_disabledState);
                    _contents.alpha = _alphaWhenDisabled;
                    break;
                default:
                    throw new ArgumentError("Invalid button state: " + _state);
            }
        }

        private function setStateTexture(texture:Texture):void
        {
            _body.texture = texture ? texture : _upState;
        }

        /** The scale factor of the button on touch. Per default, a button without a down state
         *  texture will be made slightly smaller, while a button with a down state texture
         *  remains unscaled. */
        public function get scaleWhenDown():Number { return _scaleWhenDown; }
        public function set scaleWhenDown(value:Number):void { _scaleWhenDown = value; }

        /** The scale factor of the button while the mouse cursor hovers over it. @default 1.0 */
        public function get scaleWhenOver():Number { return _scaleWhenOver; }
        public function set scaleWhenOver(value:Number):void { _scaleWhenOver = value; }

        /** The alpha value of the button on touch. @default 1.0 */
        public function get alphaWhenDown():Number { return _alphaWhenDown; }
        public function set alphaWhenDown(value:Number):void { _alphaWhenDown = value; }

        /** The alpha value of the button when it is disabled. @default 0.5 */
        public function get alphaWhenDisabled():Number { return _alphaWhenDisabled; }
        public function set alphaWhenDisabled(value:Number):void { _alphaWhenDisabled = value; }
        
        /** Indicates if the button can be triggered. */
        public function get enabled():Boolean { return _enabled; }
        public function set enabled(value:Boolean):void
        {
            if (_enabled != value)
            {
                _enabled = value;
                state = value ? ButtonState.UP : ButtonState.DISABLED;
            }
        }
        
        /** The text that is displayed on the button. */
        public function get text():String { return _textField ? _textField.text : ""; }
        public function set text(value:String):void
        {
            if (value.length == 0)
            {
                if (_textField)
                {
                    _textField.text = value;
                    _textField.removeFromParent();
                }
            }
            else
            {
                createTextField();
                _textField.text = value;
                
                if (_textField.parent == null)
                    _contents.addChild(_textField);
            }
        }
        
        /** The name of the font displayed on the button. May be a system font or a registered
         *  bitmap font. */
        public function get fontName():String { return _textField ? _textField.fontName : "Verdana"; }
        public function set fontName(value:String):void
        {
            createTextField();
            _textField.fontName = value;
        }
        
        /** The size of the font. */
        public function get fontSize():Number { return _textField ? _textField.fontSize : 12; }
        public function set fontSize(value:Number):void
        {
            createTextField();
            _textField.fontSize = value;
        }
        
        /** The color of the font. */
        public function get fontColor():uint { return _textField ? _textField.color : 0x0; }
        public function set fontColor(value:uint):void
        {
            createTextField();
            _textField.color = value;
        }
        
        /** Indicates if the font should be bold. */
        public function get fontBold():Boolean { return _textField ? _textField.bold : false; }
        public function set fontBold(value:Boolean):void
        {
            createTextField();
            _textField.bold = value;
        }
        
        /** The texture that is displayed when the button is not being touched. */
        public function get upState():Texture { return _upState; }
        public function set upState(value:Texture):void
        {
            if (value == null)
                throw new ArgumentError("Texture 'upState' cannot be null");

            if (_upState != value)
            {
                _upState = value;
                if ( _state == ButtonState.UP ||
                    (_state == ButtonState.DISABLED && _disabledState == null) ||
                    (_state == ButtonState.DOWN && _downState == null) ||
                    (_state == ButtonState.OVER && _overState == null))
                {
                    setStateTexture(value);
                }
            }
        }
        
        /** The texture that is displayed while the button is touched. */
        public function get downState():Texture { return _downState; }
        public function set downState(value:Texture):void
        {
            if (_downState != value)
            {
                _downState = value;
                if (_state == ButtonState.DOWN) setStateTexture(value);
            }
        }

        /** The texture that is displayed while mouse hovers over the button. */
        public function get overState():Texture { return _overState; }
        public function set overState(value:Texture):void
        {
            if (_overState != value)
            {
                _overState = value;
                if (_state == ButtonState.OVER) setStateTexture(value);
            }
        }

        /** The texture that is displayed when the button is disabled. */
        public function get disabledState():Texture { return _disabledState; }
        public function set disabledState(value:Texture):void
        {
            if (_disabledState != value)
            {
                _disabledState = value;
                if (_state == ButtonState.DISABLED) setStateTexture(value);
            }
        }
        
        /** The vertical alignment of the text on the button. */
        public function get textVAlign():String
        {
            return _textField ? _textField.vAlign : VAlign.CENTER;
        }
        
        public function set textVAlign(value:String):void
        {
            createTextField();
            _textField.vAlign = value;
        }
        
        /** The horizontal alignment of the text on the button. */
        public function get textHAlign():String
        {
            return _textField ? _textField.hAlign : HAlign.CENTER;
        }
        
        public function set textHAlign(value:String):void
        {
            createTextField();
            _textField.hAlign = value;
        }
        
        /** The bounds of the textfield on the button. Allows moving the text to a custom position. */
        public function get textBounds():Rectangle { return _textBounds.clone(); }
        public function set textBounds(value:Rectangle):void
        {
            _textBounds = value.clone();
            createTextField();
        }
        
        /** The color of the button's state image. Just like every image object, each pixel's
         *  color is multiplied with this value. @default white */
        public function get color():uint { return _body.color; }
        public function set color(value:uint):void { _body.color = value; }

        /** The overlay sprite is displayed on top of the button contents. It scales with the
         *  button when pressed. Use it to add additional objects to the button (e.g. an icon). */
        public function get overlay():Sprite
        {
            if (_overlay == null)
                _overlay = new Sprite();

            _contents.addChild(_overlay); // make sure it's always on top
            return _overlay;
        }

        /** Indicates if the mouse cursor should transform into a hand while it's over the button. 
         *  @default true */
        public override function get useHandCursor():Boolean { return _useHandCursor; }
        public override function set useHandCursor(value:Boolean):void { _useHandCursor = value; }
    }
}