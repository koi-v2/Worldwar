package com.koiv2.koiworld;
import android.app.Activity;
import android.os.Bundle;
import android.content.SharedPreferences;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.RectF;
import android.graphics.Typeface;
import android.view.MotionEvent;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;

public class MainActivity extends Activity {
 public void onCreate(Bundle b){super.onCreate(b);requestWindowFeature(Window.FEATURE_NO_TITLE);getWindow().setFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN,WindowManager.LayoutParams.FLAG_FULLSCREEN);setContentView(new Game());}
 final class Game extends View{
  Paint p=new Paint(3); SharedPreferences sp; int cols=10,rows=9,px=4,py=4,coins=100,gems=10,sel=0; int[][] map=new int[rows][cols]; int[] bag={8,5,3,0,2,0}; RectF[] btn=new RectF[13];
  String msg="KoiWorld Native • Ketuk petak untuk bermain"; String[] names={"Grass","Dirt","Stone","Water","Tree","Gold"}; int[] colors={0xff78c96b,0xff98633f,0xff87979b,0xff3199d5,0xff287044,0xffffcc4b}; float tx,ty,tile;
  Game(){super(MainActivity.this);sp=getSharedPreferences("kw",0);for(int y=0;y<rows;y++)for(int x=0;x<cols;x++)map[y][x]=y<2?0:y<5?1:2;map[1][1]=4;map[1][8]=4;map[2][7]=5;map[3][2]=3;map[4][2]=3;String m=sp.getString("map","");if(m.length()==90)for(int i=0;i<90;i++)map[i/cols][i%cols]=m.charAt(i)-'0';coins=sp.getInt("coins",100);gems=sp.getInt("gems",10);px=sp.getInt("px",4);py=sp.getInt("py",4);String q=sp.getString("bag","");if(q.length()==6)for(int i=0;i<6;i++)bag[i]=q.charAt(i)-'0';}
  void txt(Canvas c,String s,float x,float y,float z,int color,boolean bold){p.setColor(color);p.setTextSize(z);p.setTypeface(bold?Typeface.DEFAULT_BOLD:Typeface.DEFAULT);c.drawText(s,x,y,p);}
  void box(Canvas c,float l,float t,float r,float b,int color){p.setColor(color);c.drawRoundRect(l,t,r,b,8,8,p);}
  protected void onDraw(Canvas c){float w=getWidth(),h=getHeight();c.drawColor(0xff102a35);txt(c,"KOIWORLD",16,30,23,0xff8df0b5,true);txt(c,"NATIVE ANDROID",w-135,27,10,0xffb9d8d3,true);box(c,10,40,w-10,76,0xff193f4b);txt(c,"Gems "+gems+"   Coins "+coins+"   "+names[sel],18,63,13,0xffffdf83,true);
   tile=Math.min((w-28)/cols,(h*.40f)/rows);tx=(w-cols*tile)/2;ty=86;box(c,8,ty-5,w-8,ty+rows*tile+7,0xff0a1b22);
   for(int y=0;y<rows;y++)for(int x=0;x<cols;x++){float l=tx+x*tile,t=ty+y*tile;box(c,l+1,t+1,l+tile-2,t+tile-2,colors[map[y][x]]);if(map[y][x]==4)txt(c,"♣",l+tile*.2f,t+tile*.72f,tile*.65f,0xffe1ffb9,true);if(map[y][x]==5)txt(c,"✦",l+tile*.2f,t+tile*.72f,tile*.65f,0xffffffb0,true);if(px==x&&py==y){p.setStyle(Paint.Style.STROKE);p.setStrokeWidth(3);p.setColor(-1);c.drawRect(l+3,t+3,l+tile-3,t+tile-3,p);p.setStyle(Paint.Style.FILL);txt(c,"☺",l+tile*.18f,t+tile*.72f,tile*.65f,-1,true);}}
   float cy=ty+rows*tile+24,bw=(w-35)/4, bh=39;txt(c,"GERAK",12,cy+8,11,0xff8df0b5,true);String[] dirs={"←","↑","↓","→"};for(int i=0;i<4;i++){btn[i]=new RectF(10+i*(bw+5),cy+14,10+i*(bw+5)+bw,cy+14+bh);box(c,btn[i].left,btn[i].top,btn[i].right,btn[i].bottom,0xff24525c);txt(c,dirs[i],btn[i].left+bw/2-7,btn[i].top+26,22,-1,true);}
   float iy=cy+bh+35,sw=(w-30)/3,sh=34;txt(c,"INVENTORI • pilih blok",12,iy,11,0xff8df0b5,true);for(int i=0;i<6;i++){int row=i/3,col=i%3;float l=10+col*(sw+5),t=iy+7+row*(sh+5);btn[4+i]=new RectF(l,t,l+sw,t+sh);box(c,l,t,l+sw,t+sh,sel==i?0xff7c6630:0xff193f4b);txt(c,names[i]+" x"+bag[i],l+6,t+22,11,sel==i?0xffffdf83:0xffe8fbf2,true);}
   float ay=iy+7+2*(sh+5)+6;btn[10]=new RectF(10,ay,w*.32f,ay+35);btn[11]=new RectF(w*.34f,ay,w*.66f,ay+35);btn[12]=new RectF(w*.68f,ay,w-10,ay+35);String[] a={"⛏ Mine","Craft","Save"};for(int i=0;i<3;i++){RectF r=btn[10+i];box(c,r.left,r.top,r.right,r.bottom,0xff32616b);txt(c,a[i],r.left+8,r.top+23,12,-1,true);}float ly=ay+45;box(c,10,ly,w-10,Math.min(h-4,ly+36),0xff193f4b);txt(c,msg,16,ly+22,Math.min(12,w/32),0xffc5ddd8,false);
  }
  boolean hit(RectF r,float x,float y){return r!=null&&r.contains(x,y);} void move(int dx,int dy){px=Math.max(0,Math.min(cols-1,px+dx));py=Math.max(0,Math.min(rows-1,py+dy));msg="Posisi "+(px+1)+", "+(py+1);invalidate();}
  void mine(){int v=map[py][px];if(v==0)msg="Tidak ada blok di posisi ini";else{bag[v]=Math.min(9,bag[v]+1);map[py][px]=0;coins+=v==5?5:1;msg=names[v]+" ditambang!";}invalidate();}
  void save(){StringBuilder m=new StringBuilder(),b=new StringBuilder();for(int[] row:map)for(int v:row)m.append((char)('0'+v));for(int v:bag)b.append((char)('0'+Math.min(9,v)));sp.edit().putString("map",m.toString()).putString("bag",b.toString()).putInt("coins",coins).putInt("gems",gems).putInt("px",px).putInt("py",py).apply();msg="Progress tersimpan!";invalidate();}
  public boolean onTouchEvent(MotionEvent e){if(e.getAction()!=MotionEvent.ACTION_UP)return true;float x=e.getX(),y=e.getY();for(int i=0;i<4;i++)if(hit(btn[i],x,y)){if(i==0)move(-1,0);if(i==1)move(0,-1);if(i==2)move(0,1);if(i==3)move(1,0);return true;}for(int i=0;i<6;i++)if(hit(btn[4+i],x,y)){sel=i;msg="Dipilih "+names[i];invalidate();return true;}if(hit(btn[10],x,y)){mine();return true;}if(hit(btn[11],x,y)){if(bag[1]>0){bag[1]--;bag[0]=Math.min(9,bag[0]+1);msg="Craft: Dirt → Grass";}else msg="Butuh Dirt";invalidate();return true;}if(hit(btn[12],x,y)){save();return true;}if(y>=ty&&y<ty+rows*tile&&x>=tx&&x<tx+cols*tile){int xx=(int)((x-tx)/tile),yy=(int)((y-ty)/tile);if(Math.abs(xx-px)+Math.abs(yy-py)<=1){if(map[yy][xx]!=0){int v=map[yy][xx];bag[v]=Math.min(9,bag[v]+1);coins+=v==5?5:1;map[yy][xx]=0;msg=names[v]+" didapat";}else if(bag[sel]>0){bag[sel]--;map[yy][xx]=sel;msg=names[sel]+" dipasang";}else msg="Blok kosong";}else{px=xx;py=yy;msg="Bergerak";}invalidate();}return true;}
 }
}