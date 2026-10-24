import * as THREE from 'three';
import {RoomEnvironment} from 'three/addons/environments/RoomEnvironment.js';
import {EffectComposer} from 'three/addons/postprocessing/EffectComposer.js';
import {RenderPass} from 'three/addons/postprocessing/RenderPass.js';
import {UnrealBloomPass} from 'three/addons/postprocessing/UnrealBloomPass.js';
import {OutputPass} from 'three/addons/postprocessing/OutputPass.js';
import {SMAAPass} from 'three/addons/postprocessing/SMAAPass.js';
export {THREE};
export const $=s=>document.querySelector(s);
export const clamp=THREE.MathUtils.clamp;
export const asset=name=>`${import.meta.env.BASE_URL}assets/${name}`;
export const readSave=(key,fallback)=>{try{return JSON.parse(localStorage.getItem(key))??fallback}catch{return fallback}};
export const save=(key,data)=>{try{localStorage.setItem(key,JSON.stringify(data));return true}catch{return false}};
export function engine({background=0x111b22,fog=0,exposure=1.15,bloom=.2}={}){
 const scene=new THREE.Scene();scene.background=new THREE.Color(background);
 if(fog)scene.fog=new THREE.FogExp2(background,fog);
 const camera=new THREE.PerspectiveCamera(48,innerWidth/innerHeight,.1,3000);
 let renderer;
 try{renderer=new THREE.WebGLRenderer({antialias:true,powerPreference:'high-performance'})}catch{document.body.innerHTML='<div style="padding:10%;font-family:sans-serif;color:white;background:#111"><h1>A 3D browser is needed</h1><p>Enable hardware acceleration, then reload in a browser with WebGL 2 support.</p></div>';throw Error('WebGL 2 unavailable')}
 renderer.setPixelRatio(Math.min(devicePixelRatio,1.7));renderer.setSize(innerWidth,innerHeight);
 renderer.toneMapping=THREE.ACESFilmicToneMapping;renderer.toneMappingExposure=exposure;
 renderer.shadowMap.enabled=true;renderer.shadowMap.type=THREE.PCFSoftShadowMap;
 renderer.info.autoReset=false;
 renderer.domElement.id='world';renderer.domElement.setAttribute('aria-label','Interactive 3D game scene');$('#app').prepend(renderer.domElement);
 const pmrem=new THREE.PMREMGenerator(renderer);const room=new RoomEnvironment();scene.environment=pmrem.fromScene(room,.04).texture;room.dispose();pmrem.dispose();
 const composer=new EffectComposer(renderer);composer.addPass(new RenderPass(scene,camera));
 const glow=new UnrealBloomPass(new THREE.Vector2(innerWidth,innerHeight),bloom,.55,1.1);composer.addPass(glow);composer.addPass(new OutputPass());const aa=new SMAAPass();composer.addPass(aa);
 let quality='high';
 function setQuality(q){quality=q;const ratio=q==='high'?Math.min(devicePixelRatio,1.7):1;renderer.setPixelRatio(ratio);composer.setPixelRatio(ratio);renderer.shadowMap.enabled=q==='high';glow.enabled=q==='high';resize()}
 function resize(){camera.aspect=innerWidth/innerHeight;camera.updateProjectionMatrix();renderer.setSize(innerWidth,innerHeight);composer.setSize(innerWidth,innerHeight)}
 addEventListener('resize',resize);
 let previous=performance.now(),time=0;let callback=()=>{};
 renderer.setAnimationLoop(now=>{const dt=Math.min((now-previous)/1000,.045);previous=now;if(document.hidden)return;time+=dt;callback(dt,time);renderer.info.reset();composer.render()});
 return {scene,camera,renderer,composer,setQuality,get quality(){return quality},loop(fn){callback=fn}};
}
export function material(color,roughness=.5,metalness=0){return new THREE.MeshStandardMaterial({color,roughness,metalness})}
export function mesh(geo,mat,parent,x=0,y=0,z=0){const o=new THREE.Mesh(geo,mat);o.position.set(x,y,z);o.castShadow=true;o.receiveShadow=true;parent.add(o);return o}
export function tube(points,radius,mat,parent){return mesh(new THREE.TubeGeometry(new THREE.CatmullRomCurve3(points),Math.max(16,points.length*4),radius,8,false),mat,parent)}
export function sky(scene,top='#152f48',bottom='#d6a382'){
 const mat=new THREE.ShaderMaterial({side:THREE.BackSide,depthWrite:false,uniforms:{top:{value:new THREE.Color(top)},bottom:{value:new THREE.Color(bottom)}},vertexShader:'varying vec3 vP;void main(){vP=position;gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.);}',fragmentShader:'varying vec3 vP;uniform vec3 top;uniform vec3 bottom;void main(){float h=normalize(vP).y;gl_FragColor=vec4(mix(bottom,top,smoothstep(-.1,.7,h)),1.);}'});
 const o=mesh(new THREE.SphereGeometry(1400,32,16),mat,scene);o.castShadow=false;return o;
}
export function texture(name,repeat=1){const t=new THREE.TextureLoader().load(asset(name));t.wrapS=t.wrapT=THREE.RepeatWrapping;t.repeat.set(repeat,repeat);t.anisotropy=8;if(name.includes('color'))t.colorSpace=THREE.SRGBColorSpace;return t}
export function input(){const keys=new Set();addEventListener('keydown',e=>{if(['Space','ArrowUp','ArrowDown','ArrowLeft','ArrowRight'].includes(e.code))e.preventDefault();keys.add(e.code)});addEventListener('keyup',e=>keys.delete(e.code));addEventListener('blur',()=>keys.clear());document.addEventListener('visibilitychange',()=>keys.clear());document.querySelectorAll('[data-key]').forEach(b=>{b.addEventListener('pointerdown',e=>{e.preventDefault();b.setPointerCapture(e.pointerId);keys.add(b.dataset.key)});for(const ev of ['pointerup','pointercancel','lostpointercapture'])b.addEventListener(ev,()=>keys.delete(b.dataset.key))});return {keys,has:(...codes)=>codes.some(k=>keys.has(k)),clear:()=>keys.clear()}}
export class Sound {
 constructor(){this.enabled=readSave('vertex-audio',true);this.ctx=null}
 start(){if(!this.ctx){this.ctx=new AudioContext();this.master=this.ctx.createGain();this.master.gain.value=this.enabled?.18:0;this.master.connect(this.ctx.destination)}if(this.ctx.state==='suspended')this.ctx.resume()}
 toggle(){this.start();this.enabled=!this.enabled;this.master.gain.setTargetAtTime(this.enabled?.18:0,this.ctx.currentTime,.05);save('vertex-audio',this.enabled);return this.enabled}
 tone(freq=440,duration=.2,type='sine',volume=.5){if(!this.ctx)return;const o=this.ctx.createOscillator(),g=this.ctx.createGain();o.type=type;o.frequency.value=freq;g.gain.setValueAtTime(0,this.ctx.currentTime);g.gain.linearRampToValueAtTime(volume,this.ctx.currentTime+.02);g.gain.exponentialRampToValueAtTime(.001,this.ctx.currentTime+duration);o.connect(g);g.connect(this.master);o.start();o.stop(this.ctx.currentTime+duration+.03)}
 motor(){this.start();if(this.osc)return;this.osc=this.ctx.createOscillator();this.osc.type='sawtooth';this.filter=this.ctx.createBiquadFilter();this.filter.type='lowpass';this.filter.frequency.value=350;this.motorGain=this.ctx.createGain();this.motorGain.gain.value=0;this.osc.connect(this.filter);this.filter.connect(this.motorGain);this.motorGain.connect(this.master);this.osc.start()}
 rev(speed,active){if(!this.osc)return;this.osc.frequency.setTargetAtTime(35+speed*2,this.ctx.currentTime,.1);this.motorGain.gain.setTargetAtTime(active?.19:0,this.ctx.currentTime,.1)}
}
export function bindCommon(e,sound){$('#audio').textContent=sound.enabled?'Sound on':'Sound off';$('#audio').onclick=()=>{$('#audio').textContent=sound.toggle()?'Sound on':'Sound off'};$('#quality').onclick=()=>{e.setQuality(e.quality==='high'?'performance':'high');$('#quality').textContent=e.quality==='high'?'Quality: high':'Quality: light'};$('#help').onclick=()=>$('#instructions').showModal();$('#close-help').onclick=()=>$('#instructions').close();$('#instructions').addEventListener('click',ev=>{if(ev.target===$('#instructions'))$('#instructions').close()})}
export function notice(text){const n=$('#notice');if(!n)return;n.textContent=text;n.classList.add('visible');clearTimeout(n._t);n._t=setTimeout(()=>n.classList.remove('visible'),2800)}
