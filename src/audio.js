import {readSave,save,clamp} from './engine.js';
// Synthesized engine, road noise and tyre slip. No downloaded recording or API.
export class DrivingAudio {
 constructor(){this.enabled=readSave('neon-drift:sound',true);this.ctx=null;this.lastGear=1;this.shift=0}
 start(){
  if(this.ctx){this.ctx.resume();return}
  const C=window.AudioContext||window.webkitAudioContext;if(!C)return;
  this.ctx=new C();const c=this.ctx;
  this.master=c.createGain();this.master.gain.value=this.enabled?.42:0;
  const compressor=c.createDynamicsCompressor();compressor.threshold.value=-18;compressor.ratio.value=5;this.master.connect(compressor);this.analyser=c.createAnalyser();this.analyser.fftSize=256;compressor.connect(this.analyser);this.analyser.connect(c.destination);
  this.engineGain=c.createGain();this.engineGain.gain.value=0;
  this.engineFilter=c.createBiquadFilter();this.engineFilter.type='lowpass';this.engineFilter.frequency.value=800;this.engineFilter.Q.value=.7;this.engineFilter.connect(this.engineGain);this.engineGain.connect(this.master);
  this.oscillators=[];
  for(const [ratio,vol,type] of [[1,.28,'sawtooth'],[2,.14,'triangle'],[.5,.25,'sine'],[4,.025,'square']]){const o=c.createOscillator(),g=c.createGain();o.type=type;o.frequency.value=50*ratio;g.gain.value=vol;o.connect(g);g.connect(this.engineFilter);o.start();this.oscillators.push({o,ratio})}
  const buffer=c.createBuffer(1,c.sampleRate*2,c.sampleRate),data=buffer.getChannelData(0);let last=0;
  for(let i=0;i<data.length;i++){const white=Math.random()*2-1;last=(last+.03*white)/1.03;data[i]=last*5}
  const noise=c.createBufferSource();noise.buffer=buffer;noise.loop=true;noise.start();
  this.wind=c.createGain();this.wind.gain.value=0;const windFilter=c.createBiquadFilter();windFilter.type='lowpass';windFilter.frequency.value=900;noise.connect(windFilter);windFilter.connect(this.wind);this.wind.connect(this.master);
  this.tyre=c.createGain();this.tyre.gain.value=0;this.tyreFilter=c.createBiquadFilter();this.tyreFilter.type='bandpass';this.tyreFilter.frequency.value=1500;this.tyreFilter.Q.value=2;noise.connect(this.tyreFilter);this.tyreFilter.connect(this.tyre);this.tyre.connect(this.master);
  this.squeal=c.createOscillator();this.squeal.type='triangle';this.squeal.frequency.value=850;const sq=c.createGain();sq.gain.value=.06;this.squeal.connect(sq);sq.connect(this.tyre);this.squeal.start();
 }
 toggle(){this.start();this.enabled=!this.enabled;if(this.ctx)this.master.gain.setTargetAtTime(this.enabled?.42:0,this.ctx.currentTime,.1);save('neon-drift:sound',this.enabled);return this.enabled}
 update(car,throttle,active,dt){if(!this.ctx)return;const c=this.ctx,t=c.currentTime;const gear=clamp(1+Math.floor(car.speed/12),1,5);if(gear!==this.lastGear){this.shift=.14;this.lastGear=gear}this.shift=Math.max(0,this.shift-dt);
  const rpm=950+(car.speed%12)/12*4200+(throttle?900:0);const fundamental=rpm/60*2*(this.shift>0?.7:1);
  for(const {o,ratio} of this.oscillators)o.frequency.setTargetAtTime(fundamental*ratio,t,.06);
  this.engineFilter.frequency.setTargetAtTime(350+rpm*.2+(throttle?400:0),t,.09);this.engineGain.gain.setTargetAtTime(active?(throttle?.52:.25):0,t,.14);
  this.wind.gain.setTargetAtTime(active?Math.pow(car.speed/64,2)*.6:0,t,.2);
  this.tyre.gain.setTargetAtTime(active&&car.drifting?clamp(Math.abs(car.slip)*2,0,.85):0,t,.06);this.tyreFilter.frequency.setTargetAtTime(1100+car.speed*15,t,.1);this.squeal.frequency.setTargetAtTime(650+car.speed*9+Math.abs(car.slip)*500,t,.07);
 }
 tone(freq=440,duration=.18,type='sine',volume=.25){if(!this.ctx)return;const c=this.ctx,o=c.createOscillator(),g=c.createGain();o.type=type;o.frequency.value=freq;g.gain.setValueAtTime(.001,c.currentTime);g.gain.exponentialRampToValueAtTime(volume,c.currentTime+.008);g.gain.exponentialRampToValueAtTime(.001,c.currentTime+duration);o.connect(g);g.connect(this.master);o.start();o.stop(c.currentTime+duration+.05)}
 impact(){if(!this.ctx)return;const c=this.ctx,buffer=c.createBuffer(1,c.sampleRate*.22,c.sampleRate),d=buffer.getChannelData(0);for(let i=0;i<d.length;i++)d[i]=(Math.random()*2-1)*Math.exp(-i/d.length*7);const src=c.createBufferSource();src.buffer=buffer;const f=c.createBiquadFilter();f.type='lowpass';f.frequency.value=550;src.connect(f);f.connect(this.master);src.start();this.tone(70,.23,'sine',.5)}
 finish(){[440,554,659,880].forEach((f,i)=>setTimeout(()=>this.tone(f,.5,'sine',.25),i*110))}
}
