import { useRef, useMemo } from 'react'
import { useFrame } from '@react-three/fiber'
import * as THREE from 'three'
import { useScroll } from '@react-three/drei'

// Enhanced coffee particle shader with bloom and color transitions
const vertexShader = `
  uniform float uProgress;
  uniform float uTime;
  attribute vec3 aPositionTarget1;
  attribute vec3 aPositionTarget2;
  attribute float aSize;
  attribute float aRandom;
  
  varying float vAlpha;
  varying float vProgress;
  varying float vRandom;
  
  void main() {
    float t = uProgress;
    vProgress = t;
    vRandom = aRandom;
    
    vec3 mixedPosition;
    float turbulence = 0.0;
    
    // First transition: Bean (0) to Spiral (1)
    if (t <= 1.0) {
        float ease = t * t * (3.0 - 2.0 * t); // Smooth easing
        mixedPosition = mix(position, aPositionTarget1, ease);
        
        // Rising heat effect with individual particle timing
        float particlePhase = aRandom * 6.28;
        float heatWave = sin(mixedPosition.y * 2.5 + uTime * 1.5 + particlePhase) * 0.08;
        float heatWave2 = cos(mixedPosition.y * 1.8 + uTime * 1.2 + particlePhase) * 0.05;
        
        mixedPosition.x += heatWave * ease; 
        mixedPosition.z += heatWave2 * ease;
        
        // Add upward drift during transition
        mixedPosition.y += ease * aRandom * 0.3;
        
        turbulence = ease * 0.5;
    } 
    // Second transition: Spiral (1) to Jebena (2)
    else {
        float p = t - 1.0;
        float ease = p * p * (3.0 - 2.0 * p);
        mixedPosition = mix(aPositionTarget1, aPositionTarget2, ease);
        
        // Gentle breathing effect on final form
        if (p > 0.7) {
            float breathIntensity = (p - 0.7) / 0.3;
            float breath = sin(uTime * 1.5 + aRandom * 6.28) * 0.025 * breathIntensity;
            mixedPosition += normalize(mixedPosition) * breath;
        }
        
        // Fade out spiral turbulence
        if (p < 0.4) {
            float fadeOut = 1.0 - (p / 0.4);
            float particlePhase = aRandom * 6.28;
            mixedPosition.x += sin(mixedPosition.y * 2.0 + uTime + particlePhase) * 0.06 * fadeOut; 
            mixedPosition.z += cos(mixedPosition.y * 2.0 + uTime + particlePhase) * 0.04 * fadeOut;
        }
        
        turbulence = (1.0 - ease) * 0.3;
    }
    
    // Subtle floating motion for all particles
    float floatOffset = sin(uTime * 0.5 + aRandom * 10.0) * 0.02;
    mixedPosition.y += floatOffset;
    
    vec4 mvPosition = modelViewMatrix * vec4(mixedPosition, 1.0);
    gl_Position = projectionMatrix * mvPosition;
    
    // Dynamic size based on depth and motion
    float baseSize = aSize * 0.8 + 0.4;
    float motionSize = 1.0 + turbulence * 0.3;
    float depthFade = smoothstep(-15.0, -3.0, mvPosition.z);
    
    gl_PointSize = baseSize * motionSize * (50.0 / -mvPosition.z) * depthFade;
    
    // Pass alpha for edge particles
    vAlpha = depthFade * (0.7 + aRandom * 0.3);
  }
`

const fragmentShader = `
  uniform float uProgress;
  uniform float uTime;
  
  varying float vAlpha;
  varying float vProgress;
  varying float vRandom;
  
  void main() {
    float d = distance(gl_PointCoord, vec2(0.5));
    if (d > 0.5) discard;
    
    // Soft particle with bloom-like falloff
    float alpha = 1.0 - smoothstep(0.0, 0.5, d);
    float glow = exp(-d * 4.0) * 0.5; // Extra glow in center
    alpha = alpha + glow;
    
    // Color progression based on transition state
    // Bean: Rich coffee brown with gold hints
    // Spiral: Bright golden (roasting heat)
    // Jebena: Warm amber (tradition)
    
    vec3 colorBean = vec3(0.85, 0.65, 0.35);    // Coffee brown-gold
    vec3 colorSpiral = vec3(1.0, 0.82, 0.45);   // Bright gold (heat)
    vec3 colorJebena = vec3(0.95, 0.72, 0.38);  // Warm amber
    
    vec3 color;
    if (vProgress <= 1.0) {
        // Transition with some particles leading/lagging
        float adjustedProgress = clamp(vProgress + (vRandom - 0.5) * 0.3, 0.0, 1.0);
        color = mix(colorBean, colorSpiral, adjustedProgress);
        
        // Add heat shimmer effect
        float shimmer = sin(vRandom * 50.0 + uTime * 3.0) * 0.1 + 0.9;
        color *= shimmer;
    } else {
        float p = vProgress - 1.0;
        float adjustedProgress = clamp(p + (vRandom - 0.5) * 0.2, 0.0, 1.0);
        color = mix(colorSpiral, colorJebena, adjustedProgress);
    }
    
    // Subtle color variation per particle
    color += (vRandom - 0.5) * 0.08;
    
    gl_FragColor = vec4(color, alpha * vAlpha);
  }
`

// Background dust particles shader
const dustVertexShader = `
  uniform float uTime;
  attribute float aSize;
  attribute float aSpeed;
  
  varying float vAlpha;
  
  void main() {
    vec3 pos = position;
    
    // Slow drifting motion
    pos.y += sin(uTime * aSpeed * 0.2 + position.x) * 0.5;
    pos.x += cos(uTime * aSpeed * 0.15 + position.z) * 0.3;
    pos.z += sin(uTime * aSpeed * 0.1 + position.y) * 0.2;
    
    vec4 mvPosition = modelViewMatrix * vec4(pos, 1.0);
    gl_Position = projectionMatrix * mvPosition;
    
    gl_PointSize = aSize * (20.0 / -mvPosition.z);
    vAlpha = smoothstep(-20.0, -5.0, mvPosition.z) * 0.3;
  }
`

const dustFragmentShader = `
  varying float vAlpha;
  
  void main() {
    float d = distance(gl_PointCoord, vec2(0.5));
    if (d > 0.5) discard;
    
    float alpha = (1.0 - smoothstep(0.2, 0.5, d)) * vAlpha;
    vec3 color = vec3(0.85, 0.7, 0.5); // Warm dust color
    
    gl_FragColor = vec4(color, alpha);
  }
`

export const Experience = () => {
  const mesh = useRef<THREE.Points>(null!)
  const dustMesh = useRef<THREE.Points>(null!)
  const material = useRef<THREE.ShaderMaterial>(null!)
  const dustMaterial = useRef<THREE.ShaderMaterial>(null!)
  const scroll = useScroll()

  const count = 12000 // Increased particle count

  const [positions, targets1, targets2, sizes, randoms] = useMemo(() => {
    const positions = new Float32Array(count * 3) // Bean
    const targets1 = new Float32Array(count * 3)  // Spiral
    const targets2 = new Float32Array(count * 3)  // Jebena
    const sizes = new Float32Array(count)
    const randoms = new Float32Array(count)

    // SHAPE 1: COFFEE BEAN (Positions) - Enhanced density
    for (let i = 0; i < count; i++) {
      const theta = Math.random() * Math.PI * 2
      const phi = Math.acos(2 * Math.random() - 1)

      // Elongated Sphere with better distribution
      let r = 1.6 + Math.pow(Math.random(), 0.5) * 0.4
      let x = r * Math.sin(phi) * Math.cos(theta)
      let y = r * Math.sin(phi) * Math.sin(theta) * 1.6 // Elongate Y
      let z = r * Math.cos(phi) * 0.75 // Flatten Z

      // The "Crease" (Split the bean) - more pronounced
      const creaseStrength = 0.25
      if (x > 0) x += creaseStrength
      else x -= creaseStrength

      // Pinch the center more dramatically
      const pinchFactor = 1.0 - (1.0 - Math.abs(x) / 2.2) * 0.35
      z *= pinchFactor

      // Add surface texture variation
      const noise = (Math.random() - 0.5) * 0.08
      x += noise
      y += noise
      z += noise

      positions[i * 3] = x
      positions[i * 3 + 1] = y
      positions[i * 3 + 2] = z

      sizes[i] = 0.3 + Math.pow(Math.random(), 2) * 0.7
      randoms[i] = Math.random()
    }

    // SHAPE 2: AROMA / SPIRAL (Targets 1) - More dynamic
    for (let i = 0; i < count; i++) {
      const t = (i / count) * Math.PI * 14 // More rotations
      const heightProgress = i / count
      const radius = 0.3 + heightProgress * 2.8 // Tighter start, wider end

      // Varying density along height
      const densityFactor = Math.sin(heightProgress * Math.PI) * 0.5 + 0.5
      const spread = 0.4 * densityFactor

      const x = Math.cos(t) * radius + (Math.random() - 0.5) * spread
      const y = heightProgress * 11 - 5.5 // Rising up
      const z = Math.sin(t) * radius + (Math.random() - 0.5) * spread

      targets1[i * 3] = x
      targets1[i * 3 + 1] = y
      targets1[i * 3 + 2] = z
    }

    // SHAPE 3: ETHIOPIAN JEBENA (Targets 2) - More refined
    let i = 0

    // 1. Base Bulb (Sphere) (~55%) - Rounder, more defined
    const bodyCount = Math.floor(count * 0.55)
    for (; i < bodyCount; i++) {
      const theta = Math.random() * Math.PI * 2
      const phi = Math.acos(2 * Math.random() - 1)

      // Slightly bottom-heavy sphere
      const heightBias = 0.3 + 0.7 * Math.pow(Math.random(), 0.7)
      const r = 2.0 * heightBias + (Math.random() - 0.5) * 0.1

      targets2[i * 3] = r * Math.sin(phi) * Math.cos(theta)
      targets2[i * 3 + 1] = r * Math.sin(phi) * Math.sin(theta) - 1.8 // Lower
      targets2[i * 3 + 2] = r * Math.cos(phi)
    }

    // 2. Neck (Cylinder) (~18%) - Tapered
    const neckCount = i + Math.floor(count * 0.18)
    for (; i < neckCount; i++) {
      const theta = Math.random() * Math.PI * 2
      const h = Math.random()
      const heightPos = h * 2.8

      // Tapered neck - thinner at top
      const neckRadius = 0.55 - h * 0.15

      targets2[i * 3] = neckRadius * Math.cos(theta) + (Math.random() - 0.5) * 0.05
      targets2[i * 3 + 1] = heightPos + 0.2
      targets2[i * 3 + 2] = neckRadius * Math.sin(theta) + (Math.random() - 0.5) * 0.05
    }

    // 3. Lip/Rim (~5%)
    const lipCount = i + Math.floor(count * 0.05)
    for (; i < lipCount; i++) {
      const theta = Math.random() * Math.PI * 2
      const r = 0.45 + Math.random() * 0.15

      targets2[i * 3] = r * Math.cos(theta)
      targets2[i * 3 + 1] = 3.0 + (Math.random() - 0.5) * 0.1
      targets2[i * 3 + 2] = r * Math.sin(theta)
    }

    // 4. Spout (Angled Cylinder/Cone) (~12%)
    const spoutCount = i + Math.floor(count * 0.12)
    for (; i < spoutCount; i++) {
      const u = Math.random()
      const theta = Math.random() * Math.PI * 2

      const len = u * 2.8
      const r = 0.18 + u * 0.12 // Flare outward

      // Curved spout path
      const bx = -0.8 - len * 0.75
      const by = -0.8 + len * 0.9 + Math.pow(u, 2) * 0.3
      const bz = 0.0

      targets2[i * 3] = bx + r * Math.cos(theta) * 0.8
      targets2[i * 3 + 1] = by + r * Math.sin(theta) * 0.5
      targets2[i * 3 + 2] = bz + r * Math.sin(theta) * 0.6
    }

    // 5. Handle (Arc/Torus Segment) (Remainder) - Thicker, more defined
    for (; i < count; i++) {
      const u = Math.random() * Math.PI * 0.85 // Arc angle
      const rMajor = 1.9
      const rMinor = 0.18 + Math.random() * 0.05
      const theta = Math.random() * Math.PI * 2

      // Handle positioned on right side
      const cx = 0.9 + rMajor * Math.sin(u * 0.85)
      const cy = -0.3 + rMajor * Math.cos(u * 0.85)
      const cz = 0.0

      targets2[i * 3] = cx + rMinor * Math.cos(theta)
      targets2[i * 3 + 1] = cy + rMinor * Math.sin(theta)
      targets2[i * 3 + 2] = cz + rMinor * Math.sin(theta) * 0.8
    }

    return [positions, targets1, targets2, sizes, randoms]
  }, [])

  // Background dust particles
  const dustCount = 500
  const [dustPositions, dustSizes, dustSpeeds] = useMemo(() => {
    const positions = new Float32Array(dustCount * 3)
    const sizes = new Float32Array(dustCount)
    const speeds = new Float32Array(dustCount)

    for (let i = 0; i < dustCount; i++) {
      positions[i * 3] = (Math.random() - 0.5) * 30
      positions[i * 3 + 1] = (Math.random() - 0.5) * 20
      positions[i * 3 + 2] = (Math.random() - 0.5) * 15 - 5
      sizes[i] = 0.5 + Math.random() * 1.5
      speeds[i] = 0.5 + Math.random() * 1.5
    }

    return [positions, sizes, speeds]
  }, [])

  const uniforms = useMemo(() => ({
    uProgress: { value: 0 },
    uTime: { value: 0 }
  }), [])

  const dustUniforms = useMemo(() => ({
    uTime: { value: 0 }
  }), [])

  useFrame((state) => {
    const offset = scroll.offset // 0 to 1

    if (material.current) {
      const targetProgress = offset * 2.0

      material.current.uniforms.uProgress.value = THREE.MathUtils.lerp(
        material.current.uniforms.uProgress.value,
        targetProgress,
        0.025 // Smoother, more gradual transitions
      )
      material.current.uniforms.uTime.value = state.clock.getElapsedTime()
    }

    if (dustMaterial.current) {
      dustMaterial.current.uniforms.uTime.value = state.clock.getElapsedTime()
    }

    if (mesh.current) {
      // Premium slow rotation
      mesh.current.rotation.y = -state.clock.getElapsedTime() * 0.08
    }
  })

  return (
    <>
      {/* Background dust particles */}
      <points ref={dustMesh}>
        <bufferGeometry>
          <bufferAttribute
            attach="attributes-position"
            args={[dustPositions, 3]}
          />
          <bufferAttribute
            attach="attributes-aSize"
            args={[dustSizes, 1]}
          />
          <bufferAttribute
            attach="attributes-aSpeed"
            args={[dustSpeeds, 1]}
          />
        </bufferGeometry>
        <shaderMaterial
          ref={dustMaterial}
          vertexShader={dustVertexShader}
          fragmentShader={dustFragmentShader}
          uniforms={dustUniforms}
          transparent
          depthWrite={false}
        />
      </points>

      {/* Main particle morph */}
      <points ref={mesh} rotation-z={0.22}>
        <bufferGeometry>
          <bufferAttribute
            attach="attributes-position"
            args={[positions, 3]}
          />
          <bufferAttribute
            attach="attributes-aPositionTarget1"
            args={[targets1, 3]}
          />
          <bufferAttribute
            attach="attributes-aPositionTarget2"
            args={[targets2, 3]}
          />
          <bufferAttribute
            attach="attributes-aSize"
            args={[sizes, 1]}
          />
          <bufferAttribute
            attach="attributes-aRandom"
            args={[randoms, 1]}
          />
        </bufferGeometry>
        <shaderMaterial
          ref={material}
          vertexShader={vertexShader}
          fragmentShader={fragmentShader}
          uniforms={uniforms}
          transparent
          depthWrite={false}
          blending={THREE.AdditiveBlending}
        />
      </points>
    </>
  )
}
