//
// Whack-A-Potato
//
// Loom Game Engine Whack-A-Mole demo modified to work with Makey Makey.
//
// http://bluntbody.com/whack-a-potato/

package
{
    import loom.Application;    
    import loom.platform.Timer;
    import loom.animation.LoomTween;
    import loom.animation.LoomEaseType;
    import loom2d.display.StageScaleMode;
    import loom2d.display.Image;        
    import loom2d.textures.Texture;
    import loom2d.ui.SimpleLabel;
    import loom2d.events.KeyboardEvent;
    import loom.platform.LoomKey;
    import cocos2d.Cocos2D;

    import cocosdenshion.SimpleAudioEngine;

    import loom2d.events.TouchEvent;
    import loom2d.events.TouchPhase;

    import system.Process;

    public class WhackAMole extends Application
    {
        // Duration of a single game.
        protected const GAME_TIME_SECS = 30;

        // Max number of strikes (misses) allowed.
        protected const MAX_STRIKES = 3;

        // Number of points for a hit.
        protected const HIT_POINTS = 100;

        // Number of points for a miss.
        protected const MISS_POINTS = 5;

        // Amount of time that a mole initially remains up for (seconds).
        // This reduces as moles are whacked during the game.
        protected const INITIAL_MOLE_UP_TIME = 3.0;

        // Amount of time between timer ticks (seconds).
        // This reduces as moles are whacked during the game.
        // On each timer tick a decision is made whether to
        // pop up each of the moles.
        protected const INITIAL_TIMER_PERIOD = 1.5;

        protected var timer:Timer;
        protected var moles:Vector.<Image>;
        protected var moleStates:Vector.<Boolean>;
        protected var scores:Vector.<SimpleLabel>;
        protected var misses:Vector.<SimpleLabel>;
        protected var waitTime:Number;
        protected var totalScore:SimpleLabel;
        protected var total:Number;
        protected var strikes:Number;
        protected var gameOverLabel:Image;
        protected var timeLabel:SimpleLabel;
        protected var gameTimer:Timer;
        protected var timeLastHealthWarning:Number;
        protected var moleUpY:Number;
        protected var moleDownY:Number;
        protected var missY:Number;
        protected var scoreY:Number;

        override public function run():void
        {
            stage.scaleMode = StageScaleMode.FILL;

            var screenWidth = stage.stageWidth;
            var screenHeight = stage.stageHeight;            
         
            waitTime = INITIAL_MOLE_UP_TIME;
            strikes = 0;
            timeLastHealthWarning = 0;

            moleUpY = screenHeight * 9 / 20;
            moleDownY = screenHeight * 3 / 4;
            scoreY = screenHeight * 3 / 10;

            missY = screenHeight * 4 / 10;

            var ground = new Image(Texture.fromAsset("assets/background/bg_dirt.png"));
            ground.x = 0;
            ground.y = 0;
            ground.touchable = false;
            stage.addChild(ground);

            var top = new Image(Texture.fromAsset("assets/foreground/grass_upper.png"));
            top.x = 0;
            top.y = 0;
            top.height = screenHeight / 2;
            top.width = screenWidth;
            top.touchable = false;
            stage.addChild(top);

            moles = new Vector.<Image>();

            for (var mole_id = 0; mole_id < 3; mole_id++)
            {
                var mole = new Image(Texture.fromAsset("assets/sprites/mole_" + (mole_id + 1) + ".png"));
                mole.x = screenWidth * (2 + (mole_id * 3))/ 10;
                mole.y = moleDownY;
                mole.center();
                mole.scale = 0.5;
                stage.addChild(mole);

                mole.addEventListener(TouchEvent.TOUCH, function(e:TouchEvent) { 
                    if (e.getTouch(mole, TouchPhase.BEGAN)) {                    
                        whackMole(e, mole); 
                    }
                });            

                moles.push(mole);
            }

            moleStates = [false, false, false];

            var bottom = new Image(Texture.fromAsset("assets/foreground/grass_lower.png"));
            bottom.x = 0;
            bottom.y = screenHeight / 2;
            bottom.width = screenWidth;
            bottom.height = screenHeight / 2;
            bottom.touchable = false; 
            stage.addChild(bottom);

            total = 0;
            totalScore = new SimpleLabel("assets/fonts/Curse-hd.fnt");
            totalScore.text = "0";
            totalScore.x = screenWidth/2;
            totalScore.y = (screenHeight * 3 / 4);
            totalScore.touchable = false;
            totalScore.center();
            totalScore.scale = 0.5;
            stage.addChild(totalScore);

            gameOverLabel = new Image(Texture.fromAsset("assets/labels/gameover.png"));
            gameOverLabel.x = screenWidth / 2;
            gameOverLabel.y = screenHeight / 4;
            gameOverLabel.center();
            gameOverLabel.scale = 0.5;

            gameOverLabel.addEventListener(TouchEvent.TOUCH, function(e:TouchEvent) { 
                if (e.getTouch(gameOverLabel, TouchPhase.BEGAN))
                {
                    resetGame();
                    e.stopImmediatePropagation();
                }
            });

            timeLabel = new SimpleLabel("assets/fonts/Curse-hd.fnt");
            timeLabel.text = "30";
            timeLabel.x = screenWidth - timeLabel.size.x;
            timeLabel.y = 16;
            timeLabel.scale = 0.5;
            timeLabel.touchable = false;
            stage.addChild(timeLabel);

            gameTimer = new Timer(GAME_TIME_SECS * 1000);
            gameTimer.onComplete = endGame;
            gameTimer.start();

            gameTimer.onComplete = endGame;
            gameTimer.start();

            timer = new Timer(INITIAL_TIMER_PERIOD);
            timer.onComplete = onTimerComplete;
            timer.start();

            // Register keyboard handler.
            stage.addEventListener(KeyboardEvent.KEY_DOWN, keyDownHandler);

            createScoreLabels();

            // Switch to fullscreen mode.
            Cocos2D.toggleFullscreen();
        }

        protected function keyDownHandler(event:KeyboardEvent):void
        {   
            var keycode = event.keyCode;

            if (keycode == LoomKey.LEFTARROW) {
                whackMole(null, moles[0]);
            }
            
            if (keycode == LoomKey.UPARROW) {
                whackMole(null, moles[1]);            
            }
            
            if (keycode == LoomKey.RIGHTARROW) {
                whackMole(null, moles[2]);            
            }
            
            if(keycode == LoomKey.SPACEBAR) {
                endGame();
                resetGame();
            }

            if (keycode == LoomKey.F) {
                Cocos2D.toggleFullscreen();
            }

            if (keycode == LoomKey.ESCAPE) {
                Process.exit(0);
            }
        }

        override public function onTick()
        {
            var timeLeftSecs = GAME_TIME_SECS - Math.round(gameTimer.elapsed/1000);
            timeLabel.text = timeLeftSecs.toString();

            // Health check...
            var strikesLeft = MAX_STRIKES - strikes;

            // Play warning sound during the last 5 seconds
            if ((timeLeftSecs < 5) || (strikesLeft <= 1)) {
                if (timeLeftSecs != timeLastHealthWarning) {
                    SimpleAudioEngine.sharedEngine().playEffect("assets/sounds/health.wav");
                    timeLastHealthWarning = timeLeftSecs;                
                }
            }
        }

        protected function createScoreLabels()
        {
            // create a pool of score labels to pull from
            scores = new Vector.<SimpleLabel>();
            misses = new Vector.<SimpleLabel>();
            for (var i = 0; i < 4; i++)
            {
                var score = new SimpleLabel("assets/fonts/Curse-hd.fnt");
                score.text = "+100";
                score.x = -100;
                score.y = stage.stageHeight * 2 / 5;
                score.touchable = false;
                score.center();

                scores.push(score);
                stage.addChild(score);

                var miss = new SimpleLabel("assets/fonts/Red-hd.fnt");
                miss.text = "miss";
                miss.x = -100;
                miss.y = stage.stageHeight * 2 / 5;
                miss.center();
                miss.touchable = false;
                misses.push(miss);
                stage.addChild(miss);
            }
        }

        protected function getAvailableScoreLabel():SimpleLabel
        {
            for (var i = 0; i < scores.length; i++)
            {
                var score = scores[i];
                if (!LoomTween.isTweening(score))
                    return score;
            }

            // default, return the first one
            LoomTween.killTweensOf(scores[0]);
            return scores[0];
        }

        protected function getAvailableMissLabel():SimpleLabel
        {
            for (var i = 0; i < misses.length; i++) {
                var miss = misses[i];
                if (!LoomTween.isTweening(miss)) {
                    return miss;
                }
            }

            // default, return the first one
            LoomTween.killTweensOf(misses[0]);
            return misses[0];
        }

        protected function onTimerComplete(timer:Timer)
        {
            for (var i = 0; i < moles.length; i++)
            {
                var mole = moles[i];
                
                if (!LoomTween.isTweening(mole) && (mole.y == moleDownY)) {
                    moleStates[i] = false;
                }

                // Randomly start popping up mole
                if (Math.floor(Math.random() * 4) == 0)
                {
                    if (!LoomTween.isTweening(mole)) {
                        LoomTween.to(mole, 0.5, {"y": moleUpY, "ease": LoomEaseType.EASE_OUT});
                        LoomTween.to(mole, 0.3, {"y": moleDownY, "ease": LoomEaseType.EASE_OUT, "delay": 0.5+waitTime});
                    }
                }
            }

            // play the timer again
            timer.start();
        }

        protected function whackMole(e:TouchEvent, mole:Image)
        {
            //if (strikes == 3)
            //{
            //    return;
            //}

            var index = moles.indexOf(mole);
            if (moleStates[index] == false && (mole.y < (moleDownY - 10)))
            {
                onHit(index);
            }
            else
            {
                onMiss(index);
            }

            // stop the event propagating to the miss handler
            if (e != null)
            {
                e.stopImmediatePropagation();
            }
        }

        protected function updateTotal(points:Number)
        {
            total += points;
            totalScore.text = total.toString();       
            totalScore.x = stage.stageWidth / 2 - ((totalScore.width / 2) * totalScore.scale);
        }

        protected function onHit(index:Number)
        {
            var mole = moles[index];

            SimpleAudioEngine.sharedEngine().playEffect("assets/sounds/hit.wav");

            // increase the difficulty as we get more moles
            waitTime *= 0.9;
            timer.delay *= 0.9;

            // update our whacked state
            moleStates[index] = true;

            // animate a score
            var score = getAvailableScoreLabel();
            score.x = mole.x;
            score.y = scoreY;
            score.scale = 0.8;

            updateTotal(HIT_POINTS);

            LoomTween.to(score, 0.3, {"scaleX": 0.5, "ease": LoomEaseType.EASE_OUT_BACK});
            LoomTween.to(score, 0.3, {"scaleY": 0.5, "ease": LoomEaseType.EASE_OUT_BACK});
            LoomTween.to(score, 0.3, {"y": -100, "ease": LoomEaseType.EASE_IN_BACK, "delay": 0.3});
            LoomTween.killTweensOf(mole);
            LoomTween.to(mole, 0.3, {"y": moleDownY, "ease": LoomEaseType.EASE_OUT, "delay": 0.1}).onComplete;
        }

        protected function onMiss(index:Number)
        {
            var mole = moles[index];

            if (strikes == MAX_STRIKES)
            {
                return;
            }
            
            SimpleAudioEngine.sharedEngine().playEffect("assets/sounds/miss.wav");
            
            // Disable strike counter...
            //strikes++;

            updateTotal(-MISS_POINTS);

            var miss = getAvailableMissLabel();
            miss.x = mole.x;
            miss.y = missY;
            miss.scale = 0;

            LoomTween.to(miss, 0.3, {"scaleX": 0.5, "ease": LoomEaseType.EASE_OUT_BACK});
            LoomTween.to(miss, 0.3, {"scaleY": 0.5, "ease": LoomEaseType.EASE_OUT_BACK});
            LoomTween.to(miss, 0.3, {"y": -100, "ease": LoomEaseType.EASE_IN_BACK, "delay": 0.3});

            if (strikes == MAX_STRIKES)
            {
                endGame();
            }
        }

        protected function endGame(t:Timer=null)
        {
            strikes = MAX_STRIKES;
            timer.stop();
            gameTimer.stop();

            stage.removeChild(timeLabel);
            stage.addChild(gameOverLabel);            
        }

        protected function resetGame()
        {
            stage.addChild(timeLabel);
            strikes = 0;
            total = 0;
            updateTotal(0);

            timer.start();
            gameTimer.start();
            stage.removeChild(gameOverLabel);
            waitTime = INITIAL_MOLE_UP_TIME;
            timer.delay = INITIAL_TIMER_PERIOD;
        }
    }
}
