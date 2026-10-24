import {THREE,mesh,material,texture,tube,asset} from './engine.js';
import {RGBELoader} from 'three/addons/loaders/RGBELoader.js';
import {GLTFLoader} from 'three/addons/loaders/GLTFLoader.js';
export const ROAD_WIDTH=13.6;
export const centerline=new THREE.CatmullRomCurve3([
 [0,0,110],[-75,0,106],[-128,0,52],[-108,0,-20],[-140,0,-91],[-77,0,-150],[0,0,-139],[77,0,-112],[113,0,-52],[102,0,20],[143,0,80],[90,0,135],[38,0,142]
].map(p=>new THREE.Vector3(...p)),true,'catmullrom',.35);
export const TRACK_LENGTH=centerline.getLength();
const N=700;
export const samples=Array.from({length:N},(_,i)=>{const p=centerline.getPointAt(i/N),t=centerline.getTangentAt(i/N);return {p,t,n:new THREE.Vector3(t.z,0,-t.x),u:i/N}});
export function trackPoint(u){u=((u%1)+1)%1;const p=centerline.getPointAt(u),t=centerline.getTangentAt(u);return {p,t,n:new THREE.Vector3(t.z,0,-t.x)}}
export function nearest(x,z){let index=0,best=Infinity;for(let i=0;i<N;i++){const p=samples[i].p;const d=(x-p.x)**2+(z-p.z)**2;if(d<best){best=d;index=i}}
 const s=samples[index];return {...s,index,distance:Math.sqrt(best),offset:(x-s.p.x)*s.n.x+(z-s.p.z)*s.n.z}}
function ribbon(offsetA,offsetB,y,mat,scene){const positions=[],uv=[],indices=[];for(let i=0;i<=N;i++){const s=samples[i%N];for(const d of [offsetA,offsetB]){positions.push(s.p.x+s.n.x*d,y,s.p.z+s.n.z*d);uv.push((d-offsetA)/4,i/N*TRACK_LENGTH/4)}}for(let i=0;i<N;i++){const a=i*2;indices.push(a,a+2,a+1,a+1,a+2,a+3)}const g=new THREE.BufferGeometry();g.setAttribute('position',new THREE.Float32BufferAttribute(positions,3));g.setAttribute('uv',new THREE.Float32BufferAttribute(uv,2));g.setIndex(indices);g.computeVertexNormals();return mesh(g,mat,scene)}
function instances(geometry,mat,placements,scene){const object=new THREE.InstancedMesh(geometry,mat,placements.length),dummy=new THREE.Object3D();placements.forEach((p,i)=>{dummy.position.set(...p.pos);dummy.rotation.set(...(p.rot||[0,0,0]));dummy.scale.set(...(p.scale||[1,1,1]));dummy.updateMatrix();object.setMatrixAt(i,dummy.matrix)});object.castShadow=true;object.receiveShadow=true;scene.add(object);return object}
function seeded(seed){return()=>{seed=(seed*1664525+1013904223)>>>0;return seed/4294967296}}
export async function buildWorld(e){
 const {scene,renderer}=e;
 const random=seeded(1994);
 const map=texture('asphalt-color.jpg'),normal=texture('asphalt-normal.jpg');
 const road=material('#b3b7bd',.84);road.map=map;road.normalMap=normal;road.normalScale.set(.65,.65);
 ribbon(-ROAD_WIDTH/2,ROAD_WIDTH/2,.12,road,scene);
 const white=material('#e7dcc4',.65),yellow=material('#d9a054',.7);
 ribbon(-6.25,-6.12,.14,white,scene);ribbon(6.12,6.25,.14,white,scene);
 ribbon(-.12,-.04,.145,yellow,scene);ribbon(.04,.12,.145,yellow,scene);
 const shoulder=material('#817e72',.9);ribbon(-7.5,-6.8,.07,shoulder,scene);ribbon(6.8,7.5,.07,shoulder,scene);
 // A continuous, naturally eroded island shoulder. No isolated block scenery.
 const rockmap=texture('rock-color.jpg',1),rocknormal=texture('rock-normal.jpg',1);
 const stone=material('#8b8b7b',.92);stone.map=rockmap;stone.normalMap=rocknormal;
 for(const side of [-1,1]){
  const verts=[],uvs=[],idx=[];const bands=8;
  for(let i=0;i<=N;i++){const s=samples[i%N];for(let b=0;b<=bands;b++){const d=side*(7.5+b*5);const x=s.p.x+s.n.x*d,z=s.p.z+s.n.z*d;
   const noise=Math.sin(x*.17)*Math.cos(z*.15)*1.3+Math.sin(z*.41+x*.21)*.4;
   const h=b===0?.04:(b===1?-.3:Math.max(-13,-(b-1)*2.1+noise));verts.push(x,h,z);uvs.push(x/5,z/5)}}
  for(let i=0;i<N;i++)for(let b=0;b<bands;b++){const a=i*(bands+1)+b;idx.push(a,a+1,a+bands+1,a+1,a+bands+2,a+bands+1)}
  const g=new THREE.BufferGeometry();g.setAttribute('position',new THREE.Float32BufferAttribute(verts,3));g.setAttribute('uv',new THREE.Float32BufferAttribute(uvs,2));g.setIndex(idx);g.computeVertexNormals();const m=stone.clone();m.side=THREE.DoubleSide;mesh(g,m,scene);
 }
 // Island interior rises out of the sea, with organic rock silhouettes.
 const rocks=[];for(let i=0;i<62;i++){const angle=random()*Math.PI*2,r=15+random()*68;const x=Math.sin(angle)*r,z=Math.cos(angle)*r-10;if(nearest(x,z).distance<27)continue;rocks.push({pos:[x,0,z],scale:[13+random()*18,8+random()*16,13+random()*18],rot:[0,random()*6,0]})}
 // A continuous interior landmass seats the scanned boulders into the island.
 {const v=[],uv=[],idx=[],rings=26;for(let j=0;j<=rings;j++){const r=j/rings;for(let i=0;i<=N;i++){const s=samples[i%N],x=(s.p.x-s.n.x*8)*r,z=-5+(s.p.z-s.n.z*8+5)*r;const h=(1-r)*5+Math.sin(r*Math.PI)*4+Math.sin(x*.08)*Math.cos(z*.07)*Math.sin(r*Math.PI)*1.8-.45;v.push(x,h,z);uv.push(x/7,z/7)}}for(let j=0;j<rings;j++)for(let i=0;i<N;i++){const a=j*(N+1)+i;idx.push(a,a+1,a+N+1,a+1,a+N+2,a+N+1)}const g=new THREE.BufferGeometry();g.setAttribute('position',new THREE.Float32BufferAttribute(v,3));g.setAttribute('uv',new THREE.Float32BufferAttribute(uv,2));g.setIndex(idx);g.computeVertexNormals();const mat=stone.clone();mat.color.set('#777b65');mat.side=THREE.DoubleSide;mesh(g,mat,scene)}
 const rockAsset=await new GLTFLoader().loadAsync(asset('rock_07.glb'));let rockSource;rockAsset.scene.updateMatrixWorld(true);rockAsset.scene.traverse(o=>{if(o.isMesh)rockSource=o});const rockGeo=rockSource.geometry.clone();rockGeo.applyMatrix4(rockSource.matrixWorld);rockGeo.computeBoundingBox();const rockSize=rockGeo.boundingBox.getSize(new THREE.Vector3());const rockCenter=rockGeo.boundingBox.getCenter(new THREE.Vector3());rockGeo.translate(-rockCenter.x,-rockGeo.boundingBox.min.y,-rockCenter.z);const unit=1/Math.max(rockSize.x,rockSize.y,rockSize.z);rockGeo.scale(unit,unit,unit);const scannedStone=rockSource.material;scannedStone.roughness=.94;scannedStone.color.set('#b3b7b4');instances(rockGeo,scannedStone,rocks,scene);
 // Guardrails follow the full circuit. Fine posts and cables use instancing.
 const steel=material('#bdc3ba',.43,.7),postPlacements=[];
 for(const side of [-1,1]){
  for(let i=0;i<N;i+=4){const s=samples[i];postPlacements.push({pos:[s.p.x+s.n.x*side*7, .5,s.p.z+s.n.z*side*7],scale:[1,1,1]})}
  for(const height of [.45,.85]){const pts=Array.from({length:181},(_,i)=>{const s=trackPoint(i/180);return s.p.clone().addScaledVector(s.n,side*7).add(new THREE.Vector3(0,height,0))});tube(pts,.045,steel,scene)}
 }
 instances(new THREE.CylinderGeometry(.045,.06,1,6),steel,postPlacements,scene);
 // Photographic impostors baked from CC0 botanical meshes. Crossed planes
 // preserve intricate needles while keeping a large treeline inexpensive.
 for(let variant=0;variant<3;variant++){
  const pineMap=new THREE.TextureLoader().load(asset(`pine-${variant}.webp`));pineMap.colorSpace=THREE.SRGBColorSpace;pineMap.anisotropy=8;
  const pineMat=new THREE.MeshBasicMaterial({map:pineMap,alphaTest:.08,side:THREE.DoubleSide,color:'#e2e3cb'});
  const placements=[];
  for(let i=0;i<26;i++){const s=trackPoint(random()),side=random()>.75?1:-1,d=side*(10+random()*4),h=3+random()*3.5;const x=s.p.x+s.n.x*d,z=s.p.z+s.n.z*d;const yaw=random()*Math.PI;for(const a of [yaw,yaw+Math.PI/2])placements.push({pos:[x,h/2-.6,z],scale:[h,h,1],rot:[0,a,0]})}
  instances(new THREE.PlaneGeometry(1,1),pineMat,placements,scene);
 }
 // Distant island ridges soften into atmospheric perspective.
 const mountains=[];for(let i=0;i<26;i++){const a=i/26*Math.PI*2,r=700+random()*250;mountains.push({pos:[Math.sin(a)*r,-12,Math.cos(a)*r],scale:[90+random()*120,25+random()*65,90+random()*90],rot:[0,random()*6,0]})}instances(rockGeo,material('#706d72'),mountains,scene);
 const waterMat=new THREE.ShaderMaterial({uniforms:{time:{value:0},sun:{value:new THREE.Vector3(-.6,.2,-.5).normalize()},color:{value:new THREE.Color('#386e78')}},vertexShader:`varying vec3 vWorld;void main(){vec4 w=modelMatrix*vec4(position,1.);vWorld=w.xyz;gl_Position=projectionMatrix*viewMatrix*w;}`,fragmentShader:`varying vec3 vWorld;uniform float time;uniform vec3 sun;uniform vec3 color;void main(){vec2 p=vWorld.xz;float a=sin(p.x*.12+p.y*.05+time*.6);float b=sin(p.y*.21-p.x*.08+time*.8);vec3 n=normalize(vec3(a*.12,1.,b*.1));vec3 view=normalize(cameraPosition-vWorld);float f=pow(1.-max(dot(n,view),0.),3.);float spec=pow(max(dot(reflect(-sun,n),view),0.),100.);float foam=.015*sin(p.x*2.+time)*sin(p.y*3.);vec3 c=mix(color,vec3(.66,.68,.64),f*.68)+vec3(1.,.7,.39)*spec*.8+foam;gl_FragColor=vec4(c,1.);}`});
 const ocean=mesh(new THREE.PlaneGeometry(4000,4000),waterMat,scene,0,-7,0);ocean.rotation.x=-Math.PI/2;ocean.castShadow=false;ocean.receiveShadow=false;
 const hemi=new THREE.HemisphereLight(0xc6d6ea,0x564e3c,.8);scene.add(hemi);
 const sun=new THREE.DirectionalLight(0xffbd83,1.8);sun.position.set(-130,80,-100);sun.castShadow=true;sun.shadow.mapSize.set(2048,2048);sun.shadow.camera.left=-32;sun.shadow.camera.right=32;sun.shadow.camera.top=32;sun.shadow.camera.bottom=-32;sun.shadow.camera.near=1;sun.shadow.camera.far=400;sun.shadow.normalBias=.035;sun.shadow.bias=-.0002;sun.shadow.radius=3;scene.add(sun,sun.target);
 const start=trackPoint(0);const finishMat=material('#e9e4d4');
 const checkers=[];for(let x=0;x<14;x++)for(let y=0;y<3;y++){if((x+y)%2===0)continue;const p=start.p.clone().addScaledVector(start.n,x-.5*13).addScaledVector(start.t,y*.8);checkers.push({pos:[p.x,.155,p.z],scale:[1,1,1],rot:[-Math.PI/2,0,-Math.atan2(start.t.x,start.t.z)]})}instances(new THREE.PlaneGeometry(1,.8),finishMat,checkers,scene);
 // A sculpted metal start gantry, plus warm practical lamps.
 const gate=new THREE.Group();gate.position.copy(start.p);gate.rotation.y=Math.atan2(start.t.x,start.t.z);scene.add(gate);
 for(const side of [-1,1]){mesh(new THREE.CylinderGeometry(.13,.18,7,12),steel,gate,side*7.8,3.5,0)}
 const bar=mesh(new THREE.CylinderGeometry(.14,.14,15.6,12),steel,gate,0,7,0);bar.rotation.z=Math.PI/2;
 const canvas=document.createElement('canvas');canvas.width=1024;canvas.height=128;const c=canvas.getContext('2d');c.fillStyle='#17292b';c.fillRect(0,0,1024,128);c.fillStyle='#f3e8d3';c.font='bold 54px sans-serif';c.textAlign='center';c.fillText('NEON DRIFT  /  COAST RUN',512,84);const sign=mesh(new THREE.PlaneGeometry(12.5,1.55),new THREE.MeshBasicMaterial({map:new THREE.CanvasTexture(canvas),side:THREE.DoubleSide}),gate,0,6.15,0);
 let hdr;
 try{hdr=await new RGBELoader().loadAsync(asset('sunset.hdr'));hdr.mapping=THREE.EquirectangularReflectionMapping;scene.background=hdr;scene.backgroundRotation.y=1.8;scene.environment=hdr;scene.environmentIntensity=.75;scene.backgroundIntensity=.55}catch{scene.background=new THREE.Color('#9a8984')}
 scene.fog=new THREE.FogExp2('#9d8d85',.0019);
 return {sun,waterMat,update(dt,time,position){waterMat.uniforms.time.value=time;sun.position.set(position.x-100,80,position.z-90);sun.target.position.set(position.x,0,position.z);sun.target.updateMatrixWorld()}};
}
