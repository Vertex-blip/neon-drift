import {THREE,asset,mesh,material} from './engine.js';
import {GLTFLoader} from 'three/addons/loaders/GLTFLoader.js';
import {DRACOLoader} from 'three/addons/loaders/DRACOLoader.js';
export async function loadCar(scene){
 const decoder=new DRACOLoader().setDecoderPath(asset('draco/')).setDecoderConfig({type:'wasm'});
 const loader=new GLTFLoader().setDRACOLoader(decoder);const gltf=await loader.loadAsync(asset('ferrari.glb'));decoder.dispose();
 const root=new THREE.Group(),body=new THREE.Group();root.add(body);scene.add(root);
 const model=gltf.scene.children[0];body.add(model);
 const paint=new THREE.MeshPhysicalMaterial({color:'#f06b37',metalness:.72,roughness:.31,clearcoat:1,clearcoatRoughness:.14});
 const trim=new THREE.MeshStandardMaterial({color:'#343a3b',metalness:.85,roughness:.24});
 const glass=new THREE.MeshPhysicalMaterial({color:'#a6c1ca',metalness:.15,roughness:.08,transparent:true,opacity:.43,depthWrite:false});
 model.traverse(o=>{if(o.isMesh){o.castShadow=true;o.receiveShadow=true;if(o.name==='body')o.material=paint;if(o.name==='glass')o.material=glass;if(['rim_fl','rim_fr','rim_rl','rim_rr','trim'].includes(o.name))o.material=trim}});
 // Author's model has its nose toward -Z. Gameplay forward is +Z.
 model.rotation.y=Math.PI;
 const bounds=new THREE.Box3().setFromObject(model);const size=bounds.getSize(new THREE.Vector3());const scale=4.6/Math.max(size.x,size.z);model.scale.setScalar(scale);bounds.setFromObject(model);const center=bounds.getCenter(new THREE.Vector3());model.position.x-=center.x;model.position.z-=center.z;model.position.y-=bounds.min.y;
 const wheels=['wheel_fl','wheel_fr','wheel_rl','wheel_rr'].map(n=>model.getObjectByName(n));
 const steeringPivots=wheels.slice(0,2).map(w=>{if(!w)return null;const pivot=new THREE.Group();pivot.position.copy(w.position);w.parent.add(pivot);pivot.add(w);w.position.set(0,0,0);return pivot});
 const tailMat=new THREE.MeshStandardMaterial({color:'#7d0903',emissive:'#ff2205',emissiveIntensity:.45,roughness:.35});
 for(const x of [-.68,.68]){const m=mesh(new THREE.TorusGeometry(.135,.036,8,20),tailMat,body,x,.66,-2.12);m.rotation.y=Math.PI}
 const headMat=new THREE.MeshStandardMaterial({color:'#fff5d2',emissive:'#fff0c8',emissiveIntensity:2});
 for(const x of [-.67,.67]){const h=mesh(new THREE.CapsuleGeometry(.035,.39,4,8),headMat,body,x,.49,1.98);h.rotation.z=x<0?-.35:.35;h.rotation.x=.8}
 const headlight=new THREE.SpotLight(0xffedce,14,45,.5,.7,1.5);headlight.position.set(0,.7,1.6);headlight.target.position.set(0,0,20);root.add(headlight,headlight.target);
 const shadowCanvas=document.createElement('canvas');shadowCanvas.width=shadowCanvas.height=128;const ctx=shadowCanvas.getContext('2d'),gradient=ctx.createRadialGradient(64,64,5,64,64,64);gradient.addColorStop(0,'rgba(0,0,0,.65)');gradient.addColorStop(1,'rgba(0,0,0,0)');ctx.fillStyle=gradient;ctx.fillRect(0,0,128,128);const shadow=mesh(new THREE.PlaneGeometry(3.2,6),new THREE.MeshBasicMaterial({map:new THREE.CanvasTexture(shadowCanvas),transparent:true,depthWrite:false}),root,0,.025,0);shadow.rotation.x=-Math.PI/2;shadow.castShadow=false;
 return {root,body,model,paint,wheels,tailMat,update(car,dt,brake,time){root.position.set(car.x,.15,car.z);root.rotation.y=car.heading;body.rotation.z=THREE.MathUtils.damp(body.rotation.z,-car.steer*car.speed*.0014,5,dt);body.rotation.x=THREE.MathUtils.damp(body.rotation.x,brake?.018:-.006,4,dt);body.position.y=Math.sin(time*24)*Math.min(car.speed/64,1)*.006;for(const w of wheels)if(w)w.rotation.x-=car.speed*dt/.34;for(const p of steeringPivots)if(p)p.rotation.y=car.steer*.32;tailMat.emissiveIntensity=brake?4:.45}}
}
export function effects(scene){
 const c=document.createElement('canvas');c.width=c.height=64;const g=c.getContext('2d'),r=g.createRadialGradient(32,32,0,32,32,32);r.addColorStop(0,'rgba(215,220,214,.4)');r.addColorStop(.5,'rgba(210,215,211,.13)');r.addColorStop(1,'rgba(200,210,210,0)');g.fillStyle=r;g.fillRect(0,0,64,64);
 const smokeTexture=new THREE.CanvasTexture(c),smoke=[];
 for(let i=0;i<64;i++){const s=new THREE.Sprite(new THREE.SpriteMaterial({map:smokeTexture,transparent:true,depthWrite:false,opacity:0}));s.visible=false;scene.add(s);smoke.push({s,life:0,vx:0,vz:0})}
 const max=2400,positions=new Float32Array(max*6),alphas=new Float32Array(max*2);const geo=new THREE.BufferGeometry();geo.setAttribute('position',new THREE.BufferAttribute(positions,3));geo.setDrawRange(0,0);const marks=new THREE.LineSegments(geo,new THREE.LineBasicMaterial({color:'#161d1d',transparent:true,opacity:.55}));scene.add(marks);let count=0,last=null,smokeIndex=0,emit=0;
 return {reset(){count=0;geo.setDrawRange(0,0);last=null;for(const p of smoke){p.life=0;p.s.visible=false}},update(car,dt){
  emit-=dt;
  if(car.drifting&&emit<=0){emit=.035;for(const side of [-1,1]){const p=smoke[smokeIndex++%smoke.length];p.life=1.2;p.s.visible=true;p.s.position.set(car.x-Math.sin(car.heading)*1.5+Math.cos(car.heading)*side*.8,.35,car.z-Math.cos(car.heading)*1.5-Math.sin(car.heading)*side*.8);p.vx=car.vx*.08;p.vz=car.vz*.08}}
  for(const p of smoke)if(p.life>0){p.life-=dt;p.s.position.x+=p.vx*dt;p.s.position.z+=p.vz*dt;p.s.position.y+=dt*.6;p.s.scale.setScalar(.55+(1.2-p.life)*1.8);p.s.material.opacity=Math.max(0,p.life*.45);if(p.life<=0)p.s.visible=false}
  if(car.drifting){const points=[-1,1].map(side=>[car.x-Math.sin(car.heading)*1.5+Math.cos(car.heading)*side*.76,.165,car.z-Math.cos(car.heading)*1.5-Math.sin(car.heading)*side*.76]);if(last){for(let k=0;k<2;k++){const i=count%max;positions.set(last[k],i*6);positions.set(points[k],i*6+3);count++}geo.attributes.position.needsUpdate=true;geo.setDrawRange(0,Math.min(count,max)*2);geo.computeBoundingSphere()}last=points}else last=null;
 }}
}
