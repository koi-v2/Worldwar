package com.koi.growworld

import android.app.Activity
import android.os.Bundle
import android.view.View
import android.view.MotionEvent
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Color
import android.graphics.RectF
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min

class MainActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.decorView.systemUiVisibility = (View.SYSTEM_UI_FLAG_FULLSCREEN or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or View.SYSTEM_UI_FLAG_LAYOUT_STABLE or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN)
        setContentView(GameView())
    }
}

private class GameView : View {
    private val p = Paint(Paint.ANTI_ALIAS_FLAG)
    private val tile = 64f
    private val worldW = 80
    private val worldH = 24
    private val blocks = Array(worldH) { BooleanArray(worldW) }
    private var px = 7.0f
    private var py = 0.0f
    private var vy = 0f
    private var vx = 0f
    private var facing = 1
    private var last = System.nanoTime()
    private var camX = 0f
    private var camY = 0f
    private var moveLeft = false
    private var moveRight = false
    private var jumping = false
    private var message = "Sentuh blok untuk menghancurkannya"
    private var messageUntil = 0L
    private var breaking = false
    private var breakX = -1
    private var breakY = -1
    private val sky = Color.rgb(112, 190, 242)
    private val grass = Color.rgb(91, 190, 76)
    private val dirt = Color.rgb(143, 91, 55)
    private val stone = Color.rgb(115, 125, 137)

    init {
        isFocusable = true
        for (x in 0 until worldW) {
            val ground = 15 + ((x * 7) % 3 == 0).let { if (it) 0 else 1 }
            for (y in ground until worldH) {
                blocks[y][x] = true
            }
            blocks[ground - 1][x] = true
        }
        // A small, open spawn area
        for (x in 4..10) for (y in 11..15) blocks[y][x] = false
        for (x in 4..10) blocks[16][x] = true
        py = 10.0f
    }

    override fun onDraw(c: Canvas) {
        super.onDraw(c)
        val w = width.toFloat(); val h = height.toFloat()
        c.drawColor(sky)
        val dt = min(0.04f, (System.nanoTime() - last) / 1_000_000_000f)
        last = System.nanoTime()
        val oldX = px
        vx = when { moveLeft -> -5.2f; moveRight -> 5.2f; else -> 0f }
        if (vx != 0f) facing = if (vx > 0) 1 else -1
        px += vx * dt
        px = max(0.5f, min(worldW - 1.5f, px))
        if (collides(px, py)) px = oldX
        vy += 18f * dt
        if (jumping && onGround()) { vy = -8.5f; jumping = false }
        val oldY = py
        py += vy * dt
        if (collides(px, py)) {
            py = oldY
            if (vy > 0) vy = 0f else vy = 0f
        }
        if (py > worldH) { py = 8f; vy = 0f }
        camX = max(0f, min(worldW * tile - w, px * tile - w * 0.42f))
        camY = max(0f, min(worldH * tile - h, py * tile - h * 0.55f))

        val startX = max(0, floor(camX / tile).toInt())
        val endX = min(worldW - 1, floor((camX + w) / tile).toInt() + 1)
        val startY = max(0, floor(camY / tile).toInt())
        val endY = min(worldH - 1, floor((camY + h) / tile).toInt() + 1)
        for (y in startY..endY) for (x in startX..endX) if (blocks[y][x]) {
            val l = x * tile - camX; val t = y * tile - camY
            p.color = if (y == 0 || !blocks[y-1][x]) grass else if (y < 17) dirt else stone
            c.drawRect(l+1, t+1, l+tile-1, t+tile-1, p)
            p.color = if (y < 17) Color.rgb(110,65,39) else Color.rgb(82,91,101)
            c.drawRect(l+2, t+tile-7, l+tile-2, t+tile-2, p)
            p.color = Color.argb(45,255,255,255)
            c.drawRect(l+3,t+3,l+tile-3,t+6,p)
        }
        // Pixel-ish character
        val cx = px * tile - camX; val cy = py * tile - camY
        p.color = Color.rgb(255, 211, 166); c.drawRect(cx-13,cy-49,cx+13,cy-25,p)
        p.color = Color.rgb(42, 69, 135); c.drawRect(cx-15,cy-25,cx+15,cy+5,p)
        p.color = Color.rgb(55, 39, 31); c.drawRect(cx-13,cy-52,cx+13,cy-45,p)
        p.color = Color.rgb(255,255,255)
        if (facing > 0) c.drawRect(cx+4,cy-40,cx+8,cy-35,p) else c.drawRect(cx-8,cy-40,cx-4,cy-35,p)
        p.color = Color.rgb(35,45,60); c.drawRect(cx-12,cy+5,cx-3,cy+19,p); c.drawRect(cx+3,cy+5,cx+12,cy+19,p)

        // HUD
        p.color = Color.argb(180, 20, 29, 42); c.drawRoundRect(18f,18f,340f,76f,15f,15f,p)
        p.color = Color.WHITE; p.textSize = 25f; c.drawText("GROWWORLD  •  Alpha",34f,53f,p)
        p.textSize = 17f; c.drawText("Gerak: tombol kiri/kanan  •  Lompat: ↑  •  Hancurkan: ketuk blok",22f,h-22f,p)
        drawButton(c, 28f,h-135f,105f,h-35f,"◀",moveLeft)
        drawButton(c, 120f,h-135f,197f,h-35f,"▶",moveRight)
        drawButton(c,w-145f,h-135f,w-35f,h-35f,"↑",jumping)
        drawButton(c,w-265f,h-135f,w-155f,h-35f,"⛏",breaking)
        if (System.currentTimeMillis() < messageUntil) {
            p.color = Color.argb(205,20,29,42); c.drawRoundRect(w/2-190,h/2-35,w/2+190,h/2+35,15f,15f,p)
            p.color = Color.WHITE; p.textSize=24f; c.drawText(message,w/2-170,h/2+8,p)
        }
        postInvalidateDelayed(16)
    }

    private fun drawButton(c: Canvas,l:Float,t:Float,r:Float,b:Float,label:String,active:Boolean) {
        p.color = if (active) Color.argb(225, 255, 197, 70) else Color.argb(170, 24, 35, 52)
        c.drawRoundRect(l,t,r,b,20f,20f,p)
        p.color = Color.WHITE; p.textSize=43f
        val tw=p.measureText(label); c.drawText(label,(l+r-tw)/2f,(t+b)/2f+15f,p)
    }

    private fun collides(x:Float,y:Float):Boolean {
        val left=floor(x-0.22f).toInt(); val right=floor(x+0.22f).toInt()
        val top=floor(y-0.72f).toInt(); val bottom=floor(y+0.28f).toInt()
        for (yy in top..bottom) for (xx in left..right) if (yy in 0 until worldH && xx in 0 until worldW && blocks[yy][xx]) return true
        return false
    }
    private fun onGround() = collides(px,py+0.04f)

    override fun onTouchEvent(e: MotionEvent): Boolean {
        val h=height.toFloat(); val w=width.toFloat()
        when(e.actionMasked) {
            MotionEvent.ACTION_DOWN, MotionEvent.ACTION_POINTER_DOWN, MotionEvent.ACTION_MOVE -> {
                moveLeft=false; moveRight=false; jumping=false; breaking=false
                for(i in 0 until e.pointerCount) {
                    val x=e.getX(i); val y=e.getY(i)
                    if(y>h-155 && x<115) moveLeft=true
                    else if(y>h-155 && x<215) moveRight=true
                    else if(y>h-155 && x>w-150) jumping=true
                    else if(y>h-155 && x>w-280) breaking=true
                }
                if(e.actionMasked==MotionEvent.ACTION_DOWN && e.getY()<h-155) {
                    val tx=floor((e.getX()-0f+camX)/tile).toInt()
                    val ty=floor((e.getY()+camY)/tile).toInt()
                    if(tx in 0 until worldW && ty in 0 until worldH && blocks[ty][tx]) {
                        val dx=tx-px; val dy=ty-py
                        if(dx*dx+dy*dy<16f) {
                            blocks[ty][tx]=false
                            message="Blok dihancurkan!"; messageUntil=System.currentTimeMillis()+900
                        } else {
                            message="Dekati blok untuk menghancurkannya"; messageUntil=System.currentTimeMillis()+1000
                        }
                    }
                }
                invalidate()
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_POINTER_UP, MotionEvent.ACTION_CANCEL -> {
                moveLeft=false; moveRight=false; jumping=false; breaking=false
            }
        }
        return true
    }
}
