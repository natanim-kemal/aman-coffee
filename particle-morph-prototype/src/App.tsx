import { Suspense, useRef } from 'react'
import { Canvas, useFrame } from '@react-three/fiber'
import { ScrollControls, Scroll, useScroll } from '@react-three/drei'
import { motion } from 'framer-motion'
import { Experience } from './Experience'

// Section data
const sections = [
  {
    id: 'genesis',
    number: '01',
    title: 'GENESIS',
    accent: 'The Origin',
    subtitle: 'From the fertile highlands of Ethiopia, where coffee was first discovered. The seed of perfection awaits its journey.',
    align: 'left'
  },
  {
    id: 'aroma',
    number: '02',
    title: 'AROMA',
    accent: 'The Transformation',
    subtitle: 'The complex dance of roasting awakens dormant flavors. Heat unlocks the golden essence within.',
    align: 'right'
  },
  {
    id: 'tradition',
    number: '03',
    title: 'TRADITION',
    accent: 'The Ceremony',
    subtitle: 'The Jebena stands as a symbol of Ethiopian heritage. A ceremony of connection, honor, and timeless ritual.',
    align: 'left'
  }
]

// Navigation Dots Component (uses CSS for smooth transitions)
function NavDots() {
  return (
    <div className="nav-dots">
      {sections.map((section, index) => (
        <div
          key={section.id}
          className="nav-dot"
          data-section={index}
          title={section.title}
        />
      ))}
    </div>
  )
}

// Nav dot updater - runs inside the Canvas context using useFrame (no React state updates)
function NavDotUpdater() {
  const scroll = useScroll()
  const lastSection = useRef(-1)

  useFrame(() => {
    const offset = scroll.offset
    const sectionIndex = Math.min(Math.floor(offset * sections.length + 0.5), sections.length - 1)

    if (sectionIndex !== lastSection.current) {
      lastSection.current = sectionIndex

      // Update nav dots via DOM (faster than React state - no re-renders)
      document.querySelectorAll('.nav-dot').forEach((dot, i) => {
        dot.classList.toggle('active', i === sectionIndex)
      })
    }
  })

  return null
}

// Section Component - uses whileInView for smooth scroll-based animations
function Section({ section, index }: { section: typeof sections[0], index: number }) {
  const isLeft = section.align === 'left'

  return (
    <div
      className="overlay"
      style={{
        top: `${index * 100}vh`,
        justifyContent: index === 0 ? 'flex-start' : 'center',
        paddingTop: index === 0 ? '12vh' : undefined
      }}
    >
      <motion.div
        style={{
          alignSelf: isLeft ? 'flex-start' : 'flex-end',
          textAlign: isLeft ? 'left' : 'right',
          maxWidth: '600px'
        }}
        initial={{ opacity: 0, y: 40 }}
        whileInView={{ opacity: 1, y: 0 }}
        viewport={{ amount: 0.5, margin: "-10%" }}
        transition={{
          duration: 0.8,
          ease: [0.16, 1, 0.3, 1]
        }}
      >
        <div className="section-number">
          {section.number}
        </div>

        <h1 className="title">
          {section.title}
          <span className="title-accent">
            {section.accent}
          </span>
        </h1>

        <p className="subtitle">
          {section.subtitle}
        </p>
      </motion.div>

      {/* Scroll indicator only on first section */}
      {index === 0 && (
        <motion.div
          className="scroll-indicator"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 1.2, duration: 0.8 }}
        >
          <span className="scroll-text">Scroll to explore</span>
          <div className="scroll-line" />
        </motion.div>
      )}
    </div>
  )
}

function App() {
  return (
    <>
      <Canvas
        camera={{ position: [0, 0, 8], fov: 35 }}
        dpr={[1, 2]}
        gl={{
          antialias: true,
          alpha: false,
          powerPreference: 'high-performance'
        }}
      >
        <color attach="background" args={['#0d0906']} />
        <Suspense fallback={null}>
          <ScrollControls pages={3} damping={0.3}>
            {/* The 3D Scene */}
            <Experience />

            {/* Nav dot updater - efficient DOM-based updates */}
            <NavDotUpdater />

            {/* The HTML Overlay */}
            <Scroll html style={{ width: '100%' }}>
              {sections.map((section, index) => (
                <Section
                  key={section.id}
                  section={section}
                  index={index}
                />
              ))}
            </Scroll>

          </ScrollControls>
        </Suspense>
      </Canvas>

      {/* Navigation Dots (outside Canvas for proper z-index) */}
      <NavDots />
    </>
  )
}

export default App
