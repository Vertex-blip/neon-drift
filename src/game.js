// Deterministic driving and race rules. Distances are metres, time is seconds.
export const clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
export const wrapAngle=a=>Math.atan2(Math.sin(a),Math.cos(a));
export const approach=(a,b,k,dt)=>a+(b-a)*(1-Math.exp(-k*dt));
export function createCar(x=0,z=0,heading=0){return {x,z,heading,vx:0,vz:0,speed:0,steer:0,slip:0,drifting:false,collisionCooldown:0}}
export function stepCar(car,controls,dt){
 dt=clamp(dt,0,.05);
 const forwardX=Math.sin(car.heading),forwardZ=Math.cos(car.heading);
 const rightX=Math.cos(car.heading),rightZ=-Math.sin(car.heading);
 let longitudinal=car.vx*forwardX+car.vz*forwardZ;
 let lateral=car.vx*rightX+car.vz*rightZ;
 car.steer=approach(car.steer,controls.steer,5.5,dt);
 const acceleration=controls.throttle?19:0;
 const brake=controls.brake?32:0;
 longitudinal+=acceleration*dt;
 longitudinal=Math.max(0,longitudinal-(brake+1.5+longitudinal*longitudinal*.0038)*dt);
 if(controls.handbrake)longitudinal=Math.max(0,longitudinal-5*dt);
 longitudinal=clamp(longitudinal,0,64);
 const grip=controls.handbrake?1.7:9;
 lateral*=Math.exp(-grip*dt);
 const yawRate=car.steer*(.32+Math.min(longitudinal,38)*.025)*(controls.handbrake?1.5:1);
 if(longitudinal>.25)car.heading+=yawRate*dt;
 // Momentum remains in world space; steering rotates the tyre force frame.
 car.vx=forwardX*longitudinal+rightX*lateral;
 car.vz=forwardZ*longitudinal+rightZ*lateral;
 car.x+=car.vx*dt;car.z+=car.vz*dt;
 car.speed=Math.hypot(car.vx,car.vz);
 const velocityHeading=Math.atan2(car.vx,car.vz);
 car.slip=wrapAngle(velocityHeading-car.heading);
 car.drifting=car.speed>10&&Math.abs(car.slip)>.09;
 car.collisionCooldown=Math.max(0,car.collisionCooldown-dt);
 return car;
}
export function createRace(mode='sprint'){return {mode,time:0,penalty:0,lap:1,laps:2,nextGate:1,gates:16,passed:0,score:0,combo:1,driftTime:0,finished:false,won:false,lastLap:0,lapTimes:[]}}
export function stepRace(race,car,dt){
 if(race.finished)return;
 race.time+=dt;
 if(car.drifting){race.driftTime+=dt;race.combo=clamp(1+race.driftTime/2,1,5);race.score+=car.speed*Math.abs(car.slip)*race.combo*dt*30}else{race.driftTime=Math.max(0,race.driftTime-dt*2);race.combo=clamp(1+race.driftTime/2,1,5)}
 if(race.mode==='drift'&&race.time>=90){race.time=90;race.finished=true;race.won=race.score>=10000}
}
export function passGate(race,index){
 if(race.finished||index!==race.nextGate)return false;
 race.passed++;race.nextGate=(race.nextGate+1)%race.gates;
 if(index===0){race.lapTimes.push(race.time-race.lastLap);race.lastLap=race.time;if(race.mode==='sprint'){if(race.lap===race.laps){race.finished=true;race.won=true}else race.lap++}else race.lap++}
 return true;
}
export function hitBarrier(car,race,nx,nz){
 const toward=car.vx*nx+car.vz*nz;
 if(toward>0){car.vx-=toward*nx*1.4;car.vz-=toward*nz*1.4}
 car.vx*=.7;car.vz*=.7;
 if(car.collisionCooldown<=0){race.driftTime=0;race.combo=1;car.collisionCooldown=.8;return true}return false;
}
export function formatTime(seconds){if(!Number.isFinite(seconds))return '—';const ticks=Math.round(Math.max(0,seconds)*100),m=Math.floor(ticks/6000),s=(ticks%6000)/100;return `${String(m).padStart(2,'0')}:${s.toFixed(2).padStart(5,'0')}`}
